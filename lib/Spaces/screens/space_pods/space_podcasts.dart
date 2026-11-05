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
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class SpacePodcasts extends StatelessWidget {
  SpacePodcasts({super.key});

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

    Widget _buildEmptyPodcastSection(String message) {
      return Container(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.podcasts, size: 32, color: MangoPalette.grey400),
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

    Widget _buildPodcastCard(Map<String, dynamic> podcastData, int index) {
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
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                    image: DecorationImage(
                      image: NetworkImage(
                        podcastData['thumbnail'] ?? podcastData['coverImage'] ?? '',
                      ),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        print('Error loading podcast image: $exception');
                      },
                    ),
                  ),
                ),
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
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          podcastData['duration']?.toString() ?? '0:00',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
              podcastData['title'] ?? 'Unknown Title',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              podcastData['host'] ?? 'Unknown Host',
              style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    Widget _buildPodcastCollectionSection() {
      return _buildSectionWithSeeAll(
        'Podcast Collection',
        onSeeAll: () => Get.toNamed('/podcast-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId!)
              .collection('space-podcasts')
              .orderBy('savedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 180,
                width: 160,
                color: MangoPalette.grey300,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyPodcastSection(
                isAdmin 
                    ? 'No podcasts added yet. Tap the + button to add podcasts!'
                    : 'No podcasts have been spaced yet'
              );
            }
            
            final spaceItems = snapshot.data!.docs;
            
            return Container(
              height: 180,
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
                        .collection('podcasts')
                        .doc(originalItemId)
                        .get(),
                    builder: (context, podcastSnapshot) {
                      if (podcastSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildCardSkeleton();
                      }

                      if (podcastSnapshot.hasError || !podcastSnapshot.hasData || !podcastSnapshot.data!.exists) {
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
                                          Icons.podcasts,
                                          color: MangoPalette.grey600,
                                          size: 24,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Podcast not found',
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
                                'Podcast not available',
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

                      final podcastData = podcastSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildPodcastCard(podcastData, index);
                    },
                  );
                },
              ),
            );
          },
        ),
      );
    }

    Widget _buildTrendingPodcastsSection() {
      return _buildSectionWithSeeAll(
        'Trending Podcasts',
        onSeeAll: () => Get.toNamed('/podcast-home'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('podcasts')
              .where('isTrending', isEqualTo: true)
              .orderBy('listens', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return HorizontalShimmerList(
                height: 180,
                width: 160,
                color: MangoPalette.grey300,
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyPodcastSection('No trending podcasts available');
            }
            
            final podcasts = snapshot.data!.docs;
            
            return Container(
              height: 180,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: podcasts.length,
                itemBuilder: (context, index) {
                  final podcastData = podcasts[index].data() as Map<String, dynamic>;
                  return _buildPodcastCard(podcastData, index);
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
                            text: "This is how we catch a vibe.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: "\nNo Sweat.",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SpacePodcastsActions(
                    spaceId: spaceId!, 
                    podType: 'podcast',
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 10),
                  _buildPodcastCollectionSection(),
                  const SizedBox(height: 10),
                  _buildTrendingPodcastsSection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10,
                    ),
                    child: Text(
                      'Podcast Club',
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
                    child: PodcastClubCard(
                      spaceId: spaceId!, 
                      podType: 'podcast',
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
                            text: "Recording Sessions...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LiveRecordingSessionsCard(
                      spaceId: spaceId!, 
                      podType: 'podcast',
                      isAdmin: isAdmin,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "Studio Corner",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StudioCornerList(spaceId: spaceId!, isAdmin: isAdmin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Podcast-specific Actions Widget
class SpacePodcastsActions extends StatelessWidget {
  final String podType;
  final String spaceId;
  final bool isAdmin;
  
  const SpacePodcastsActions({
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
            text: "Podcast Club",
            onTap: isAdmin 
                ? () => _openPodcastClubSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "start podcast club discussions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: Colors.red,
            icon: Icons.mic,
            text: "Record Live",
            onTap: isAdmin 
                ? () => _openRecordingSessionSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create recording sessions"),
            isDisabled: !isAdmin,
          ),
          _buildButton(
            context,
            color: MangoPalette.green500,
            icon: Icons.mic_none,
            text: "Studio",
            onTap: isAdmin 
                ? () => _openStudioCornerSheet(context, spaceId, podType)
                : () => _showPermissionDenied(context, "create studio events"),
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

  void _openPodcastClubSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for podcast club discussion creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Podcast club discussion feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openRecordingSessionSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for recording session creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Recording session feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }

  void _openStudioCornerSheet(BuildContext context, String spaceId, String podType) {
    // Implementation for studio corner event creation
    UtilsService().showSnackbar(
      "Coming Soon",
      "Studio corner feature coming soon!",
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      context: context,
    );
  }
}

// Podcast Club Card (Podcast-specific)
class PodcastClubCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const PodcastClubCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<PodcastClubCard> createState() => _PodcastClubCardState();
}

class _PodcastClubCardState extends State<PodcastClubCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400",
    "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400",
    "https://images.unsplash.com/photo-1515378960530-7c0da6231fb1?w=400",
    "https://images.unsplash.com/photo-1494232410401-ad00d5433cfa?w=400",
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
          .collection('podcastClub')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoPodcastClubCarousel();
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
                            data['title'] ?? "Podcast Club",
                            style: TextStyle(
                              color: Theme.of(context).primaryColorLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data['members'] ?? 0} members listening",
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
                                data['description'] ?? 'Join our podcast discussions!',
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
                                  "asset/images/podcast_club.jpg",
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

  Widget _buildNoPodcastClubCarousel() {
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
                  Icon(Icons.podcasts, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "PODCAST CLUB",
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
                  widget.isAdmin ? "Start a Podcast Club" : "Join the Podcast Club",
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
                      ? "Create a podcast club and share your favorite episodes with members!"
                      : "No active podcast clubs. Check back later!",
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

// Live Recording Sessions Card (Podcast-specific)
class LiveRecordingSessionsCard extends StatefulWidget {
  final String spaceId;
  final String podType;
  final bool isAdmin;
  
  const LiveRecordingSessionsCard({
    super.key,
    required this.spaceId,
    required this.podType,
    required this.isAdmin,
  });

  @override
  State<LiveRecordingSessionsCard> createState() => _LiveRecordingSessionsCardState();
}

class _LiveRecordingSessionsCardState extends State<LiveRecordingSessionsCard> {
  bool _isExpanded = false;
  int _currentImageIndex = 0;
  late Timer _carouselTimer;

  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=400",
    "https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400",
    "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=400",
    "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400",
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
          .collection('recordingSessions')
          .where('podType', isEqualTo: widget.podType)
          .orderBy('scheduledTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoRecordingSessionsCarousel();
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
                              _getRecordingTimeText(currentSession),
                              style: const TextStyle(
                                fontSize: 12,
                                color: MangoPalette.grey500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            currentSession['title'] ?? "Recording Session",
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
                                "${currentSession['listeners'] ?? 0} listeners.",
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
                                  "asset/images/recording_session.jpg",
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

  String _getRecordingTimeText(Map<String, dynamic> session) {
    if (session['isLive'] == true) {
      return "RECORDING NOW";
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
    return Colors.red;
  }

  Widget _buildNoRecordingSessionsCarousel() {
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
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(MangoRadius.md),
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
                  Icon(Icons.mic, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "RECORDING",
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
                  widget.isAdmin ? "Start Recording" : "Live Recording Sessions",
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
                      ? "Start a live recording session and create podcasts with your space members!"
                      : "No recording sessions scheduled. Check back later!",
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
                        ? Colors.red
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

// Studio Corner List (Podcast-specific)
class StudioCornerList extends StatelessWidget {
  final String spaceId;
  final bool isAdmin;
  
  const StudioCornerList({
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
          .collection('studioCorner')
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildNoStudioCornerCarousel();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return _buildNoStudioCornerCarousel();
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
                                data["host"],
                                style: TextStyle(
                                  color: Theme.of(context).primaryColorLight,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  data["genre"] ?? "Studio Session",
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

  Widget _buildNoStudioCornerCarousel() {
    return _StudioCornerCarousel(isAdmin: isAdmin);
  }
}

class _StudioCornerCarousel extends StatefulWidget {
  final bool isAdmin;
  
  const _StudioCornerCarousel({required this.isAdmin});
  
  @override
  State<_StudioCornerCarousel> createState() => _StudioCornerCarouselState();
}

class _StudioCornerCarouselState extends State<_StudioCornerCarousel> {
  final List<String> _carouselImages = [
    "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=400",
    "https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400",
    "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400",
    "https://images.unsplash.com/photo-1478737270239-2f02b77fc618?w=400",
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
                  Icon(Icons.mic_none, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "STUDIO",
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
                  widget.isAdmin ? "Create Studio Session" : "Studio Corner",
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
                      ? "Set up a studio session and record professional podcasts with your team!"
                      : "No studio sessions scheduled. Check back later!",
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