import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Contributors/pages/upload_album.dart';
import 'package:mango/Contributors/pages/upload_song.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/MusicPlayer/music_player.dart';
import 'package:mango/Utils/optimized_lists.dart';

class MusicBoxPage extends StatefulWidget {
  final MangoUser user; 
  final String? contributorId; 
  
  const MusicBoxPage({
    super.key, 
    required this.user,
    this.contributorId,
  });

  @override
  _MusicBoxPageState createState() => _MusicBoxPageState();
}

class _MusicBoxPageState extends State<MusicBoxPage>
    with TickerProviderStateMixin {
  bool _showUploadOptions = false;
  bool _showYourSongs = true;
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
    
    print('Using contributor ID: $_contributorId');
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleYourSongs() {
    setState(() {
      _showYourSongs = !_showYourSongs;
      _showYourSongs ? _controller.forward() : _controller.reverse();
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
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final cardColor = isDarkMode ? Colors.grey[800] : Colors.grey[50];
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    
    if (_contributorId == null || _contributorId!.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Music Box',
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
                color: Colors.orange,
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
                'Please register as a creator to upload music.',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
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
          'Music Box',
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

                
                _buildSectionTitle('Albums & EPs', textColor),
                _buildHorizontalAlbumsList(isDarkMode),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildSectionTitle('Best Performing', textColor),
                _buildSongsList(isDarkMode, textColor, secondaryTextColor!),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                
                _buildYourTracksSection(
                  isDarkMode,
                  textColor,
                  secondaryTextColor,
                ),

                
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Mango Music. © 2025',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
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
            .collection("music")
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
              tracksCount: 0,
              totalStreams: 0,
              monthlyPlays: 0,
              totalLikes: 0,
              isDarkMode: isDarkMode,
            );
          }

          final songs = snapshot.data!.docs;
          int totalStreams = 0;
          int monthlyPlays = 0;
          int totalLikes = 0;
          final now = DateTime.now();
          final monthAgo = DateTime(now.year, now.month - 1, now.day);

          for (var song in songs) {
            totalStreams += (song['plays'] ?? 0) as int;
            totalLikes += (song['likes'] ?? 0) as int;
            final timestamp = song['timestamp'];
            if (timestamp != null) {
              final createdAt = (timestamp as Timestamp).toDate();
              if (createdAt.isAfter(monthAgo)) {
                monthlyPlays += (song['plays'] ?? 0) as int;
              }
            }
          }

          return _buildModernStatCard(
            tracksCount: songs.length,
            totalStreams: totalStreams,
            monthlyPlays: monthlyPlays,
            totalLikes: totalLikes,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard({
    int? tracksCount,
    int? totalStreams,
    int? monthlyPlays,
    int? totalLikes,
    bool isLoading = false,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
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
                value: tracksCount ?? 0,
                label: 'Total Tracks',
                icon: Icons.music_note,
                color: Colors.purple,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalStreams ?? 0,
                label: 'Total Streams',
                icon: Icons.play_arrow,
                color: Colors.blue,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: monthlyPlays ?? 0,
                label: 'Monthly Plays',
                icon: Icons.trending_up,
                color: Colors.green,
                isLoading: isLoading,
                isDarkMode: isDarkMode,
              ),
              _buildModernStatItem(
                value: totalLikes ?? 0,
                label: 'Total Likes',
                icon: Icons.favorite,
                color: Colors.red,
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
        color: isDarkMode ? Colors.grey[800] : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(6),
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
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
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
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontFamily: 'Inter',
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 4),
              
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              color: isDarkMode ? Colors.white : Colors.black,
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
          color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
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
                    'Upload Your Music',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
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
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  _buildUploadOption(
                    'Upload a Single Track',
                    Icons.music_note_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadSongPage(
                          contributorId: _contributorId!, 
                        ),
                      ),
                    ),
                    isDarkMode,
                  ),
                  _buildUploadOption(
                    'Upload an Album/EP',
                    Icons.album_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadAlbumPage(
                          contributorId: _contributorId!, 
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, size: 20, color: Colors.orange, semanticLabel: title),
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

  Widget _buildHorizontalAlbumsList(bool isDarkMode) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("albums")
              .where("contributorId", isEqualTo: _contributorId) 
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error loading albums",
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No albums yet",
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              );
            }

            final albums = snapshot.data!.docs;

            return OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return _buildAlbumCard(
                  album['coverUrl'] ?? '',
                  album['title'] ?? 'Untitled',
                  isDarkMode,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlbumCard(String imageUrl, String title, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => Container(
                width: 120,
                height: 120,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                child: Icon(
                  Icons.album,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 120,
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                child: Icon(
                  Icons.album,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("music")
            .where("contributorId", isEqualTo: _contributorId) 
            .orderBy("plays", descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading songs",
                style: TextStyle(color: secondaryTextColor),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No songs yet",
                style: TextStyle(color: secondaryTextColor),
              ),
            );
          }

          final songs = snapshot.data!.docs;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            child: Column(
              children: List.generate(songs.length, (index) {
                final songDoc = songs[index];
                final music = Music.fromFirestore(songDoc);

                return _buildEnhancedSongItem(
                  music: music,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedSongItem({
    required Music music,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MusicPlayer(musicId: music.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: music.artworkUrl,
                        placeholder: (context, url) => Container(
                          width: 50,
                          height: 50,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          child: Icon(
                            Icons.music_note,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          child: Icon(
                            Icons.music_note,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (music.isExplicit)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'E',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: music.displayTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            if (music.duration != null)
                              TextSpan(
                                text: ' • ${music.formattedDuration}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${music.artistName} • ${music.genre}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      if (music.mood != null && music.mood!.isNotEmpty)
                        Text(
                          'Mood: ${music.mood!}${music.language != null && music.language!.isNotEmpty ? ' • ${music.language!}' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: secondaryTextColor.withOpacity(0.8),
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${music.plays} plays',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${music.likes} likes',
                      style: TextStyle(
                        fontSize: 10,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYourTracksSection(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleYourSongs,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Tracks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showYourSongs ? 0.5 : 0,
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
                  .collection("music")
                  .where("contributorId", isEqualTo: _contributorId) 
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error loading tracks",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No songs uploaded yet",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  );
                }

                final songs = snapshot.data!.docs;

                return Column(
                  children: List.generate(songs.length, (index) {
                    final song = songs[index];
                    final music = Music.fromFirestore(song);

                    return _buildEnhancedSongItem(
                      music: music,
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}