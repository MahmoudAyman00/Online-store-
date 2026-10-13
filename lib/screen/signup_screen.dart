import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/validators.dart' as v;
import '../core/responsive.dart';
import '../core/theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String value) => v.isStrongPassword(value);

  void _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;
    if (_selectedDate == null) {
      _showErrorDialog('Please select your birth date.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      await user?.updateDisplayName(_nameController.text.trim());
      // تحقق إيميل — يقلل الحسابات الوهمية والسبام
      try {
        await user?.sendEmailVerification();
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('Users Collection')
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'username': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'birthDate': Timestamp.fromDate(_selectedDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
        'emailVerified': false,
      });

      // اخرج المستخدم لحد ما يفعّل الإيميل (يمنع دخول غير موثق)
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorDialog(_getErrorMessage(e));
    } catch (_) {
      if (mounted) _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak (min 8 chars with letters + numbers)';
      case 'email-already-in-use':
        return 'Email is already in use';
      case 'invalid-email':
        return 'Invalid email format';
      case 'operation-not-allowed':
        return 'Email signup is disabled. Contact support';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      default:
        return 'An unexpected error occurred';
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your email'),
        content: const Text(
            'Account created! We sent a verification link to your email. Verify it, then login.'),
        actions: [
          TextButton(
            child: const Text('Login'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // تحديد تاريخ الميلاد من خلال DatePicker
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = '${picked.toLocal()}'.split(' ')[0]; // تنسيق التاريخ
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Account'),
        centerTitle: true,
      ),
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
                child: Form(
                key: _formKey,
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
                            'https://cdn-icons-png.flaticon.com/512/3503/3503508.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // حقل الاسم
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Full Name',
                              prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // حقل رقم الهاتف
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Phone Number',
                              prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (!RegExp(r'^\+?[0-9\s-]{8,15}$').hasMatch(v)) {
                                return 'Enter a valid phone (8-15 digits)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // حقل البريد الإلكتروني
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Email Address',
                              prefixIcon: const Icon(Icons.email, color: AppColors.primary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email address';
                              } else if (!RegExp(r"^[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // حقل كلمة المرور
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Password (min 8 + letters & numbers)',
                              prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (!_isStrongPassword(v)) {
                                return 'Min 8 chars with letters + numbers';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // تأكيد كلمة المرور
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                    _obscureConfirm = !_obscureConfirm),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // حقل تاريخ الميلاد
                          // حقل تاريخ الميلاد
TextFormField(
  controller: _birthDateController,
  decoration: InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: 'Date of Birth',
    prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
  ),
  readOnly: true,
  onTap: _selectBirthDate, // عند الضغط على الحقل سيتم اختيار التاريخ
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please select your birth date';
    }
    return null;
  },
),
                          const SizedBox(height: 30),

                          // زر التسجيل
                          ElevatedButton(
                            onPressed: _isLoading ? null : _createAccount,
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
                                    'Sign Up',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
