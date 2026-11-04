import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Spaces/controllers/space_item.dart';
import 'package:mango/utils.dart';

import '../../../Home/controllers/dashboard_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';
import '../../../Home/pages/post_shimmer.dart';

class SpaceVines extends StatelessWidget {
  SpaceVines({super.key});

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
        child: CircularProgressIndicator(),
      ),
    );
  }

  String _formatCount(int count) {
      if (count >= 1000000) {
        return '${(count / 1000000).toStringAsFixed(1)}M';
      } else if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(1)}K';
      }
      return count.toString();
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
                GestureDetector(
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

    Widget _buildEmptyVineSection(String message) {
      return Container(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, size: 32, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              width: 100,
              height: 12,
              color: Colors.grey[300],
              margin: EdgeInsets.only(bottom: 4),
            ),
            Container(width: 80, height: 10, color: Colors.grey[300]),
          ],
        ),
      );
    }

    Widget _buildVineCard(Map<String, dynamic> vineData, int index) {
      final views = vineData['views'] ?? 0;
      final likes = vineData['likes'] ?? 0;
      
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
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(
                        vineData['thumbnail'] ?? vineData['videoThumbnail'] ?? '',
                      ),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        print('Error loading vine thumbnail: $exception');
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
                      borderRadius: BorderRadius.circular(12),
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
                // Duration badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vineData['duration'] ?? '0:15',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                // Play button overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              vineData['title'] ?? 'Unknown Vine',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              vineData['creator'] ?? 'Unknown Creator',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(Icons.play_circle, size: 10, color: Colors.grey),
                SizedBox(width: 2),
                Text(
                  _formatCount(views),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                SizedBox(width: 8),
                Icon(Icons.favorite, size: 10, color: Colors.red),
                SizedBox(width: 2),
                Text(
                  _formatCount(likes),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      );
    }

  

    Widget _buildVineCollectionSection() {
      return _buildSectionWithSeeAll(
        'Vine Collection',
        onSeeAll: () => Get.toNamed('/vines-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId!)
              .collection('space-vines')
              .orderBy('savedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 200,
                width: 160,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyVineSection(
                isAdmin 
                    ? 'No vines added yet. Tap the + button to add vines!'
                    : 'No vines have been spaced yet'
              );
            }
            
            final spaceItems = snapshot.data!.docs;
            
            return Container(
              height: 220,
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
                        .collection('vines')
                        .doc(originalItemId)
                        .get(),
                    builder: (context, vineSnapshot) {
                      if (vineSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildCardSkeleton();
                      }

                      if (vineSnapshot.hasError || !vineSnapshot.hasData || !vineSnapshot.data!.exists) {
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
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.video_library,
                                          color: Colors.grey[600],
                                          size: 24,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Vine not found',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Vine not available',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Unknown',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }

                      final vineData = vineSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildVineCard(vineData, index);
                    },
                  );
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildTrendingVinesSection() {
      return _buildSectionWithSeeAll(
        'Trending Vines',
        onSeeAll: () => Get.toNamed('/vines-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('vines')
              .where('isTrending', isEqualTo: true)
              .orderBy('views', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 200,
                width: 160,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyVineSection('No trending vines available');
            }
            
            final vines = snapshot.data!.docs;
            
            return Container(
              height: 220,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: vines.length,
                itemBuilder: (context, index) {
                  final vineData = vines[index].data() as Map<String, dynamic>;
                  return _buildVineCard(vineData, index);
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildPopularCreatorsSection() {
      return _buildSectionWithSeeAll(
        'Popular Creators',
        onSeeAll: () => Get.toNamed('/creators-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('isCreator', isEqualTo: true)
              .orderBy('followers', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 120,
                width: 100,
                color: Colors.grey[300]!,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyVineSection('No creators found');
            }
            
            final creators = snapshot.data!.docs;
            
            return Container(
              height: 130,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: creators.length,
                itemBuilder: (context, index) {
                  final creatorData = creators[index].data() as Map<String, dynamic>;
                  return Container(
                    width: 100,
                    margin: EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundImage: NetworkImage(
                            creatorData['profileImage'] ?? '',
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          creatorData['username'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_formatCount(creatorData['followers'] ?? 0)} followers',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
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
                            text: "Short & Sweet.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: "\nVine Vibes.",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SpaceVinesActions(
                    spaceId: spaceId!, 
                    podType: 'vines',
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 10),
                  _buildVineCollectionSection(),
                  const SizedBox(height: 10),
                  _buildTrendingVinesSection(),
                  const SizedBox(height: 10),
                  _buildPopularCreatorsSection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Text(
                      'Vine Club',
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
                    child: VineClubCard(
                      spaceId: spaceId!, 
                      podType: 'vines',
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
                            text: "Premieres...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LivePremieresCard(
                      spaceId: spaceId!, 
                      podType: 'vines',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "Creator Spotlight",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CreatorSpotlightList(spaceId: spaceId!, isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Vine-specific Actions Widget
class SpaceVinesActions extends StatelessWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const SpaceVinesActions({
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
            text: "Vine Club",
            onTap: isAdmin 
                ? () => _openVineClubSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "start vine club discussions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.red,
            icon: Icons.live_tv,
            text: "Premiere",
            onTap: isAdmin 
                ? () => _openPremiereSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create premieres"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.orange,
            icon: Icons.emoji_events,
            text: "Creator",
            onTap: isAdmin 
                ? () => _openCreatorSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create creator spotlights"),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        width: 90,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[700] : color,
          borderRadius: BorderRadius.circular(20),
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

  void _openVineClubSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Vine club discussion feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openPremiereSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Premiere feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openCreatorSheet(BuildContext context, String spaceId, String podType) {
    UtilsService().showSnackbar(
      "Coming Soon",
      "Creator spotlight feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }
}

// Vine Club Card (Vine-specific)
class VineClubCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const VineClubCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<VineClubCard> createState() => _VineClubCardState();
}

class _VineClubCardState extends State<VineClubCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d8?w=400",
    "https://images.unsplash.com/photo-1536240476400-6f6a1b7a3b0c?w=400",
    "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400",
    "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400",
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
          .collection('vineClub')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoVineClubCarousel();
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
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
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
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              data['status'] ?? "Active",
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            data['title'] ?? "Vine Club",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data['members'] ?? 0} members watching",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
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
                                    fontSize: 8,
                                    color: Colors.black.withOpacity(0.8),
                                  ),
                                ),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black.withOpacity(0.8),
                                  size: 10,
                                ),
                              ],
                            ),
                          ),
                          if (_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data['description'] ?? 'Discuss vines, share reactions, and discover new creators!',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.black.withOpacity(0.6),
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
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: data['image'] != null
                              ? Image.network(
                                  data['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/vine_club.jpg",
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

  Widget _buildNoVineClubCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
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
                borderRadius: BorderRadius.circular(12),
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
                  Icon(Icons.video_library, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "VINE CLUB",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
                  widget.isAdmin ? "Start a Vine Club" : "Join the Vine Club",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Create a vine club to share and discuss short videos with members!"
                      : "No active vine clubs. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
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
                        color: Colors.black.withOpacity(0.3),
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

// Live Premieres Card (Vine-specific)
class LivePremieresCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const LivePremieresCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<LivePremieresCard> createState() => _LivePremieresCardState();
}

class _LivePremieresCardState extends State<LivePremieresCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1536240476400-6f6a1b7a3b0c?w=400",
    "https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d8?w=400",
    "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400",
    "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400",
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
          .collection('premieres')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('scheduledTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoPremieresCarousel();
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
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
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
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _getPremiereTimeText(currentSession),
                              style: const TextStyle(
                                fontSize: 7,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            currentSession['title'] ?? "Vine Premiere",
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
                                "${currentSession['viewers'] ?? 0} viewers.",
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.black,
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(currentSession),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
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
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(10, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: currentSession['image'] != null
                              ? Image.network(
                                  currentSession['image'],
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  "asset/images/premiere.jpg",
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

  String _getPremiereTimeText(Map<String, dynamic> session) {
    if (session['isLive'] == true) {
      return "PREMIERING NOW";
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
    if (session['isScheduled'] == true) return Colors.orange;
    return Colors.red;
  }

  Widget _buildNoPremieresCarousel() {
    return Container(
      width: double.infinity,
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
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
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.live_tv, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "PREMIERE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
                  widget.isAdmin ? "Host a Premiere" : "Upcoming Premieres",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Schedule a premiere for your vines and build anticipation!"
                      : "No premieres scheduled. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
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
                        ? Colors.red
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
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

// Creator Spotlight List (Vine-specific)
class CreatorSpotlightList extends StatelessWidget {
  final String spaceId;
  final bool isAdmin;
  
  const CreatorSpotlightList({
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
          .collection('creatorSpotlight')
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildNoCreatorSpotlightCarousel();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildNoCreatorSpotlightCarousel();
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
                                data["creator"],
                                style: TextStyle(
                                  color: Theme.of(context).primaryColorLight,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  data["category"] ?? "Creator",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).primaryColorLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(data["image"]),
                      ),
                      SizedBox(width: 15),
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

  Widget _buildNoCreatorSpotlightCarousel() {
    return _CreatorSpotlightCarousel(isAdmin: isAdmin);
  }
}

class _CreatorSpotlightCarousel extends StatefulWidget {
  final bool isAdmin;
  
  const _CreatorSpotlightCarousel({required this.isAdmin});
  
  @override
  State<_CreatorSpotlightCarousel> createState() => _CreatorSpotlightCarouselState();
}

class _CreatorSpotlightCarouselState extends State<_CreatorSpotlightCarousel> {
  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1536240476400-6f6a1b7a3b0c?w=400",
    "https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d8?w=400",
    "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400",
    "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400",
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                  Colors.black,
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
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "CREATOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
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
                  widget.isAdmin ? "Feature a Creator" : "Creator Spotlight",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAdmin
                      ? "Showcase creators and their vines in your space!"
                      : "No creators featured yet. Check back later!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
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
                        ? Colors.orange
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
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