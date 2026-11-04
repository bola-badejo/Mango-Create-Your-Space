import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Spaces/screens/space_detail.dart';
import 'package:mango/Spaces/screens/space_home.dart';
import 'package:mango/Utils/format_naira.dart';
import 'package:mango/Utils/text_highlighter.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Utils/theme.dart';

class SpaceContentScreen extends StatefulWidget {
  final SpaceContentArguments arguments;

  const SpaceContentScreen({super.key, required this.arguments});

  @override
  State<SpaceContentScreen> createState() => _SpaceContentScreenState();
}

class _SpaceContentScreenState extends State<SpaceContentScreen>
    with TickerProviderStateMixin {
  final SpaceController _controller = Get.find<SpaceController>();
  final ThemeController _themeController = Get.find<ThemeController>();
  
  late AnimationController _animationController;
  late Animation<double> _cardHeightAnimation;
  late Animation<double> _cardWidthAnimation;
  late Animation<double> _contentOpacityAnimation;
  late Animation<double> _imageScaleAnimation;

  List<SpaceModel> _spaces = [];
  List<SpaceModel> _filteredSpaces = [];
  bool _isLoading = true;
  bool _animationsInitialized = false;

  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  final FocusNode _searchFocusNode = FocusNode();

  static const _animationDuration = Duration(milliseconds: 600);
  static const _avatarRadius = 40.0;
  static const _maxImages = 15;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _fetchSpaces();
    _searchController.addListener(_onSearchChanged);
  }

  // FIXED: Now both featured and private spaces use list view
  bool get _useListView {
    return widget.arguments.cardType == 'featured' ||
        widget.arguments.cardType == 'private';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationsInitialized) {
      _initializeAnimations();
      _animationsInitialized = true;
      _animationController.forward();
    }
  }

  void _initializeAnimations() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    _cardHeightAnimation =
        Tween<double>(
          begin: widget.arguments.height,
          end: screenHeight * 0.4,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _cardWidthAnimation =
        Tween<double>(begin: widget.arguments.width, end: screenWidth).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );

    _contentOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _imageScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  Stream<List<SpaceModel>> _getSpaceStream() {
    switch (widget.arguments.cardType) {
      case 'featured':
        return _controller.fetchFeaturedSpaces();
      case 'private':
        return _controller.fetchPrivateSpaces();
      case 'joined':
        return _controller.fetchJoinedSpaces();
      case 'explore':
        return _controller.fetchAllSpaces();
      default:
        return _controller.fetchAllSpaces();
    }
  }

  void _fetchSpaces() {
    final stream = _getSpaceStream();

    stream.listen(
      (spaces) {
        if (mounted) {
          setState(() {
            _spaces = spaces;
            _filteredSpaces = spaces;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        _showErrorSnackbar(error.toString());
      },
    );
  }

  void _showErrorSnackbar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading spaces: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredSpaces = _spaces;
      });
      return;
    }

    setState(() {
      _filteredSpaces = _spaces.where((space) {
        return space.title.toLowerCase().contains(query) ||
            space.description.toLowerCase().contains(query) ||
            space.category.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
        _filteredSpaces = _spaces;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.arguments.color,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              // Background Animation
              Positioned.fill(
                left: -100,
                bottom: -20,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _darkenColor(widget.arguments.color, 0.05),
                    BlendMode.srcATop,
                  ),
                  child: Lottie.asset(
                    "asset/images/scratching.json",
                    fit: BoxFit.cover,
                    repeat: true,
                    animate: true,
                  ),
                ),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
                    ),
                  ),
                ),
              ),

              // Main Content
              MediaQuery.removePadding(
                removeTop: true,
                context: context,
                child: SafeArea(
                  top: true,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              Container(
                                height: MediaQuery.of(context).size.height * 0.4,
                                child: _buildHeroContent(),
                              ),
                              const SizedBox(height: 20),

                              Opacity(
                                opacity: _contentOpacityAnimation.value,
                                child: _useListView
                                    ? _buildListViewLayout()
                                    : _buildGridViewLayout(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              Positioned.fill(
                top: -640,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildSearchBar(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroContent() {
    return Stack(
      children: [
        Positioned(
          right: -100,
          top: -100,
          child: Transform.scale(
            scale: _imageScaleAnimation.value,
            child: SizedBox(
              height: _getImageSize(_cardHeightAnimation.value),
              child: _buildHeroImage(
                widget.arguments.imageUrl,
                _getImageSize(_cardHeightAnimation.value),
                borderRadius: widget.arguments.cardType == 'joined' ? 25 : 12,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: widget.arguments.titleTag,
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        widget.arguments.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Hero(
                    tag: widget.arguments.subtitleTag,
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        widget.arguments.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              Row(
                children: [
                  _buildRatingBox(widget.arguments.rating),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showSearchBar
          ? Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search by title, description, category...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _toggleSearchBar,
                  ),
                ],
              ),
            )
          : Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _toggleSearchBar,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Search ${widget.arguments.title.toLowerCase()}...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // NEW: List View Layout for Private and Featured Spaces
  Widget _buildListViewLayout() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredSpaces.isEmpty) {
      return _buildEmptyState();
    }

    return OptimizedListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredSpaces.length,
      itemBuilder: (context, index) {
        final space = _filteredSpaces[index];
        return _buildCustomCard(space, index);
      },
    );
  }

  // NEW: Custom Card Widget for Private and Featured Spaces
  Widget _buildCustomCard(SpaceModel space, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        _contentOpacityAnimation.value == 1.0 ? 0 : 30,
        0,
      ),
      child: GestureDetector(
        onTap: () {
          Get.to(
            () => SpaceDetailScreen(space),
            arguments: {'spaceId': space.id},
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Stack(
            children: [
              // Main Card Container
              Container(
                width: double.infinity,
                height: 250,
                margin: const EdgeInsets.only(right: 10, left: 10, top: 50),
                padding: const EdgeInsets.only(left: 25, right: 20),
                decoration: BoxDecoration(
                  color: _themeController.isDarkMode.value 
                      ? Colors.grey[800] 
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 10),
                      blurRadius: 33,
                      color: _themeController.primaryColorValue.withOpacity(0.3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 80.0),
                      child: Text(
                        space.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _themeController.isDarkMode.value 
                              ? Colors.white 
                              : _themeController.primaryColorValue,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      space.category,
                      style: TextStyle(
                        color: _themeController.isDarkMode.value 
                            ? Colors.white 
                            : _themeController.primaryColorValue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSpaceItem(
                          name: "Price",
                          value: space.price.isEmpty ? "0" : formatNaira(space.price),
                        ),
                        _buildSpaceItem(
                          name: "Members",
                          value: space.members.toString(),
                        ),
                        _buildSpaceItem(
                          name: "Category",
                          value: space.category,
                        ),
                        _buildSpaceItem(
                          name: "Rating",
                          value: space.rating.isEmpty ? "0" : space.rating,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Hero Image
              Positioned(
                right: 30,
                child: Hero(
                  tag: space.image.isEmpty ? "space_image" : space.image,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: space.image.isEmpty
                        ? Image.asset(
                            "asset/images/space3.png",
                            height: 115,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            space.image,
                            height: 115,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                                  "asset/images/space3.png",
                                  height: 115,
                                  fit: BoxFit.cover,
                                ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for space items (Price, Members, Category, Rating)
  Widget _buildSpaceItem({required String name, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _themeController.isDarkMode.value 
                ? Colors.white 
                : _themeController.primaryColorValue,
          ),
        ),
        Text(
          name,
          style: TextStyle(
            fontSize: 8,
            color: _themeController.isDarkMode.value 
                ? Colors.white70 
                : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Grid View Layout for Explore and Joined Spaces
  Widget _buildGridViewLayout() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredSpaces.isEmpty) {
      return _buildEmptyState();
    }

    return OptimizedGridView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 50,
        childAspectRatio: 0.7,
      ),
      itemCount: _filteredSpaces.length,
      itemBuilder: (context, index) {
        final space = _filteredSpaces[index];
        return _buildAnimatedGridCard(space, index);
      },
    );
  }

  Widget _buildAnimatedGridCard(SpaceModel space, int index) {
    const avatarRadius = 40.0;

    int imageIndex = (index % _maxImages) + 1;
    String imagePath = 'asset/images/mango-$imageIndex.jpg';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        _contentOpacityAnimation.value == 1.0 ? 0 : 50,
        0,
      ),
      child: SizedBox(
        height: 300 + avatarRadius,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        space.image.isNotEmpty ? space.image : imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(imagePath, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 1, sigmaY: 4),
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.3),
                                    Colors.black.withOpacity(0.6),
                                  ],
                                  stops: const [
                                    0.0,
                                    0.2,
                                    0.4,
                                    0.5,
                                    0.6,
                                    0.7,
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(height: avatarRadius),
                          HighlightedMultilineText(
                            text: space.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              height: 1,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            space.category,
                            style: const TextStyle(
                              fontSize: 6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            space.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 9,
                              height: 1,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          const Divider(color: Colors.white, thickness: 0.6),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Get.to(
                                    () => SpaceDetailScreen(space),
                                    arguments: {'spaceId': space.id},
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.1),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Space',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatNaira(space.price),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  _buildCardRatingBox(space.rating),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -avatarRadius,
              left: 0,
              right: 0,
              child: _buildSpaceAvatar(space, avatarRadius),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearchQuery = _searchController.text.isNotEmpty;

    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearchQuery ? Icons.search_off : Icons.space_dashboard,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearchQuery
                  ? 'No spaces found for "${_searchController.text}"'
                  : 'No spaces found',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            if (hasSearchQuery) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                },
                child: const Text(
                  'Clear search',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpaceAvatar(SpaceModel space, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: space.iconUrl.isNotEmpty && _isValidImageUrl(space.iconUrl)
          ? CircleAvatar(
              radius: radius - 2,
              backgroundColor: Colors.transparent,
              backgroundImage: NetworkImage(space.iconUrl),
            )
          : CircleAvatar(
              radius: radius - 2,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.space_dashboard,
                size: radius,
                color: Colors.grey[600],
              ),
            ),
    );
  }

  bool _isValidImageUrl(String url) {
    return url.isNotEmpty &&
        url.startsWith('http') &&
        Uri.tryParse(url)?.host.isNotEmpty == true;
  }

  double _getImageSize(double cardHeight) {
    double baseSize;
    switch (widget.arguments.cardType) {
      case 'featured':
      case 'private':
        baseSize = 200;
        break;
      case 'joined':
      case 'explore':
        baseSize = 200;
        break;
      default:
        baseSize = 200;
    }
    return baseSize * (1.0 + _animationController.value * 0.2);
  }

  Widget _buildHeroImage(
    String imageUrl,
    double height, {
    double borderRadius = 12,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Hero(
        tag: imageUrl,
        child: _buildImageWithFallback(imageUrl, height),
      ),
    );
  }

  Widget _buildImageWithFallback(String imageUrl, double height) {
    try {
      return Image.asset(imageUrl, height: height, fit: BoxFit.cover);
    } catch (e) {
      return Container(
        height: height,
        width: height,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }
  }

  Widget _buildRatingBox(String rating) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              4,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 10),
            ),
            const Icon(Icons.star, color: Colors.grey, size: 10),
            const SizedBox(width: 4),
            Text(
              rating,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRatingBox(String rating) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              4,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 4),
            ),
            const Icon(Icons.star, color: Colors.grey, size: 4),
            Text(
              rating,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 6,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}