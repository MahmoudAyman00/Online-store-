import 'package:cloud_firestore/cloud_firestore.dart';

/// Null-safe, type-tolerant models. Firestore may store numbers as int or
/// double — every numeric field goes through `(x as num)`.

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description = '',
    this.categoryId = '',
    this.stock = 0,
    this.soldCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String categoryId;
  final int stock;
  final int soldCount;
  final DateTime? createdAt;

  factory Product.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime? created;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) created = rawCreated.toDate();
    return Product(
      id: doc.id,
      name: (data['name'] ?? 'Unnamed').toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? data['category'] ?? '').toString(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      soldCount: (data['soldCount'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'description': description,
        'categoryId': categoryId,
        'stock': stock,
        'soldCount': soldCount,
      };
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.description = '',
  });

  final String id;
  final String name;
  final String imageUrl;
  final String description;

  factory Category.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Category(
      id: doc.id,
      name: (data['name'] ?? 'Unnamed').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
    );
  }
}

class CartItem {
  const CartItem({
    required this.docId,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  final String docId;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  factory CartItem.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CartItem(
      docId: doc.id,
      productId: (data['productId'] ?? '').toString(),
      name: (data['name'] ?? 'Unknown').toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      imageUrl: (data['imageUrl'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl,
      };
}
