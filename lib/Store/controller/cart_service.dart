// lib/Services/cart_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Store/models/cart_item.dart';

class CartService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get cart collection reference for current user
  CollectionReference<Map<String, dynamic>> get _cartCollection {
    if (_currentUserId == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('cart');
  }

  // Add item to cart
  Future<void> addToCart({
    required String productId,
    required String vendorId,
    required String vendorName,
    required String name,
    required double price,
    required String imageUrl,
    Map<String, dynamic>? productDetails,
    int quantity = 1,
  }) async {
    try {
      // Check if item already exists in cart
      final existingItem = await _cartCollection
          .where('productId', isEqualTo: productId)
          .where('vendorId', isEqualTo: vendorId)
          .limit(1)
          .get();

      if (existingItem.docs.isNotEmpty) {
        // Update quantity if item exists
        final doc = existingItem.docs.first;
        final currentQuantity = doc['quantity'] ?? 1;
        await _cartCollection.doc(doc.id).update({
          'quantity': currentQuantity + quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new item to cart
        await _cartCollection.add({
          'productId': productId,
          'vendorId': vendorId,
          'vendorName': vendorName,
          'name': name,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': quantity,
          'productDetails': productDetails,
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error adding to cart: $e');
      rethrow;
    }
  }

  // Get cart items stream
  Stream<List<CartItem>> getCartItems() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _cartCollection.orderBy('addedAt', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs.map((doc) {
          return CartItem.fromMap(doc.id, doc.data());
        }).toList();
      },
    );
  }

  Future<bool> validateCartItems(List<CartItem> items) async {
    try {
      for (var item in items) {
        final product = await _firestore
            .collection('products')
            .doc(item.productId)
            .get();

        if (!product.exists) {
          await removeFromCart(item.id);
          return false;
        }

        final stockQuantity = product.data()?['stockQuantity'] ?? 0;
        if (stockQuantity < item.quantity) {
          await updateQuantity(item.id, stockQuantity);
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error validating cart: $e');
      return false;
    }
  }

  // Update item quantity
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
    } else {
      await _cartCollection.doc(cartItemId).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Remove item from cart
  Future<void> removeFromCart(String cartItemId) async {
    await _cartCollection.doc(cartItemId).delete();
  }

  // Clear entire cart
  Future<void> clearCart() async {
    final items = await _cartCollection.get();
    final batch = _firestore.batch();

    for (var doc in items.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get cart summary
  Future<CartSummary> getCartSummary() async {
    final items = await _cartCollection.get();
    final cartItems = items.docs.map((doc) {
      return CartItem.fromMap(doc.id, doc.data());
    }).toList();

    return CartSummary.fromCartItems(cartItems);
  }

  // Get cart item count
  Stream<int> getCartItemCount() {
    if (_currentUserId == null) {
      return Stream.value(0);
    }

    return _cartCollection.snapshots().map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        count += int.parse(doc['quantity'] ?? 1);
      }
      return count;
    });
  }

  // Checkout - Move cart items to orders
  Future<Map<String, dynamic>> checkout({
    required String shippingAddress,
    required String paymentMethod,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final cartItems = await _cartCollection.get();
      if (cartItems.docs.isEmpty) {
        throw Exception('Cart is empty');
      }

      final items = cartItems.docs.map((doc) {
        return CartItem.fromMap(doc.id, doc.data());
      }).toList();

      final summary = CartSummary.fromCartItems(items);

      // Create order
      final orderRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('orders')
          .doc();

      final orderData = {
        'orderId': orderRef.id,
        'userId': _currentUserId,
        'items': items.map((item) => item.toMap()).toList(),
        'summary': {
          'subtotal': summary.subtotal,
          'shipping': summary.shipping,
          'tax': summary.tax,
          'total': summary.total,
          'discount': summary.discount,
          'itemCount': summary.itemCount,
        },
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'additionalInfo': additionalInfo,
        'status':
            'pending', // pending, processing, shipped, delivered, cancelled
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await orderRef.set(orderData);

      // Clear cart after successful checkout
      await clearCart();

      return {'success': true, 'orderId': orderRef.id, 'orderData': orderData};
    } catch (e) {
      print('Error during checkout: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
