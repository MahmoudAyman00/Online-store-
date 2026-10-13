import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/firestore_paths.dart';
import 'models.dart';

/// Shared cart writes (used by product grid, search, wishlist flows).
class CartService {
  const CartService._();

  static Future<bool> addToCart(
      BuildContext context, Product product,
      {int quantity = 1}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return false;
    }
    final cartRef = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(user.uid)
        .collection('Cart');
    final qty = quantity < 1 ? 1 : quantity;
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
          'quantity': qty,
          'imageUrl': product.imageUrl,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${product.name} added to cart!')),
          );
        }
      } else {
        final doc = existing.docs.first;
        final newQty =
            ((doc.data()['quantity'] as num?)?.toInt() ?? 0) + qty;
        await cartRef.doc(doc.id).update({'quantity': newQty});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Updated quantity of ${product.name}.')),
          );
        }
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to add ${product.name}. Try again.')),
        );
      }
      return false;
    }
  }
}
