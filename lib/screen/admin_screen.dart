import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../core/checkout_service.dart' show isCurrentUserAdmin;
import '../core/theme.dart';
import 'add_product_screen.dart';
import 'add_category_screen.dart';
import 'update_category_screen.dart';
import 'update_product_screen.dart';
import 'delete_category_screen.dart';
import 'delete_product_screen.dart';
import 'best_selling_chart_screen.dart';
import 'transaction_screen.dart'; 
import 'feedback_screen.dart'; 


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _checkingRole = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  /// حماية واجهة فقط — الحماية الحقيقية في firestore.rules.
  /// تمنع فتح شاشة الأدمن بالتنقل المباشر من حساب غير أدمن.
  Future<void> _verifyAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }
      // Claims أولاً (الحل النهائي)، ثم role من Firestore للفترة الانتقالية
      if (await isCurrentUserAdmin()) {
        if (!mounted) return;
        setState(() {
          _isAdmin = true;
          _checkingRole = false;
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('Users Collection')
          .doc(user.uid)
          .get();
      final role =
          (doc.data()?['role'] as String?)?.trim().toLowerCase() ?? '';
      if (!mounted) return;
      if (role == 'admin') {
        setState(() {
          _isAdmin = true;
          _checkingRole = false;
        });
      } else {
        // حساب غير أدمن حاول يفتح الأدمن — رجعه للـ Home
        if (!mounted) return;
        setState(() => _checkingRole = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: admins only')),
        );
      }
    } catch (_) {
      _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
  Future<String> _fetchUsername() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'Admin';

      final userDoc = await FirebaseFirestore.instance
          .collection('Users Collection')
          .doc(currentUser.uid)
          .get();

      return userDoc.data()?['username']?.isNotEmpty == true
          ? userDoc.data()!['username']
          : 'Admin';
    } catch (e) {
      debugPrint('Error fetching username: $e');
      return 'Admin';
    }
  }

  void _logout(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    if (_checkingRole || !_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        centerTitle: true,
      ),
      drawer: FutureBuilder<String?>(
        future: _fetchUsername(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Drawer(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final username = snapshot.data ?? 'Admin';

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
                  accountName: Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Center(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  accountEmail: SizedBox.shrink(),
                  currentAccountPicture: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: 50,
                    ),
                  ),
                ),
                // Add Product
                ListTile(
                  leading: Icon(Icons.add, color: AppColors.primary),
                  title: Text('Add Product', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddProductScreen()),
                    );
                  },
                ),
                // Add Category
                ListTile(
                  leading: Icon(Icons.category, color: AppColors.primary),
                  title: Text('Add Category', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddCategoryScreen()),
                    );
                  },
                ),
                // Update Category
                ListTile(
                  leading: Icon(Icons.edit, color: AppColors.primary),
                  title: Text('Update Category', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UpdateCategoryScreen()),
                    );
                  },
                ),
                // Update Product
                ListTile(
                  leading: Icon(Icons.update, color: AppColors.primary),
                  title: Text('Update Product', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UpdateProductScreen()),
                    );
                  },
                ),
                // Delete Category
                ListTile(
                  leading: Icon(Icons.category, color: AppColors.error),
                  title: Text('Delete Category', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeleteCategoryScreen()),
                    );
                  },
                ),
                // Delete Product
                ListTile(
                  leading: Icon(Icons.production_quantity_limits, color: AppColors.error),
                  title: Text('Delete Product', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DeleteProductScreen()),
                    );
                  },
                ),
                Divider(),
                // View Transaction Report
                ListTile(
                  leading: Icon(Icons.report, color: AppColors.primary),
                  title: Text('Transaction Report', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TransactionScreen()),
                    );
                  },
                ),
                // Manage Feedback
                ListTile(
                  leading: Icon(Icons.feedback, color: AppColors.accent),
                  title: Text('Manage Feedback', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FeedbackScreen()),
                    );
                  },
                ),
                // Best Selling Products Chart
                ListTile(
                  leading: Icon(Icons.bar_chart, color: AppColors.primary),
                  title: Text('Best Selling Products', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BestSellingChartScreen()),
                    );
                  },
                ),
                Divider(),
                SwitchListTile(
                  secondary: Icon(
                    ThemeController.mode.value == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: AppColors.primary,
                  ),
                  title:
                      Text('Dark mode', style: TextStyle(fontSize: 16)),
                  value:
                      ThemeController.mode.value == ThemeMode.dark,
                  onChanged: (_) {
                    ThemeController.toggle();
                    setState(() {});
                  },
                ),
                Divider(),
                // Log out
                ListTile(
                  leading: Icon(Icons.logout, color: AppColors.primary),
                  title: Text('Logout', style: TextStyle(fontSize: 16)),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          );
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
