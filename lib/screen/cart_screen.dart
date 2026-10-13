import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/checkout_service.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import 'receipt_screen.dart'; // استيراد شاشة الإيصال

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isCheckingOut = false;

  Future<List<Map<String, dynamic>>> _fetchCartItems() async {
    if (currentUser == null) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('Users Collection')
        .doc(currentUser!.uid)
        .collection('Cart')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'productId': (data['productId'] ?? '').toString(),
        'name': (data['name'] ?? 'Unknown').toString(),
        'price': (data['price'] as num?)?.toDouble() ?? 0.0,
        'quantity': (data['quantity'] as num?)?.toInt() ?? 0,
        'imageUrl': (data['imageUrl'] ?? '').toString(),
      };
    }).where((e) =>
        (e['productId'] as String).isNotEmpty &&
        (e['quantity'] as int) > 0).toList();
  }

  Future<void> _updateQuantity(String docId, int newQuantity) async {
    if (currentUser == null) return;

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('Users Collection')
          .doc(currentUser!.uid)
          .collection('Cart');

      if (newQuantity > 0) {
        await cartRef.doc(docId).update({'quantity': newQuantity});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity updated successfully.')),
        );
      } else {
        await cartRef.doc(docId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from cart.')),
        );
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update cart. Please try again.')),
      );
    }
  }

  double _calculateTotal(List<Map<String, dynamic>> items) {
    return items.fold(
        0.0,
        (sum, item) =>
            sum +
            ((item['price'] as num).toDouble() *
                (item['quantity'] as num).toInt()));
  }


  /// Checkout: يحاول Function السيرفر أولاً، ويسقط على Transaction
  /// المحلية الموثقة لو الـ Function غير منشورة بعد (فترة انتقالية).
  Future<void> _checkout(List<Map<String, dynamic>> cartItems) async {
    if (_isCheckingOut) return;
    // جرّب السيرفر أولاً
    try {
      setState(() => _isCheckingOut = true);
      final result = await CheckoutService().checkout(cartItems);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            cartItems: result.items,
            totalPrice: result.totalPrice,
            orderId: result.orderId,
          ),
        ),
      );
      return;
    } on CheckoutException catch (e) {
      // لو الـ Function غير منشورة (متوقع قبل النشر) → fallback محلي.
      // الكود الرسمي للدالة الناقصة هو not-found / unimplemented.
      final code = e.code.toLowerCase().replaceAll('_', '-');
      final notDeployed =
          code == 'not-found' || code == 'unimplemented' || code == 'internal';
      if (!notDeployed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      // else: اكمل للـ fallback المحلي بالأسفل
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
    await _checkoutLocal(cartItems);
  }

  /// Fallback محلي آمن (أسعار تُعاد قراءتها داخل Transaction).
  /// يُستخدم فقط حتى نشر functions/checkout — احذفه بعد الاعتماد الكامل على السيرفر.
  Future<void> _checkoutLocal(List<Map<String, dynamic>> cartItems) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }
    if (cartItems.isEmpty || _isCheckingOut) return;

    setState(() => _isCheckingOut = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final cartRef = firestore
          .collection('Users Collection')
          .doc(user.uid)
          .collection('Cart');
      final orderRef = firestore.collection('Transactions').doc();

      List<Map<String, dynamic>> verifiedItems = [];
      double verifiedTotal = 0;

      await firestore.runTransaction((tx) async {
        // 1) كل القراءات أولاً (شرط Firestore Transactions)
        final Map<String, DocumentSnapshot> productDocs = {};
        for (final item in cartItems) {
          final pid = (item['productId'] ?? '').toString();
          if (pid.isEmpty) throw Exception('Invalid product in cart.');
          productDocs[pid] =
              await tx.get(firestore.collection('products').doc(pid));
        }

        // 2) تحقق من السعر والمخزون وابنِ قائمة موثقة
        final List<Map<String, dynamic>> items = [];
        double total = 0;
        for (final item in cartItems) {
          final pid = (item['productId'] ?? '').toString();
          final snap = productDocs[pid]!;
          if (!snap.exists) {
            throw Exception('${item['name']} is no longer available.');
          }
          final pdata = snap.data() as Map<String, dynamic>;
          final serverPrice = (pdata['price'] as num).toDouble();
          final stock = (pdata['stock'] as num?)?.toInt() ?? 0;
          final qty = (item['quantity'] as num).toInt();
          if (qty <= 0) throw Exception('Invalid quantity.');
          if (stock < qty) {
            throw Exception(
                'Not enough stock for ${pdata['name'] ?? item['name']} (available: $stock).');
          }
          items.add({
            'productId': pid,
            'name': (pdata['name'] ?? item['name']).toString(),
            'price': serverPrice,
            'quantity': qty,
            'imageUrl': (pdata['imageUrl'] ?? item['imageUrl'] ?? '').toString(),
          });
          total += serverPrice * qty;
        }
        if (items.isEmpty) throw Exception('Cart is empty.');
        if (total <= 0) throw Exception('Invalid total.');

        // 3) الكتابة: طلب + مخزون + مسح سلة — Atomic
        tx.set(orderRef, {
          'userId': user.uid,
          'items': items
              .map((e) => {
                    'productId': e['productId'],
                    'name': e['name'],
                    'price': e['price'],
                    'quantity': e['quantity'],
                  })
              .toList(),
          'totalPrice': total,
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (final v in items) {
          final pid = v['productId'] as String;
          final snap = productDocs[pid]!;
          final pdata = snap.data() as Map<String, dynamic>;
          final stock = (pdata['stock'] as num?)?.toInt() ?? 0;
          final sold = (pdata['soldCount'] as num?)?.toInt() ?? 0;
          final qty = v['quantity'] as int;
          tx.update(firestore.collection('products').doc(pid), {
            'stock': stock - qty,
            'soldCount': sold + qty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        for (final item in cartItems) {
          tx.delete(cartRef.doc((item['id'] ?? '').toString()));
        }

        verifiedItems = items;
        verifiedTotal = total;
      });

      if (!mounted) return;
      // نجاح — انتقل للإيصال بالبيانات الموثقة من السيرفر (مش بيانات السلة)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            cartItems: verifiedItems,
            totalPrice: verifiedTotal,
            orderId: orderRef.id,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
      // أعد تحميل السلة بعد العملية (ناجحة كانت أو لا)
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cart'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>( 
        future: _fetchCartItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const AppEmpty(
                message: 'Your cart is empty.',
                icon: Icons.shopping_cart_outlined);
          }

          final cartItems = snapshot.data!;
          final totalPrice = _calculateTotal(cartItems);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return FadeIn(
                      index: index % 10,
                      child: Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 16),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: item['imageUrl'],
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: context.softFill,
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.image_not_supported,
                                    color: context.muted),
                          ),
                        ),
                        title: Text(
                          item['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        subtitle: Text(
                          'Price: \$${(item['price'] as num).toDouble().toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.primary),
                              onPressed: () => _updateQuantity(
                                  item['id'], item['quantity'] - 1),
                            ),
                            Text('${item['quantity']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppColors.primary),
                              onPressed: () => _updateQuantity(
                                  item['id'], item['quantity'] + 1),
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Total Price: \$${totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.onSurface),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isCheckingOut ? null : () => _checkout(cartItems),
                    child: _isCheckingOut
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text('Checkout'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
