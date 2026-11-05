import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/Store/controller/product_services.dart';
import 'package:mango/Store/screens/product_detail_screen.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ShopController extends GetxController {
  final MangoDashboardController dashboardController = Get.find();
  final CartController cartController = Get.find();
  final ProductService productService = ProductService();

  final RxList<MangoProductItem> topOffers = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> bestSellers = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> catalogs = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> allProducts = <MangoProductItem>[].obs;
  final RxList<MangoProductItem> filteredProducts =
      <MangoProductItem>[].obs; // Add this

  final RxBool isLoading = true.obs; // Change to true initially
  final RxString searchQuery = ''.obs;
  final RxInt selectedTabIndex = 0.obs; // Add this for tab selection

  // Add these vendor properties
  final String? vendorLogo = '';
  final String? vendorBio = '';
  final double? vendorRating = 4.5;

  final String vendorId;
  final String vendorName;

  ShopController({required this.vendorId, required this.vendorName});

  @override
  void onInit() {
    super.onInit();
    loadShopData();

    // Listen to search query
    ever(searchQuery, (_) => filterProducts());
  }

  Future<void> loadShopData() async {
    isLoading.value = true;

    try {
      // Get products from product service
      productService
          .getProductsStream(vendorId: vendorId)
          .listen(
            (products) {
              allProducts.value = products;
              filteredProducts.value = products; // Initialize filtered products
              categorizeProducts(products);
              isLoading.value = false;
            },
            onError: (error) {
              print('Error loading products: $error');
              isLoading.value = false;
            },
          );
    } catch (e) {
      print('Error loading shop data: $e');
      isLoading.value = false;
    }
  }

  void categorizeProducts(List<MangoProductItem> products) {
    // Categorize items based on tags and product properties
    topOffers.assignAll(
      products
          .where(
            (product) =>
                product.onSale == true ||
                product.tags.contains('Sale') ||
                product.tags.contains('Limited Edition'),
          )
          .toList(),
    );

    // Best sellers based on sold count, rating, or tags
    bestSellers.assignAll(
      products
          .where(
            (product) =>
                product.soldCount > 50 ||
                product.rating >= 4.5 ||
                product.tags.contains('Best Seller'),
          )
          .toList(),
    );

    // All other products go to catalogs
    catalogs.assignAll(
      products
          .where(
            (product) =>
                !topOffers.contains(product) && !bestSellers.contains(product),
          )
          .toList(),
    );

    // If no items are categorized, show all items in top offers
    if (topOffers.isEmpty && bestSellers.isEmpty && catalogs.isEmpty) {
      topOffers.assignAll(products);
    }
  }

  void filterProducts() {
    if (searchQuery.value.isEmpty) {
      filteredProducts.value = allProducts;
      categorizeProducts(allProducts);
      return;
    }

    final filtered = allProducts.where((product) {
      final title = product.title.toLowerCase();
      final brand = product.brand.toLowerCase();
      final query = searchQuery.value.toLowerCase();
      return title.contains(query) || brand.contains(query);
    }).toList();

    filteredProducts.value = filtered;
    categorizeProducts(filtered);
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

  // Helper method to navigate to product detail
  void navigateToProductDetail(MangoProductItem product) {
    debugPrint('Navigating to product detail: ${product.id}');
    Get.to(
      () => ProductDetailScreen(productId: product.id),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }
}

class Item {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String category;
  final int stock;
  final int height;
  final List<String>? tags;
  final String vendorId;
  final String vendorName;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description = '',
    this.category = '',
    this.stock = 0,
    this.height = 200,
    this.tags,
    required this.vendorId,
    required this.vendorName,
  });

  factory Item.fromFirestore(
    Map<String, dynamic> data,
    String id,
    String vendorId,
    String vendorName,
  ) {
    return Item(
      id: id,
      name: data['title'] ?? data['name'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['images'] != null && data['images'].isNotEmpty
          ? data['images'][0]
          : data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      stock: data['stock'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      vendorId: vendorId,
      vendorName: vendorName,
    );
  }
}

class ShopScreen extends GetView<ShopController> {
  final String vendorId;
  final String vendorName;

  const ShopScreen({Key? key, required this.vendorId, required this.vendorName})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    Get.put(ShopController(vendorId: vendorId, vendorName: vendorName));

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == vendorId;

    return Scaffold(
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      appBar: _buildAppBar(isDarkMode),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _buildLoadingShimmer(context);
        }

        if (controller.allProducts.isEmpty) {
          return _buildEmptyState(isDarkMode, isOwner);
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildVendorHeader(isDarkMode)),
            SliverToBoxAdapter(child: _buildSearchBar(isDarkMode)),
            SliverToBoxAdapter(child: _buildCategoryTabs(isDarkMode)),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: _buildProductsGrid(),
            ),
          ],
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: Icon(
          Icons.arrow_back,
          color: isDarkMode ? Colors.white : MangoPalette.black,
        ),
        onPressed: () => Get.back(),
      ),
      title: Text(
        vendorName,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : MangoPalette.black,
        ),
      ),
      centerTitle: true,
      actions: [
        Obx(
          () => Stack(
            children: [
              IconButton(
        tooltip: 'Cart',
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
                onPressed: () => Get.toNamed('/cart'),
              ),
              if (controller.cartController.cartItems.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: MangoPalette.green500,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      controller.cartController.cartItems.length.toString(),
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
          ),
        ),
      ],
    );
  }

  Widget _buildVendorHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MangoPalette.green500.withOpacity(0.1),
            ),
            child: ClipOval(
              child:
                  controller.vendorLogo != null &&
                      controller.vendorLogo!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: controller.vendorLogo!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
                      errorWidget: (context, url, error) =>
                          Icon(Icons.store, size: 30, color: MangoPalette.green500),
                    )
                  : Icon(Icons.store, size: 30, color: MangoPalette.green500),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendorName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 4),
                if (controller.vendorBio != null &&
                    controller.vendorBio!.isNotEmpty)
                  Text(
                    controller.vendorBio!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatChip(
                      Icons.shopping_bag_outlined,
                      '${controller.allProducts.length} Products',
                      isDarkMode,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      Icons.star,
                      '${controller.vendorRating ?? 4.5} ★',
                      isDarkMode,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MangoPalette.green500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.sm),
          border: Border.all(
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
          ),
        ),
        child: TextField(
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : MangoPalette.black,
          ),
          decoration: InputDecoration(
            hintText: 'Search in $vendorName...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (query) => controller.searchQuery.value = query,
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryTab('All', 0, isDarkMode),
          _buildCategoryTab('Top Offers', 1, isDarkMode),
          _buildCategoryTab('Best Sellers', 2, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String title, int index, bool isDarkMode) {
    return Obx(
      () => MangoPressable(
        onTap: () => controller.selectedTabIndex.value = index,
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: controller.selectedTabIndex.value == index
                    ? MangoPalette.green500
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: controller.selectedTabIndex.value == index
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: controller.selectedTabIndex.value == index
                  ? MangoPalette.green500
                  : (isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return Obx(() {
      List<MangoProductItem> products = [];

      switch (controller.selectedTabIndex.value) {
        case 1:
          products = controller.topOffers;
          break;
        case 2:
          products = controller.bestSellers;
          break;
        default:
          products = controller.filteredProducts.isEmpty
              ? controller.allProducts
              : controller.filteredProducts;
      }

      if (products.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: MangoPalette.grey400),
                const SizedBox(height: 16),
                Text(
                  controller.searchQuery.value.isNotEmpty
                      ? 'No products found for "${controller.searchQuery.value}"'
                      : 'No products in this category',
                  style: TextStyle(fontSize: 14, color: MangoPalette.grey500),
                ),
              ],
            ),
          ),
        );
      }

      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildProductCard(products[index], context),
          childCount: products.length,
        ),
      );
    });
  }

  Widget _buildProductCard(MangoProductItem product, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MangoPressable(
      onTap: () => controller.navigateToProductDetail(product),
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 160,
                            color: isDarkMode
                                ? MangoPalette.grey800
                                : MangoPalette.grey200,
                            child: const Center(
                              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 160,
                            color: isDarkMode
                                ? MangoPalette.grey800
                                : MangoPalette.grey200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDarkMode
                                  ? MangoPalette.grey600
                                  : MangoPalette.grey400,
                            ),
                          ),
                        )
                      : Container(
                          height: 160,
                          color: isDarkMode
                              ? MangoPalette.grey800
                              : MangoPalette.grey200,
                          child: Icon(
                            Icons.image,
                            color: isDarkMode
                                ? MangoPalette.grey600
                                : MangoPalette.grey400,
                          ),
                        ),
                ),
                if (product.onSale)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(MangoRadius.xs),
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
                if (!product.inStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: MangoPalette.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
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
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? MangoPalette.grey400
                              : MangoPalette.grey600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₦${product.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MangoPalette.green500,
                        ),
                      ),
                      if (product.onSale)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '₦${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? MangoPalette.grey500
                                  : MangoPalette.grey400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildEmptyState(bool isDarkMode, bool isOwner) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 50,
                color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isOwner ? 'No Products Yet' : 'No Products Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : MangoPalette.black,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                isOwner
                    ? 'Start adding products to your shop to showcase your items to customers.'
                    : 'This vendor hasn\'t added any products yet. Check back later for new items.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isOwner)
              ElevatedButton.icon(
                onPressed: () => Get.toNamed(
                  '/upload-product',
                  arguments: {'vendorId': vendorId, 'vendorName': vendorName},
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Your First Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MangoPalette.green500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return MangoShimmer(
      baseColor: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
      highlightColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: OptimizedGridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: isDarkMode ? MangoPalette.grey800 : Colors.white,
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}

class TopOfferCard extends StatelessWidget {
  final Item item;
  final VoidCallback onAddToCart;

  const TopOfferCard({Key? key, required this.item, required this.onAddToCart})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MangoPressable(
      onTap: () {
        // Navigate to item detail
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        color: isDarkMode ? MangoPalette.grey850 : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₦${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: MangoPalette.green500,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          '-20%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      child: item.imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: item.imageUrl,
              height: item.height.toDouble(),
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: item.height.toDouble(),
                color: MangoPalette.grey200,
                child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
              ),
              errorWidget: (context, url, error) => Container(
                height: item.height.toDouble(),
                color: MangoPalette.grey200,
                child: Icon(Icons.image_not_supported, size: 40),
              ),
            )
          : Container(
              height: item.height.toDouble(),
              color: MangoPalette.grey200,
              child: Icon(Icons.image, size: 40, color: MangoPalette.grey400),
            ),
    );
  }
}

class BestSellerCard extends StatelessWidget {
  final Item item;
  final VoidCallback onAddToCart;

  const BestSellerCard({
    Key? key,
    required this.item,
    required this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MangoPressable(
      onTap: () {
        // Navigate to item detail
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        color: isDarkMode ? MangoPalette.grey850 : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150, maxHeight: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: double.infinity,
                        height: 150.0,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: MangoPalette.grey200,
                          child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: MangoPalette.grey200,
                          child: Icon(Icons.image_not_supported, size: 40),
                        ),
                      )
                    : Container(
                        height: 150,
                        color: MangoPalette.grey200,
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: MangoPalette.grey400,
                        ),
                      ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : MangoPalette.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₦${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: MangoPalette.green500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '₦${(item.price * 1.2).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? MangoPalette.grey500
                                      : MangoPalette.grey400,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          if (item.stock > 0)
                            Text(
                              'In Stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: MangoPalette.green500,
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: onAddToCart,
                        child: Text(
                          'Add to Cart',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 36),
                          backgroundColor: MangoPalette.green500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MangoRadius.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const CatalogCard({Key? key, required this.item, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MangoPressable(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: isDarkMode ? MangoPalette.grey850 : Colors.white,
        margin: EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            child: item.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: MangoPalette.grey200,
                      child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: MangoPalette.grey200,
                      child: Icon(Icons.image, size: 30),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: MangoPalette.grey200,
                    child: Icon(Icons.image, size: 30),
                  ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '₦${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: MangoPalette.green500,
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
          ),
        ),
      ),
    );
  }
}
