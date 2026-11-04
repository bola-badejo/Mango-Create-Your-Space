import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mango/Utils/optimized_lists.dart';

import '../../../MusicPlayer/music_player.dart';
import '../../controllers/dashboard_controller.dart';

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final MangoDashboardController _controller =
      Get.find<MangoDashboardController>();

  final List<String> _genreFilters = [
    'All',
    'Afrobeats',
    'Hip Hop',
    'R&B',
    'Pop',
    'Amapiano',
    'Jazz',
    'Rock'
  ];
  String _selectedGenre = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Keep a local cache of loaded songs per genre to avoid reloading on scroll
  final Map<String, List<Music>> _songsCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-load initial songs
    _loadSongsForGenre(_selectedGenre);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongsForGenre(String genre) async {
    // If already loading or data exists in cache, skip
    if (_isLoading) return;
    if (_songsCache.containsKey(genre) && _songsCache[genre] != null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final stream = genre == 'All'
          ? _controller.getMusic()
          : _controller.getSongsByGenre(genre);
      final songs = await stream.first;
      setState(() {
        _songsCache[genre] = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with back button
            SliverToBoxAdapter(
              child: _buildHeader(context, isDark),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark),
            ),

            // Genre Filter
            SliverToBoxAdapter(
              child: _buildGenreFilter(isDark),
            ),

            // Songs Grid
            _buildSongsGrid(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
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
            'explore music',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            // Implement search functionality
            setState(() {});
          },
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search songs, artists, or albums...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
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

  Widget _buildGenreFilter(bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 15),
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genreFilters.length,
        itemBuilder: (context, index) {
          final genre = _genreFilters[index];
          final isSelected = _selectedGenre == genre;

          return GestureDetector(
            onTap: () {
              if (_selectedGenre == genre) return;
              setState(() {
                _selectedGenre = genre;
              });
              _loadSongsForGenre(genre);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? Colors.orange
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Center(
                child: Text(
                  genre,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongsGrid(bool isDark) {
    final cachedSongs = _songsCache[_selectedGenre];
    final hasData = cachedSongs != null && cachedSongs.isNotEmpty;

    // Filter songs based on search
    final filteredSongs = _searchController.text.isEmpty
        ? cachedSongs
        : cachedSongs?.where((song) =>
            song.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            song.primaryArtistName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            song.genre.toLowerCase().contains(_searchController.text.toLowerCase())
        ).toList();

    // Loading state (first load)
    if (_isLoading && cachedSongs == null) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildShimmerCard(isDark),
            childCount: 6,
          ),
        ),
      );
    }

    // No data state
    if (!hasData || filteredSongs == null || filteredSongs.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchController.text.isNotEmpty ? Icons.search_off : Icons.music_off,
                size: 60,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty ? 'No results found' : 'No songs found',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Display filtered songs in grid
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = filteredSongs[index];
            return _buildSongCard(song, index, isDark);
          },
          childCount: filteredSongs.length,
        ),
      ),
    );
  }

  Widget _buildSongCard(Music song, int index, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayer(musicId: song.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.grey).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: song.artworkUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 140,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 140,
                  color: Colors.grey[300],
                  child: const Icon(Icons.music_note, size: 40, color: Colors.grey),
                ),
              ),
            ),
            // Song Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.primaryArtistName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          song.genre,
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.play_circle_outline, size: 10, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            _formatPlays(song.plays),
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
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
    );
  }

  Widget _buildShimmerCard(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Colors.white,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 14, width: 100, child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 8),
                  SizedBox(height: 11, width: 80, child: ColoredBox(color: Colors.white)),
                  SizedBox(height: 8),
                  SizedBox(height: 10, width: 60, child: ColoredBox(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPlays(int plays) {
    if (plays >= 1000000) {
      return '${(plays / 1000000).toStringAsFixed(1)}M';
    } else if (plays >= 1000) {
      return '${(plays / 1000).toStringAsFixed(1)}K';
    }
    return plays.toString();
  }
}