// lib/Store/controller/home_product_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Store/screens/product_detail_screen.dart';
import '../../Models/customModel/MangoProduct.dart';

class HomeProductController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<List<MangoProductItem>> getAllProductsStream() {
  return _firestore
      .collection('products')
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(4)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList();
      })
      .handleError((error) {
        debugPrint('Products stream error: $error');
        return [];
      });
}

  Stream<List<MangoProductItem>> getTopOffersStream() {
    return _firestore
        .collection('products')
        .where('onSale', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  Stream<List<MangoProductItem>> getBestSellersStream() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('soldCount', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  void navigateToProductDetail(MangoProductItem product) {
    debugPrint('Navigating to product detail: ${product.id}');
    Get.to(
      () => ProductDetailScreen(productId: product.id),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }
}