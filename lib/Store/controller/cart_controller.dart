// lib/Controllers/cart_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Store/controller/cart_service.dart';
import 'package:mango/Store/models/cart_item.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class CartController extends GetxController {
  final CartService _cartService = CartService();

  final RxList<CartItem> cartItems = <CartItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isCheckingOut = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadCartItems();
  }

  void loadCartItems() {
    _cartService.getCartItems().listen((items) {
      cartItems.value = items;
    });
  }

  Stream<List<CartItem>> getCartItemsStream() {
    return _cartService.getCartItems();
  }

  Stream<int> getCartItemCountStream() {
    return _cartService.getCartItemCount();
  }

  Future<bool> validateCart() async {
    return await _cartService.validateCartItems(cartItems);
  }

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
    isLoading.value = true;
    try {
      await _cartService.addToCart(
        productId: productId,
        vendorId: vendorId,
        vendorName: vendorName,
        name: name,
        price: price,
        imageUrl: imageUrl,
        productDetails: productDetails,
        quantity: quantity,
      );

      Get.snackbar(
        'Success',
        'Added to cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add to cart: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    try {
      await _cartService.updateQuantity(cartItemId, newQuantity);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update quantity',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> removeFromCart(String cartItemId) async {
    try {
      await _cartService.removeFromCart(cartItemId);
      Get.snackbar(
        'Removed',
        'Item removed from cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove item',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> clearCart() async {
    try {
      await _cartService.clearCart();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to clear cart',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<CartSummary> getCartSummary() async {
    return await _cartService.getCartSummary();
  }

  Future<Map<String, dynamic>> checkout({
    required String shippingAddress,
    required String paymentMethod,
    Map<String, dynamic>? additionalInfo,
  }) async {
    isCheckingOut.value = true;
    try {
      // Validate cart items first
      final isValid = await validateCart();
      if (!isValid) {
        Get.snackbar(
          'Cart Updated',
          'Some items were out of stock or removed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          colorText: Colors.white,
        );
        return {'success': false, 'error': 'Cart items invalid'};
      }

      final result = await _cartService.checkout(
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        additionalInfo: additionalInfo,
      );

      if (result['success']) {
        Get.snackbar(
          'Success',
          'Order placed successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }

      return result;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Checkout failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return {'success': false, 'error': e.toString()};
    } finally {
      isCheckingOut.value = false;
    }
  }

  double get subtotal {
    return cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get shipping {
    return subtotal > 50 ? 0.0 : 5.99;
  }

  double get tax {
    return subtotal * 0.075;
  }

  double get total {
    return subtotal + shipping + tax;
  }
}
