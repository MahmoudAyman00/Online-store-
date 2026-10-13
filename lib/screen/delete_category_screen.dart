import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';

class DeleteCategoryScreen extends StatefulWidget {
  @override
  _DeleteCategoryScreenState createState() => _DeleteCategoryScreenState();
}

class _DeleteCategoryScreenState extends State<DeleteCategoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCategoryId;

  Future<void> _deleteCategory() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a category to delete!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    try {
      await _firestore.collection('Categories').doc(_selectedCategoryId).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Category deleted successfully!'),
        backgroundColor: Colors.green,
      ));
      setState(() {
        _selectedCategoryId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error deleting category!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Category'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('Categories').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Text('Error loading categories');
                }
                final categories = snapshot.data!.docs.map((doc) {
                  final name = doc['name'] ?? 'Unnamed Category';
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(name),
                  );
                }).toList();

                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  hint: Text('Select Category'),
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  items: categories,
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _deleteCategory,
              icon: Icon(Icons.delete),
              label: Text('Delete Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
