// lib/Store/controller/product_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/Store/controller/product_services.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import '../../Models/customModel/MangoProduct.dart';

class ProductController extends GetxController {
  final ProductService _productService = ProductService();
  final CartController cartController = Get.find<CartController>();
  final Uuid _uuid = const Uuid();

  // Current product
  final Rx<MangoProductItem?> currentProduct = Rx<MangoProductItem?>(null);
  final RxList<MangoProductItem> products = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> featuredProducts = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> onSaleProducts = <MangoProductItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxString errorMessage = ''.obs;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;

  // Comments
  final RxList<ProductComment> productComments = <ProductComment>[].obs;
  final RxBool isAddingComment = false.obs;

  // Filters
  final RxString selectedCategory = 'all'.obs;
  final RxString selectedSort = 'newest'.obs;
  final RxString searchQuery = ''.obs;

  String get currentUserId => _productService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    
    // Listen to filter changes
    ever(selectedCategory, (_) => refreshProducts());
    ever(selectedSort, (_) => sortProducts());
    ever(searchQuery, (_) => filterProducts());
  }

  // Load product details
  Future<void> loadProduct(String productId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Increment view count
      await _productService.incrementViewCount(productId);
      
      // Listen to product updates
      _productService.getProductStream(productId).listen((product) {
        currentProduct.value = product;
      });
      
      // Listen to comments
      _productService.getCommentsStream(productId).listen((comments) {
        productComments.value = comments;
      });
      
    } catch (e) {
      errorMessage.value = 'Failed to load product: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // Load products with pagination
  Future<void> loadProducts({bool refresh = false}) async {
    if (isLoading.value) return;
    
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      if (refresh) {
        _lastDocument = null;
        products.clear();
      }
      
      final loadedProducts = await _productService.getProducts(
        category: selectedCategory.value == 'all' ? null : selectedCategory.value,
        lastDocument: _lastDocument,
        limit: _pageSize,
      );
      
      if (loadedProducts.isNotEmpty) {
        if (_lastDocument == null) {
          products.assignAll(loadedProducts);
        } else {
          products.addAll(loadedProducts);
        }
        
        _lastDocument = await _getLastDocumentSnapshot();
        hasMore.value = loadedProducts.length == _pageSize;
      } else {
        hasMore.value = false;
      }
      
      // Update categorized lists
      featuredProducts.value = products.where((p) => p.isActive && p.rating >= 4.0).toList();
      onSaleProducts.value = products.where((p) => p.onSale && p.inStock).toList();
      
    } catch (e) {
      errorMessage.value = 'Failed to load products: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<DocumentSnapshot?> _getLastDocumentSnapshot() async {
    if (products.isEmpty) return null;
    
    final lastProduct = products.last;
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .doc(lastProduct.id)
        .get();
    
    return snapshot;
  }

  // Load more products for pagination
  Future<void> loadMoreProducts() async {
    if (!hasMore.value || isLoading.value) return;
    await loadProducts();
  }

  // Refresh products
  Future<void> refreshProducts() async {
    await loadProducts(refresh: true);
  }

  // Filter products by search query
  void filterProducts() {
    if (searchQuery.value.isEmpty) {
      loadProducts(refresh: true);
      return;
    }
    
    final filtered = products.where((product) {
      final title = product.title.toLowerCase();
      final brand = product.brand.toLowerCase();
      final query = searchQuery.value.toLowerCase();
      return title.contains(query) || brand.contains(query);
    }).toList();
    
    products.value = filtered;
  }

  // Sort products
  void sortProducts() {
    final sorted = List<MangoProductItem>.from(products);
    
    switch (selectedSort.value) {
      case 'newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_low_high':
        sorted.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case 'price_high_low':
        sorted.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'top_rated':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'best_selling':
        sorted.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        break;
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    products.value = sorted;
  }

  // Toggle product like
  Future<void> toggleLike(BuildContext context) async {
    try {
      if (currentProduct.value == null) return;
      
      await _productService.toggleLike(
        currentProduct.value!.id, 
        currentUserId
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to toggle like: $e';
      UtilsService().showSnackbar(
        'Error', 
        'Failed to update like', 
        context: context,
        backgroundColor: Colors.red,
      );
    }
  }

  // Add comment to product
  Future<void> addComment(String text, BuildContext context, {double rating = 0.0}) async {
    try {
      if (currentProduct.value == null || text.isEmpty) return;
      
      isAddingComment.value = true;
      
      final comment = ProductComment(
        id: _uuid.v4(),
        userId: currentUserId,
        userEmail: _productService.currentUser?.email ?? 'user@example.com',
        userAvatar: _productService.currentUser?.photoURL ?? '',
        text: text,
        rating: rating,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _productService.addComment(currentProduct.value!.id, comment);
      
      UtilsService().showSnackbar(
        'Success', 
        'Comment added successfully', 
        context: context,
        backgroundColor: Colors.green,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to add comment: $e';
      UtilsService().showSnackbar(
        'Error', 
        'Failed to add comment', 
        context: context,
        backgroundColor: Colors.red,
      );
    } finally {
      isAddingComment.value = false;
    }
  }

  // Update comment
  Future<void> updateComment(String commentId, String newText, BuildContext context) async {
    try {
      if (currentProduct.value == null) return;
      
      final comment = productComments.firstWhere(
        (c) => c.id == commentId,
        orElse: () => throw Exception('Comment not found'),
      );
      
      final updatedComment = comment.copyWith(
        text: newText,
        updatedAt: DateTime.now(),
      );
      
      await _productService.updateComment(currentProduct.value!.id, updatedComment);
      
      UtilsService().showSnackbar(
        'Success', 
        'Comment updated successfully', 
        context: context,
        backgroundColor: Colors.green,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to update comment: $e';
      UtilsService().showSnackbar(
        'Error', 
        'Failed to update comment', 
        context: context,
        backgroundColor: Colors.red,
      );
    }
  }

  // Delete comment
  Future<void> deleteComment(String commentId, BuildContext context) async {
    try {
      if (currentProduct.value == null) return;
      
      await _productService.deleteComment(currentProduct.value!.id, commentId);
      
      UtilsService().showSnackbar(
        'Success', 
        'Comment deleted successfully', 
        context: context,
        backgroundColor: Colors.green,
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to delete comment: $e';
      UtilsService().showSnackbar(
        'Error', 
        'Failed to delete comment', 
        context: context,
        backgroundColor: Colors.red,
      );
    }
  }

  // Toggle comment like
  Future<void> toggleCommentLike(String commentId) async {
    try {
      if (currentProduct.value == null) return;
      
      await _productService.toggleCommentLike(
        currentProduct.value!.id, 
        commentId, 
        currentUserId
      );
      
    } catch (e) {
      errorMessage.value = 'Failed to toggle comment like: $e';
    }
  }

  // Add product to cart
  Future<void> addToCart(MangoProductItem product, {int quantity = 1, Map<String, String>? selectedVariant}) async {
  // Check stock
  if (product.stockQuantity < quantity) {
    Get.snackbar(
      'Out of Stock',
      'Only ${product.stockQuantity} items available',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return;
  }
  
  await cartController.addToCart(
    productId: product.id,
    vendorId: product.vendorId, // Now using vendorId from product
    vendorName: product.vendorName, // Now using vendorName from product
    name: product.title,
    price: product.currentPrice,
    imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
    productDetails: {
      'sku': product.sku,
      'brand': product.brand,
      'category': product.category,
      'description': product.description,
      'variants': product.variants.map((v) => v.toMap()).toList(),
      'selectedVariant': selectedVariant,
    },
    quantity: quantity,
  );
}

  // Buy now (add to cart and go to checkout)
  Future<void> buyNow(MangoProductItem product, {int quantity = 1}) async {
    await addToCart(product, quantity: quantity);
    Get.toNamed('/cart');
  }

  // Get products by vendor
  Stream<List<MangoProductItem>> getProductsByVendor(String vendorId) {
    return _productService.getProductsStream(vendorId: vendorId);
  }

  // Check if product is liked
  bool get isProductLiked {
    return currentProduct.value?.isLikedBy(currentUserId) ?? false;
  }

  // Check if comment is liked
  bool isCommentLiked(ProductComment comment) {
    return comment.likedBy.contains(currentUserId);
  }

  // Clear current product
  void clearCurrentProduct() {
    currentProduct.value = null;
    productComments.clear();
  }
}