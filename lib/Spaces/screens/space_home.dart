import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Spaces/common/card_items.dart';
import 'package:mango/Spaces/common/model.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Spaces/screens/space_content.dart';
import 'package:mango/Spaces/screens/space_detail.dart';
import 'package:mango/Spaces/screens/space_pods/space_music.dart';
import 'package:shimmer/shimmer.dart';

class SpaceHomeConstants {
  static const double horizontalPadding = 25.0;
  static const double headerTopSpacing = 80.0;
  static const double cardSpacing = 10.0;
  static const double smallCardSpacing = 20.0;
}

class SpaceCardThemes {
  static Map<String, Color> getCardColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return {
      'featured': isDark ? Colors.blue.shade800 : Colors.lightBlue.shade400,
      'private': isDark ? Colors.purple.shade800 : Colors.deepPurpleAccent.shade400,
      'joined': isDark ? Colors.green.shade800 : Colors.lightGreen.shade400,
      'explore': isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade400,
    };
  }
  
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade900
        : Colors.white;
  }
  
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }
  
  static Color getSubtitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }
  
  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }
  
  static Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withOpacity(0.5)
        : Colors.black12;
  }
}

class SpaceContentArguments {
  final String cardType;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String rating;
  final Color color;
  final String heroTag;
  final String titleTag;
  final String subtitleTag;
  final double height;
  final double width;
  final Widget imagePosition;

  const SpaceContentArguments({
    required this.cardType,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.color,
    required this.heroTag,
    required this.titleTag,
    required this.subtitleTag,
    required this.height,
    required this.width,
    required this.imagePosition,
  });
}

class SpaceHomeScreen extends StatelessWidget {
  final SpaceController _controller = Get.put(SpaceController());

  SpaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpaceCardThemes.getBackgroundColor(context),
      extendBodyBehindAppBar: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceHomeConstants.horizontalPadding),
          child: Column(
            children: [
              const SizedBox(height: SpaceHomeConstants.headerTopSpacing),
              _buildHeader(context),
              const SizedBox(height: SpaceHomeConstants.smallCardSpacing),
              // Explore Spaces card moved to top
              _buildExploreSpacesCard(context),
              const SizedBox(height: SpaceHomeConstants.cardSpacing),
              _buildTopRowCards(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Create\nyour Space",
          style: TextStyle(
            fontSize: 30,
            height: 1.1,
            color: SpaceCardThemes.getTextColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: (){
            Get.toNamed('new-space');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: SpaceCardThemes.getShadowColor(context),
                  blurRadius: 9,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.add, 
              size: 28, 
              color: SpaceCardThemes.getIconColor(context)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopRowCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFeaturedSpacesCard(context),
            _buildRightColumnCards(context),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSpacesCard(BuildContext context) {
    final colors = SpaceCardThemes.getCardColors(context);
    return _SpaceCard(
      height: 400,
      width: (MediaQuery.of(context).size.width / 2) - 30,
      title: "Featured Spaces",
      subtitle: "Discover the most loved and buzzing spaces.",
      imageUrl: "asset/images/space.png",
      rating: "4.0",
      color: colors['featured']!,
      heroTag: "image1",
      titleTag: "title1",
      subtitleTag: "subtitle1",
      imagePosition: Positioned(
        bottom: -50,
        right: -120,
        child: _buildHeroImage("asset/images/space.png", 350),
      ),
      onTap: () => _handleCardTap('featured', context),
    );
  }

  Widget _buildRightColumnCards(BuildContext context) {
    return Column(
      children: [
        _buildPrivateSpacesCard(context),
        const SizedBox(height: SpaceHomeConstants.cardSpacing),
        _buildJoinedSpacesCard(context),
      ],
    );
  }

  Widget _buildPrivateSpacesCard(BuildContext context) {
    final colors = SpaceCardThemes.getCardColors(context);
    return _SpaceCard(
      height: 195,
      width: (MediaQuery.of(context).size.width / 2) - 30,
      title: "Private Spaces",
      subtitle: "Safe, personal, just\nfor your inner circle.",
      imageUrl: "asset/images/jupiter_PNG3.png",
      rating: "4.2",
      color: colors['private']!,
      heroTag: "image2",
      titleTag: "title2",
      subtitleTag: "subtitle2",
      imagePosition: Positioned(
        left: 20,
        bottom: -110,
        child: _buildHeroImage("asset/images/jupiter_PNG3.png", 200),
      ),
      onTap: () => _handleCardTap('private', context),
    );
  }

  Widget _buildJoinedSpacesCard(BuildContext context) {
    final colors = SpaceCardThemes.getCardColors(context);
    return _SpaceCard(
      height: 195,
      width: (MediaQuery.of(context).size.width / 2) - 30,
      title: "Joined Spaces",
      subtitle: "Stay close to the\nspaces you belong.",
      imageUrl: "asset/images/space_4.png",
      rating: "4.3",
      color: colors['joined']!,
      heroTag: "image3",
      titleTag: "title3",
      subtitleTag: "subtitle3",
      imagePosition: Positioned(
        left: 20,
        bottom: -110,
        child: _buildHeroImage(
          "asset/images/space_4.png",
          200,
          borderRadius: 25,
        ),
      ),
      onTap: () => _handleCardTap('joined', context),
    );
  }

  Widget _buildExploreSpacesCard(BuildContext context) {
    final colors = SpaceCardThemes.getCardColors(context);
    return _SpaceCard(
      height: 160,
      width: MediaQuery.of(context).size.width,
      title: "Explore Spaces",
      subtitle: "Dive into fresh spaces\nand meet new people.",
      imageUrl: "asset/images/space_5.png",
      rating: "4.1",
      color: colors['explore']!,
      heroTag: "image4",
      titleTag: "title4",
      subtitleTag: "subtitle4",
      imagePosition: Positioned(
        bottom: -30,
        right: -30,
        child: _buildHeroImage("asset/images/space_5.png", 200),
      ),
      onTap: () => _handleCardTap('explore', context),
    );
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
        child: Icon(Icons.image, color: Colors.grey.shade600),
      );
    }
  }

  void _handleCardTap(String cardType, BuildContext context) {
    final colors = SpaceCardThemes.getCardColors(context);
    switch (cardType) {
      case 'featured':
        _navigateToSpaceContent(
          context,
          SpaceContentArguments(
            cardType: 'featured',
            title: "Featured Spaces",
            subtitle: "Discover the most loved and buzzing spaces.",
            imageUrl: "asset/images/space.png",
            rating: "4.0",
            color: colors['featured']!,
            heroTag: "image1",
            titleTag: "title1",
            subtitleTag: "subtitle1",
            height: 400,
            width: (MediaQuery.of(context).size.width / 2) - 30,
            imagePosition: Positioned(
              bottom: -50,
              right: -120,
              child: _buildHeroImage("asset/images/space.png", 350),
            ),
          ),
        );
        break;
      case 'private':
        _navigateToSpaceContent(
          context,
          SpaceContentArguments(
            cardType: 'private',
            title: "Private Spaces",
            subtitle: "Safe, personal, just\nfor your inner circle.",
            imageUrl: "asset/images/jupiter_PNG3.png",
            rating: "4.2",
            color: colors['private']!,
            heroTag: "image2",
            titleTag: "title2",
            subtitleTag: "subtitle2",
            height: 195,
            width: (MediaQuery.of(context).size.width / 2) - 30,
            imagePosition: Positioned(
              left: 20,
              bottom: -110,
              child: _buildHeroImage("asset/images/jupiter_PNG3.png", 200),
            ),
          ),
        );
        break;
      case 'joined':
        _navigateToSpaceContent(
          context,
          SpaceContentArguments(
            cardType: 'joined',
            title: "Joined Spaces",
            subtitle: "Stay close to the\nspaces you belong.",
            imageUrl: "asset/images/space_4.png",
            rating: "4.3",
            color: colors['joined']!,
            heroTag: "image3",
            titleTag: "title3",
            subtitleTag: "subtitle3",
            height: 195,
            width: (MediaQuery.of(context).size.width / 2) - 30,
            imagePosition: Positioned(
              left: 20,
              bottom: -110,
              child: _buildHeroImage("asset/images/space_4.png", 200, borderRadius: 25),
            ),
          ),
        );
        break;
      case 'explore':
        _navigateToSpaceContent(
          context,
          SpaceContentArguments(
            cardType: 'explore',
            title: "Explore Spaces",
            subtitle: "Dive into fresh spaces\nand meet new people.",
            imageUrl: "asset/images/space_5.png",
            rating: "4.1",
            color: colors['explore']!,
            heroTag: "image4",
            titleTag: "title4",
            subtitleTag: "subtitle4",
            height: 160,
            width: MediaQuery.of(context).size.width,
            imagePosition: Positioned(
              bottom: -30,
              right: -30,
              child: _buildHeroImage("asset/images/space_5.png", 200),
            ),
          ),
        );
        break;
    }
  }

  void _navigateToSpaceContent(BuildContext context, SpaceContentArguments args) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return SpaceContentScreen(arguments: args);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 400,
                width: (Get.width / 2) - 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Column(
                children: [
                  Container(
                    height: 195,
                    width: (Get.width / 2) - 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 195,
                    width: (Get.width / 2) - 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            width: Get.width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final double height;
  final double width;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String rating;
  final Color color;
  final String heroTag;
  final String titleTag;
  final String subtitleTag;
  final Widget imagePosition;
  final VoidCallback? onTap;

  const _SpaceCard({
    required this.height,
    required this.width,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.rating,
    required this.color,
    required this.heroTag,
    required this.titleTag,
    required this.subtitleTag,
    required this.imagePosition,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              
              Positioned.fill(
                left: -40,
                right: 0,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _darkenColor(color, 0.03),
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

              Container(color: Colors.black.withOpacity(0.05)),
              
              imagePosition,
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: titleTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Hero(
                      tag: subtitleTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _ratingBox(rating),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingBox(String rating) {
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

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}