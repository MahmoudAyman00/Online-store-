import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_screen.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import 'wishlist_screen.dart';
import 'search_screen.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/ui.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedCategoryId;
  String selectedCategoryName = 'Welcome to Online Store';
  String? searchQuery;

  Future<String> _fetchUsername() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'Guest';

      final userDoc = await FirebaseFirestore.instance
          .collection('Users Collection')
          .doc(currentUser.uid)
          .get();

      return userDoc.data()?['username']?.isNotEmpty == true
          ? userDoc.data()!['username']
          : 'Unknown User';
    } catch (e) {
      debugPrint('Error fetching username: $e');
      return 'Guest';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Categories').get();
      return snapshot.docs.map((doc) => {
            'id': doc.id,
            'name': doc['name'],
            'imageUrl': doc['imageUrl'] ?? 'https://via.placeholder.com/150',
          }).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  void _refresh() {
    FocusScope.of(context).unfocus();
    setState(() {}); // إعادة بناء الـ FutureBuilder → إعادة الجلب
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedCategoryName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: FutureBuilder<String?>(
        future: _fetchUsername(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Drawer(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final username = snapshot.data ?? 'Guest';
          return Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  accountName: Center(
                    child: Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  accountEmail: const SizedBox.shrink(),
                  currentAccountPicture: const Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.person, color: AppColors.primary),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen()), // الانتقال إلى شاشة Profile
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_cart,
                      color: AppColors.primary),
                  title: const Text('Cart'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CartScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long,
                      color: AppColors.primary),
                  title: const Text('My Orders'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OrdersScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_border,
                      color: AppColors.primary),
                  title: const Text('Wishlist'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WishlistScreen()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: AppColors.error),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
                const Divider(),
                SwitchListTile(
                  secondary: Icon(
                    ThemeController.mode.value == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: AppColors.primary,
                  ),
                  title: const Text('Dark mode'),
                  value:
                      ThemeController.mode.value == ThemeMode.dark,
                  onChanged: (_) {
                    ThemeController.toggle();
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(AppRadius.card),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SearchScreen()),
                    );
                  },
                  child: IgnorePointer(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search all products',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
              ),
              FutureBuilder<List<Map<String, dynamic>>>( 
                future: _fetchCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: AppLoading(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: AppError(
                        message: 'Error loading categories',
                        onRetry: () => setState(() {}),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: AppEmpty(message: 'No categories available'),
                    );
                  }

                  List<Map<String, dynamic>> categories = snapshot.data!;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = responsiveColumns(
                        constraints.maxWidth,
                        tileMinWidth: 160,
                      );
                      return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      var category = categories[index];
                      return FadeIn(
                        index: index % 12,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductScreen(
                                  categoryId: category['id'],
                                  categoryName: category['name'],
                                ),
                              ),
                            );
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: CachedNetworkImage(
                                    imageUrl: category['imageUrl'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(
                                      color: context.softFill,
                                      child: const Center(
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    ),
                                    errorWidget:
                                        (context, url, error) =>
                                            Container(
                                      color: context.softFill,
                                      child: Icon(
                                          Icons.category,
                                          color: context.muted,
                                          size: 40),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  child: Text(
                                    category['name'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: context.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
