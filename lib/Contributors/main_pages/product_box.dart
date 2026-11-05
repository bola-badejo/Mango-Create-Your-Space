import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:mango/Contributors/pages/upload_product.dart';
import 'package:mango/Contributors/pages/upload_product_collecrion.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Store/screens/product_detail_screen.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ProductBoxPage extends StatefulWidget {
  final MangoUser user;
  final String? contributorId;

  const ProductBoxPage({super.key, required this.user, this.contributorId});

  @override
  _ProductBoxPageState createState() => _ProductBoxPageState();
}

class _ProductBoxPageState extends State<ProductBoxPage>
    with TickerProviderStateMixin {
  bool _showUploadOptions = false;
  bool _showYourProducts = true;
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _contributorId;

  @override
  void initState() {
    super.initState();
    _determineContributorId();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  void _determineContributorId() {
    if (widget.contributorId != null && widget.contributorId!.isNotEmpty) {
      _contributorId = widget.contributorId;
    } else if (widget.user.vendorID != null &&
        widget.user.vendorID!.isNotEmpty) {
      _contributorId = widget.user.vendorID;
    } else if (widget.user.creatorID != null &&
        widget.user.creatorID!.isNotEmpty) {
      _contributorId = widget.user.creatorID;
    } else if (widget.user.distributorID != null &&
        widget.user.distributorID!.isNotEmpty) {
      _contributorId = widget.user.distributorID;
    }

    debugPrint('ProductBoxPage using contributor ID: $_contributorId');
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleYourProducts() {
    setState(() {
      _showYourProducts = !_showYourProducts;
      _showYourProducts ? _controller.forward() : _controller.reverse();
    });
  }

  void _toggleUploadOptions() {
    setState(() {
      _showUploadOptions = !_showUploadOptions;
    });
  }

  Future<void> _refreshData() async {
    setState(() {});
  }

  // Helper method to safely get numeric values from Firestore
  int _getIntValue(
    Map<String, dynamic> data,
    String key, {
    int defaultValue = 0,
  }) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  double _getDoubleValue(
    Map<String, dynamic> data,
    String key, {
    double defaultValue = 0.0,
  }) {
    final value = data[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return defaultValue;
  }

  String _getStringValue(
    Map<String, dynamic> data,
    String key, {
    String defaultValue = '',
  }) {
    final value = data[key];
    if (value is String) return value;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : MangoPalette.black;
    final backgroundColor = isDarkMode ? MangoPalette.grey900 : Colors.white;
    final cardColor = isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50;
    final secondaryTextColor = isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600;

    if (_contributorId == null || _contributorId!.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Product Box',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: MangoPalette.green500),
              const SizedBox(height: 16),
              Text(
                'No Vendor Profile Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please register as a vendor to upload products.',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Product Box',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
              slivers: [
                _buildStatisticsSection(isDarkMode, textColor, cardColor!),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                _buildUploadSection(isDarkMode, textColor),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                _buildSectionTitle('Best Selling Products', textColor),
                _buildHorizontalProductsList(isDarkMode),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                _buildSectionTitle('Your Collections', textColor),
                _buildHorizontalCollectionsList(isDarkMode),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                _buildYourProductsSection(
                  isDarkMode,
                  textColor,
                  secondaryTextColor!,
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Mango Products. © 2025',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(
    bool isDarkMode,
    Color textColor,
    Color cardColor,
  ) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("products")
            .where("contributorId", isEqualTo: _contributorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildModernStatCard(
              isLoading: true,
              isDarkMode: isDarkMode,
            );
          }

          if (snapshot.hasError) {
            return _buildErrorWidget('Failed to load statistics', isDarkMode);
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildModernStatCard(
              productsCount: 0,
              totalSales: 0,
              monthlySales: 0,
              totalRevenue: 0,
              isDarkMode: isDarkMode,
            );
          }

          final products = snapshot.data!.docs;
          int totalSales = 0;
          int monthlySales = 0;
          double totalRevenue = 0;
          final now = DateTime.now();
          final monthAgo = DateTime(now.year, now.month - 1, now.day);

          for (var productDoc in products) {
            final data = productDoc.data() as Map<String, dynamic>;

            // Safely get values with fallbacks
            final sales = _getIntValue(data, 'sales');
            final revenue = _getDoubleValue(data, 'revenue');
            final price = _getDoubleValue(data, 'price');
            final soldCount = _getIntValue(data, 'soldCount');

            totalSales += sales;
            totalRevenue += revenue;

            // If no revenue field, calculate from price * soldCount
            if (revenue == 0 && price > 0) {
              totalRevenue += price * soldCount;
            }

            final timestamp = data['timestamp'];
            if (timestamp != null) {
              final createdAt = (timestamp as Timestamp).toDate();
              if (createdAt.isAfter(monthAgo)) {
                monthlySales += sales;
              }
            }
          }

          return _buildModernStatCard(
            productsCount: products.length,
            totalSales: totalSales,
            monthlySales: monthlySales,
            totalRevenue: totalRevenue,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard({
    int? productsCount,
    int? totalSales,
    int? monthlySales,
    double? totalRevenue,
    bool isLoading = false,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(isDarkMode ? 0.4 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(Icons.analytics, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Business Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              _buildModernStatItem(
                value: productsCount ?? 0,
                label: 'Total Products',
                icon: Icons.inventory_2,
                color: Colors.teal,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalSales ?? 0,
                label: 'Total Sales',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: monthlySales ?? 0,
                label: 'Monthly Sales',
                icon: Icons.trending_up,
                color: MangoPalette.green500,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildRevenueStatItem(
                value: totalRevenue ?? 0.0,
                label: 'Total Revenue',
                icon: Icons.attach_money,
                color: MangoPalette.green500,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem({
    required int value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey800 : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                )
              else
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: IntTween(begin: 0, end: value),
                  builder: (context, animatedValue, child) {
                    return Text(
                      _formatNumber(animatedValue),
                      style: TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : MangoPalette.black,
                        fontFamily: 'Inter',
                      ),
                    );
                  },
                ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueStatItem({
    required double value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey800 : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                )
              else
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1000),
                  tween: IntTween(begin: 0, end: value.toInt()),
                  builder: (context, animatedValue, child) {
                    return Text(
                      '₦${_formatNumber(animatedValue)}',
                      style: TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : MangoPalette.black,
                        fontFamily: 'Inter',
                      ),
                    );
                  },
                ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.white,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: isDarkMode ? Colors.white : MangoPalette.black),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(bool isDarkMode, Color textColor) {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upload Your Product',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
        tooltip: 'Show options',
                    icon: AnimatedRotation(
                      turns: _showUploadOptions ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(Icons.arrow_drop_down, color: textColor),
                    ),
                    onPressed: _toggleUploadOptions,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _showUploadOptions
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(
                    color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                  ),
                  _buildUploadOption(
                    'Upload a Product',
                    Icons.inventory_2,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UploadProductPage(contributorId: _contributorId),
                      ),
                    ),
                    isDarkMode,
                  ),
                  _buildUploadOption(
                    'Upload a Collection',
                    Icons.collections,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadProductCollectionPage(
                          contributorId: _contributorId,
                        ),
                      ),
                    ),
                    isDarkMode,
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 20, color: Colors.teal, semanticLabel: title),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalProductsList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 180,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("products")
              .where("contributorId", isEqualTo: _contributorId)
              .orderBy("soldCount", descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading products",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No products yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final products = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final data = products[index].data() as Map<String, dynamic>;
                final imageUrl = _getStringValue(data, 'imageUrl');
                final title = _getStringValue(
                  data,
                  'title',
                  defaultValue: 'Untitled',
                );
                final price = _getDoubleValue(data, 'price');
                final soldCount = _getIntValue(data, 'soldCount');

                return _buildProductCard(
                  imageUrl,
                  title,
                  '₦${price.toStringAsFixed(2)}',
                  '$soldCount sold',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalCollectionsList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 180,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("product_collections")
              .where("contributorId", isEqualTo: _contributorId)
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading collections",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No collections yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final collections = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final data = collections[index].data() as Map<String, dynamic>;
                final coverUrl = _getStringValue(data, 'coverUrl');
                final title = _getStringValue(
                  data,
                  'title',
                  defaultValue: 'Untitled Collection',
                );
                final totalProducts = _getIntValue(data, 'totalProducts');

                return _buildCollectionCard(
                  coverUrl,
                  title,
                  '$totalProducts items',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(
    String imageUrl,
    String name,
    String price,
    String sales,
    bool isDarkMode,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MangoRadius.md),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => Container(
                    width: 140,
                    height: 140,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.shopping_bag,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 140,
                    height: 140,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.shopping_bag,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 400),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                Text(
                  sales,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(
    String imageUrl,
    String name,
    String itemCount,
    bool isDarkMode,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(MangoRadius.md),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => Container(
                    width: 140,
                    height: 140,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.collections,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 140,
                    height: 140,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.collections,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    itemCount,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : MangoPalette.black,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourProductsSection(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          MangoPressable(
            onTap: _toggleYourProducts,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showYourProducts ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_up, color: textColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizeTransition(
  sizeFactor: _animation,
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection("products")
        .where("contributorId", isEqualTo: _contributorId)
        .orderBy("timestamp", descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading', 
            color: isDarkMode ? Colors.white : MangoPalette.black,
          ),
        );
      }

      if (snapshot.hasError) {
        // Check for specific Firebase errors
        final error = snapshot.error.toString();
        
        // Missing index error
        if (error.contains('FAILED_PRECONDITION') || error.contains('index')) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle,
                    size: 48,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Setting up database...",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This may take a few minutes",
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(MangoRadius.sm),
                      ),
                      child: Text(
                        "Debug: Missing composite index for products collection.\nCreate index: contributorId Ascending, timestamp Descending",
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        // Permission denied error
        if (error.contains('PERMISSION_DENIED')) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: secondaryTextColor,
                ),
                const SizedBox(height: 16),
                Text(
                  "Access restricted",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "You don't have permission to view these products",
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Network error
        if (error.contains('UNAVAILABLE') || error.contains('network')) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 48,
                  color: secondaryTextColor,
                ),
                const SizedBox(height: 16),
                Text(
                  "Connection issue",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please check your internet connection",
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Force refresh the stream
                    (context as Element).markNeedsBuild();
                  },
                  child: Text(
                    "Retry",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Generic error
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: secondaryTextColor,
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't load products",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Pull to refresh or try again later",
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                  ),
                  child: Text(
                    "Debug: ${snapshot.error}",
                    style: TextStyle(
                      color: Colors.red[300],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: secondaryTextColor,
              ),
              const SizedBox(height: 16),
              Text(
                "No products yet",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Products you upload will appear here",
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      final products = snapshot.data!.docs;

      return Column(
        children: List.generate(products.length, (index) {
          final data = products[index].data() as Map<String, dynamic>;
          final imageUrl = _getStringValue(data, 'imageUrl');
          final title = _getStringValue(
            data,
            'title',
            defaultValue: 'Untitled',
          );
          final price = _getDoubleValue(data, 'price');
          final soldCount = _getIntValue(data, 'soldCount');

          return _buildProductItem(
            id: products[index].id,
            imageUrl: imageUrl,
            name: title,
            price: '₦${price.toStringAsFixed(2)}',
            sales: soldCount,
            isDarkMode: isDarkMode,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          );
        }),
      );
    },
  ),
),
        ],
      ),
    );
  }

  Widget _buildProductItem({
    required String id,
    required String imageUrl,
    required String name,
    required String price,
    required int sales,
    required bool isDarkMode,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.to(
              () => ProductDetailScreen(productId: id),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 300),
            );
          },
          borderRadius: BorderRadius.circular(MangoRadius.md),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey50,
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                      child: Icon(
                        Icons.shopping_bag,
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                      child: Icon(
                        Icons.shopping_bag,
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                    ),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 12,
                          color: MangoPalette.green500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Text(
                    '$sales sold',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
