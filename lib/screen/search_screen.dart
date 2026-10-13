import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/firestore_paths.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/cart_service.dart';
import '../data/models.dart';
import 'product_details_screen.dart';

/// Global search across ALL products (home search opens here).
/// No composite index needed: single fetch + local filter.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Product> _all = [];
  bool _isLoading = true;
  String? _error;

  String get _query => _controller.text.trim().toLowerCase();

  List<Product> get _results => _query.isEmpty
      ? []
      : _all
          .where((p) => p.name.toLowerCase().contains(_query))
          .take(50)
          .toList();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _controller.addListener(_onChanged);
    _load();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    try {
      // Single capped fetch, filtered locally — catalog-scale friendly
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.products)
          .limit(300)
          .get();
      if (!mounted) return;
      setState(() {
        _all = snap.docs.map(Product.fromDoc).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load products.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search all products',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const AppLoading();
    if (_error != null) {
      return AppError(message: _error!, onRetry: _load);
    }
    if (_query.isEmpty) {
      return const AppEmpty(
        message: 'Type to search all products.',
        icon: Icons.search,
      );
    }
    final results = _results;
    if (results.isEmpty) {
      return AppEmpty(message: 'No results for "$_query".');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final p = results[index];
        return FadeIn(
          index: index % 10,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailsScreen(product: p),
                  ),
                );
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: p.imageUrl.isEmpty
                      ? 'https://via.placeholder.com/150'
                      : p.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.softFill,
                    child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Icon(
                      Icons.image_not_supported,
                      color: context.muted),
                ),
              ),
              title: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                '\$${p.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_shopping_cart,
                    color: AppColors.primary),
                tooltip: p.stock <= 0 ? 'Out of stock' : 'Add to cart',
                onPressed: p.stock <= 0
                    ? null
                    : () => CartService.addToCart(context, p),
              ),
            ),
          ),
        );
      },
    );
  }
}
