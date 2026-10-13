import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';

class DeleteProductScreen extends StatefulWidget {
  @override
  _DeleteProductScreenState createState() => _DeleteProductScreenState();
}

class _DeleteProductScreenState extends State<DeleteProductScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedCategoryId;
  String? _selectedProductId;
  List<DropdownMenuItem<String>> _categories = [];
  List<DropdownMenuItem<String>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadCategories(); // تحميل الفئات عند بدء الشاشة
  }

  // تحميل الفئات من Firestore
  Future<void> _loadCategories() async {
    try {
      final snapshot = await _firestore.collection('Categories').get();
      setState(() {
        _categories = snapshot.docs.map((doc) {
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(doc['name']),
          );
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading categories!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // تحميل المنتجات بناءً على الفئة المختارة
  Future<void> _loadProducts(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      setState(() {
        _products = snapshot.docs.map((doc) {
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(doc['name']),
          );
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading products!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // حذف المنتج
Future<void> _deleteProduct() async {
  if (_selectedProductId == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Please select a product to delete!'),
      backgroundColor: Colors.red,
    ));
    return;
  }

  try {
    await _firestore.collection('products').doc(_selectedProductId).delete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Product deleted successfully!'),
      backgroundColor: Colors.green,
    ));
    setState(() {
      _selectedProductId = null;  // إعادة تعيين حقل المنتج
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Error deleting product!'),
      backgroundColor: Colors.red,
    ));
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delete Product'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Dropdown لعرض الفئات
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              hint: Text('Select Category'),
              decoration: InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _selectedProductId = null; // إعادة تعيين المنتج المحدد
                  _products.clear(); // مسح المنتجات السابقة
                });
                if (value != null) {
                  _loadProducts(value); // تحميل المنتجات الخاصة بالفئة
                }
              },
              items: _categories,
            ),
            SizedBox(height: 20),

            // Dropdown لعرض المنتجات بناءً على الفئة المحددة
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              hint: Text('Select Product'),
              decoration: InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                });
              },
              items: _products,
            ),
            SizedBox(height: 20),

            // زر لحذف المنتج
            ElevatedButton.icon(
              onPressed: _deleteProduct,
              icon: Icon(Icons.delete),
              label: Text('Delete Product'),
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
