import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/firestore_paths.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../data/repositories.dart';

/// Buyer's saved products. Add to cart moves the item (keeps a copy
/// in wishlist? No — moves: adds to cart AND removes from wishlist).
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _wishlist = WishlistRepository();

  Future<void> _moveToCart(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final product = Product(
      id: (data['productId'] ?? '').toString(),
      name: (data['name'] ?? 'Unknown').toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: (data['imageUrl'] ?? '').toString(),
    );
    if (product.id.isEmpty) return;

    final cartRef = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .collection('Cart');
    try {
      final existing = await cartRef
          .where('productId', isEqualTo: product.id)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        await cartRef.add({
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': 1,
          'imageUrl': product.imageUrl,
        });
      } else {
        final doc = existing.docs.first;
        final qty =
            ((doc.data()['quantity'] as num?)?.toInt() ?? 0) + 1;
        await cartRef.doc(doc.id).update({'quantity': qty});
      }
      await _wishlist.remove(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} moved to cart!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: const AppEmpty(message: 'Please login first.'),
      );
    }
    final col = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .collection('Wishlist');
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            return const AppEmpty(
                message: 'Failed to load wishlist.');
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const AppEmpty(
              message: 'Wishlist is empty.',
              icon: Icons.favorite_border,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>? ?? {};
              final price =
                  (data['price'] as num?)?.toDouble() ?? 0;
              return FadeIn(
                index: index % 10,
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl:
                            (data['imageUrl'] ?? '').toString(),
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
                      (data['name'] ?? 'Unknown').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                              Icons.add_shopping_cart,
                              color: AppColors.primary),
                          tooltip: 'Move to cart',
                          onPressed: () => _moveToCart(data),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error),
                          tooltip: 'Remove',
                          onPressed: () => _wishlist.remove(
                              (data['productId'] ?? '').toString()),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
