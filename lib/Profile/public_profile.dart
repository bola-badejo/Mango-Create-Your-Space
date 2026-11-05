import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Contributors/components/contributor_profile_screen.dart';
import 'package:mango/Home/components/book_components.dart';
import 'package:mango/Home/components/post_card.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Profile/access_pages/user_books_screen.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Profile/access_pages/user_followers_screen.dart';
import 'package:mango/Profile/access_pages/user_following.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Spaces/screens/space_detail.dart';
import 'package:mango/Utils/format_naira.dart';
import 'package:mango/Utils/text_highlighter.dart';
import 'package:mango/Wallet/components/wallet_screen.dart';
import 'package:mango/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;
  final String? username;

  const PublicProfilePage({Key? key, required this.userId, this.username})
    : super(key: key);

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ProfileController profileController = Get.put(ProfileController());
  final RxBool _isFollowing = false.obs;
  final RxBool _followLoading = false.obs;
  static const _avatarRadius = 40.0;

  @override
  void initState() {
    super.initState();
    profileController.loadUserData(widget.userId);
    _checkFollowingStatus();
  }

  Future<void> _checkFollowingStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == widget.userId) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userId)
          .get();
      _isFollowing.value = doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading.value) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == widget.userId) {
      UtilsService().showSnackbar(
        'Cannot Follow',
        'You cannot follow yourself',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    _followLoading.value = true;

    try {
      if (_isFollowing.value) {
        await _unfollowUser(widget.userId);
        _isFollowing.value = false;
        profileController.followersCount.value--;
      } else {
        await _followUser(widget.userId);
        _isFollowing.value = true;
        profileController.followersCount.value++;
      }

      UtilsService().showSnackbar(
        _isFollowing.value ? 'Followed' : 'Unfollowed',
        _isFollowing.value
            ? 'You are now following @${profileController.username}'
            : 'You unfollowed @${profileController.username}',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to ${_isFollowing.value ? 'unfollow' : 'follow'} user',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      _followLoading.value = false;
    }
  }

  Future<void> _followUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(userId)
        .set({});
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(currentUser.uid)
        .set({});
  }

  Future<void> _unfollowUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(userId)
        .delete();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('followers')
        .doc(currentUser.uid)
        .delete();
  }

  void _showReportUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: const Text(
          'Why are you reporting this user?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reportUser();
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    UtilsService().showSnackbar(
      'Reported',
      'Thank you for your report. We will review this user.',
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
    );
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

  @override
  Widget build(BuildContext context) {
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
                Icon(Icons.person_off, size: 64, color: MangoPalette.grey500),
                const SizedBox(height: 16),
                Text(
                  'User not found',
                  style: TextStyle(color: _getTextColor(context)),
                ),
                const SizedBox(height: 16),
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
              leading: IconButton(
        tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
        tooltip: 'More options',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showUserMenu(context),
                ),
              ],
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
                      _buildFollowButton(context),
                      const SizedBox(height: 8),
                      if (profileController.bio.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Text(
                              profileController.bio,
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
                                  fontSize: 12,
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
                              MangoPressable(
                                onTap: () => _navigateToFollowers(),
                                child: Text(
                                  '${profileController.followersCount.value} followers',
                                  style: TextStyle(
                                    color: _getTextColor(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MangoPressable(
                                onTap: () => _navigateToFollowing(),
                                child: Text(
                                  '${profileController.followingCount.value} following',
                                  style: TextStyle(
                                    color: _getTextColor(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FaIcon(
                                _getProfileTypeIcon(
                                  profileController.profileType,
                                ),
                                size: 9,
                                color: MangoPalette.green500,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                profileController.profileType.toUpperCase(),
                                style: TextStyle(
                                  color: MangoPalette.green500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                      _buildQuickAccessGrid(context),
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

  Widget _buildFollowButton(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == widget.userId) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Obx(
        () => _followLoading.value
            ? Center(
                child: SizedBox(
                  width: 100,
                  height: 36,
                  child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              )
            : MangoPressable(
                onTap: _toggleFollow,
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                    color: _isFollowing.value
                        ? Colors.transparent
                        : Theme.of(context).primaryColor,
                    border: _isFollowing.value
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _isFollowing.value ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: _isFollowing.value
                            ? Theme.of(context).primaryColor
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: MangoPalette.green500),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _showReportUserDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockUserDialog();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block @${profileController.username}? '
          'You will no longer see their posts and they will not be able to interact with you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _blockUser() {
    UtilsService().showSnackbar(
      'Blocked',
      'User has been blocked',
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
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
                      MangoPalette.black.withOpacity(0.3),
                      MangoPalette.black.withOpacity(0.7),
                    ]
                  : [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.7),
                    ],
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
                      color: MangoPalette.black.withOpacity(0.2),
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
                      borderRadius: BorderRadius.circular(MangoRadius.xs),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isDarkMode
                            ? [
                                MangoPalette.black.withOpacity(0.7),
                                MangoPalette.black.withOpacity(0.4),
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
                          color: isDarkMode ? Colors.white : MangoPalette.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MangoRadius.xs),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: isDarkMode
                            ? [
                                MangoPalette.black.withOpacity(0.6),
                                MangoPalette.black.withOpacity(0.3),
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
                          color: isDarkMode ? MangoPalette.grey500 : Colors.black54,
                          fontSize: 12,
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

  // Reuse existing methods from ProfilePage for content display
  Widget _buildShimmerLoading(BuildContext context) {
    // Implementation similar to ProfilePage's shimmer loading
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300;

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
              background: Container(color: baseColor),
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
                        height: 44,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShimmerLoading(
                      child: Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
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
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
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
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorStatusRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            'Contributor Profiles',
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
                color: MangoPalette.green500,
                context: context,
              ),
              _buildContributorCard(
                title: 'Vendor',
                isRegistered: profileController.isVendor.value,
                icon: FontAwesomeIcons.store,
                color: MangoPalette.green500,
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
    if (!isRegistered) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(color: MangoPalette.grey500.withOpacity(0.3), width: 1),
            color: _getCardColor(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MangoPalette.grey500.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  icon,
                  color: _getSecondaryTextColor(context),
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Not registered',
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
      child: MangoPressable(
        onTap: () {
          if (contributorId.isNotEmpty) {
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
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(color: color, width: 2),
            image: hasImage
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      MangoPalette.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  )
                : null,
            color: hasImage ? Colors.transparent : color.withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                    color: hasImage ? Colors.white : _getTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: hasImage
                        ? [
                            Shadow(
                              blurRadius: 4,
                              color: MangoPalette.black.withOpacity(0.8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasImage
                      ? color.withOpacity(0.9)
                      : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: hasImage ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Text(
              'Content',
              style: TextStyle(
                color: _getTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) {
              // Fix: Extract the onTap function properly
              final VoidCallback? onTap = item['onTap'] as VoidCallback?;

              return GestureDetector(
                onTap: onTap, // Use the extracted function directly
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _getCardColor(context),
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        item['icon'] as IconData,
                        color: _getTextColor(context),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['count'] as String,
                        style: TextStyle(
                          color: _getTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: _getSecondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToPosts() {
    // Get.to(() => PostsScreen(userId: widget.userId));
  }

  void _navigateToBooks() {
    // Get.to(() => BooksScreen(userId: widget.userId));
  }

  void _navigateToMusic() {
    // Get.to(() => MusicScreen(userId: widget.userId));
  }

  void _navigateToSpaces() {
    // Get.to(() => SpacesScreen(userId: widget.userId));
  }

  void _navigateToPodcasts() {
    // Get.to(() => PodcastsScreen(userId: widget.userId));
  }

  void _navigateToMovies() {
    // Get.to(() => MoviesScreen(userId: widget.userId));
  }

  void _navigateToProducts() {
    // Get.to(() => ProductsScreen(userId: widget.userId));
  }

  void _navigateToFollowers() {
    Get.to(() => FollowersScreen(userId: widget.userId));
  }

  void _navigateToFollowing() {
    Get.to(() => FollowingScreen(userId: widget.userId));
  }

  // Content display methods (copied from ProfilePage)
  Widget _buildContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            title,
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            title,
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            title,
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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

  Widget _buildPostContentSection({
    required String title,
    required List<dynamic> items,
    required Widget Function(dynamic) itemBuilder,
    required BuildContext context,
  }) {
    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Text(
            title,
            style: TextStyle(
              color: _getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        itemBuilder(items[0]),
        const SizedBox(height: 10),
        if (items.length > 1)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: Colors.lightGreenAccent.withOpacity(.4),
              ),
              onPressed: () => _navigateToPosts(),
              child: const Text(
                "View more posts",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMusicItem(Music playlist, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black87 : Colors.white70,
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Text(
                    'free',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : MangoPalette.black,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white54,
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Text(
                    _formatCount(playlist.plays),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black54 : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.play, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            playlist.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getTextColor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            playlist.artistName == '' ? 'Unknown Artiste' : playlist.artistName,
            style: TextStyle(
              fontSize: 12,
              color: _getSecondaryTextColor(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
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
            borderRadius: BorderRadius.circular(MangoRadius.md),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(right: 10, top: 40),
              color: _getCardColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
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
                                        MangoPalette.black.withOpacity(0.1),
                                        MangoPalette.black.withOpacity(0.3),
                                        MangoPalette.black.withOpacity(0.6),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          space.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white : MangoPalette.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          space.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            height: 1,
                            color: isDarkMode ? Colors.white : MangoPalette.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Divider(
                          color: isDarkMode ? Colors.white : MangoPalette.black,
                          thickness: 0.6,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            MangoPressable(
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
                                      : MangoPalette.black,
                                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? MangoPalette.black.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  'View Space',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? MangoPalette.black
                                        : Colors.white,
                                    fontSize: 12,
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
                                        : MangoPalette.black,
                                    fontSize: 12,
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
              : MangoPalette.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(MangoRadius.sm),
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
            const FaIcon(FontAwesomeIcons.solidStar, size: 4),
            Text(
              rating,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDarkMode ? Colors.white : MangoPalette.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reuse ShimmerLoading class from ProfilePage
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
    final baseColor = isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300;
    final highlightColor = isDarkMode ? MangoPalette.grey700 : MangoPalette.grey100;

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
