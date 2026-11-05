import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Store/controller/all_products.dart';
import 'package:shimmer/shimmer.dart';

import '../../../Models/customModel/MangoProduct.dart';
import '../../../Store/screens/product_detail_screen.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MarketPlace extends StatefulWidget {
  const MarketPlace({Key? key}) : super(key: key);

  @override
  State<MarketPlace> createState() => _MarketPlaceState();
}

class _MarketPlaceState extends State<MarketPlace> {
  late final AllProductsController controller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Register controller if not already registered
    if (!Get.isRegistered<AllProductsController>()) {
      Get.put(AllProductsController());
    }
    controller = Get.find<AllProductsController>();
    
    // Sync search controller with reactive variable
    _searchController.addListener(() {
      controller.searchQuery.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with back button and actions
            SliverToBoxAdapter(
              child: _buildHeader(isDarkMode),
            ),
            
            // Search Bar
            SliverToBoxAdapter(
              child: _buildSearchBar(isDarkMode),
            ),
            
            // Category Chips
            SliverToBoxAdapter(
              child: _buildCategoryChips(isDarkMode),
            ),
            
            // Products Grid
            _buildProductsGrid(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          MangoPressable(
            onTap: () => Get.back(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'marketplace',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Cart Button
          Obx(() => Stack(
            children: [
              IconButton(
        tooltip: 'Cart',
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  size: 28,
                ),
                onPressed: () => Get.toNamed('/cart'),
              ),
              if (controller.cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: MangoPalette.green500,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      controller.cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          )),
          // Filter Button
          IconButton(
        tooltip: 'Filter',
            icon: Icon(
              Icons.filter_list,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 28,
            ),
            onPressed: () => _showFilterBottomSheet(context, isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey100,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : MangoPalette.black,
          ),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey500,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 22,
              color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
            ),
            suffixIcon: Obx(() => controller.searchQuery.isNotEmpty
                ? IconButton(
        tooltip: 'Clear',
                    icon: Icon(
                      Icons.clear,
                      size: 20,
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      controller.searchQuery.value = '';
                    },
                  )
                : const SizedBox.shrink()),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDarkMode) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 15),
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];
          final isSelected = controller.selectedCategory.value == category;

          return MangoPressable(
            onTap: () {
              controller.selectedCategory.value = category;
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? MangoPalette.green500
                    : (isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? MangoPalette.green500
                      : (isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300),
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ));
  }

  Widget _buildProductsGrid(bool isDarkMode) {
    return Obx(() {
      if (controller.isLoading.value && controller.allProducts.isEmpty) {
        return _buildLoadingShimmer(isDarkMode);
      }

      if (controller.filteredProducts.isEmpty) {
        return _buildEmptyState(isDarkMode);
      }

      // Setup scroll notification for pagination
      return NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!controller.isLoadingMore.value &&
              scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
              controller.hasMore.value) {
            controller.loadMoreProducts();
          }
          return true;
        },
        child: SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == controller.filteredProducts.length) {
                  return _buildLoadingMoreIndicator(isDarkMode);
                }
                return _buildProductCard(controller.filteredProducts[index], isDarkMode);
              },
              childCount: controller.filteredProducts.length + (controller.hasMore.value ? 1 : 0),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProductCard(MangoProductItem product, bool isDarkMode) {
    return MangoPressable(
      onTap: () => Get.to(
        () => ProductDetailScreen(productId: product.id),
        transition: Transition.rightToLeft,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 150,
                            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                            child: const Center(
                              child: CircularProgressIndicator(semanticsLabel: 'Loading', strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 150,
                            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                            ),
                          ),
                        )
                      : Container(
                          height: 150,
                          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                          child: Icon(
                            Icons.image,
                            color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                          ),
                        ),
                ),
                // Sale Badge
                if (product.onSale)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                      ),
                      child: Text(
                        '-${((product.price - product.salePrice!) / product.price * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Out of Stock Badge
                if (!product.inStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: MangoPalette.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Vendor Name
                  Text(
                    product.vendorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Row(
                    children: [
                      Text(
                        '₦${product.currentPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: MangoPalette.green500,
                        ),
                      ),
                      if (product.onSale)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '₦${product.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: product.inStock
                          ? () => controller.addToCart(product)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MangoPalette.green500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                        ),
                        minimumSize: const Size(double.infinity, 32),
                      ),
                      child: Text(
                        product.inStock ? 'Add to Cart' : 'Out of Stock',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Products Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Obx(() => Text(
                controller.searchQuery.value.isNotEmpty
                    ? 'No products match your search.'
                    : 'No products available at the moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              )),
            ),
            Obx(() {
              if (controller.searchQuery.value.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      controller.searchQuery.value = '';
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MangoPalette.green500,
                      side: const BorderSide(color: MangoPalette.green500),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.lg),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isDarkMode) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => MangoShimmer(
            baseColor: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
            highlightColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey800 : Colors.white,
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(bool isDarkMode) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(semanticsLabel: 'Loading', 
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(MangoPalette.green500),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? MangoPalette.grey850 : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey300,
                borderRadius: BorderRadius.circular(MangoRadius.xs),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Filter Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // Price Range
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price Range',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() => RangeSlider(
                  values: controller.priceRange.value,
                  min: 0,
                  max: 100000,
                  divisions: 100,
                  labels: RangeLabels(
                    '₦${controller.priceRange.value.start.toStringAsFixed(0)}',
                    '₦${controller.priceRange.value.end.toStringAsFixed(0)}',
                  ),
                  onChanged: (values) {
                    controller.priceRange.value = values;
                  },
                  activeColor: MangoPalette.green500,
                  inactiveColor: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey300,
                )),
              ],
            ),
            const SizedBox(height: 20),
            // Sort By
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => Wrap(
                  spacing: 8,
                  children: controller.sortOptions.map((option) {
                    final isSelected = controller.selectedSort.value == option;
                    return ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          controller.selectedSort.value = option;
                        }
                      },
                      backgroundColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
                      selectedColor: MangoPalette.green500.withOpacity(0.2),
                      checkmarkColor: MangoPalette.green500,
                      labelStyle: TextStyle(
                        color: isSelected ? MangoPalette.green500 : (isDarkMode ? Colors.white : MangoPalette.black),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                )),
              ],
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      controller.resetFilters();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : MangoPalette.black,
                      side: BorderSide(
                        color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      controller.applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MangoPalette.green500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}