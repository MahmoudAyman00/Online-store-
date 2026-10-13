import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AddCategoryScreen extends StatefulWidget {
  @override
  _AddCategoryScreenState createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _categoryNameController = TextEditingController();
  final _categoryDescriptionController = TextEditingController();
  final _categoryImageUrlController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addCategory() async {
    try {
      final categoryName = _categoryNameController.text.trim();
      final categoryDescription = _categoryDescriptionController.text.trim();
      final categoryImageUrl = _categoryImageUrlController.text.trim();

      if (categoryName.isEmpty ||
          categoryDescription.isEmpty ||
          categoryImageUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill all fields!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final createdAt = Timestamp.now();
      final updatedAt = createdAt;

      await _firestore.collection('Categories').add({
        'name': categoryName,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'description': categoryDescription,
        'imageUrl': categoryImageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Category added successfully!'),
        backgroundColor: Colors.green,
      ));
      _clearFields();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error adding category!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _clearFields() {
    _categoryNameController.clear();
    _categoryDescriptionController.clear();
    _categoryImageUrlController.clear();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _categoryDescriptionController.dispose();
    _categoryImageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Category'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Add Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _categoryNameController,
                      decoration: const InputDecoration(
                          labelText: 'Category Name',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _categoryDescriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Category Description',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _categoryImageUrlController,
                      decoration: const InputDecoration(
                          labelText: 'Category Image Url',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _addCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Category'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
