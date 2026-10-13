import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productStockController = TextEditingController();
  final _productImageUrlController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategoryId;

  Future<void> _addProduct() async {
    try {
      // قراءة الحقول
      final name = _productNameController.text.trim();
      final description = _productDescriptionController.text.trim();
      final imageUrl = _productImageUrlController.text.trim();
      final categoryId = _selectedCategoryId;
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      final createdAt = Timestamp.now();
      final updatedAt = createdAt;

      // التحقق من الحقول النصية الفارغة
      if (name.isEmpty ||
          description.isEmpty ||
          imageUrl.isEmpty ||
          categoryId == null ||
          adminId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please fill all fields!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // التحقق من الحقول العددية
      double? price;
      int? stock;

      try {
        price = double.parse(_productPriceController.text.trim());
        stock = int.parse(_productStockController.text.trim());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Price and stock must be valid numbers!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // التحقق النهائي إذا كانت الحقول العددية غير صالحة
      if (price <= 0 || stock < 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Price must be greater than 0 and stock cannot be negative!'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // إضافة المنتج إلى Firestore
      await _firestore.collection('products').add({
        'adminId': adminId,
        'category': categoryId,
        'categoryId': categoryId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'price': price,
        'rating': 0,
        'soldCount': 0,
        'stock': stock,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Product added successfully!'),
        backgroundColor: Colors.green,
      ));
      _clearFields(); // مسح الحقول بعد الإضافة
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding product!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _clearFields() {
    _productNameController.clear();
    _productDescriptionController.clear();
    _productPriceController.clear();
    _productStockController.clear();
    _productImageUrlController.clear();
    setState(() {
      _selectedCategoryId = null;
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productStockController.dispose();
    _productImageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Product'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Add Product',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _productDescriptionController,
                      decoration: InputDecoration(
                          labelText: 'Product Description',
                          border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _productPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Product Price',
                          border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _productImageUrlController,
                      decoration: InputDecoration(
                          labelText: 'Product Image Url',
                          border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _productStockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'Stock Quantity',
                          border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 10),
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore.collection('Categories').get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Text('Error loading categories');
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
                          hint: Text('Select Category'),
                          decoration:
                              InputDecoration(border: OutlineInputBorder()),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                          items: categoryItems,
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _addProduct,
                      icon: Icon(Icons.add),
                      label: Text('Add Product'),
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
