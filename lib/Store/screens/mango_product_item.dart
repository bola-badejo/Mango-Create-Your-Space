import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Store/controller/product_controller.dart';

class MangoProduct extends StatelessWidget {
  final MangoProductItem product;
  final VoidCallback? onTap;
  final bool showVariants;
  final bool showLikeButton;

  const MangoProduct({
    super.key,
    required this.product,
    this.onTap,
    this.showVariants = false,
    this.showLikeButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final productController = Get.find<ProductController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            _buildProductImage(isDark, productController, context),
            
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.brand,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  
                  
                  const SizedBox(height: 8),
                  _buildPriceSection(),
                  
                  
                  if (showVariants && product.hasVariants) ...[
                    const SizedBox(height: 8),
                    _buildVariantsPreview(),
                  ],
                  
                  
                  const SizedBox(height: 8),
                  _buildSocialSection(productController),
                  
                  
                  const SizedBox(height: 8),
                  _buildFooterSection(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(bool isDark, ProductController productController, context) {
    return Stack(
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          child: product.imageUrls.isNotEmpty
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    product.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 40,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.photo_library,
                  color: Colors.grey[400],
                  size: 40,
                ),
        ),
        
        
        if (product.imageUrls.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${product.imageUrls.length - 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        
        if (product.onSale)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SALE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        
        if (showLikeButton)
          Positioned(
            top: 8,
            right: 40,
            child: Obx(() {
              final isLiked = product.isLikedBy(productController.currentUserId);
              return IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  
                  productController.toggleLike(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
              );
            }),
          ),
        
        
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Text(
                  'OUT OF STOCK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Text(
          '₦${product.currentPrice.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: product.onSale ? Colors.red : Colors.black,
          ),
        ),
        if (product.onSale) ...[
          const SizedBox(width: 4),
          Text(
            '₦${product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialSection(ProductController productController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        
        Row(
          children: [
            Icon(
              Icons.favorite,
              color: Colors.red[400],
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              product.likeCount.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        
        
        Row(
          children: [
            Icon(
              Icons.comment,
              color: Colors.blue[400],
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              product.commentCount.toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        
        
        if (product.rating > 0)
          Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                product.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildVariantsPreview() {
    final colors = product.availableColors;
    final sizes = product.availableSizes;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'Colors: ',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              ...colors.take(3).map((color) {
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorFromString(color),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                );
              }).toList(),
              if (colors.length > 3)
                Text(
                  '+${colors.length - 3}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ],
        if (sizes.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Sizes: ${sizes.take(3).join(', ')}${sizes.length > 3 ? '...' : ''}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterSection(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: product.inStock 
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            product.inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
            style: TextStyle(
              fontSize: 10,
              color: product.inStock ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        
        Row(
          children: [
            Icon(
              Icons.remove_red_eye,
              color: Colors.grey[600],
              size: 14,
            ),
            const SizedBox(width: 2),
            Text(
              product.viewCount.toString(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorFromString(String colorName) {
    final colorMap = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'black': Colors.black,
      'white': Colors.white,
      'yellow': Colors.yellow,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'orange': Colors.orange,
      'brown': Colors.brown,
      'gray': Colors.grey,
    };
    
    return colorMap[colorName.toLowerCase()] ?? Colors.grey;
  }
}