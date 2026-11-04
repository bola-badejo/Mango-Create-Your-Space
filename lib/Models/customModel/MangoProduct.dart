import 'package:cloud_firestore/cloud_firestore.dart';

class MangoProductItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double? salePrice;
  final String sku;
  final String brand;
  final int stockQuantity;
  final List<String> imageUrls;
  final List<ProductVariant> variants;
  final List<ProductAttribute> attributes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final double rating;
  final int reviewCount;
  final int viewCount;
  final int soldCount;
  
  // Vendor information
  final String vendorId;
  final String vendorName;
  
  // Tags
  final List<String> tags;
  
  final List<String> likedBy; 
  final List<ProductComment> comments; 

  MangoProductItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.salePrice,
    required this.sku,
    required this.brand,
    required this.stockQuantity,
    required this.imageUrls,
    required this.variants,
    required this.attributes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.viewCount = 0,
    this.soldCount = 0,
    required this.vendorId,
    required this.vendorName,
    this.tags = const [],
    this.likedBy = const [], 
    this.comments = const [], 
  });

  factory MangoProductItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MangoProductItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      salePrice: data['salePrice']?.toDouble(),
      sku: data['sku'] ?? '',
      brand: data['brand'] ?? '',
      stockQuantity: data['stockQuantity'] ?? 0,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      variants: (data['variants'] as List? ?? []).map((v) => ProductVariant.fromMap(v)).toList(),
      attributes: (data['attributes'] as List? ?? []).map((a) => ProductAttribute.fromMap(a)).toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      soldCount: data['soldCount'] ?? 0,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      comments: (data['comments'] as List? ?? []).map((c) => ProductComment.fromMap(c)).toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'salePrice': salePrice,
      'sku': sku,
      'brand': brand,
      'stockQuantity': stockQuantity,
      'imageUrls': imageUrls,
      'variants': variants.map((v) => v.toMap()).toList(),
      'attributes': attributes.map((a) => a.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.now(),
      'isActive': isActive,
      'rating': rating,
      'reviewCount': reviewCount,
      'viewCount': viewCount,
      'soldCount': soldCount,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'tags': tags,
      'likedBy': likedBy,
      'comments': comments.map((c) => c.toMap()).toList(),
    };
  }

  double get currentPrice => salePrice ?? price;
  bool get onSale => salePrice != null && salePrice! < price;
  bool get inStock => stockQuantity > 0;
  String get formattedPrice => '₦${price.toStringAsFixed(2)}';
  String get formattedSalePrice => salePrice != null ? '₦${salePrice!.toStringAsFixed(2)}' : '';
  
  int get likeCount => likedBy.length;
  bool isLikedBy(String userId) => likedBy.contains(userId);
  
  int get commentCount => comments.length;
  List<ProductComment> get sortedComments => comments..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  bool get hasVariants => variants.length > 1 || 
      (variants.isNotEmpty && variants.first.attributes.isNotEmpty);
  
  List<String> get availableColors {
    final colorAttributes = attributes.where((attr) => attr.name.toLowerCase() == 'color').toList();
    if (colorAttributes.isNotEmpty) {
      return colorAttributes.first.options;
    }
    
    final variantColors = variants
        .map((v) => v.attributes['color'])
        .where((color) => color != null && color!.isNotEmpty)
        .toSet()
        .toList();
    
    return variantColors.cast<String>();
  }

  List<String> get availableSizes {
    final sizeAttributes = attributes.where((attr) => attr.name.toLowerCase() == 'size').toList();
    if (sizeAttributes.isNotEmpty) {
      return sizeAttributes.first.options;
    }
    
    final variantSizes = variants
        .map((v) => v.attributes['size'])
        .where((size) => size != null && size!.isNotEmpty)
        .toSet()
        .toList();
    
    return variantSizes.cast<String>();
  }

  MangoProductItem copyWith({
    List<String>? likedBy,
    List<ProductComment>? comments,
    int? viewCount,
    int? soldCount,
    double? rating,
    int? reviewCount,
    int? stockQuantity,
    String? vendorId,
    String? vendorName,
    List<String>? tags,
  }) {
    return MangoProductItem(
      id: id,
      title: title,
      description: description,
      category: category,
      price: price,
      salePrice: salePrice,
      sku: sku,
      brand: brand,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrls: imageUrls,
      variants: variants,
      attributes: attributes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      viewCount: viewCount ?? this.viewCount,
      soldCount: soldCount ?? this.soldCount,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      tags: tags ?? this.tags,
      likedBy: likedBy ?? this.likedBy,
      comments: comments ?? this.comments,
    );
  }
}


class ProductComment {
  final String id;
  final String userId;
  final String userEmail; 
  final String userAvatar; 
  final String text;
  final double rating; 
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> likedBy; 
  final String? parentId; 

  ProductComment({
    required this.id,
    required this.userId,
    required this.userEmail,
    this.userAvatar = '',
    required this.text,
    this.rating = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.likedBy = const [],
    this.parentId,
  });

  factory ProductComment.fromMap(Map<String, dynamic> data) {
    return ProductComment(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userAvatar: data['userAvatar'] ?? '',
      text: data['text'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      parentId: data['parentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userAvatar': userAvatar,
      'text': text,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'likedBy': likedBy,
      'parentId': parentId,
    };
  }

  
  int get likeCount => likedBy.length;
  bool get isReply => parentId != null;
  
  
  ProductComment copyWith({
    String? text,
    double? rating,
    List<String>? likedBy,
    DateTime? updatedAt,
  }) {
    return ProductComment(
      id: id,
      userId: userId,
      userEmail: userEmail,
      userAvatar: userAvatar,
      text: text ?? this.text,
      rating: rating ?? this.rating,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likedBy: likedBy ?? this.likedBy,
      parentId: parentId,
    );
  }
}

class ProductVariant {
  final String id;
  final String sku;
  final double price;
  final double? salePrice;
  final int stockQuantity;
  final Map<String, String> attributes;
  final String? imageUrl;
  final double weight;
  final bool isActive;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.price,
    this.salePrice,
    required this.stockQuantity,
    required this.attributes,
    this.imageUrl,
    this.weight = 0.0,
    this.isActive = true,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> data) {
    return ProductVariant(
      id: data['id'] ?? '',
      sku: data['sku'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      salePrice: data['salePrice']?.toDouble(),
      stockQuantity: data['stockQuantity'] ?? 0,
      attributes: Map<String, String>.from(data['attributes'] ?? {}),
      imageUrl: data['imageUrl'],
      weight: (data['weight'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'price': price,
      'salePrice': salePrice,
      'stockQuantity': stockQuantity,
      'attributes': attributes,
      'imageUrl': imageUrl,
      'weight': weight,
      'isActive': isActive,
    };
  }

  bool get inStock => stockQuantity > 0;
  double get currentPrice => salePrice ?? price;
}

class ProductAttribute {
  final String name;
  final List<String> options;
  final bool isVisible;
  final bool isVariation;

  ProductAttribute({
    required this.name,
    required this.options,
    this.isVisible = true,
    this.isVariation = false,
  });

  factory ProductAttribute.fromMap(Map<String, dynamic> data) {
    return ProductAttribute(
      name: data['name'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      isVisible: data['isVisible'] ?? true,
      isVariation: data['isVariation'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'options': options,
      'isVisible': isVisible,
      'isVariation': isVariation,
    };
  }
}