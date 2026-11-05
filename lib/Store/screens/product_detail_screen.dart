// lib/Store/screens/product_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Contributors/controllers/product_detail_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:shimmer/shimmer.dart';
import '../../Models/customModel/MangoProduct.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ProductDetailScreen extends GetView<ProductDetailController> {
  final String productId;
  
  const ProductDetailScreen({Key? key, required this.productId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    debugPrint('ProductDetailScreen building for productId: $productId');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Register the controller if not already registered
    if (!Get.isRegistered<ProductDetailController>()) {
      Get.put(ProductDetailController());
    }
    final controller = Get.find<ProductDetailController>();
    
    // Load product when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadProduct(productId);
    });
    
    return Scaffold(
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      body: Obx(() {
        if (controller.isLoading.value && controller.currentProduct.value == null) {
          return _buildShimmerLoading(isDarkMode);
        }
        
        if (controller.errorMessage.value.isNotEmpty) {
          return _buildErrorState(isDarkMode);
        }
        
        final product = controller.currentProduct.value;
        if (product == null) {
          return _buildErrorState(isDarkMode);
        }
        
        return CustomScrollView(
          slivers: [
            _buildAppBar(product, isDarkMode, context, controller),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroImageCarousel(product, isDarkMode),
                  _buildProductInfo(product, isDarkMode),
                  _buildActionButtons(product, controller),
                  _buildKeySpecs(product, isDarkMode),
                  _buildDescription(product, isDarkMode),
                  if (product.hasVariants) _buildVariantsSection(product),
                  _buildTagsSection(product, isDarkMode),
                  _buildVendorSection(product, isDarkMode),
                  _buildReviewsSection(product, isDarkMode, controller),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: _buildStickyBottomBar(controller.currentProduct.value, controller),
    );
  }
  
  Widget _buildAppBar(MangoProductItem product, bool isDarkMode, BuildContext context, ProductDetailController controller) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
        tooltip: 'Back',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Get.back(),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? MangoPalette.grey850 : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: MangoPalette.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Obx(() => IconButton(
            icon: Icon(
              controller.isProductLiked ? Icons.favorite : Icons.favorite_border,
              color: controller.isProductLiked ? Colors.red : null,
            ),
            onPressed: () => controller.toggleLike(context),
          )),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? MangoPalette.grey850 : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: MangoPalette.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
        tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share product
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeroImageCarousel(MangoProductItem product, bool isDarkMode) {
    if (product.imageUrls.isEmpty) {
      return Container(
        height: 400,
        color: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey100,
        child: Center(
          child: Icon(
            Icons.photo_library,
            size: 80,
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300,
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 450,
      child: PageView.builder(
        itemCount: product.imageUrls.length,
        itemBuilder: (context, index) {
          return Hero(
            tag: 'product_image_${product.id}_$index',
            child: CachedNetworkImage(
              imageUrl: product.imageUrls[index],
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey100,
                child: const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey100,
                child: const Icon(Icons.image_not_supported, size: 50),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildProductInfo(MangoProductItem product, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.brand.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
              color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : MangoPalette.black,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRatingStars(product.rating),
              const SizedBox(width: 8),
              Text(
                product.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey700,
                ),
              ),
              Text(
                ' (${product.reviewCount} reviews)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (product.onSale) ...[
                Text(
                  '₦${product.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '₦${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500,
                    borderRadius: BorderRadius.circular(MangoRadius.lg),
                  ),
                  child: Text(
                    'SAVE ${((product.price - product.salePrice!) / product.price * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  '₦${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (!product.inStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MangoRadius.lg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Out of Stock',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 16);
        }
      }),
    );
  }
  
  Widget _buildActionButtons(MangoProductItem product, ProductDetailController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: product.inStock ? () => controller.addToCart(product) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: MangoPalette.green500,
                side: const BorderSide(color: MangoPalette.green500),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: product.inStock ? () => controller.buyNow(product) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: MangoPalette.green500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
              child: const Text(
                'Buy Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKeySpecs(MangoProductItem product, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Specs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSpecItem(Icons.inventory_2, 'SKU', product.sku),
              const SizedBox(width: 20),
              _buildSpecItem(Icons.category, 'Category', product.category),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSpecItem(Icons.inventory, 'Stock', '${product.stockQuantity} units'),
              const SizedBox(width: 20),
              _buildSpecItem(Icons.sell, 'Sold', '${product.soldCount} units'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSpecItem(Icons.visibility, 'Views', '${product.viewCount}'),
              const SizedBox(width: 20),
              _buildSpecItem(Icons.favorite, 'Likes', '${product.likeCount}'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: MangoPalette.green500),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: MangoPalette.grey500),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDescription(MangoProductItem product, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? MangoPalette.grey300 : MangoPalette.grey700,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVariantsSection(MangoProductItem product) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (product.availableColors.isNotEmpty) ...[
            Text(
              'Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MangoPalette.grey600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: product.availableColors.map((color) {
                return ChoiceChip(
                  label: Text(color),
                  selected: false,
                  onSelected: (selected) {},
                  backgroundColor: _getColorFromString(color).withOpacity(0.2),
                  selectedColor: _getColorFromString(color),
                  labelStyle: const TextStyle(fontSize: 12),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (product.availableSizes.isNotEmpty) ...[
            Text(
              'Sizes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: MangoPalette.grey600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: product.availableSizes.map((size) {
                return ChoiceChip(
                  label: Text(size),
                  selected: false,
                  onSelected: (selected) {},
                  backgroundColor: MangoPalette.grey200,
                  labelStyle: const TextStyle(fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTagsSection(MangoProductItem product, bool isDarkMode) {
    if (product.tags.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tags',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: product.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MangoPalette.green500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: MangoPalette.green500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVendorSection(MangoProductItem product, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: MangoPalette.green500.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                product.vendorName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MangoPalette.green500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sold by',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
                Text(
                  product.vendorName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Get.toNamed('/shop', parameters: {
                'vendorId': product.vendorId,
                'vendorName': product.vendorName,
              });
            },
            child: const Text('View Shop'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MangoPalette.green500,
              side: const BorderSide(color: MangoPalette.green500),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewsSection(MangoProductItem product, bool isDarkMode, ProductDetailController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              ),
              TextButton(
                onPressed: () => _showAddReviewDialog(product, controller),
                child: const Text(
                  'Write a Review',
                  style: TextStyle(color: MangoPalette.green500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (controller.productComments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return OptimizedListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.productComments.length > 3 ? 3 : controller.productComments.length,
              itemBuilder: (context, index) {
                final comment = controller.productComments[index];
                return _buildReviewCard(comment, isDarkMode);
              },
            );
          }),
          if (controller.productComments.length > 3)
            Center(
              child: TextButton(
                onPressed: () {
                  // Show all reviews
                },
                child: const Text('See All Reviews'),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReviewCard(ProductComment comment, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey850 : Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: MangoPalette.green500.withOpacity(0.1),
                child: Text(
                  comment.userEmail[0].toUpperCase(),
                  style: const TextStyle(color: MangoPalette.green500),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userEmail.split('@')[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : MangoPalette.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRatingStars(comment.rating),
                  ],
                ),
              ),
              Text(
                _formatDate(comment.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment.text,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? MangoPalette.grey300 : MangoPalette.grey700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStickyBottomBar(MangoProductItem? product, ProductDetailController controller) {
    if (product == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).brightness == Brightness.dark ? MangoPalette.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: MangoPalette.grey600,
                    ),
                  ),
                  Text(
                    '₦${product.currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: MangoPalette.green500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: product.inStock ? () => controller.buyNow(product) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MangoPalette.green500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                ),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddReviewDialog(MangoProductItem product, ProductDetailController controller) {
    final ratingController = 0.0.obs;
    final reviewController = TextEditingController();
    
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.lg)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write a Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Obx(() => Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < ratingController.value
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => ratingController.value = index + 1,
                  );
                }),
              )),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => ElevatedButton(
                      onPressed: ratingController.value == 0 || reviewController.text.isEmpty
                          ? null
                          : () async {
                              await controller.addComment(
                                reviewController.text,
                                Get.context!,
                                rating: ratingController.value,
                              );
                              Get.back();
                            },
                      child: const Text('Submit'),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildShimmerLoading(bool isDarkMode) {
    return MangoShimmer(
      baseColor: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
      highlightColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 400,
              color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 30,
              width: double.infinity,
              color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 20,
              width: 200,
              color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
            ),
            const SizedBox(height: 30),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 50,
              width: double.infinity,
              color: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CupertinoButton(
            onPressed: () => controller.loadProduct(productId),
            color: MangoPalette.green500,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  Color _getColorFromString(String colorName) {
    final colorMap = {
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': MangoPalette.green500,
      'Black': MangoPalette.black,
      'White': Colors.white,
      'Yellow': Colors.yellow,
      'Purple': Colors.purple,
      'Pink': Colors.pink,
      'Orange': MangoPalette.green500,
      'Brown': Colors.brown,
      'Gray': MangoPalette.grey500,
      'Multi-color': Colors.purpleAccent,
    };
    
    return colorMap[colorName] ?? MangoPalette.grey500;
  }
}