import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Spaces/controllers/space_item.dart';
import 'package:mango/utils.dart';

import '../../../Home/controllers/dashboard_controller.dart';
import '../../../Home/pages/post_shimmer.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class SpaceShop extends StatelessWidget {
  SpaceShop({super.key});

  final MangoDashboardController controller = Get.put(
    MangoDashboardController(),
  );
  final SpaceItemsService itemController = Get.put(SpaceItemsService());
  final String? spaceId = Get.arguments?['spaceId'];

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (spaceId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Space ID not provided',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    
    final spaceDoc = FirebaseFirestore.instance.collection('spaces').doc(spaceId!);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: spaceDoc.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(
                'Space not found',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        
        final spaceData = snapshot.data!.data() as Map<String, dynamic>?;
        final isCreator = spaceData?['postCreator'] == currentUserId;
        final collaborators = List<String>.from(spaceData?['collaborators'] ?? []);
        final isCollaborator = collaborators.contains(currentUserId);
        final isAdmin = isCreator || isCollaborator;
        
        return _buildMainContent(context, isAdmin);
      },
    );
  }
  
  Widget _buildLoadingScaffold() {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading'),
      ),
    );
  }
  
  Widget _buildMainContent(BuildContext context, bool isAdmin) {
    Widget _buildSectionWithSeeAll(
      String title, {
      required VoidCallback onSeeAll,
      required Widget content,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColorLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                MangoPressable(
        semanticLabel: 'Next',
                  onTap: onSeeAll,
                  child: const Icon(Icons.arrow_forward_ios, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          content,
        ],
      );
    }

    Widget _buildEmptyProductSection(String message) {
      return Container(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag, size: 32, color: MangoPalette.grey400),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: MangoPalette.grey600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildCardSkeleton() {
      return Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(semanticsLabel: 'Loading', strokeWidth: 2),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: MangoPalette.grey300,
              margin: EdgeInsets.only(bottom: 4),
            ),
            Container(width: 80, height: 10, color: MangoPalette.grey300),
          ],
        ),
      );
    }

    Widget _buildProductCard(Map<String, dynamic> productData, int index) {
      final price = productData['price'] ?? 0;
      final originalPrice = productData['originalPrice'] ?? price;
      final isOnSale = productData['isOnSale'] ?? false;
      final discount = productData['discount'] ?? 0;
      
      return Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                    image: DecorationImage(
                      image: NetworkImage(
                        productData['image'] ?? productData['thumbnail'] ?? '',
                      ),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        print('Error loading product image: $exception');
                      },
                    ),
                  ),
                ),
                // Rank badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Sale badge
                if (isOnSale)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                      child: Text(
                        '-${discount}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Price tag
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₦${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isOnSale)
                          Text(
                            '₦${originalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productData['title'] ?? 'Unknown Product',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              productData['seller'] ?? 'Unknown Seller',
              style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(Icons.star, size: 10, color: Colors.amber),
                SizedBox(width: 2),
                Text(
                  productData['rating']?.toString() ?? '0.0',
                  style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                ),
                SizedBox(width: 8),
                Icon(Icons.shopping_cart, size: 10, color: MangoPalette.grey500),
                SizedBox(width: 2),
                Text(
                  productData['sold']?.toString() ?? '0',
                  style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildMarketplaceCollectionSection() {
      return _buildSectionWithSeeAll(
        'Marketplace',
        onSeeAll: () => Get.toNamed('/shop-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId!)
              .collection('space-products')
              .orderBy('savedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 200,
                width: 160,
                color: MangoPalette.grey300,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyProductSection(
                isAdmin 
                    ? 'No products added yet. Tap the + button to add products!'
                    : 'No products available in the marketplace yet'
              );
            }
            
            final spaceItems = snapshot.data!.docs;
            
            return Container(
              height: 210,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: spaceItems.length,
                itemBuilder: (context, index) {
                  final item = spaceItems[index];
                  final data = item.data() as Map<String, dynamic>;
                  final originalItemId = data['originalItemId'] ?? '';
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('products')
                        .doc(originalItemId)
                        .get(),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildCardSkeleton();
                      }

                      if (productSnapshot.hasError || !productSnapshot.hasData || !productSnapshot.data!.exists) {
                        return Container(
                          width: 140,
                          margin: EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: MangoPalette.grey300,
                                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag,
                                          color: MangoPalette.grey600,
                                          size: 24,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Product not found',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: MangoPalette.grey600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Product not available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MangoPalette.grey500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }

                      final productData = productSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildProductCard(productData, index);
                    },
                  );
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildTrendingProductsSection() {
      return _buildSectionWithSeeAll(
        'Trending Items',
        onSeeAll: () => Get.toNamed('/shop-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('isTrending', isEqualTo: true)
              .orderBy('sales', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 200,
                width: 160,
                color: MangoPalette.grey300,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyProductSection('No trending products available');
            }
            
            final products = snapshot.data!.docs;
            
            return Container(
              height: 210,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final productData = products[index].data() as Map<String, dynamic>;
                  return _buildProductCard(productData, index);
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildDealsOfTheDaySection() {
      return _buildSectionWithSeeAll(
        'Deals of the Day',
        onSeeAll: () => Get.toNamed('/shop-deals'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('isOnSale', isEqualTo: true)
              .where('dealEndsAt', isGreaterThan: Timestamp.now())
              .orderBy('discount', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 200,
                width: 160,
                color: MangoPalette.grey300,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyProductSection('No active deals right now');
            }
            
            final products = snapshot.data!.docs;
            
            return Container(
              height: 210,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final productData = products[index].data() as Map<String, dynamic>;
                  return _buildProductCard(productData, index);
                },
              ),
            );
          },
        ),
      );
    }

    var size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(height: size.height * .1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleMedium,
                        children: const [
                          TextSpan(
                            text: "Shop the Vibe.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: "\nMarketplace.",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SpaceShopActions(
                    spaceId: spaceId!, 
                    podType: 'shop',
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 10),
                  _buildMarketplaceCollectionSection(),
                  const SizedBox(height: 10),
                  _buildTrendingProductsSection(),
                  const SizedBox(height: 10),
                  _buildDealsOfTheDaySection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Text(
                      'Marketplace Chat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColorLight,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: MarketplaceChatCard(
                      spaceId: spaceId!, 
                      podType: 'shop',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleSmall,
                        children: const [
                          TextSpan(text: "Live "),
                          TextSpan(
                            text: "Shopping Events...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LiveShoppingCard(
                      spaceId: spaceId!, 
                      podType: 'shop',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "Vendor Spotlight",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  VendorSpotlightList(spaceId: spaceId!, isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shop-specific Actions Widget
class SpaceShopActions extends StatelessWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const SpaceShopActions({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildButton(
            context,
            color: Colors.deepPurple,
            icon: Icons.chat,
            text: "Market Chat",
            onTap: isAdmin 
                ? () => _openMarketChatSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "start market chats"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: MangoPalette.green500,
            icon: Icons.live_tv,
            text: "Live Shopping",
            onTap: isAdmin 
                ? () => _openLiveShoppingSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create live shopping events"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: MangoPalette.green500,
            icon: Icons.store,
            text: "Vendor",
            onTap: isAdmin 
                ? () => _openVendorSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create vendor spots"),
            isDisabled: !isAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return MangoPressable(
      onTap: onTap,
      child: Container(
        height: 100,
        width: 90,
        decoration: BoxDecoration(
          color: isDisabled ? MangoPalette.grey700 : color,
          borderRadius: BorderRadius.circular(MangoRadius.lg),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPermissionDenied(BuildContext context, String action) {
    UtilsService().showSnackbar(
      "Permission Denied",
      "Only space creators and collaborators can $action",
      backgroundColor: Colors.red,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openMarketChatSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Market chat feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openLiveShoppingSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Live shopping feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openVendorSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Vendor spotlight feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }
}

// Marketplace Chat Card (Shop-specific)
class MarketplaceChatCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const MarketplaceChatCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<MarketplaceChatCard> createState() => _MarketplaceChatCardState();
}

class _MarketplaceChatCardState extends State<MarketplaceChatCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400",
    "https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400",
    "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400",
    "https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400",
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('marketChat')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoMarketChatCarousel();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: MangoPalette.black,
                              borderRadius: BorderRadius.circular(MangoRadius.sm),
                            ),
                            child: Text(
                              data['status'] ?? "Active",
                              style: const TextStyle(
                                fontSize: 12,
                                color: MangoPalette.grey500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            data['title'] ?? "Marketplace Chat",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data['members'] ?? 0} shoppers online",
                            style: const TextStyle(
                              fontSize: 12,
                              color: MangoPalette.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          MangoPressable(
                            onTap: () {
                              setState(() {
                                _isExpanded = !_isExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'tap for more',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: MangoPalette.black.withOpacity(0.8),
                                  ),
                                ),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: MangoPalette.black.withOpacity(0.8),
                                  size: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data['description'] ?? 'Discuss products, deals, and shopping tips!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MangoPalette.black.withOpacity(0.6),
                                ),
                                maxLines: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        width: _isExpanded ? 140 : 100,
                        height: _isExpanded ? 140 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MangoPalette.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                          child: data['image'] != null
                              ? Image.network(
                                  data['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/marketplace.jpg",
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoMarketChatCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  MangoPalette.black.withOpacity(0.3),
                  MangoPalette.black.withOpacity(0.6),
                  MangoPalette.black.withOpacity(0.8),
                  MangoPalette.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.9),
                borderRadius: BorderRadius.circular(MangoRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "MARKET",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Start a Market Chat" : "Join the Market",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Create a marketplace chat to discuss products, deals, and shopping!"
                      : "No active marketplace chats. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.deepPurple
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: MangoPalette.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Live Shopping Card (Shop-specific)
class LiveShoppingCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const LiveShoppingCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<LiveShoppingCard> createState() => _LiveShoppingCardState();
}

class _LiveShoppingCardState extends State<LiveShoppingCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400",
    "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400",
    "https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400",
    "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400",
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('liveShopping')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('scheduledTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoLiveShoppingCarousel();
        }

        final sessions = snapshot.data!.docs;
        final currentSession = sessions.first.data() as Map<String, dynamic>;

        return Container(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: _isExpanded ? 200 : 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.lg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: MangoPalette.black,
                              borderRadius: BorderRadius.circular(MangoRadius.sm),
                            ),
                            child: Text(
                              _getShoppingTimeText(currentSession),
                              style: const TextStyle(
                                fontSize: 12,
                                color: MangoPalette.grey500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            currentSession['title'] ?? "Live Shopping",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "${currentSession['shoppers'] ?? 0} shoppers.",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MangoPalette.black,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentSession),
                                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                                ),
                                child: Text(
                                  _getStatusText(currentSession),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        width: _isExpanded ? 140 : 100,
                        height: _isExpanded ? 140 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MangoPalette.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                          child: currentSession['image'] != null
                              ? Image.network(
                                  currentSession['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/live_shopping.jpg",
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getShoppingTimeText(Map<String, dynamic> session) {
    if (session['isLive'] == true) {
      return "LIVE NOW";
    } else if (session['scheduledTime'] != null) {
      final scheduledTime = session['scheduledTime'].toDate();
      final now = DateTime.now();
      final difference = scheduledTime.difference(now);

      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else {
        return 'Starting soon';
      }
    }
    return "Coming soon";
  }

  String _getStatusText(Map<String, dynamic> session) {
    if (session['isLive'] == true) return "LIVE";
    if (session['isScheduled'] == true) return "SCHEDULED";
    return "UPCOMING";
  }

  Color _getStatusColor(Map<String, dynamic> session) {
    if (session['isLive'] == true) return Colors.red;
    if (session['isScheduled'] == true) return MangoPalette.green500;
    return MangoPalette.green500;
  }

  Widget _buildNoLiveShoppingCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  MangoPalette.black.withOpacity(0.3),
                  MangoPalette.black.withOpacity(0.6),
                  MangoPalette.black.withOpacity(0.8),
                  MangoPalette.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MangoPalette.green500.withOpacity(0.9),
                borderRadius: BorderRadius.circular(MangoRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.green500.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "SHOPPING",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Host a Live Shopping Event" : "Live Shopping Events",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Create a live shopping event and showcase products to your space members!"
                      : "No live shopping events scheduled. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? MangoPalette.green500
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: MangoPalette.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Vendor Spotlight List (Shop-specific)
class VendorSpotlightList extends StatelessWidget {
  final String spaceId;
  final bool isAdmin;
  
  const VendorSpotlightList({
    super.key,
    required this.spaceId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('vendorSpotlight')
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildNoVendorSpotlightCarousel();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildNoVendorSpotlightCarousel();
        }

        return Column(
          children: docs.map((data) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 25.0,
                vertical: 10,
              ),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(38.5),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 10),
                      blurRadius: 33,
                      color: Theme.of(context).splashColor.withOpacity(.24),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data["title"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data["vendor"],
                                style: TextStyle(
                                  color: Theme.of(context).primaryColorLight,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  data["category"] ?? "Vendor",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColorLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Image.network(
                        data["image"],
                        width: 55,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoVendorSpotlightCarousel() {
    return _VendorSpotlightCarousel(isAdmin: isAdmin);
  }
}

class _VendorSpotlightCarousel extends StatefulWidget {
  final bool isAdmin;
  
  const _VendorSpotlightCarousel({required this.isAdmin});
  
  @override
  State<_VendorSpotlightCarousel> createState() => _VendorSpotlightCarouselState();
}

class _VendorSpotlightCarouselState extends State<_VendorSpotlightCarousel> {
  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400",
    "https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=400",
    "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=400",
    "https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400",
  ];
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                image: DecorationImage(
                  image: NetworkImage(_carouselImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  MangoPalette.black.withOpacity(0.3),
                  MangoPalette.black.withOpacity(0.6),
                  MangoPalette.black.withOpacity(0.8),
                  MangoPalette.black,
                ],
                stops: const [0.0, 0.3, 0.5, 0.65, 0.8, 0.9, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MangoPalette.green500.withOpacity(0.9),
                borderRadius: BorderRadius.circular(MangoRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.green500.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.store, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "VENDOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).size.height * 0.65 * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? "Feature a Vendor" : "Vendor Spotlight",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Showcase vendors and their products in your marketplace!"
                      : "No vendors featured yet. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: MangoPalette.black.withOpacity(0.6),
                        blurRadius: 8,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselImages.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? MangoPalette.green500
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: MangoPalette.black.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}