import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Contributors/pages/upload_podcast_series.dart';
import 'package:mango/Contributors/pages/upload_podcast.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class PodcastBoxPage extends StatefulWidget {
  final MangoUser user;  
  final String? contributorId;  

  const PodcastBoxPage({
    super.key,
    required this.user,
    this.contributorId,
  });

  @override
  _PodcastBoxPageState createState() => _PodcastBoxPageState();
}

class _PodcastBoxPageState extends State<PodcastBoxPage>
    with TickerProviderStateMixin {
  bool _showUploadOptions = false;
  bool _showYourPodcasts = true;
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
    } else if (widget.user.creatorID != null && widget.user.creatorID!.isNotEmpty) {
      _contributorId = widget.user.creatorID;
    } else if (widget.user.distributorID != null && widget.user.distributorID!.isNotEmpty) {
      _contributorId = widget.user.distributorID;
    } else if (widget.user.vendorID != null && widget.user.vendorID!.isNotEmpty) {
      _contributorId = widget.user.vendorID;
    }

    debugPrint('PodcastBoxPage using contributor ID: $_contributorId');
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleYourPodcasts() {
    setState(() {
      _showYourPodcasts = !_showYourPodcasts;
      _showYourPodcasts ? _controller.forward() : _controller.reverse();
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
            'Podcast Box',
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: MangoPalette.green500,
              ),
              const SizedBox(height: 16),
              Text(
                'No Contributor Profile Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please register as a creator to upload podcasts.',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
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
          'Podcast Box',
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

                
                _buildSectionTitle('Trending Podcasts', textColor),
                _buildHorizontalPodcastsList(isDarkMode),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildSectionTitle('Your Series', textColor),
                _buildHorizontalSeriesList(isDarkMode),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildYourPodcastsSection(
                  isDarkMode,
                  textColor,
                  secondaryTextColor!,
                ),

                
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Mango Podcast. © 2025',
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

  Widget _buildStatisticsSection(bool isDarkMode, Color textColor, Color cardColor) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("podcasts")
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
              podcastsCount: 0,
              totalListens: 0,
              monthlyListens: 0,
              totalSubscribers: 0,
              isDarkMode: isDarkMode,
            );
          }

          final podcasts = snapshot.data!.docs;
          int totalListens = 0;
          int monthlyListens = 0;
          int totalSubscribers = 0;
          final now = DateTime.now();
          final monthAgo = DateTime(now.year, now.month - 1, now.day);

          for (var podcast in podcasts) {
            totalListens += (podcast['listens'] ?? 0) as int;
            totalSubscribers += (podcast['subscribers'] ?? 0) as int;
            final timestamp = podcast['timestamp'];
            if (timestamp != null) {
              final createdAt = (timestamp as Timestamp).toDate();
              if (createdAt.isAfter(monthAgo)) {
                monthlyListens += (podcast['listens'] ?? 0) as int;
              }
            }
          }

          return _buildModernStatCard(
            podcastsCount: podcasts.length,
            totalListens: totalListens,
            monthlyListens: monthlyListens,
            totalSubscribers: totalSubscribers,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard({
    int? podcastsCount,
    int? totalListens,
    int? monthlyListens,
    int? totalSubscribers,
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Analytics',
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
                value: podcastsCount ?? 0,
                label: 'Total Podcasts',
                icon: Icons.podcasts,
                color: Colors.purple,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalListens ?? 0,
                label: 'Total Listens',
                icon: Icons.headphones,
                color: Colors.blue,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: monthlyListens ?? 0,
                label: 'Monthly Listens',
                icon: Icons.trending_up,
                color: MangoPalette.green500,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalSubscribers ?? 0,
                label: 'Total Subscribers',
                icon: Icons.people,
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
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
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
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
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
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: isDarkMode ? Colors.white : MangoPalette.black,
            ),
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
                    'Upload Your Podcast',
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
                    'Upload a Podcast',
                    Icons.podcasts,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadPodcastPage(
                          contributorId: _contributorId,  
                        ),
                      ),
                    ),
                    isDarkMode,
                  ),
                  _buildUploadOption(
                    'Upload a Series',
                    Icons.podcasts_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadPodcastSeriesPage(
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
                Icon(icon, size: 20, color: Colors.purple, semanticLabel: title),
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

  Widget _buildHorizontalPodcastsList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("podcasts")
              .where("contributorId", isEqualTo: _contributorId)  
              .orderBy("listens", descending: true)
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
                  "Error loading podcasts",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No podcasts yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final podcasts = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                final podcast = podcasts[index];
                return _buildPodcastCard(
                  podcast['coverUrl'] ?? '',
                  podcast['title'] ?? 'Untitled',
                  podcast['host'] ?? 'Unknown Host',
                  '${podcast['episodeCount'] ?? 0} eps',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalSeriesList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("podcast_series")
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
                  "Error loading series",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No series yet",
                  style: TextStyle(
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              );
            }

            final series = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: series.length,
              itemBuilder: (context, index) {
                final seriesItem = series[index];
                return _buildSeriesCard(
                  seriesItem['coverUrl'] ?? '',
                  seriesItem['title'] ?? 'Untitled Series',
                  '${seriesItem['podcastCount'] ?? 0} podcasts',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodcastCard(String imageUrl, String title, String host, String episodeCount, bool isDarkMode) {
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
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.podcasts,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.podcasts,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 400),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    episodeCount,
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
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : MangoPalette.black,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                Text(
                  host,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCard(String imageUrl, String title, String podcastCount, bool isDarkMode) {
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
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.podcasts_outlined,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 120,
                    color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                    child: Icon(
                      Icons.podcasts_outlined,
                      color: isDarkMode ? MangoPalette.grey600 : MangoPalette.grey400,
                      size: 40,
                    ),
                  ),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    podcastCount,
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
            width: 120,
            child: Text(
              title,
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

  Widget _buildYourPodcastsSection(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          MangoPressable(
            onTap: _toggleYourPodcasts,
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
                    'Your Podcasts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showYourPodcasts ? 0.5 : 0,
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
                  .collection("podcasts")
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
                      "Error loading podcasts",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No podcasts uploaded yet",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                final podcasts = snapshot.data!.docs;

                return Column(
                  children: List.generate(podcasts.length, (index) {
                    final podcast = podcasts[index];
                    return _buildPodcastItem(
                      id: podcast.id,
                      imageUrl: podcast['coverUrl'] ?? '',
                      title: podcast['title'] ?? 'Untitled',
                      host: podcast['host'] ?? 'Unknown Host',
                      listens: (podcast['listens'] ?? 0) as int,
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

  Widget _buildPodcastItem({
    required String id,
    required String imageUrl,
    required String title,
    required String host,
    required int listens,
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
                        Icons.podcasts,
                        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey400,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? MangoPalette.grey700 : MangoPalette.grey300,
                      child: Icon(
                        Icons.podcasts,
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
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      Text(
                        host,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
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
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                  child: Text(
                    '$listens listens',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
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