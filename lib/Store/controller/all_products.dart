// lib/Store/controller/all_products_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/Store/controller/product_services.dart';

class AllProductsController extends GetxController {
  final ProductService productService = ProductService();
  final CartController cartController = Get.find();
  
  final RxList<MangoProductItem> allProducts = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> filteredProducts = <MangoProductItem>[].obs;
  
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentPage = 0.obs;
  
  // Search and Filter
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxString selectedSort = 'Newest'.obs;
  final Rx<RangeValues> priceRange = Rx<RangeValues>(const RangeValues(0, 100000));
  
  final List<String> categories = [
    'All', 'Fashion', 'Electronics', 'Books', 'Music', 
    'Home & Garden', 'Beauty & Health', 'Sports', 'Toys & Games'
  ];
  
  final List<String> sortOptions = [
    'Newest', 'Price: Low to High', 'Price: High to Low', 'Top Rated', 'Best Selling'
  ];
  
  int get cartItemCount => cartController.cartItems.length;
  
  @override
  void onInit() {
    super.onInit();
    loadProducts();
    
    // Debounced search
    ever(searchQuery, (_) => filterAndSortProducts());
    ever(selectedCategory, (_) => filterAndSortProducts());
    ever(selectedSort, (_) => sortProducts());
  }
  
  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 0;
      hasMore.value = true;
      allProducts.clear();
    }
    
    isLoading.value = true;
    
    try {
      final products = await productService.getProducts(
        limit: 20,
        lastDocument: refresh ? null : null, // Implement pagination
      );
      
      if (refresh) {
        allProducts.assignAll(products);
      } else {
        allProducts.addAll(products);
      }
      
      hasMore.value = products.length == 20;
      filterAndSortProducts();
    } catch (e) {
      print('Error loading products: $e');
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> loadMoreProducts() async {
    if (isLoadingMore.value || !hasMore.value) return;
    
    isLoadingMore.value = true;
    currentPage.value++;
    
    try {
      final products = await productService.getProducts(
        limit: 20,
        lastDocument: null, // Implement pagination with last document
      );
      
      if (products.isNotEmpty) {
        allProducts.addAll(products);
        filterAndSortProducts();
      }
      
      hasMore.value = products.length == 20;
    } catch (e) {
      print('Error loading more products: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }
  
  void filterAndSortProducts() {
    var filtered = allProducts.toList();
    
    // Filter by search query
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((product) {
        final title = product.title.toLowerCase();
        final brand = product.brand.toLowerCase();
        final query = searchQuery.value.toLowerCase();
        return title.contains(query) || brand.contains(query);
      }).toList();
    }
    
    // Filter by category
    if (selectedCategory.value != 'All') {
      filtered = filtered.where((product) {
        return product.category == selectedCategory.value;
      }).toList();
    }
    
    // Filter by price range
    filtered = filtered.where((product) {
      return product.currentPrice >= priceRange.value.start &&
             product.currentPrice <= priceRange.value.end;
    }).toList();
    
    filteredProducts.value = filtered;
    sortProducts();
  }
  
  void sortProducts() {
    final sorted = filteredProducts.toList();
    
    switch (selectedSort.value) {
      case 'Newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Price: Low to High':
        sorted.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
        break;
      case 'Price: High to Low':
        sorted.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case 'Top Rated':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Best Selling':
        sorted.sort((a, b) => b.soldCount.compareTo(a.soldCount));
        break;
    }
    
    filteredProducts.value = sorted;
  }
  
  void resetFilters() {
    searchQuery.value = '';
    selectedCategory.value = 'All';
    selectedSort.value = 'Newest';
    priceRange.value = const RangeValues(0, 100000);
    filterAndSortProducts();
  }
  
  void applyFilters() {
    filterAndSortProducts();
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
  
  void refreshProducts() {
    loadProducts(refresh: true);
  }
}