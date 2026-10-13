import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/firestore_paths.dart';
import 'models.dart';

/// All Firestore access for products/categories goes through here.
/// No widget should import collection-name strings directly anymore.
class ProductRepository {
  ProductRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const pageSize = 20;

  Future<List<Category>> fetchCategories() async {
    final snap = await _db.collection(FirestorePaths.categories).get();
    return snap.docs.map(Category.fromDoc).toList();
  }

  /// First page of a category. Returns the docs + last doc for paging.
  /// Uses where + limit only (no composite index required).
  Future<ProductPage> fetchProductsPage({
    required String categoryId,
    DocumentSnapshot? startAfter,
  }) async {
    Query q = _db
        .collection(FirestorePaths.products)
        .where('categoryId', isEqualTo: categoryId)
        .limit(pageSize);
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await q.get();
    return ProductPage(
      products: snap.docs.map(Product.fromDoc).toList(),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == pageSize,
    );
  }

  Future<Product?> fetchProduct(String id) async {
    final doc = await _db.collection(FirestorePaths.products).doc(id).get();
    if (!doc.exists) return null;
    return Product.fromDoc(doc);
  }
}

class ProductPage {
  const ProductPage({
    required this.products,
    required this.lastDoc,
    required this.hasMore,
  });
  final List<Product> products;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;
}

/// Single place for current-user profile reads (was copy-pasted in
/// home_screen + admin_screen).
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc =
        await _db.collection(FirestorePaths.users).doc(user.uid).get();
    return doc.data();
  }

  Future<String> fetchUsername({String fallback = 'Guest'}) async {
    try {
      final data = await fetchCurrentProfile();
      final name = (data?['username'] as String?)?.trim() ?? '';
      return name.isNotEmpty ? name : fallback;
    } catch (_) {
      return fallback;
    }
  }
}

/// Wishlist stored per-user (doc id = productId). Works fully offline of
/// admin flows; rules allow owners only (deploy rules to activate).
class WishlistRepository {
  WishlistRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference? _col() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _db
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .collection('Wishlist');
  }

  Stream<Set<String>> watchIds() {
    final col = _col();
    if (col == null) return Stream.value(<String>{});
    return col.snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<bool> toggle(Product product) async {
    final col = _col();
    if (col == null) return false;
    final doc = col.doc(product.id);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
      return false;
    }
    await doc.set({
      'productId': product.id,
      'name': product.name,
      'price': product.price,
      'imageUrl': product.imageUrl,
      'addedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<void> remove(String productId) async {
    final col = _col();
    if (col == null) return;
    await col.doc(productId).delete();
  }
}
