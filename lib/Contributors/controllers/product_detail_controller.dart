// lib/Store/controller/product_detail_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Store/controller/product_services.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/utils.dart';

class ProductDetailController extends GetxController {
  final ProductService _productService = ProductService();
  final CartController cartController = Get.find<CartController>();
  
  final Rx<MangoProductItem?> currentProduct = Rx<MangoProductItem?>(null);
  final RxList<ProductComment> productComments = <ProductComment>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isAddingComment = false.obs;
  
  String get currentUserId => _productService.currentUserId;
  
  @override
  void onInit() {
    super.onInit();
    debugPrint('ProductDetailController initialized');
  }
  
  Future<void> loadProduct(String productId) async {
    debugPrint('Loading product: $productId');
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      await _productService.incrementViewCount(productId);
      
      _productService.getProductStream(productId).listen(
        (product) {
          debugPrint('Product loaded: ${product.title}');
          currentProduct.value = product;
          isLoading.value = false;
        },
        onError: (error) {
          debugPrint('Error loading product stream: $error');
          errorMessage.value = 'Failed to load product: $error';
          isLoading.value = false;
        },
      );
      
      _productService.getCommentsStream(productId).listen(
        (comments) {
          productComments.value = comments;
        },
        onError: (error) {
          debugPrint('Error loading comments: $error');
        },
      );
      
    } catch (e) {
      debugPrint('Error in loadProduct: $e');
      errorMessage.value = 'Failed to load product: $e';
      isLoading.value = false;
    }
  }
  
  Future<void> toggleLike(BuildContext context) async {
    try {
      if (currentProduct.value == null) return;
      await _productService.toggleLike(currentProduct.value!.id, currentUserId);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to update like', context: context);
    }
  }
  
  Future<void> addComment(String text, BuildContext context, {double rating = 0.0}) async {
    if (currentProduct.value == null || text.isEmpty) return;
    
    isAddingComment.value = true;
    try {
      final comment = ProductComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUserId,
        userEmail: _productService.currentUser?.email ?? 'user@example.com',
        text: text,
        rating: rating,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _productService.addComment(currentProduct.value!.id, comment);
      UtilsService().showSnackbar('Success', 'Comment added', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to add comment', context: context);
    } finally {
      isAddingComment.value = false;
    }
  }
  
  Future<void> addToCart(MangoProductItem product) async {
    await cartController.addToCart(
      productId: product.id,
      vendorId: product.vendorId,
      vendorName: product.vendorName,
      name: product.title,
      price: product.currentPrice,
      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      productDetails: {
        'description': product.description,
        'category': product.category,
        'brand': product.brand,
        'sku': product.sku,
      },
      quantity: 1,
    );
  }
  
  Future<void> buyNow(MangoProductItem product) async {
    await addToCart(product);
    Get.toNamed('/cart');
  }
  
  bool get isProductLiked {
    return currentProduct.value?.likedBy.contains(currentUserId) ?? false;
  }
}