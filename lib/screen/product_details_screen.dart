import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/cart_service.dart';
import '../data/models.dart';
import '../data/repositories.dart';

/// Full product details: gallery image, price, stock, description,
/// quantity stepper + add to cart + wishlist toggle.
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});
  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _wishlist = WishlistRepository();
  StreamSubscription<Set<String>>? _sub;
  bool _isFav = false;
  int _qty = 1;
  bool _adding = false;

  Product get p => widget.product;
  int get _maxQty => p.stock <= 0 ? 1 : p.stock.clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _sub = _wishlist.watchIds().listen((ids) {
      if (mounted) setState(() => _isFav = ids.contains(p.id));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _add() async {
    if (_adding || p.stock <= 0) return;
    setState(() => _adding = true);
    await CartService.addToCart(context, p, quantity: _qty);
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? AppColors.error : null,
            ),
            tooltip: 'Wishlist',
            onPressed: () => _wishlist.toggle(p),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: CachedNetworkImage(
                imageUrl: p.imageUrl.isEmpty
                    ? 'https://via.placeholder.com/600'
                    : p.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: context.softFill,
                  child: const Center(
                      child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: context.softFill,
                  child: Icon(Icons.image_not_supported,
                      size: 64, color: context.muted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${p.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (p.stock > 0
                              ? AppColors.success
                              : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.stock > 0
                          ? 'In stock (${p.stock})'
                          : 'Out of stock',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.stock > 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.description.isEmpty
                        ? 'No description available.'
                        : p.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: context.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _qty > 1
                                  ? () =>
                                      setState(() => _qty--)
                                  : null,
                            ),
                            SizedBox(
                              width: 32,
                              child: Text('$_qty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _qty < _maxQty
                                  ? () =>
                                      setState(() => _qty++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              (p.stock <= 0 || _adding) ? null : _add,
                          icon: _adding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_shopping_cart),
                          label: Text(
                              'Add ${(_qty * p.price).toStringAsFixed(2)}\$'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
