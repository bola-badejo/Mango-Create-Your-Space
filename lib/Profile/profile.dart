import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Contributors/components/contributor_profile_screen.dart';
import 'package:mango/Contributors/contribute_content.dart';
import 'package:mango/Home/components/book_components.dart';
import 'package:mango/Home/components/post_card.dart';
import 'package:mango/Home/feeds.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Profile/access_pages/user_books_screen.dart';
import 'package:mango/Profile/access_pages/user_followers_screen.dart';
import 'package:mango/Profile/access_pages/user_following.dart';
import 'package:mango/Profile/access_pages/user_movies_screen.dart';
import 'package:mango/Profile/access_pages/user_music_screen.dart';
import 'package:mango/Profile/access_pages/user_podcasts_screen.dart';
import 'package:mango/Profile/access_pages/user_posts_screen.dart';
import 'package:mango/Profile/access_pages/user_products_screen.dart';
import 'package:mango/Profile/access_pages/user_spaces_screen.dart';
import 'package:mango/Profile/pages/contributor.dart';
import 'package:mango/Profile/pages/help_center.dart';
import 'package:mango/Profile/pages/settings.dart';
import 'package:mango/Profile/pages/terms_and_conditions.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Spaces/screens/space_detail.dart';
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/Utils/format_naira.dart';
import 'package:mango/Utils/text_highlighter.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Wallet/components/wallet_screen.dart';
import 'package:mango/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  final String id;
  const ProfilePage({super.key, required this.id});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ProfileController profileController = Get.put(ProfileController());
  final CartController cartController = Get.put(CartController());
  final ThemeController _themeController = Get.put(ThemeController());
  static const _avatarRadius = 40.0;

  @override
  void initState() {
    super.initState();
    profileController.loadUserData(widget.id);
  }

  Color _getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge!.color!;
  }

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.color!;
  }

  Color _getCardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  IconData _getProfileTypeIcon(String profileType) {
    switch (profileType.toLowerCase()) {
      case 'creator':
        return FontAwesomeIcons.palette;
      case 'artist':
        return FontAwesomeIcons.music;
      case 'author':
        return FontAwesomeIcons.penNib;
      case 'influencer':
        return FontAwesomeIcons.star;
      case 'professional':
        return FontAwesomeIcons.suitcase;
      case 'premium':
        return FontAwesomeIcons.crown;
      default:
        return FontAwesomeIcons.user;
    }
  }

  void showAboutMangoSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 5,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Icon(
                  Icons.emoji_objects_rounded,
                  size: 50,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  "About Mango",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Mango is a creative learning platform built to empower African youth through honest work, art, and knowledge. It blends social interaction, creator economy, and AI technology — helping you learn, earn, and grow.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 20),
                _aboutItem(
                  icon: Icons.public_rounded,
                  label: "Website",
                  onTap: () => UtilsService().showSnackbar(
                    "Coming Soon",
                    "Our official website is in orbit 🚀",
                    context: context,
                  ),
                ),
                _aboutItem(
                  icon: Icons.email_rounded,
                  label: "support@mangoapp.ng",
                  onTap: () => UtilsService().showSnackbar(
                    "Support",
                    "Email us directly for help.",
                    context: context,
                  ),
                ),
                _aboutItem(
                  icon: Icons.copyright_rounded,
                  label: "© 2025 Mango Technologies",
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _aboutItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 10.5)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _themeController.isDarkMode.value;
    return Obx(() {
      if (profileController.isLoading.value) {
        return _buildShimmerLoading(context);
      }

      if (profileController.userData.value == null) {
        return Scaffold(
          backgroundColor: _getBackgroundColor(context),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unable to load profile',
                  style: TextStyle(color: _getTextColor(context)),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => profileController.loadUserData(widget.id),
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _getBackgroundColor(context),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: _getBackgroundColor(context),
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final double expandedHeight = 200;
                  final double currentHeight = constraints.biggest.height;
                  final double visibleFraction = currentHeight / expandedHeight;

                  return FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    stretchModes: const [StretchMode.zoomBackground],
                    title: visibleFraction <= 0.6
                        ? _buildCollapsedTitle(context)
                        : const SizedBox.shrink(),
                    background: _buildExpandedBackground(context),
                  );
                },
              ),
            ),

            SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  color: _getBackgroundColor(context),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            profileController.bio.isNotEmpty
                                ? profileController.bio
                                : '',
                            style: TextStyle(
                              color: _getSecondaryTextColor(context),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.locationDot,
                                size: 9,
                                color: _getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                profileController.location.isNotEmpty
                                    ? profileController.location
                                    : 'Location unavailable',
                                style: TextStyle(
                                  color: _getSecondaryTextColor(context),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.userGroup,
                                size: 9,
                                color: _getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${profileController.followersCount.value.toString()} followers • ${profileController.followingCount.value.toString()} following • ',
                                style: TextStyle(
                                  color: _getSecondaryTextColor(context),
                                  fontSize: 10,
                                ),
                              ),
                              FaIcon(
                                _getProfileTypeIcon(
                                  profileController.profileType,
                                ),
                                size: 9,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                profileController.profileType.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Obx(
                                () => Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.shopping_cart_outlined,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      onPressed: () => Get.toNamed('/cart'),
                                    ),
                                    if (cartController.cartItems.isNotEmpty)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            cartController.cartItems.length
                                                .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      _buildContributorStatusRow(context),

                      if (profileController.userPosts.isNotEmpty) ...[
                        _buildPostContentSection(
                          title: 'Posts',
                          items: profileController.userPosts,
                          itemBuilder: (post) => _buildPostItem(post),
                          context: context,
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (profileController.userMusic.isNotEmpty) ...[
                        _buildContentSection(
                          title: 'Music',
                          items: profileController.userMusic,
                          itemBuilder: (music) =>
                              _buildMusicItem(music, context),
                          context: context,
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (profileController.userBooks.isNotEmpty) ...[
                        _buildBookContentSection(
                          title: 'Books',
                          items: profileController.userBooks,
                          itemBuilder: (book) => MangoLibraryList(book: book),
                          context: context,
                        ),
                        const SizedBox(height: 32),
                      ],

                      if (profileController.userSpaces.isNotEmpty) ...[
                        _buildSpaceContentSection(
                          title: 'Spaces',
                          items: profileController.userSpaces,
                          itemBuilder: (space) =>
                              _buildSpaceItem(space, context),
                          context: context,
                        ),
                        const SizedBox(height: 32),
                      ],

                      _buildSectionTitle('Quick Access', context),

                      const SizedBox(height: 12),

                      _buildQuickAccessGrid(context),

                      const SizedBox(height: 32),

                      _buildActionButtons(context),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Scaffold(
      backgroundColor: _getBackgroundColor(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: _getBackgroundColor(context),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.withOpacity(0.3),
                      Colors.grey.withOpacity(0.1),
                    ],
                  ),
                ),
                child: ShimmerLoading(
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ShimmerLoading(
                      child: Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading(
                      child: Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShimmerLoading(
                      child: Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildShimmerContributorRow(baseColor),
                    SizedBox(height: 24),
                    ...List.generate(
                      3,
                      (index) => Column(
                        children: [
                          _buildShimmerSectionTitle(baseColor),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: OptimizedListView(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (context, index) =>
                                  _buildShimmerContentItem(baseColor),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerStat(Color baseColor) {
    return Column(
      children: [
        ShimmerLoading(
          child: Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ShimmerLoading(
          child: Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerSectionTitle(Color baseColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ShimmerLoading(
        child: Container(
          width: 100,
          height: 20,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerContentItem(Color baseColor) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ShimmerLoading(
            child: Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ShimmerLoading(
            child: Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedTitle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBackgroundColor(context),
          ),
          child: CircleAvatar(
            backgroundImage: profileController.profileImageUrl.isNotEmpty
                ? NetworkImage(profileController.profileImageUrl)
                : const AssetImage('asset/images/mango-13.jpg')
                      as ImageProvider,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "@${profileController.username}",
          style: TextStyle(
            color: _getTextColor(context),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedBackground(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        profileController.bannerImageUrl.isNotEmpty
            ? Image.network(profileController.bannerImageUrl, fit: BoxFit.cover)
            : Image.asset('asset/images/mango-13.jpg', fit: BoxFit.cover),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ]
                  : [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.7),
                    ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDarkMode
                    ? [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.6),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 16,
          left: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: profileController.profileImageUrl.isNotEmpty
                      ? NetworkImage(profileController.profileImageUrl)
                      : const AssetImage('asset/images/mango-13.jpg')
                            as ImageProvider,
                ),
              ),
              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isDarkMode
                            ? [
                                Colors.black.withOpacity(0.7),
                                Colors.black.withOpacity(0.4),
                              ]
                            : [
                                Colors.white.withOpacity(0.7),
                                Colors.white.withOpacity(0.4),
                              ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        profileController.displayName,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isDarkMode
                            ? [
                                Colors.black.withOpacity(0.6),
                                Colors.black.withOpacity(0.3),
                              ]
                            : [
                                Colors.white.withOpacity(0.6),
                                Colors.white.withOpacity(0.3),
                              ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        '@${profileController.username}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String playValue(int plays) {
    final int playValue = plays;

    if (playValue > 999) {
      return '${(playValue / 1000).floor()}k';
    } else if (playValue > 1000000) {
      return '${(playValue / 30).floor()}m';
    } else {
      return '$playValue';
    }
  }

  Widget _buildStatItem(String count, String label, BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: _getTextColor(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: _getSecondaryTextColor(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Text(
        title,
        style: TextStyle(
          color: _getTextColor(context),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, context),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return itemBuilder(items[index]);
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildShimmerContributorRow(Color baseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerSectionTitle(baseColor),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildShimmerContributorCard(baseColor),
            _buildShimmerContributorCard(baseColor),
            _buildShimmerContributorCard(baseColor),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildShimmerContributorCard(Color baseColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        child: ShimmerLoading(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 8,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionTitle(title, context),
        const SizedBox(height: 20),
        ...List.generate(
          items.length > 1 ? 2 : items.length, // Show max 2 preview posts
          (index) => itemBuilder(items[index]),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              backgroundColor: Colors.lightGreenAccent.withOpacity(0.4),
            ),
            onPressed: () {
              // Navigate to all posts page
              Get.to(
                () =>
                    AllPostsPage(posts: items.cast<MangoPost>(), title: title),
              );
            },
            child: const Text(
              "View more posts",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, context),
        const SizedBox(height: 20),
        SizedBox(
          height: 210,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return itemBuilder(items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpaceContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, context),
        const SizedBox(height: 20),
        SizedBox(
          height: 340,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return itemBuilder(items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMusicItem(Music playlist, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  borderRadius: BorderRadius.circular(5),
                  image: DecorationImage(
                    image: NetworkImage(playlist.artworkUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black87 : Colors.white70,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'free',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    playValue(playlist.plays),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.play,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            playlist.title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getTextColor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            playlist.artistName == '' ? 'Unknown Artiste' : playlist.artistId,
            style: TextStyle(
              fontSize: 9,
              color: _getSecondaryTextColor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(MangoPost post) {
    return PostCard(post: post);
  }

  Widget _buildSpaceItem(dynamic space, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      width: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Card(
              elevation: 4,
              margin: EdgeInsets.only(right: 10, top: 40),
              color: _getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      space.image.isNotEmpty
                          ? space.image
                          : 'asset/images/mango-9.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'asset/images/mango-9.jpg',
                        fit: BoxFit.cover,
                      ),
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
                                colors: isDarkMode
                                    ? [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                        Colors.black.withOpacity(0.3),
                                        Colors.black.withOpacity(0.6),
                                      ]
                                    : [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.6),
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
                        const SizedBox(height: 40),
                        HighlightedMultilineText(
                          text: space.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          space.category,
                          style: TextStyle(
                            fontSize: 6,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          space.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                            height: 1,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Divider(
                          color: isDarkMode ? Colors.white : Colors.black,
                          thickness: 0.6,
                        ),
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
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  'View Space',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.black
                                        : Colors.white,
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
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                                _buildCardRatingBox(space.rating, context),
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
            top: 0,
            left: 0,
            right: 0,
            child: _buildSpaceAvatar(space, 40, context),
          ),
        ],
      ),
    );
  }

  bool _isValidImageUrl(String url) {
    return url.isNotEmpty &&
        url.startsWith('http') &&
        Uri.tryParse(url)?.host.isNotEmpty == true;
  }

  Widget _buildSpaceAvatar(
    SpaceModel space,
    double radius,
    BuildContext context,
  ) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getCardColor(context),
      child: space.iconUrl.isNotEmpty && _isValidImageUrl(space.iconUrl)
          ? CircleAvatar(
              radius: radius - 2,
              backgroundColor: Colors.transparent,
              backgroundImage: NetworkImage(space.iconUrl),
            )
          : CircleAvatar(
              radius: radius - 2,
              backgroundColor: Colors.transparent,
              child: FaIcon(
                FontAwesomeIcons.layerGroup,
                size: radius,
                color: _getSecondaryTextColor(context),
              ),
            ),
    );
  }

  Widget _buildCardRatingBox(String rating, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.25)
              : Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              4,
              (index) => const FaIcon(
                FontAwesomeIcons.solidStar,
                color: Colors.amber,
                size: 4,
              ),
            ),
            FaIcon(
              FontAwesomeIcons.solidStar,
              color: isDarkMode ? Colors.grey : Colors.grey.shade600,
              size: 4,
            ),
            Text(
              rating,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 6,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  final String redditUrl =
      "https://www.reddit.com/user/Slow-Toe6518/comments/1onwape/mango_community/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button";

  Future<void> _launchReddit() async {
    final uri = Uri.parse(redditUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch Reddit community';
    }
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    final items = [
      {
        'icon': FontAwesomeIcons.squarePlus,
        'label': 'Posts',
        'count': profileController.postsCount.value.toString(),
        'onTap': () => _navigateToPosts(),
      },
      {
        'icon': FontAwesomeIcons.book,
        'label': 'Books',
        'count': profileController.booksCount.value.toString(),
        'onTap': () => _navigateToBooks(),
      },
      {
        'icon': FontAwesomeIcons.music,
        'label': 'Music',
        'count': profileController.musicCount.value.toString(),
        'onTap': () => _navigateToMusic(),
      },
      {
        'icon': FontAwesomeIcons.users,
        'label': 'Spaces',
        'count': profileController.spacesCount.value.toString(),
        'onTap': () => _navigateToSpaces(),
      },
      {
        'icon': FontAwesomeIcons.podcast,
        'label': 'Podcasts',
        'count': profileController.podcastsCount.value.toString(),
        'onTap': () => _navigateToPodcasts(),
      },
      {
        'icon': FontAwesomeIcons.film,
        'label': 'Movies',
        'count': profileController.moviesCount.value.toString(),
        'onTap': () => _navigateToMovies(),
      },
      {
        'icon': FontAwesomeIcons.store,
        'label': 'Products',
        'count': profileController.productsCount.value.toString(),
        'onTap': () => _navigateToProducts(),
      },
      {
        'icon': FontAwesomeIcons.solidSquarePlus,
        'label': 'Followers',
        'count': profileController.followersCount.value.toString(),
        'onTap': () => _navigateToFollowers(),
      },
      {
        'icon': FontAwesomeIcons.circlePlus,
        'label': 'Following',
        'count': profileController.followingCount.value.toString(),
        'onTap': () => _navigateToFollowing(),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return GestureDetector(
            onTap: () => item['onTap'],
            child: Container(
              width: 100,
              height: 120,
              decoration: BoxDecoration(
                color: _getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    item['icon'] as IconData,
                    color: _getTextColor(context),
                    size: 18,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['count'] as String,
                    style: TextStyle(
                      color: _getTextColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    child: Divider(color: _getSecondaryTextColor(context)),
                  ),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: _getSecondaryTextColor(context),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _navigateToPosts() {
    Get.to(() => PostsScreen());
  }

  void _navigateToBooks() {
    Get.to(() => BooksScreen());
  }

  void _navigateToMusic() {
    Get.to(() => MusicScreen());
  }

  void _navigateToSpaces() {
    Get.to(() => SpacesScreen());
  }

  void _navigateToPodcasts() {
    Get.to(() => PodcastsScreen());
  }

  void _navigateToMovies() {
    Get.to(() => MoviesScreen());
  }

  void _navigateToProducts() {
    Get.to(() => ProductsScreen());
  }

  void _navigateToFollowers() {
    Get.to(() => FollowersScreen(userId: widget.id));
  }

  void _navigateToFollowing() {
    Get.to(() => FollowingScreen(userId: widget.id));
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.gear,
              label: 'Settings',
              caption: 'Privacy, notifications & preferences',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AccountSettingsPage(),
                  ),
                );
              },
              context: context,
            ),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.userEdit,
              label: 'Mango Contributor',
              caption: 'Create and earn from your content',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => Contributors()));
              },
              context: context,
            ),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.wallet,
              label: 'Wallet',
              caption: 'Balance, transactions & rewards',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => WalletScreen()));
              },
              context: context,
            ),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.circleQuestion,
              label: 'Terms of Use',
              caption: 'Terms built for creators, not corporations.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TermsAndConditionsPage(),
                  ),
                );
              },
              context: context,
            ),

          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.peopleGroup,
              label: 'Join our Community',
              caption: 'Frequently asked questions',
              onTap: _launchReddit,
              context: context,
            ),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.headset,
              label: 'Help Center',
              caption: 'Get support and contact us',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => HelpCenterPage()),
                );
              },
              context: context,
            ),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            const SizedBox(height: 12),
          if (widget.id == FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.circleInfo,
              label: 'About Mango',
              caption: 'Version 1.0.0 • Learn more about us',
              onTap: () {
                showAboutMangoSheet(context);
              },
              context: context,
            ),
          if (widget.id != FirebaseAuth.instance.currentUser!.uid)
            _buildActionButton(
              icon: FontAwesomeIcons.userSlash,
              label: 'Block User',
              caption: 'Restrict this user\'s interactions',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => Contributors()));
              },
              context: context,
            ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildContributorStatusRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Contributor Profiles', context),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildContributorCard(
                title: 'Creator',
                isRegistered: profileController.isCreator.value,
                icon: FontAwesomeIcons.palette,
                color: Colors.blue,
                context: context,
              ),
              _buildContributorCard(
                title: 'Distributor',
                isRegistered: profileController.isDistributor.value,
                icon: FontAwesomeIcons.shareNodes,
                color: Colors.green,
                context: context,
              ),
              _buildContributorCard(
                title: 'Vendor',
                isRegistered: profileController.isVendor.value,
                icon: FontAwesomeIcons.store,
                color: Colors.orange,
                context: context,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildContributorCard({
    required String title,
    required bool isRegistered,
    required IconData icon,
    required Color color,
    required BuildContext context,
  }) {
    String getImageUrl() {
      final userData = profileController.userData.value;
      if (userData == null) return '';

      switch (title) {
        case 'Creator':
          return userData.creatorImageUrl ?? '';
        case 'Distributor':
          return userData.distributorImageUrl ?? '';
        case 'Vendor':
          return userData.vendorImageUrl ?? '';
        default:
          return '';
      }
    }

    String getDisplayName() {
      final userData = profileController.userData.value;
      if (userData == null) return title;

      switch (title) {
        case 'Creator':
          return userData.creatorName ?? title;
        case 'Distributor':
          return userData.distributorName ?? title;
        case 'Vendor':
          return userData.vendorName ?? title;
        default:
          return title;
      }
    }

    String getContributorId() {
      final userData = profileController.userData.value;
      if (userData == null) return '';

      switch (title) {
        case 'Creator':
          return userData.creatorID ?? '';
        case 'Distributor':
          return userData.distributorID ?? '';
        case 'Vendor':
          return userData.vendorID ?? '';
        default:
          return '';
      }
    }

    final String imageUrl = getImageUrl();
    final String displayName = getDisplayName();
    final bool hasImage = imageUrl.isNotEmpty;
    final String contributorId = getContributorId();

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isRegistered) {
            _navigateToContributorRegistration(title);
          } else if (contributorId.isNotEmpty) {
            Get.to(
              () => ContributorProfileScreen(contributorId: contributorId),
            );
          } else {
            UtilsService().showSnackbar(
              'Profile Unavailable',
              'Could not load $title profile',
              backgroundColor: Colors.redAccent,
              colorText: Colors.white,
              context: context,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRegistered ? color : Colors.grey.withOpacity(0.3),
              width: isRegistered ? 2 : 1,
            ),
            image: isRegistered && hasImage
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  )
                : null,
            color: isRegistered
                ? (hasImage ? Colors.transparent : color.withOpacity(0.1))
                : _getCardColor(context),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isRegistered) ...[
                    if (!hasImage) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(icon, color: color, size: 16),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: hasImage
                              ? Colors.white
                              : _getTextColor(context),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: hasImage
                              ? [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ]
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: hasImage
                            ? color.withOpacity(0.9)
                            : color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: hasImage ? Colors.white : color,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: hasImage
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: color,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.circlePlus,
                          color: _getSecondaryTextColor(context),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: _getSecondaryTextColor(context),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: _getSecondaryTextColor(context),
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              if (isRegistered && contributorId.isNotEmpty)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: null,
                      splashColor: color.withOpacity(0.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToContributorRegistration(String type) {
    bool isRegistered = false;
    String? contributorId;

    switch (type) {
      case 'Creator':
        isRegistered = profileController.isCreator.value;
        contributorId = profileController.userData.value?.creatorID;
        break;
      case 'Distributor':
        isRegistered = profileController.isDistributor.value;
        contributorId = profileController.userData.value?.distributorID;
        break;
      case 'Vendor':
        isRegistered = profileController.isVendor.value;
        contributorId = profileController.userData.value?.vendorID;
        break;
    }

    if (isRegistered && contributorId != null && contributorId.isNotEmpty) {
      Get.to(
        () => ContributorRegistrationPage(
          title: type,
          isEditMode: true,
          contributorId: contributorId,
        ),
      );
    } else {
      Get.to(() => ContributorRegistrationPage(title: type));
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String caption,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(
          left: 15,
          right: 15,
          top: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: _getCardColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FaIcon(icon, color: _getTextColor(context), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _getTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: TextStyle(
                      color: _getSecondaryTextColor(context),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              color: _getSecondaryTextColor(context),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({Key? key, required this.child}) : super(key: key);

  @override
  _ShimmerLoadingState createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 2), 0.0),
              end: Alignment(1.0 + (_controller.value * 2), 0.0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Enhanced AllPostsPage with search functionality
class AllPostsPage extends StatefulWidget {
  final List<MangoPost> posts;
  final String title;

  const AllPostsPage({
    Key? key,
    required this.posts,
    this.title = 'Posts',
  }) : super(key: key);

  @override
  State<AllPostsPage> createState() => _AllPostsPageState();
}

class _AllPostsPageState extends State<AllPostsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<MangoPost> _filteredPosts = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filteredPosts = widget.posts;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          _filteredPosts = widget.posts;
        } else {
          _filteredPosts = widget.posts
              .where((post) =>
                  post.text.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(
              child: _filteredPosts.isEmpty
                  ? _buildEmptyState()
                  : _buildPostsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search posts...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[600],
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) {
        return PostCard(post: _filteredPosts[index]);
      },
    );
  }
}