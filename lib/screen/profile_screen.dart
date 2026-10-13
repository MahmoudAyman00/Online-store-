import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'edit_profile_screen.dart';
import 'package:intl/intl.dart'; // إضافة هذه المكتبة لتنسيق التاريخ
import '../core/firestore_paths.dart';
import '../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchUserProfile();
  }

  void _refresh() {
    setState(() => _profileFuture = _fetchUserProfile());
  }

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(currentUser.uid)
          .get();

      return userDoc.data();
    } catch (e) {
      return null;
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: 'Edit profile',
            onPressed: _openEdit,
          ),
          // إضافة أيقونة home في الـ AppBar
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () {
              // الانتقال إلى شاشة HomeScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text('Error loading profile information.'));
          }

          final userData = snapshot.data!;
          
          String formattedBirthdate = 'N/A';
if (userData['birthDate'] != null && userData['birthDate'] is Timestamp) {
  Timestamp timestamp = userData['birthDate'];
  DateTime birthDate = timestamp.toDate();
  formattedBirthdate = DateFormat('yyyy-MM-dd').format(birthDate); // تنسيق التاريخ حسب الحاجة
} else {
  formattedBirthdate = 'N/A'; // في حالة عدم وجود قيمة أو النوع غير صحيح
}



          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _ProfileTile(
                    icon: Icons.person,
                    label: 'Name',
                    value: '${userData['username'] ?? 'N/A'}'),
                _ProfileTile(
                    icon: Icons.email,
                    label: 'Email',
                    value: '${userData['email'] ?? 'N/A'}'),
                _ProfileTile(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: '${userData['phone'] ?? 'N/A'}'),
                _ProfileTile(
                    icon: Icons.cake,
                    label: 'Birthdate',
                    value: formattedBirthdate),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.softFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(label,
            style: TextStyle(
                fontSize: 13, color: context.muted)),
        subtitle: Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.onSurface)),
      ),
    );
  }
}

