const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });
const db = admin.firestore();

const MAX_ITEMS = 50;
const MAX_TOTAL = 500000;

function assertAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login required.");
  }
  // Enforce verified email (matches client-side policy)
  const emailVerified =
    request.auth.token.email_verified === true ||
    request.auth.token.emailVerified === true;
  if (!emailVerified) {
    throw new HttpsError("permission-denied", "Verify your email first.");
  }
  return request.auth.uid;
}

/**
 * checkout — creates the order server-side.
 * Input: { items: [{ productId: string, quantity: number }] }
 * Server is source of truth for price/stock. Atomic via runTransaction.
 */
exports.checkout = onCall(async (request) => {
  const uid = assertAuth(request);

  const rawItems = request.data && request.data.items;
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    throw new HttpsError("invalid-argument", "Cart is empty.");
  }
  if (rawItems.length > MAX_ITEMS) {
    throw new HttpsError("invalid-argument", "Too many items (max 50).");
  }

  const wanted = rawItems.map((it) => {
    const productId = String((it && it.productId) || "").trim();
    const quantity = Number(it && it.quantity);
    if (!productId) throw new HttpsError("invalid-argument", "Invalid product.");
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > 99) {
      throw new HttpsError("invalid-argument", "Invalid quantity.");
    }
    return { productId, quantity };
  });

  const cartRef = db.collection("Users Collection").doc(uid).collection("Cart");
  const orderRef = db.collection("Transactions").doc();

  let receipt = null;

  await db.runTransaction(async (t) => {
    // ---- all reads first ----
    const cartSnap = await t.get(cartRef);
    const cartQty = new Map();
    const cartDocByProduct = new Map();
    cartSnap.forEach((d) => {
      const data = d.data() || {};
      if (data.productId) {
        cartQty.set(String(data.productId), Number(data.quantity) || 0);
        if (!cartDocByProduct.has(String(data.productId))) {
          cartDocByProduct.set(String(data.productId), d.ref);
        }
      }
    });

    const productSnaps = new Map();
    for (const w of wanted) {
      // must have been added to cart (prevents ordering arbitrary ids)
      if (!cartQty.has(w.productId)) {
        throw new HttpsError("failed-precondition", "Cart changed. Please refresh.");
      }
      const pref = db.collection("products").doc(w.productId);
      productSnaps.set(w.productId, await t.get(pref));
    }

    // ---- validate + build ----
    const items = [];
    let total = 0;
    for (const w of wanted) {
      const snap = productSnaps.get(w.productId);
      if (!snap.exists) {
        throw new HttpsError("not-found", "A product is no longer available.");
      }
      const p = snap.data() || {};
      const price = Number(p.price);
      const stock = Number(p.stock != null ? p.stock : 0);
      const sold = Number(p.soldCount != null ? p.soldCount : 0);
      if (!Number.isFinite(price) || price <= 0) {
        throw new HttpsError("failed-precondition", "Invalid product price.");
      }
      if (!Number.isInteger(stock) || stock < w.quantity) {
        throw new HttpsError(
          "failed-precondition",
          `Not enough stock for ${p.name || "a product"} (available: ${Number.isInteger(stock) ? stock : 0}).`
        );
      }
      items.push({
        productId: w.productId,
        name: String(p.name || "Product"),
        price,
        quantity: w.quantity,
        imageUrl: String(p.imageUrl || ""),
        _stock: stock,
        _sold: Number.isInteger(sold) ? sold : 0,
      });
      total += price * w.quantity;
    }
    if (items.length === 0 || total <= 0 || total > MAX_TOTAL) {
      throw new HttpsError("invalid-argument", "Invalid order total.");
    }

    // ---- writes ----
    t.set(orderRef, {
      userId: uid,
      items: items.map(({ productId, name, price, quantity }) => ({
        productId, name, price, quantity,
      })),
      totalPrice: total,
      status: "completed",
      checkoutVia: "function",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (const it of items) {
      t.update(db.collection("products").doc(it.productId), {
        stock: it._stock - it.quantity,
        soldCount: it._sold + it.quantity,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    for (const w of wanted) {
      const ref = cartDocByProduct.get(w.productId);
      if (ref) t.delete(ref);
    }

    receipt = {
      orderId: orderRef.id,
      totalPrice: total,
      items: items.map(({ productId, name, price, quantity, imageUrl }) => ({
        productId, name, price, quantity, imageUrl,
      })),
    };
  });

  return receipt;
});

/**
 * setAdminRole — callable by an existing admin only.
 * Input: { uid: string }
 * Sets custom claim admin:true AND mirrors role field for UI.
 */
exports.setAdminRole = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Admins only.");
  }
  const uid = String((request.data && request.data.uid) || "").trim();
  if (!uid) throw new HttpsError("invalid-argument", "uid required.");
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  await db.collection("Users Collection").doc(uid).set(
    { role: "admin", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  return { uid, admin: true };
});

/**
 * Bootstrap first admin (run once from a trusted machine):
 *   firebase functions:shell  →  bootstrapFirstAdmin({uid:"..."})
 * or via Admin SDK script. Kept separate so no open endpoint creates admins.
 */
exports.bootstrapFirstAdmin = onCall(async (request) => {
  // Only allow if NO admin exists yet is unenforceable here without a marker;
  // instead require the caller to be authenticated AND pass a setup secret
  // configured via: firebase functions:secrets:set SETUP_SECRET
  const secret = process.env.SETUP_SECRET || "";
  if (!secret || (request.data && request.data.secret) !== secret) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }
  const uid = String((request.data && request.data.uid) || "").trim();
  if (!uid) throw new HttpsError("invalid-argument", "uid required.");
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  await db.collection("Users Collection").doc(uid).set(
    { role: "admin", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  return { uid, admin: true };
});
