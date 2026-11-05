import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Contributors/controllers/contributor_service.dart';
import 'package:mango/Contributors/models/contributors_profile.dart';
import 'package:mango/Contributors/components/edit_contributors_profile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class ContributorProfileScreen extends StatefulWidget {
  final String contributorId;
  const ContributorProfileScreen({super.key, required this.contributorId});

  @override
  State<ContributorProfileScreen> createState() =>
      _ContributorProfileScreenState();
}

class _ContributorProfileScreenState extends State<ContributorProfileScreen>
    with SingleTickerProviderStateMixin {
  final ContributorService _contributorService = ContributorService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isFollowing = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String type) {
    switch (type.toLowerCase()) {
      case 'creator':
        return Colors.blue;
      case 'distributor':
        return MangoPalette.green500;
      case 'vendor':
        return MangoPalette.green500;
      default:
        return MangoPalette.grey500;
    }
  }

  IconData _getRoleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'creator':
        return FontAwesomeIcons.palette;
      case 'distributor':
        return FontAwesomeIcons.shareNodes;
      case 'vendor':
        return FontAwesomeIcons.store;
      default:
        return FontAwesomeIcons.user;
    }
  }

  String _getStatLabel(String type) {
    switch (type.toLowerCase()) {
      case 'creator':
        return 'monthly listeners';
      case 'distributor':
        return 'distributions';
      case 'vendor':
        return 'products sold';
      default:
        return 'followers';
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!uri.hasScheme) {
      // Add https if no scheme is provided
      final fullUri = Uri.parse('https://$url');
      if (await canLaunchUrl(fullUri)) {
        await launchUrl(fullUri);
      } else {
        _showErrorSnackbar('Could not launch URL');
      }
    } else if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorSnackbar('Could not launch URL');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MangoPalette.black : Colors.white,
      body: StreamBuilder<ContributorProfile?>(
        stream: _contributorService.getContributorStream(widget.contributorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'asset/images/loading.json',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Profile...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildNotFound(isDark);
          }

          final profile = snapshot.data!;
          final isOwnProfile = _isOwnProfile(profile.userId);
          final roleColor = _getRoleColor(profile.type);
          
          // Start animation once data is loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animationController.forward();
          });

          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 380,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  backgroundColor: isDark ? MangoPalette.black : Colors.white,
                  elevation: innerBoxIsScrolled ? 1 : 0,
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  title: Text(
                    profile.displayName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    if (isOwnProfile)
                      IconButton(
        tooltip: 'Edit',
                        icon: Icon(
                          Icons.edit_outlined,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () async {
                          final result = await Get.to(() => EditContributorProfileScreen());
                          if (result == true) {
                            // Refresh the profile
                            setState(() {});
                          }
                        },
                      ),
                    IconButton(
        tooltip: 'Share',
                      icon: Icon(
                        Icons.share_outlined,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        _showShareOptions(context, profile, isDark);
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Banner Image
                        _buildBannerImage(profile, isDark),
                        
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (isDark ? MangoPalette.black : Colors.white).withOpacity(0.9),
                              ],
                              stops: const [0.3, 1.0],
                            ),
                          ),
                        ),
                        
                        // Profile Content
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Profile Avatar
                                _buildAvatar(profile, isDark),
                                const SizedBox(width: 16),
                                
                                // Name and Role
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Role Badge
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: roleColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: roleColor.withOpacity(0.4),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _getRoleIcon(profile.type),
                                                  size: 10,
                                                  color: roleColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  profile.roleTitle.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: roleColor,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.verified,
                                              size: 16,
                                              color: roleColor,
                                            ),
                                          ],
                                          if (profile.isPremium) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(MangoRadius.md),
                                                border: Border.all(
                                                  color: Colors.amber.withOpacity(0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: 10,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'PREMIUM',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.amber,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Display Name
                                      Text(
                                        profile.displayName,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                          letterSpacing: -0.5,
                                          height: 1.2,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8,
                                              color: MangoPalette.black.withOpacity(0.3),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      // Location
                                      if (profile.location != null && profile.location!.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 12,
                                              color: isDark ? Colors.white60 : Colors.black45,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              profile.location!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white60 : Colors.black45,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      
                                      // Stats Row
                                      Row(
                                        children: [
                                          Icon(
                                            profile.type == 'creator' 
                                                ? Icons.headphones 
                                                : (profile.type == 'vendor' 
                                                    ? Icons.shopping_cart 
                                                    : Icons.people),
                                            size: 14,
                                            color: isDark ? Colors.white60 : Colors.black45,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${profile.monthlyListeners} ${_getStatLabel(profile.type)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Contributor ID Badge
                                MangoPressable(
                                  onTap: () => _showContributorIdDialog(context, profile, isDark),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : MangoPalette.black).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : MangoPalette.black).withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.fingerprint,
                                          size: 14,
                                          color: roleColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${profile.contributorId.substring(0, 6)}...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                if (!isOwnProfile) ...[
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _isFollowing = !_isFollowing;
                                          _followerCount += _isFollowing ? 1 : -1;
                                        });
                                      },
                                      icon: Icon(
                                        _isFollowing ? Icons.check : Icons.person_add,
                                        size: 14,
                                      ),
                                      label: Text(_isFollowing ? 'Following' : 'Follow'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing ? MangoPalette.grey500 : roleColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(MangoRadius.lg),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bio Section
                    if (profile.bio.isNotEmpty) ...[
                      _buildSectionHeader('About', isDark),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          side: BorderSide(
                            color: isDark 
                                ? Colors.white.withOpacity(0.06) 
                                : MangoPalette.black.withOpacity(0.04),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            profile.bio,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Skills Section (Primary)
                    if (profile.skill != null && profile.skill!.isNotEmpty) ...[
                      _buildSectionHeader('Primary Skill', isDark),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              roleColor.withOpacity(0.15),
                              roleColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          border: Border.all(
                            color: roleColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 20,
                              color: roleColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                profile.skill!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Content Categories Section
                    if (profile.categories != null && profile.categories!.isNotEmpty) ...[
                      _buildSectionHeader('Content Categories', isDark),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.categories!.map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(MangoRadius.lg),
                              border: Border.all(
                                color: roleColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 12,
                                  color: roleColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: roleColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Subcategories Section
                    if (profile.subCategories != null && profile.subCategories!.isNotEmpty) ...[
                      _buildSectionHeader('Specializations', isDark),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.subCategories!.map((subCategory) {
                          return Chip(
                            label: Text(
                              subCategory,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            backgroundColor: isDark ? MangoPalette.grey800 : MangoPalette.grey200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.lg),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Tags/Skills & Interests Section
                    if (profile.tags.isNotEmpty) ...[
                      _buildSectionHeader('Skills & Interests', isDark),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(MangoRadius.lg),
                              border: Border.all(
                                color: roleColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 13,
                                color: roleColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Contact Info Section
                    if (profile.email.isNotEmpty || profile.phone.isNotEmpty || profile.socialMedia.isNotEmpty) ...[
                      _buildSectionHeader('Contact & Social', isDark),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          side: BorderSide(
                            color: isDark 
                                ? Colors.white.withOpacity(0.06) 
                                : MangoPalette.black.withOpacity(0.04),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (profile.email.isNotEmpty) ...[
                                _buildContactRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  value: profile.email,
                                  isDark: isDark,
                                  onTap: () => _launchUrl('mailto:${profile.email}'),
                                ),
                                const Divider(height: 24),
                              ],
                              if (profile.phone.isNotEmpty) ...[
                                _buildContactRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  value: profile.phone,
                                  isDark: isDark,
                                  onTap: () => _launchUrl('tel:${profile.phone}'),
                                ),
                                const Divider(height: 24),
                              ],
                              if (profile.socialMedia.isNotEmpty) ...[
                                _buildContactRow(
                                  icon: Icons.link,
                                  label: 'Social',
                                  value: profile.socialMedia,
                                  isDark: isDark,
                                  isLink: true,
                                  onTap: () => _launchUrl(profile.socialMedia),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Portfolio Section
                    if (profile.portfolio.isNotEmpty) ...[
                      _buildSectionHeader('Portfolio', isDark),
                      const SizedBox(height: 12),
                      MangoPressable(
                        onTap: () => _launchUrl(profile.portfolio),
                        child: Card(
                          elevation: 0,
                          color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MangoRadius.md),
                            side: BorderSide(
                              color: isDark 
                                  ? Colors.white.withOpacity(0.06) 
                                  : MangoPalette.black.withOpacity(0.04),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(MangoRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.work_outline,
                                    color: roleColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View Portfolio',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        profile.portfolio,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new,
                                  size: 16,
                                  color: isDark ? MangoPalette.grey400 : Colors.black38,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Company Info Section
                    if (profile.companyName != null && profile.companyName!.isNotEmpty) ...[
                      _buildSectionHeader('Company Information', isDark),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: isDark ? const Color(0xFF1B241E) : const Color(0xFFF5F6F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          side: BorderSide(
                            color: isDark 
                                ? Colors.white.withOpacity(0.06) 
                                : MangoPalette.black.withOpacity(0.04),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (profile.companyName != null && profile.companyName!.isNotEmpty)
                                _buildInfoRow(
                                  icon: Icons.business,
                                  label: 'Company',
                                  value: profile.companyName!,
                                  isDark: isDark,
                                ),
                              if (profile.companyAddress != null && profile.companyAddress!.isNotEmpty) ...[
                                if (profile.companyName != null && profile.companyName!.isNotEmpty)
                                  const Divider(height: 24),
                                _buildInfoRow(
                                  icon: Icons.location_city,
                                  label: 'Address',
                                  value: profile.companyAddress!,
                                  isDark: isDark,
                                ),
                              ],
                              if (profile.creatorType != null && profile.creatorType!.isNotEmpty) ...[
                                if ((profile.companyName != null && profile.companyName!.isNotEmpty) ||
                                    (profile.companyAddress != null && profile.companyAddress!.isNotEmpty))
                                  const Divider(height: 24),
                                _buildInfoRow(
                                  icon: Icons.work_history,
                                  label: 'Type',
                                  value: profile.creatorType!,
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Stats Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            roleColor.withOpacity(0.15),
                            roleColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(MangoRadius.lg),
                        border: Border.all(
                          color: roleColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            value: profile.followers.toString(),
                            label: 'Followers',
                            isDark: isDark,
                            color: roleColor,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: roleColor.withOpacity(0.2),
                          ),
                          _buildStatItem(
                            value: profile.monthlyListeners.toString(),
                            label: _getStatLabel(profile.type),
                            isDark: isDark,
                            color: roleColor,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: roleColor.withOpacity(0.2),
                          ),
                          _buildStatItem(
                            value: profile.isVerified ? 'Yes' : 'No',
                            label: 'Verified',
                            isDark: isDark,
                            color: roleColor,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
        letterSpacing: -0.5,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'music':
        return Icons.music_note;
      case 'books':
        return Icons.book;
      case 'podcasts':
        return Icons.mic;
      case 'movies':
        return Icons.movie;
      case 'art':
        return Icons.art_track;
      case 'products':
        return Icons.shopping_bag;
      case 'services':
        return Icons.construction;
      default:
        return Icons.category;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? MangoPalette.grey400 : Colors.black38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerImage(ContributorProfile profile, bool isDark) {
    final bannerUrl = profile.bannerImageUrl;
    final roleColor = _getRoleColor(profile.type);
    
    if (bannerUrl != null && bannerUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: bannerUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: isDark ? MangoPalette.grey900 : MangoPalette.grey200,
        ),
        errorWidget: (_, __, ___) => _buildDefaultBanner(roleColor, isDark),
      );
    }
    
    return _buildDefaultBanner(roleColor, isDark);
  }

  Widget _buildDefaultBanner(Color roleColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roleColor.withOpacity(0.8),
            roleColor.withOpacity(0.4),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            bottom: -50,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.person,
                size: 200,
                color: isDark ? Colors.white : MangoPalette.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ContributorProfile profile, bool isDark) {
    final imageUrl = profile.profileImageUrl;
    final roleColor = _getRoleColor(profile.type);
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? Colors.white : MangoPalette.black).withOpacity(0.2),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 56,
        backgroundColor: roleColor.withOpacity(0.2),
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImageProvider(imageUrl)
            : const AssetImage('asset/images/mango-13.jpg') as ImageProvider,
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return MangoPressable(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? MangoPalette.grey400 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLink 
                        ? Colors.blue 
                        : (isDark ? Colors.white : Colors.black87),
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (isLink)
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Colors.blue,
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildNotFound(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 80,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 16),
          Text(
            'Contributor profile not found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  bool _isOwnProfile(String profileUserId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == profileUserId;
  }

  void _showContributorIdDialog(BuildContext context, ContributorProfile profile, bool isDark) {
    final roleColor = _getRoleColor(profile.type);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B241E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: roleColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contributor ID',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : MangoPalette.grey100,
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.contributorId,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
        tooltip: 'Copy',
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: roleColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ID copied to clipboard',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.sm)),
                            backgroundColor: isDark ? const Color(0xFF243028) : Colors.white,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.copy,
                        color: roleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: roleColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareOptions(BuildContext context, ContributorProfile profile, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B241E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    icon: Icons.copy,
                    label: 'Copy ID',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Contributor ID copied: ${profile.contributorId}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.share,
                    label: 'Share',
                    color: MangoPalette.green500,
                    onTap: () {
                      Navigator.pop(context);
                      // Implement share functionality
                    },
                  ),
                  _buildShareOption(
                    icon: Icons.qr_code,
                    label: 'QR Code',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _showQRCodeDialog(context, profile, isDark);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MangoPressable(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, ContributorProfile profile, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1B241E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.lg)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${profile.displayName}\'s QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.white,
                  child: const Center(
                    child: Icon(Icons.qr_code, size: 150),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}