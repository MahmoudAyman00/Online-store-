import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/firestore_paths.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import 'product_details_screen.dart';

class ProductScreen extends StatefulWidget {
  final String? categoryId;
  final String categoryName;

  const ProductScreen({super.key, this.categoryId, required this.categoryName});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _repo = ProductRepository();
  final _wishlist = WishlistRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<Set<String>>? _wishlistSub;

  List<Product> _products = [];
  Set<String> _wishlistIds = {};
  _SortMode _sort = _SortMode.recommended;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  Timer? _debounce;

  String get _query => _searchController.text.trim().toLowerCase();

  // المنتجات بعد فلترة البحث (الاسم أو الـ barcode/id) + الترتيب المختار
  List<Product> get _visible {
    final base = _query.isEmpty
        ? _products
        : _products
            .where((p) =>
                p.name.toLowerCase().contains(_query) ||
                p.id.toLowerCase() == _query)
            .toList();
    final sorted = [...base];
    switch (_sort) {
      case _SortMode.priceAsc:
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortMode.priceDesc:
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortMode.newest:
        sorted.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        break;
      case _SortMode.recommended:
        break;
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _wishlistSub = _wishlist.watchIds().listen((ids) {
      if (mounted) setState(() => _wishlistIds = ids);
    });
    _loadFirst();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // عند البحث: حمّل كل منتجات الفئة (cap) حتى تشمل النتائج أصنافاً لم تُحمّل بعد
      if (_query.isNotEmpty) {
        _loadAllForSearch();
      } else {
        setState(() {}); // مجرد إعادة فلترة/عرض
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading &&
        _query.isEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchProductsPage(
        categoryId: widget.categoryId ?? '',
      );
      if (!mounted) return;
      setState(() {
        _products = page.products;
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
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

  Future<void> _loadMore() async {
    if (!_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repo.fetchProductsPage(
        categoryId: widget.categoryId ?? '',
        startAfter: _lastDoc,
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...page.products];
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// تحميل كل الفئة (بحد أقصى 10 صفحات) عند البحث — الكتالوج صغير
  /// ولا يوجد index لبحث سيرفر-side، فالفلترة محلية بعد التحميل.
  Future<void> _loadAllForSearch() async {
    if (_isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      var pages = 0;
      while (_hasMore && pages < 10) {
        final page = await _repo.fetchProductsPage(
          categoryId: widget.categoryId ?? '',
          startAfter: _lastDoc,
        );
        if (!mounted) return;
        _products = [..._products, ...page.products];
        _lastDoc = page.lastDoc;
        _hasMore = page.hasMore;
        pages++;
      }
    } catch (_) {
      // تجاهل — اعرض ما تم تحميله
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    _lastDoc = null;
    _hasMore = true;
    await _loadFirst();
  }

  void addToCart(Product product) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }

    final cartRef = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(currentUser.uid)
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} added to cart!')),
        );
      } else {
        final doc = existing.docs.first;
        final qty = ((doc.data()['quantity'] as num?)?.toInt() ?? 0) + 1;
        await cartRef.doc(doc.id).update({'quantity': qty});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated quantity of ${product.name}.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to add ${product.name} to cart. Try again.')),
      );
    }
  }

  Future<void> _toggleWishlist(Product product) async {
    final added = await _wishlist.toggle(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added
            ? '${product.name} saved to wishlist!'
            : '${product.name} removed from wishlist.'),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _wishlistSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (mode) {
              if (mounted) setState(() => _sort = mode);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SortMode.recommended,
                child: Text('Recommended'),
              ),
              PopupMenuItem(
                value: _SortMode.priceAsc,
                child: Text('Price: low to high'),
              ),
              PopupMenuItem(
                value: _SortMode.priceDesc,
                child: Text('Price: high to low'),
              ),
              PopupMenuItem(
                value: _SortMode.newest,
                child: Text('Newest'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoading();
    }
    if (_error != null && _products.isEmpty) {
      return AppError(message: _error!, onRetry: _loadFirst);
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return const AppEmpty(message: 'No products found.');
    }
    // أعمدة متجاوبة حسب عرض الشاشة بدل 5 ثابتة
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth ~/ 180).clamp(2, 6);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: visible.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= visible.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return FadeIn(
              index: index % 12,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(AppRadius.card),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(
                          product: visible[index]),
                    ),
                  );
                },
                child: _ProductCard(
                  product: visible[index],
                  isFav: _wishlistIds.contains(visible[index].id),
                  onFav: () => _toggleWishlist(visible[index]),
                  onAdd: () => addToCart(visible[index]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SortMode {
  const _SortMode._(this.label);
  final String label;
  static const recommended = _SortMode._('Recommended');
  static const priceAsc = _SortMode._('PriceAsc');
  static const priceDesc = _SortMode._('PriceDesc');
  static const newest = _SortMode._('Newest');
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(
      {required this.product,
      required this.isFav,
      required this.onFav,
      required this.onAdd});

  final Product product;
  final bool isFav;
  final VoidCallback onFav;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: product.imageUrl.isEmpty
                      ? 'https://via.placeholder.com/150'
                      : product.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: context.softFill,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: context.softFill,
                    child: Icon(Icons.image_not_supported,
                        color: context.muted),
                  ),
                ),
                if (product.stock <= 0)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Out of stock',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onFav,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isFav
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: isFav
                              ? AppColors.error
                              : context.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(
              product.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: context.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart,
                      color: AppColors.primary),
                  onPressed: product.stock <= 0 ? null : onAdd,
                  tooltip: 'Add to cart',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
