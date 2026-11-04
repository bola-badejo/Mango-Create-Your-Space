// lib/Store/controllers/store_controller.dart

import 'package:get/get.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Store/controller/cart_controller.dart';

class StoreController extends GetxController {
  final MangoDashboardController dashboardController = Get.find();
  final CartController cartController = Get.find();
  
  final RxList<Map<String, dynamic>> vendors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredVendors = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;
  final RxInt selectedTabIndex = 0.obs;
  final RxBool isLoading = true.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadVendors();
    
    // Listen to search query changes
    ever(searchQuery, (_) => filterVendors());
    ever(selectedTabIndex, (_) => filterVendors());
  }
  
  void loadVendors() {
    dashboardController.getVendors().listen((vendorList) {
      vendors.value = vendorList;
      filteredVendors.value = vendorList;
      isLoading.value = false;
    });
  }
  
  void filterVendors() {
    var filtered = vendors.toList();
    
    // Filter by search query
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((vendor) {
        final name = (vendor['storeName'] ?? vendor['fullName'] ?? '').toLowerCase();
        final bio = (vendor['bio'] ?? '').toLowerCase();
        final query = searchQuery.value.toLowerCase();
        return name.contains(query) || bio.contains(query);
      }).toList();
    }
    
    // Filter by tab
    if (selectedTabIndex.value == 1) {
      // Featured vendors (you can add a 'featured' field to vendors)
      filtered = filtered.where((vendor) => vendor['isFeatured'] == true).toList();
    } else if (selectedTabIndex.value == 2) {
      // Top rated vendors (sort by rating)
      filtered.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
    }
    
    filteredVendors.value = filtered;
  }
}