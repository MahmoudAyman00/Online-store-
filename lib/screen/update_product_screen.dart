import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateProductScreen extends StatefulWidget {
  @override
  _UpdateProductScreenState createState() => _UpdateProductScreenState();
}

class _UpdateProductScreenState extends State<UpdateProductScreen> {
  final _productDescriptionController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productStockController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCategoryId;
  String? _selectedProductId;

  List<DropdownMenuItem<String>> _categories = [];
  List<DropdownMenuItem<String>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

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

  Future<void> _loadProductDetails(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _productDescriptionController.text = data['description'] ?? '';
        _productPriceController.text = data['price']?.toString() ?? '';
        _productStockController.text = data['stock']?.toString() ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading product details!'),
        backgroundColor: Colors.red,
      ));
    }
  }

void _clearFields() {
  _productDescriptionController.clear();
  _productPriceController.clear();
  _productStockController.clear();
  setState(() {
    _selectedCategoryId = null;
    _selectedProductId = null;  // إعادة تعيين حقل المنتج
  });
}

  @override
  void dispose() {
    _productDescriptionController.dispose();
    _productPriceController.dispose();
    _productStockController.dispose();
    super.dispose();
  }

Future<void> _updateProduct() async {
  try {
    final description = _productDescriptionController.text.trim();
    final stockInput = _productStockController.text.trim();
    final priceInput = _productPriceController.text.trim();

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please select a product!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    double? price;
    int? stock;

    try {
      price = priceInput.isNotEmpty ? double.parse(priceInput) : null;
      stock = stockInput.isNotEmpty ? int.parse(stockInput) : null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Price and stock must be valid numbers!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (price != null && price <= 0 || stock != null && stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Price must be greater than 0 and stock cannot be negative!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    await _firestore.collection('products').doc(_selectedProductId).update({
      if (description.isNotEmpty) 'description': description,
      if (price != null) 'price': price,
      if (stock != null) 'stock': stock,
      'updatedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Product updated successfully!'),
      backgroundColor: Colors.green,
    ));
    _clearFields();  // تفريغ الحقول
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Error updating product!'),
      backgroundColor: Colors.red,
    ));
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Product'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Update Product',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              hint: Text('Select Category'),
              decoration: InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                  _selectedProductId = null;
                  _products.clear();
                });
                if (value != null) {
                  _loadProducts(value);
                }
              },
              items: _categories,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              hint: Text('Select Product'),
              decoration: InputDecoration(border: OutlineInputBorder()),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                });
                if (value != null) {
                  _loadProductDetails(value);
                }
              },
              items: _products,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _productDescriptionController,
              decoration: InputDecoration(
                labelText: 'Product Description',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _productPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Product Price',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _productStockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _updateProduct,
              icon: Icon(Icons.update),
              label: Text('Update Product'),
            ),
          ],
        ),
      ),
    );
  }
}
