import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Spaces/common/card_items.dart';
import 'package:mango/Spaces/common/insights.dart';
import 'package:mango/Spaces/common/model.dart';
import 'package:mango/Spaces/common/more_options.dart';
import 'package:mango/Spaces/common/settings.dart';
import 'package:mango/Spaces/screens/space_landing.dart';
import 'package:mango/utils.dart';

import '../../Home/controllers/dashboard_controller.dart' hide FirestoreService;
import '../../Models/customModel/user.dart';
import '../controllers/space_model.dart';
import '../controllers/space_controller.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Spaces/world/space_world_screen.dart';

class AppColors {
  static const Color lightPrimary = Color.fromARGB(255, 230, 145, 97);
  static const Color lightPrimaryVariant = Color.fromARGB(255, 233, 92, 32);
  static const Color lightSecondary = Color(0xFF369365);
  static const Color lightBackground = Color(0xFFF5F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFE53935);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF1E221F);
  static const Color lightOnSurface = Color(0xFF1E221F);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFDEE1DC);
  static const Color lightIcon = Color(0xFF757575);

  static const Color darkPrimary = Color.fromARGB(255, 9, 169, 55);
  static const Color darkPrimaryVariant = Color.fromARGB(255, 65, 211, 65);
  static const Color darkSecondary = Color(0xFF66BB6A);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1B241E);
  static const Color darkError = Color(0xFFCF6679);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkOnSecondary = Color(0xFFFFFFFF);
  static const Color darkOnBackground = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnError = Color(0xFF0B0F0C);
  static const Color darkCard = Color(0xFF243028);
  static const Color darkDivider = Color(0xFF424242);
  static const Color darkIcon = Color(0xFFAEB1AC);
}

class SpaceDetailScreen extends StatefulWidget {
  SpaceDetailScreen(this.space, {super.key});
  final SpaceModel space;

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  final MangoDashboardController dashboardController = Get.put(
    MangoDashboardController(),
  );
  final SpaceController spaceController = Get.find<SpaceController>();
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = widget.space.postCreator == currentUserId;

    return Scaffold(
      // Step inside the virtual Space: presence, wall, live events.
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'enter-space',
        onPressed: () => Get.to(() => SpaceWorldScreen(spaceId: widget.space.id)),
        icon: const Icon(Icons.meeting_room_rounded),
        label: const Text('Enter Space'),
      ),
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          setState(() {
            _scrollOffset = _scrollController.offset;
          });
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.height * 0.42,
              pinned: true,
              floating: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Parallax Background
                    _buildParallaxBackground(),

                    // Gradient Overlay
                    _buildGradientOverlay(),

                    // App Bar
                    SafeArea(
                      child: _buildAppBar(context, widget.space, isOwner),
                    ),
                  ],
                ),
              ),
            ),

            // Content Card with Image
            SliverToBoxAdapter(
              child: _buildContentCardWithImage(context, widget.space, isOwner),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParallaxBackground() {
    final bg = widget.space.spaceBackground;
    final double parallaxOffset = _scrollOffset * 0.4;

    if (bg != null && bg.isNotEmpty) {
      return Transform.translate(
        offset: Offset(0, parallaxOffset),
        child: CachedNetworkImage(
          imageUrl: bg,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: MangoPalette.grey900,
            child: Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          errorWidget: (context, error, stackTrace) {
            return Transform.translate(
              offset: Offset(0, parallaxOffset),
              child: Image.asset(
                "asset/images/space_bg.png",
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      );
    }
    return Transform.translate(
      offset: Offset(0, parallaxOffset),
      child: Image.asset("asset/images/space_bg.png", fit: BoxFit.cover),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MangoPalette.black.withOpacity(0.2),
            MangoPalette.black.withOpacity(0.4),
            MangoPalette.black.withOpacity(0.6),
            MangoPalette.black.withOpacity(0.85),
          ],
          stops: const [0.0, 0.25, 0.5, 0.85],
        ),
      ),
    );
  }

  Widget _buildContentCardWithImage(
    BuildContext context,
    SpaceModel space,
    bool isOwner,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Content Card
        _buildContentCard(context, space, isOwner),

        // Space Image (positioned to overlap the card)
        Positioned(right: 24, top: -40, child: _buildSpaceImage(space)),
      ],
    );
  }

  Widget _buildContentCard(
    BuildContext context,
    SpaceModel space,
    bool isOwner,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 56),
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space Info
          _buildSpaceInfo(context),

          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: _getTextColor(context).withOpacity(0.1)),

          const SizedBox(height: 16),

          // User Info and Actions
          _buildUserInfoAndActions(context, space, isOwner),
        ],
      ),
    );
  }

  Widget _buildSpaceInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          widget.space.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
            color: _getTextColor(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Category Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:
                (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary)
                    .withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.lg),
          ),
          child: Text(
            widget.space.category,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.attach_money_rounded,
              label: "Price",
              value: widget.space.price.isEmpty
                  ? "Free"
                  : "₦${widget.space.price}",
              context: context,
            ),
            Container(
              width: 1,
              height: 30,
              color: _getTextColor(context).withOpacity(0.1),
            ),
            _buildStatItem(
              icon: Icons.people_alt_rounded,
              label: "Members",
              value: widget.space.members.toString(),
              context: context,
            ),
            Container(
              width: 1,
              height: 30,
              color: _getTextColor(context).withOpacity(0.1),
            ),
            _buildStatItem(
              icon: Icons.category_rounded,
              label: "Category",
              value: widget.space.category,
              context: context,
            ),
            Container(
              width: 1,
              height: 30,
              color: _getTextColor(context).withOpacity(0.1),
            ),
            _buildStatItem(
              icon: Icons.star_rounded,
              label: "Rating",
              value: widget.space.rating.isEmpty ? "0.0" : widget.space.rating,
              context: context,
              valueColor: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: _getTextColor(context).withOpacity(0.5)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? _getTextColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _getTextColor(context).withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoAndActions(
    BuildContext context,
    SpaceModel space,
    bool isOwner,
  ) {
    return StreamBuilder<MangoUser?>(
      stream: spaceController.getUserInfo(space.postCreator),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                strokeWidth: 2,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Text(
            "User not found",
            style: TextStyle(color: _getTextColor(context)),
          );
        }

        var user = snapshot.data!;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: CachedNetworkImageProvider(user.profileImage),
              ),
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Rating
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _getTextColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "@${user.username}",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: _getTextColor(context).withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Rating Stars
                  _buildRatingStars(context),

                  const SizedBox(height: 16),

                  // Action Buttons
                  _buildActionButtons(context, space, isOwner),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingStars(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(Icons.star_rounded, color: Colors.amber, size: 16),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    SpaceModel space,
    bool isOwner,
  ) {
    return Row(
      children: [
        if (!isOwner) ...[
          _buildSubscribeButton(space, context),
          const SizedBox(width: 12),
        ],
        _buildGoInButton(context, space),
      ],
    );
  }

  Widget _buildSubscribeButton(SpaceModel space, BuildContext context) {
    return StreamBuilder<bool>(
      stream: spaceController.isSubscribed(space.id),
      builder: (context, snap) {
        final subscribed = snap.data ?? false;
        return MangoPressable(
          onTap: () {
            spaceController.toggleSubscription(space.id, subscribed);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: subscribed
                  ? LinearGradient(
                      colors: [MangoPalette.grey400, MangoPalette.grey500],
                    )
                  : LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [
                              AppColors.darkPrimary,
                              AppColors.darkPrimaryVariant,
                            ]
                          : [
                              AppColors.lightPrimary,
                              AppColors.lightPrimaryVariant,
                            ],
                    ),
              boxShadow: subscribed
                  ? null
                  : [
                      BoxShadow(
                        color:
                            (Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Text(
              subscribed ? "Subscribed" : "Subscribe",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoInButton(BuildContext context, SpaceModel space) {
    return Expanded(
      child: MangoPressable(
        onTap: () {
          _navigateToSpaceLanding(space);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [AppColors.darkPrimary, AppColors.darkPrimaryVariant]
                  : [AppColors.lightPrimary, AppColors.lightPrimaryVariant],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              "Go in",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSpaceLanding(SpaceModel space) {
    final spaceStations = <dynamic>[
      space.hasMusic == true
          ? {
              'Title': 'Music',
              'Image': 'asset/images/music.jpeg',
              'Description': 'Stream music with members',
              'rating': '5.0',
              'Likes': "138",
            }
          : null,
      space.hasBooks == true
          ? {
              'Title': 'Books',
              'Image': 'asset/images/library.jpeg',
              'Description': 'Read with members',
              'rating': '5.0',
              'Likes': "2h:10m",
            }
          : null,
      space.hasPodcast == true
          ? {
              'Title': 'Podcasts',
              'Image': 'asset/images/podcasts.jpeg',
              'Description': 'Live or recorded podcasts',
              'rating': '4.6',
              'Likes': "1h:45m",
            }
          : null,
      space.hasVines == true
          ? {
              'Title': 'Vines',
              'Image': 'asset/images/movies.jpeg',
              'Description': 'Short video content',
              'rating': '5.0',
              'Likes': "2h:42m",
            }
          : null,
      space.hasShop == true
          ? {
              'Title': 'Shop',
              'Image': 'asset/images/shop.jpeg',
              'Description': 'Buy items or cart for later',
              'rating': '4.0',
              'Likes': "1h:22m",
            }
          : null,
      space.hasLounge == true
          ? {
              'Title': 'Lounge',
              'Image': 'asset/images/lounge.jpeg',
              'Description': 'Live gatherings.',
              'rating': '4.0',
              'Likes': "1h:22m",
            }
          : null,
    ];

    List nonNullSpaceStations = spaceStations.where((e) => e != null).toList();

    Get.to(
      () => SpaceLanding(space, nonNullSpaceStations),
      arguments: {'spaceId': space.id},
    );
  }

  Widget _buildSpaceImage(SpaceModel space) {
    return Hero(
      tag: "space_image_${space.id}",
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: space.iconUrl,
            height: 90,
            width: 90,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: MangoPalette.grey800,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                  strokeWidth: 2,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [AppColors.darkPrimary, AppColors.darkPrimaryVariant]
                      : [AppColors.lightPrimary, AppColors.lightPrimaryVariant],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 45,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkCard
        : AppColors.lightCard;
  }

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
  }

  Color _getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkIcon
        : AppColors.lightIcon;
  }

  Widget _buildAppBar(BuildContext context, SpaceModel space, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: MangoPalette.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
        tooltip: 'Back',
              onPressed: () => Get.back(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MangoPalette.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  color: MangoPalette.green300,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  space.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Menu Button
          Container(
            decoration: BoxDecoration(
              color: MangoPalette.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: _buildAppBarMenu(space, isOwner, context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarMenu(
    SpaceModel space,
    bool isOwner,
    BuildContext context,
  ) {
    return IconButton(
        tooltip: 'More options',
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
      onPressed: () => _showModalSheet(context, space, isOwner),
    );
  }

  void _showModalSheet(BuildContext context, SpaceModel space, bool isOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCardColor(context),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MangoPalette.grey600,
                borderRadius: BorderRadius.circular(MangoRadius.xs),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkPrimary.withOpacity(0.1)
                    : AppColors.lightPrimary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? [
                                AppColors.darkPrimary,
                                AppColors.darkPrimaryVariant,
                              ]
                            : [
                                AppColors.lightPrimary,
                                AppColors.lightPrimaryVariant,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Text(
                      space.title[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          space.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            color: _getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          space.category,
                          style: TextStyle(
                            color: _getTextColor(context).withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Options
            _buildMenuOption(
              context,
              icon: Icons.block_rounded,
              title: 'Block Space',
              subtitle: 'Block this space from appearing',
              onTap: () {
                Navigator.pop(context);
                _handleBlockSpace(space, context);
              },
              isDestructive: true,
            ),
            _buildMenuOption(
              context,
              icon: Icons.analytics_rounded,
              title: 'Insights',
              subtitle: 'View space analytics and statistics',
              onTap: () {
                Navigator.pop(context);
                _showSpaceInsights(space);
              },
            ),
            if (isOwner)
              _buildMenuOption(
                context,
                icon: Icons.settings_rounded,
                title: 'Space Settings',
                subtitle: 'Manage space configuration',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToSpaceSettings(space);
                },
              ),
            _buildMenuOption(
              context,
              icon: Icons.share_rounded,
              title: 'Share Space',
              subtitle: 'Share with friends and community',
              onTap: () {
                Navigator.pop(context);
                _shareSpace(space, context);
              },
            ),
            _buildMenuOption(
              context,
              icon: Icons.more_horiz_rounded,
              title: 'More Options',
              subtitle: 'Additional space actions',
              onTap: () {
                Navigator.pop(context);
                _showMoreOptions(space);
              },
            ),

            // Close Button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  foregroundColor: _getTextColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                    ),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final iconColor = isDestructive
        ? AppColors.lightError
        : (Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary);

    final textColor = isDestructive
        ? AppColors.lightError
        : _getTextColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: _getIconColor(context),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  void _handleBlockSpace(SpaceModel space, context) {
    Get.defaultDialog(
      title: "Block Space",
      titleStyle: TextStyle(
        color: _getTextColor(Get.context!),
        fontWeight: FontWeight.bold,
      ),
      content: Text(
        "Are you sure you want to block ${space.title}?",
        style: TextStyle(color: _getTextColor(Get.context!)),
        textAlign: TextAlign.center,
      ),
      backgroundColor: _getCardColor(Get.context!),
      radius: 20,
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
        ),
        onPressed: () {
          Get.back();
          UtilsService().showSnackbar(
            "Space Blocked",
            "You have blocked ${space.title}",
            backgroundColor: _getCardColor(Get.context!),
            colorText: _getTextColor(Get.context!),
            context: context,
          );
        },
        child: const Text(
          "Block",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Text(
          "Cancel",
          style: TextStyle(
            color: _getTextColor(Get.context!),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSpaceInsights(SpaceModel space) {
    Get.to(() => SpaceInsightsScreen(space: space));
  }

  void _navigateToSpaceSettings(SpaceModel space) {
    Get.to(() => SpaceSettingsScreen(space: space));
  }

  void _showMoreOptions(SpaceModel space) {
    Get.to(() => MoreOptionsScreen(space: space));
  }

  void _shareSpace(SpaceModel space, context) {
    UtilsService().showSnackbar(
      "Share",
      "Share ${space.title} with others",
      backgroundColor: _getCardColor(Get.context!),
      colorText: _getTextColor(Get.context!),
      context: context,
    );
  }
}
