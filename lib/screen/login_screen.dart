import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'admin_screen.dart';
// استيراد مكتبة SharedPreferences لتخزين حالة "تذكرني"
import 'package:shared_preferences/shared_preferences.dart';
import '../core/responsive.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMeState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // تحميل حالة "تذكرني" — نخزن الإيميل فقط، الباسورد لا يُخزن أبداً.
  // الجلسة نفسها يحفظها FirebaseAuth تلقائياً.
  Future<void> _loadRememberMeState() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final savedEmail = prefs.getString('rememberedEmail') ?? '';

    // Back-compat: امسح أي باسورد كان متخزن قبل الإصلاح الأمني
    await prefs.remove('password');
    await prefs.remove('email');

    if (!mounted) return;
    setState(() {
      _rememberMe = rememberMe;
      if (_rememberMe && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
    });

    // لو المستخدم طلب عدم التذكر وكان فيه جلسة قديمة، اخرج منها
    if (!rememberMe && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // حفظ حالة "تذكرني" — الإيميل فقط للملء التلقائي
  Future<void> _saveRememberMeState(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', _rememberMe);
    if (_rememberMe && email.isNotEmpty) {
      await prefs.setString('rememberedEmail', email);
    } else {
      await prefs.remove('rememberedEmail');
    }
    // تأكيد عدم وجود باسورد مخزن لأي سبب
    await prefs.remove('password');
    await prefs.remove('email');
  }

  Future<void> _navigateByRole(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('Users Collection')
        .doc(uid)
        .get();

    if (!mounted) return;

    final data = userDoc.data();
    if (!userDoc.exists || data == null || data['role'] == null) {
      await FirebaseAuth.instance.signOut();
      _showErrorDialog('Account profile is missing. Please contact support.');
      return;
    }

    final String role = (data['role'] as String).trim().toLowerCase();
    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _signIn() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // امنع دخول الإيميلات غير المفعلة (يمنع الحسابات الوهمية)
      await userCredential.user?.reload();
      final freshUser = FirebaseAuth.instance.currentUser;
      if (freshUser != null && !freshUser.emailVerified) {
        try {
          await freshUser.sendEmailVerification();
        } catch (_) {}
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showErrorDialog(
              'Please verify your email first. We sent you a new link.');
        }
        return;
      }

      // احفظ التفضيل دائماً (سواء true أو false) عشان إلغاء التفعيل يمسح الإيميل
      await _saveRememberMeState(email);

      await _navigateByRole(userCredential.user!.uid);
    } on FirebaseAuthException catch (e) {
      String message = 'Invalid login credentials';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Invalid login credentials';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Check your connection';
      }
      if (mounted) _showErrorDialog(message);
    } catch (_) {
      if (mounted) _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // صفحة إعادة تعيين كلمة المرور
  void _resetPassword() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: resetEmailController,
            decoration: const InputDecoration(hintText: 'Enter your email'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: resetEmailController.text.trim(),
                  );
                  Navigator.of(context).pop();
                  _showErrorDialog('Password reset email sent');
                } on FirebaseAuthException {
                  _showErrorDialog('Error sending reset email');
                }
              },
              child: const Text('Send Reset Email'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ).then((_) => resetEmailController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.authTop, AppColors.authBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CenteredConstrained(
                maxWidth: 480,
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Image.network(
                          'https://cdn-icons-png.flaticon.com/512/2438/2438078.png',
                          width: 120,
                          height: 120,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Email Address',
                          icon: Icons.email,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock,
                          isPassword: true,
                        ),
                        const SizedBox(height: 25),
                        // تذكرني
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (bool? value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                              },
                            ),
                            const Text(
                              'Remember Me',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                        const SizedBox(height: 15),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SignUpScreen()),
                            );
                          },
                          child: const Text(
                            'Create New Account',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 15),
                        // رابط إعادة تعيين كلمة المرور
                        TextButton(
                          onPressed: _resetPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }
}
