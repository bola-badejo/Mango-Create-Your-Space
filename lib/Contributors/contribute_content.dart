import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Models/customModel/user.dart';

import 'main_pages/book_box.dart';
import 'main_pages/movie_box.dart';
import 'main_pages/music_box.dart';
import 'main_pages/podcast_box.dart';
import 'main_pages/product_box.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MagicBoxPage extends StatefulWidget {
  final MangoUser contentData;
  final Map<String, dynamic> contributorData;
  
  const MagicBoxPage({super.key, this.contributorData = const {}, required this.contentData});

  @override
  _MagicBoxPageState createState() => _MagicBoxPageState();
}

class _MagicBoxPageState extends State<MagicBoxPage> with SingleTickerProviderStateMixin {
  final MangoDashboardController controller = Get.find<MangoDashboardController>();
  final Map<String, bool> _expandedStates = {};
  late MangoUser _userData;
  String _userRole = 'none';
  bool _isLoading = true;
  String? _userId;
  String? _contributorId;
  Map<String, dynamic> _contributorData = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> options = [
    {
      'title': 'Music',
      'description': 'Turn your sound into a movement. Share your music, reach new audiences, and get rewarded.',
      'lottie': 'asset/images/album.json',
      'color1': '0xFF6A0572',
      'color2': '0xFF9C27B0',
      'allowedRoles': 'creator,distributor',
      'route': 'music',
    },
    {
      'title': 'Books',
      'description': 'Your words, your legacy. Publish your books and inspire a generation.',
      'lottie': 'asset/images/book.json',
      'color1': '0xFF1E3A5F',
      'color2': '0xFF2196F3',
      'allowedRoles': 'creator,distributor',
      'route': 'books',
    },
    {
      'title': 'Products',
      'description': 'Create. Sell. Thrive. Showcase your products and grow your brand.',
      'lottie': 'asset/images/shop_shelf.json',
      'color1': '0xFF004D40',
      'color2': '0xFF26A69A',
      'allowedRoles': 'vendor', 
      'route': 'products',
    },
    {
      'title': 'Podcasts',
      'description': 'Amplify your voice. Share stories, ideas, and knowledge with the world.',
      'lottie': 'asset/images/podcast.json',
      'color1': '0xFFB71C1C',
      'color2': '0xFFD32F2F',
      'allowedRoles': 'creator,distributor',
      'route': 'podcasts',
    },
    {
      'title': 'Movies',
      'description': 'Lights, camera, impact! Share your films and captivate audiences everywhere.',
      'lottie': 'asset/images/movie.json',
      'color1': '0xFF3E2723',
      'color2': '0xFF795548',
      'allowedRoles': 'creator,distributor',
      'route': 'movies',
    },
  ];

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
    
    for (var item in options) {
      _expandedStates[item['title']!] = false;
    }
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userId = user.uid;
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userData = MangoUser.fromDocument(userDoc);
            _userRole = _getUserRole(_userData);
            _contributorId = _getContributorId(_userData, _userRole);
            _contributorData = _buildContributorDataFromUser(_userData, _userRole);
            _isLoading = false;
          });
          _animationController.forward();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _buildContributorDataFromUser(MangoUser user, String role) {
    switch (role) {
      case 'creator':
        return {
          'fullName': user.displayName,
          'stageName': user.creatorName,
          'bio': user.bio,
          'profileImageUrl': user.creatorImageUrl.isNotEmpty 
              ? user.creatorImageUrl 
              : user.profileImage,
          'logoUrl': user.creatorLogoUrl,
          'skill': '',
          'tags': user.hobbies,
          'socialMedia': '',
          'portfolio': '',
        };
      case 'distributor':
        return {
          'fullName': user.displayName,
          'distributorLabel': user.distributorName,
          'bio': user.bio,
          'profileImageUrl': user.distributorImageUrl.isNotEmpty 
              ? user.distributorImageUrl 
              : user.profileImage,
          'logoUrl': user.distributorLogoUrl,
          'companyName': '',
          'companyAddress': '',
          'tags': user.hobbies,
        };
      case 'vendor':
        return {
          'fullName': user.displayName,
          'storeName': user.vendorName,
          'bio': user.bio,
          'profileImageUrl': user.vendorImageUrl.isNotEmpty 
              ? user.vendorImageUrl 
              : user.profileImage,
          'logoUrl': user.vendorLogoUrl,
          'companyName': '',
          'companyAddress': '',
          'tags': user.hobbies,
        };
      default:
        return {
          'fullName': user.displayName,
          'bio': user.bio,
          'profileImageUrl': user.profileImage,
          'tags': user.hobbies,
        };
    }
  }

  void _toggleExpansion(String title) {
    setState(() {
      _expandedStates[title] = !_expandedStates[title]!;
    });
  }

  bool _isUserAllowed(String itemTitle, String userRole) {
    final item = options.firstWhere((opt) => opt['title'] == itemTitle);
    final allowedRoles = item['allowedRoles']!.split(',');
    return allowedRoles.contains(userRole);
  }

  String _getAccessDeniedMessage(String itemTitle, String userRole) {
    if (itemTitle == 'Products') {
      if (userRole == 'distributor') {
        return 'Distributors cannot upload products. Product upload is exclusively for vendors.';
      } else if (userRole == 'creator') {
        return 'Only vendors can upload products. Creators can upload music, books, podcasts, and movies.';
      }
    }
    
    if (userRole == 'vendor') {
      return 'Only creators and distributors can access $itemTitle features';
    } else {
      return 'Only vendors can access $itemTitle features';
    }
  }

  void _handleItemTap(String title, String userRole, BuildContext context) {
    if (!_isUserAllowed(title, userRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _getAccessDeniedMessage(title, userRole),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    switch (title) {
      case 'Music':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MusicBoxPage(
              user: widget.contentData,
              contributorId: _contributorId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
        break;
      case 'Books':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => BookBoxPage(
              user: widget.contentData,
              contributorId: _contributorId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
        break;
      case 'Podcasts':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PodcastBoxPage(
              user: widget.contentData,
              contributorId: _contributorId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
        break;
      case 'Products':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProductBoxPage(
              user: widget.contentData,
              contributorId: _contributorId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
        break;
      case 'Movies':
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MovieBoxPage(
              user: widget.contentData,
              contributorId: _contributorId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
        break;
    }
  }

  String _getUserRole(MangoUser userData) {
    if (userData.isVendor == true) return 'vendor';
    if (userData.isCreator == true) return 'creator';
    if (userData.isDistributor == true) return 'distributor';
    return 'none';
  }

  String? _getContributorId(MangoUser userData, String userRole) {
    switch (userRole) {
      case 'creator':
        return userData.creatorID.isNotEmpty ? userData.creatorID : userData.id;
      case 'vendor':
        return userData.vendorID.isNotEmpty ? userData.vendorID : userData.id;
      case 'distributor':
        return userData.distributorID.isNotEmpty ? userData.distributorID : userData.id;
      default:
        return userData.id;
    }
  }

  String _getDisplayName() {
    switch (_userRole) {
      case 'creator':
        return _contributorData['stageName'] != null && _contributorData['stageName'].toString().isNotEmpty
            ? _contributorData['stageName']
            : (_contributorData['fullName'] ?? 'Creator');
      case 'distributor':
        return _contributorData['distributorLabel'] != null && _contributorData['distributorLabel'].toString().isNotEmpty
            ? _contributorData['distributorLabel']
            : (_contributorData['fullName'] ?? 'Distributor');
      case 'vendor':
        return _contributorData['storeName'] != null && _contributorData['storeName'].toString().isNotEmpty
            ? _contributorData['storeName']
            : (_contributorData['fullName'] ?? 'Vendor');
      default:
        return _contributorData['fullName'] ?? 'Contributor';
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole) {
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

  Color _getRoleColor() {
    switch (_userRole) {
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? MangoPalette.grey900 : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'asset/images/loading.json',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Magic Pod...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: isDarkMode ? MangoPalette.grey900 : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : MangoPalette.black,
        ),
        elevation: 0,
        title: Text(
          'Magic Pod',
          style: TextStyle(
            color: isDarkMode ? Colors.white : MangoPalette.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: isDarkMode ? MangoPalette.grey900 : Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Your creative universe awaits. Share, sell, and make magic happen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Contributor Status Row (matching Profile page style)
                  _buildContributorStatusRow(context),
                  
                  const SizedBox(height: 24),
                  
                  if (_userRole == 'distributor')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Distributor Access',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'As a distributor, you can distribute music, books, podcasts, and movies. '
                            'Product upload is exclusively for vendors.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.blue[200] : Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: options.map((item) {
                          final isExpanded = _expandedStates[item['title']] ?? false;
                          final isAllowed = _isUserAllowed(item['title']!, _userRole);
                          final itemWidth = (constraints.maxWidth - 12) / 2;
                          final isProduct = item['title'] == 'Products';

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutQuart,
                            width: itemWidth,
                            height: isExpanded ? itemWidth * 1.4 : itemWidth * 1.1,
                            child: GestureDetector(
                              onTap: () => _handleItemTap(item['title']!, _userRole, context),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(MangoRadius.md),
                                  onTap: () => _handleItemTap(item['title']!, _userRole, context),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(int.parse(item['color1']!)),
                                          Color(int.parse(item['color2']!)),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(MangoRadius.md),
                                      boxShadow: [
                                        BoxShadow(
                                          color: MangoPalette.black.withOpacity(isDarkMode ? 0.4 : 0.2),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  Lottie.asset(
                                                    item['lottie']!,
                                                    height: 50,
                                                    width: 50,
                                                    fit: BoxFit.cover,
                                                  ),
                                                  if (!isAllowed)
                                                    Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.lock_outline,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                item['title']!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              AnimatedOpacity(
                                                duration: const Duration(milliseconds: 300),
                                                opacity: isExpanded ? 1.0 : 0.0,
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 400),
                                                  height: isExpanded ? null : 0,
                                                  child: SingleChildScrollView(
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    child: Column(
                                                      children: [
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          item['description']!,
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: Colors.white70,
                                                          ),
                                                          maxLines: 4,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (!isAllowed) ...[
                                                          const SizedBox(height: 6),
                                                          Container(
                                                            padding: const EdgeInsets.all(4),
                                                            decoration: BoxDecoration(
                                                              color: MangoPalette.black.withOpacity(0.3),
                                                              borderRadius: BorderRadius.circular(MangoRadius.xs),
                                                            ),
                                                            child: Text(
                                                              _getAccessDeniedMessage(item['title']!, _userRole),
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                              maxLines: 3,
                                                            ),
                                                          ),
                                                        ],
                                                        if (isProduct && _userRole == 'distributor') ...[
                                                          const SizedBox(height: 6),
                                                          Container(
                                                            padding: const EdgeInsets.all(4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.withOpacity(0.3),
                                                              borderRadius: BorderRadius.circular(MangoRadius.xs),
                                                            ),
                                                            child: const Text(
                                                              'STRICTLY VENDORS ONLY',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: MangoPressable(
                                            onTap: () => _toggleExpansion(item['title']!),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: AnimatedRotation(
                                                duration: const Duration(milliseconds: 400),
                                                turns: isExpanded ? 0.5 : 0,
                                                child: const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role Capabilities:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : MangoPalette.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCapabilityItem('🎵 Music', ['Creator', 'Distributor']),
                        _buildCapabilityItem('📚 Books', ['Creator', 'Distributor']),
                        _buildCapabilityItem('🎙️ Podcasts', ['Creator', 'Distributor']),
                        _buildCapabilityItem('🎬 Movies', ['Creator', 'Distributor']),
                        _buildCapabilityItem('🛍️ Products', ['Vendor Only']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContributorStatusRow(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Contributor Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : MangoPalette.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildContributorCard(
                title: 'Creator',
                isRegistered: _userData.isCreator == true,
                icon: FontAwesomeIcons.palette,
                color: Colors.blue,
                context: context,
              ),
              _buildContributorCard(
                title: 'Distributor',
                isRegistered: _userData.isDistributor == true,
                icon: FontAwesomeIcons.shareNodes,
                color: MangoPalette.green500,
                context: context,
              ),
              _buildContributorCard(
                title: 'Vendor',
                isRegistered: _userData.isVendor == true,
                icon: FontAwesomeIcons.store,
                color: MangoPalette.green500,
                context: context,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    String getImageUrl() {
      switch (title) {
        case 'Creator':
          return _userData.creatorImageUrl ?? '';
        case 'Distributor':
          return _userData.distributorImageUrl ?? '';
        case 'Vendor':
          return _userData.vendorImageUrl ?? '';
        default:
          return '';
      }
    }

    String getDisplayName() {
      switch (title) {
        case 'Creator':
          return _userData.creatorName ?? title;
        case 'Distributor':
          return _userData.distributorName ?? title;
        case 'Vendor':
          return _userData.vendorName ?? title;
        default:
          return title;
      }
    }

    String getContributorId() {
      switch (title) {
        case 'Creator':
          return _userData.creatorID ?? '';
        case 'Distributor':
          return _userData.distributorID ?? '';
        case 'Vendor':
          return _userData.vendorID ?? '';
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
          if (!isRegistered) {
            // Navigate to registration
            Get.snackbar(
              'Registration Required',
              'Please register as a $title to access this feature',
              backgroundColor: MangoPalette.green500,
              colorText: Colors.white,
            );
          } else {
            // Show contributor ID or navigate to profile
            _showContributorInfo(title, displayName, contributorId, color, context);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(
              color: isRegistered ? color : MangoPalette.grey500.withOpacity(0.3),
              width: isRegistered ? 2 : 1,
            ),
            image: isRegistered && hasImage
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      MangoPalette.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  )
                : null,
            color: isRegistered
                ? (hasImage ? Colors.transparent : color.withOpacity(0.1))
                : (isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200),
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
                              : (isDarkMode ? Colors.white : MangoPalette.black),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                        borderRadius: BorderRadius.circular(MangoRadius.xs),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MangoPalette.grey500.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.circlePlus,
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContributorInfo(String title, String name, String id, Color color, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1B241E) : Colors.white,
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
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: FaIcon(
                      _getContributorIcon(title),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(MangoRadius.lg),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
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
                  color: isDarkMode ? Colors.black38 : MangoPalette.grey100,
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contributor ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            id.isNotEmpty ? id : 'Not set',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'monospace',
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (id.isNotEmpty)
                      IconButton(
        tooltip: 'Copy',
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: color, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ID copied to clipboard',
                                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.sm)),
                              backgroundColor: isDarkMode ? const Color(0xFF243028) : Colors.white,
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.copy,
                          color: color,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'This is your unique $title identifier. Use it when collaborating or receiving payments.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
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

  IconData _getContributorIcon(String title) {
    switch (title) {
      case 'Creator':
        return FontAwesomeIcons.palette;
      case 'Distributor':
        return FontAwesomeIcons.shareNodes;
      case 'Vendor':
        return FontAwesomeIcons.store;
      default:
        return FontAwesomeIcons.user;
    }
  }

  Widget _buildCapabilityItem(String capability, List<String> allowedRoles) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              capability,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white : MangoPalette.black,
              ),
            ),
          ),
          Text(
            allowedRoles.join(', '),
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}