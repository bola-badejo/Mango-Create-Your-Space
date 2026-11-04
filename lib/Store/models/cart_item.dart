// lib/Models/customModel/cart_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String productId;
  final String vendorId;
  final String vendorName;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;
  final Map<String, dynamic>? productDetails;
  final DateTime addedAt;
  final Map<String, String>? selectedVariant; // For tracking selected variant
  
  CartItem({
    required this.id,
    required this.productId,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.productDetails,
    required this.addedAt,
    this.selectedVariant,
  });
  
  double get totalPrice => price * quantity;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'productDetails': productDetails,
      'selectedVariant': selectedVariant,
      'addedAt': addedAt,
    };
  }
  
  factory CartItem.fromMap(String id, Map<String, dynamic> data) {
    return CartItem(
      id: id,
      productId: data['productId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      name: data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      quantity: data['quantity'] ?? 1,
      productDetails: data['productDetails'],
      selectedVariant: Map<String, String>.from(data['selectedVariant'] ?? {}),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CartSummary {
  final int itemCount;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final double discount;
  
  CartSummary({
    required this.itemCount,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    this.discount = 0,
  });
  
  factory CartSummary.fromCartItems(List<CartItem> items) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final shipping = subtotal > 50 ? 0.0 : 5.99;
    final tax = subtotal * 0.075; // 7.5% tax
    final total = subtotal + shipping + tax;
    
    return CartSummary(
      itemCount: items.length,
      subtotal: subtotal,
      shipping: shipping,
      tax: tax,
      total: total,
    );
  }
}