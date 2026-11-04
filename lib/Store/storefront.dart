// lib/Store/screens/store_front.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/Store/components/vendor_card.dart';
import 'package:mango/Store/controller/store_controller.dart';
import 'package:mango/Store/screens/general_store.dart';
import 'package:mango/Utils/optimized_lists.dart';

class StoreFront extends GetView<StoreController> {
  const StoreFront({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Store',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          // Cart icon
          StreamBuilder<int>(
            stream: controller.cartController.getCartItemCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart_outlined),
                    onPressed: () => Get.toNamed(AppRoutes.cart),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vendors or products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              ),
              onChanged: (query) {
                controller.searchQuery.value = query;
              },
            ),
          ),
          // Tabs for different views
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabButton('All Vendors', 0, context),
                _buildTabButton('Featured', 1, context),
                _buildTabButton('Top Rated', 2, context),
              ],
            ),
          ),
          Divider(height: 1),
          // Content
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (controller.filteredVendors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No vendors found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return OptimizedListView(
                padding: EdgeInsets.all(16),
                itemCount: controller.filteredVendors.length,
                itemBuilder: (context, index) {
                  final vendor = controller.filteredVendors[index];
                  return VendorCard(
                    vendor: vendor,
                    onTap: () {
                      Get.to(
                        () => ShopScreen(
                          vendorId: vendor['contributorId'],
                          vendorName: vendor['storeName'] ?? vendor['fullName'],
                        ),
                        transition: Transition.rightToLeft,
                      );
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String title, int index, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final storeController = Get.find<StoreController>();
    
    return Expanded(
      child: GestureDetector(
        onTap: () => storeController.selectedTabIndex.value = index,
        child: Obx(() => Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: storeController.selectedTabIndex.value == index
                    ? Colors.orange
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: storeController.selectedTabIndex.value == index
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: storeController.selectedTabIndex.value == index
                    ? Colors.orange
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ),
        )),
      ),
    );
  }
}