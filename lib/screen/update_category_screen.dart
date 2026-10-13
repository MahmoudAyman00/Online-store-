import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateCategoryScreen extends StatefulWidget {
  @override
  _UpdateCategoryScreenState createState() => _UpdateCategoryScreenState();
}

class _UpdateCategoryScreenState extends State<UpdateCategoryScreen> {
  final _categoryDescriptionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCategoryId;

  void _clearFields() {
    _categoryDescriptionController.clear();
    setState(() {
      _selectedCategoryId = null;
    });
  }

  @override
  void dispose() {
    _categoryDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoryDescription(String categoryId) async {
    try {
      final doc = await _firestore.collection('Categories').doc(categoryId).get();
      if (doc.exists) {
        _categoryDescriptionController.text = doc['description'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading category description!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _updateCategory() async {
    try {
      final description = _categoryDescriptionController.text.trim();

      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please select a category!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      if (description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Category description is required!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      await _firestore.collection('Categories').doc(_selectedCategoryId).update({
        'description': description,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Category updated successfully!'),
        backgroundColor: Colors.green,
      ));
      _clearFields();  // تفريغ الحقول
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error updating category!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Category'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Update Category',
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
                    // قائمة اختيار الفئة
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore.collection('Categories').get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Text('Error loading categories');
                        }
                        List<DropdownMenuItem<String>> categoryItems =
                            snapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList();

                        return DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          hint: const Text('Select Category'),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                            if (value != null) {
                              _loadCategoryDescription(value);  // تحميل الوصف عند اختيار الفئة
                            }
                          },
                          items: categoryItems,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // حقل وصف الفئة
                    TextField(
                      controller: _categoryDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Category Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // زر التحديث
                    ElevatedButton.icon(
                      onPressed: _updateCategory,
                      icon: const Icon(Icons.update),
                      label: const Text('Update Category'),
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
