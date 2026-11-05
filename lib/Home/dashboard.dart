import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Contributors/controllers/home_product_controller.dart';
import 'package:mango/Contributors/controllers/product_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Events/components/event_card.dart';
import 'package:mango/Home/components/book_components.dart';
import 'package:mango/Home/components/music_components.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/pages/open_pages/marketplace.dart';
import 'package:mango/Home/pages/post_shimmer.dart';
import 'package:mango/Home/pages/vendors_list_page.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Music/controllers/mango_music_controller.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/MusicPlayer/music_player.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/Profile/profile.dart';
import 'package:mango/Spaces/common/card_items.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Spaces/screens/space_detail.dart';
import 'package:mango/Store/components/marketplace_card.dart';
import 'package:mango/Store/screens/product_detail_screen.dart';
import 'package:mango/Utils/theme.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MiniPlayerWrapper extends StatelessWidget {
  const MiniPlayerWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<MusicPlayerState>();
    return playerState.currentTrack != null
        ? const MinimizedPlayerView()
        : const SizedBox.shrink();
  }
}

String timeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays > 365) {
    return '${(difference.inDays / 365).floor()}y ago';
  } else if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()}mo ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
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

class MangoDashboard extends StatefulWidget {
  MangoDashboard({super.key});

  @override
  State<MangoDashboard> createState() => _MangoDashboardState();

  getSongsForMood(List<String> genres) {}
}

class _MangoDashboardState extends State<MangoDashboard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  // Use late initialization to prevent rebuilds
  late final MangoDashboardController controller;
  late final SpaceController spaceController;
  late final ProductController productController;
  late final NotificationController notificationsController;
  
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  bool _showSearchResults = false;
  late TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebouncer;

  // Cache theme controller reference
  ThemeController? _cachedThemeController;

  ThemeController get _themeController {
    _cachedThemeController ??= ThemeController.to;
    return _cachedThemeController!;
  }

  @override
  bool get wantKeepAlive => true;

  SearchState get _currentSearchState {
    if (!_isSearchExpanded) return SearchState.collapsed;
    if (_showSearchResults) return SearchState.results;
    return SearchState.expandedNoResults;
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers once
    controller = Get.put(MangoDashboardController(), permanent: true);
    spaceController = Get.put(SpaceController(), permanent: true);
    productController = Get.put(ProductController(), permanent: true);
    notificationsController = Get.find<NotificationController>();
    
    _tabController = TabController(length: 7, vsync: this);
    
    // Use addListener without setState to prevent unnecessary rebuilds
    _tabController.addListener(_onTabChanged);
    
    // Initialize notifications in post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationsController.requestPermissionIfNeeded();
      notificationsController.debugCheckTokenStorage();
    });
    
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onTabChanged() {
    // Only rebuild if mounted and tab actually changed
    if (mounted) {
      setState(() {});
    }
  }

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus && !_isSearchExpanded) {
      setState(() {
        _isSearchExpanded = true;
      });
    }
  }

  void _onSearchChanged(String text) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showSearchResults = text.isNotEmpty;
        });
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showSearchResults = false;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _cancelSearch() {
    setState(() {
      _searchController.clear();
      _showSearchResults = false;
      _isSearchExpanded = false;
      _searchFocusNode.unfocus();
    });
  }

  void _toggleSearchExpansion() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
        _showSearchResults = false;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  Widget _buildImageWithShimmer({
    required String imageUrl,
    required double width,
    required double height,
    required double borderRadius,
    required IconData icon,
    bool isNetworkImage = true,
    Map<String, String>? headers,
  }) {
    final isDarkMode = _themeController.isDarkMode.value;

    if (imageUrl.isEmpty) {
      return _buildPlaceholder(
        isDarkMode,
        width,
        height,
        borderRadius,
        icon,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        httpHeaders: headers,
        memCacheWidth: width.toInt(),
        memCacheHeight: height.toInt(),
        maxWidthDiskCache: width.toInt(),
        maxHeightDiskCache: height.toInt(),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300,
          child: Center(
            child: SizedBox(
              width: width * 0.3,
              height: height * 0.3,
              child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  _themeController.primaryColorValue,
                ),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300,
          ),
          child: Icon(
            icon,
            size: width * 0.4,
            color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    bool isDarkMode,
    double width,
    double height,
    double borderRadius,
    IconData icon,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey300,
      ),
      child: Icon(
        icon,
        size: width * 0.4,
        color: isDarkMode ? MangoPalette.grey500 : MangoPalette.grey600,
      ),
    );
  }

  Future<bool> _checkImageUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Obx(() {
      final isDarkMode = _themeController.isDarkMode.value;
      
      return Scaffold(
        backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
        body: Column(
          children: [
            _buildSearchHeader(),
            Expanded(
              child: _showSearchResults
                  ? _buildSearchResults()
                  : _isSearchExpanded
                  ? _buildTrendingContent()
                  : _buildMainContent(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSearchHeader() {
    final themeController = ThemeController.to;

    return Obx(() {
      return Container(
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        padding: const EdgeInsets.only(top: 33),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _showSearchResults
              ? 53
              : _isSearchExpanded
              ? 100
              : 53,
          child: Card(
            elevation: 2,
            shadowColor: MangoPalette.black.withOpacity(0.1),
            color: themeController.isDarkMode.value
                ? MangoPalette.black
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_isSearchExpanded ? 16 : 25),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 35,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeController.isDarkMode.value
                                  ? Colors.white
                                  : MangoPalette.black,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search music, books, podcasts...",
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: themeController.isDarkMode.value
                                    ? MangoPalette.grey500
                                    : MangoPalette.grey500,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              isDense: true,
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
        tooltip: 'Clear',
                                      icon: Icon(
                                        Icons.clear,
                                        size: 16,
                                        color: themeController.isDarkMode.value
                                            ? Colors.white
                                            : MangoPalette.black,
                                      ),
                                      onPressed: _clearSearch,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        _buildSmartSearchButton(),
                      ],
                    ),
                  ),
                  if (_isSearchExpanded && !_showSearchResults)
                    _buildCompactTrendingSuggestions(),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSmartSearchButton() {
    final themeController = ThemeController.to;

    return Obx(() {
      switch (_currentSearchState) {
        case SearchState.collapsed:
          return IconButton(
        tooltip: 'Search',
            icon: Icon(
              Icons.search,
              size: 18,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            onPressed: _toggleSearchExpansion,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          );
        case SearchState.expandedNoResults:
        case SearchState.results:
          return IconButton(
        tooltip: 'Close',
            icon: Icon(
              Icons.close,
              size: 18,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            onPressed: _cancelSearch,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          );
      }
    });
  }

  Widget _buildCompactTrendingSuggestions() {
    final themeController = ThemeController.to;

    return Obx(() {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Trending Now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeController.isDarkMode.value
                        ? MangoPalette.grey500
                        : MangoPalette.grey500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CompactTrendingChip(label: 'Afrobeats 2024'),
                    _CompactTrendingChip(label: 'Tech Spaces'),
                    _CompactTrendingChip(label: 'Business Books'),
                    _CompactTrendingChip(label: 'Comedy Podcasts'),
                    _CompactTrendingChip(label: 'Nollywood Movies'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTrendingContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactTrendingSection(
            title: 'Trending Music',
            icon: Icons.music_note,
            content: _buildCompactTrendingMusic(),
          ),
          _buildCompactTrendingSection(
            title: 'Trending Books',
            icon: Icons.menu_book,
            content: _buildCompactTrendingBooks(),
          ),
          _buildCompactTrendingSection(
            title: 'Trending Podcasts',
            icon: Icons.podcasts,
            content: _buildCompactTrendingPodcasts(),
          ),
          _buildCompactTrendingSection(
            title: 'Trending Movies',
            icon: Icons.movie,
            content: _buildCompactTrendingMovies(),
          ),
          _buildCompactTrendingSection(
            title: 'Trending Spaces',
            icon: Icons.people,
            content: _buildCompactTrendingSpaces(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTrendingSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    final themeController = ThemeController.to;

    return Obx(() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey600,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      );
    });
  }

  Widget _buildCompactTrendingMusic() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<Music>>(
      stream: controller.getTrendingMusic(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 60,
            width: 60,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No trending music",
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var music = snapshot.data!.take(5).toList();
        return SizedBox(
          height: 80,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            itemCount: music.length,
            itemBuilder: (context, index) {
              var track = music[index];
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    _buildImageWithShimmer(
                      imageUrl: track.artworkUrl,
                      width: 50,
                      height: 50,
                      borderRadius: 6,
                      icon: Icons.music_note,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompactTrendingBooks() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoBooks>>(
      stream: controller.getBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 90,
            width: 60,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No trending books",
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var books = snapshot.data!.take(5).toList();
        return SizedBox(
          height: 110,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              var book = books[index];
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    _buildImageWithShimmer(
                      imageUrl: book.coverUrl,
                      width: 50,
                      height: 70,
                      borderRadius: 3,
                      icon: Icons.menu_book,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompactTrendingPodcasts() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoPlaylist>>(
      stream: controller.getPlaylists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 40,
            width: 40,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No trending podcasts",
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var podcasts = snapshot.data!.take(3).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: podcasts
              .map(
                (podcast) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: _buildImageWithShimmer(
                    imageUrl: podcast.image,
                    width: 35,
                    height: 35,
                    borderRadius: 6,
                    icon: Icons.podcasts,
                  ),
                  title: Text(
                    podcast.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeController.isDarkMode.value
                          ? Colors.white
                          : MangoPalette.black,
                    ),
                  ),
                  subtitle: Text(
                    podcast.artiste,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeController.isDarkMode.value
                          ? MangoPalette.grey500
                          : MangoPalette.grey500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.play_arrow,
                    size: 14,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCompactTrendingMovies() {
    final themeController = ThemeController.to;

    return SizedBox(
      height: 100,
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                _buildImageWithShimmer(
                  imageUrl: 'https://picsum.photos/200/300',
                  width: 50,
                  height: 70,
                  borderRadius: 3,
                  icon: Icons.movie,
                ),
                const SizedBox(height: 2),
                Text(
                  'Movie ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactTrendingSpaces() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<SpaceModel>>(
      stream: spaceController.fetchGeneralSpaces(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 60,
            width: 180,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No trending spaces",
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var spaces = snapshot.data!.take(2).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: spaces
              .map(
                (space) => Card(
                  color: themeController.isDarkMode.value
                      ? MangoPalette.black
                      : Colors.white,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    leading: _buildImageWithShimmer(
                      imageUrl: space.image,
                      width: 35,
                      height: 35,
                      borderRadius: 6,
                      icon: Icons.people,
                      isNetworkImage: space.image.isNotEmpty,
                    ),
                    title: Text(
                      space.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                    ),
                    subtitle: Text(
                      '${space.members} members • ${space.category}',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey500
                            : MangoPalette.grey500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: themeController.isDarkMode.value
                          ? Colors.white
                          : MangoPalette.black,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.zero,
          child: TabBar(
            padding: EdgeInsets.zero,
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: ThemeController.to.primaryColorValue,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              _buildSearchTab("All", 0),
              _buildSearchTab("Users", 1),
              _buildSearchTab("Posts", 2),
              _buildSearchTab("Music", 3),
              _buildSearchTab("Books", 4),
              _buildSearchTab("Podcasts", 5),
              _buildSearchTab("Spaces", 6),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGlobalSearchResults(),
              _buildUserSearchResults(),
              _buildPostSearchResults(),
              _buildMusicSearchResults(),
              _buildBookSearchResults(),
              _buildPodcastSearchResults(),
              _buildSpaceSearchResults(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(String label, int index) {
    final themeController = ThemeController.to;

    return Obx(() {
      return Tab(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _tabController.index == index
                ? themeController.primaryColorValue
                : themeController.isDarkMode.value
                ? MangoPalette.grey500
                : MangoPalette.grey500,
          ),
        ),
      );
    });
  }

  Widget _buildGlobalSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoPost>>(
      stream: controller.searchPosts(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No results found for '${_searchController.text}'",
          );
        }

        var posts = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var post = posts[index];
            return _buildSearchPostItem(post);
          },
        );
      },
    );
  }

  Widget _buildUserSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoUser>>(
      stream: controller.searchUsers(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No users found for '${_searchController.text}'",
          );
        }

        var users = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user.profileImage),
              ),
              title: Text(
                user.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              subtitle: Text(
                '@${user.username}',
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
              trailing: Icon(
                Icons.person,
                size: 16,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              onTap: () {
                Get.to(() => ProfilePage(id: user.id));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPostSearchResults() {
    return StreamBuilder<List<MangoPost>>(
      stream: controller.searchPosts(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No posts found for '${_searchController.text}'",
          );
        }

        var posts = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            var post = posts[index];
            return _buildSearchPostItem(post);
          },
        );
      },
    );
  }

  Widget _buildMusicSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<Music>>(
      stream: controller.searchMusic(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No music found for '${_searchController.text}'",
          );
        }

        var music = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: music.length,
          itemBuilder: (context, index) {
            var track = music[index];
            return ListTile(
              leading: _buildImageWithShimmer(
                imageUrl: track.artworkUrl,
                width: 40,
                height: 40,
                borderRadius: 6,
                icon: Icons.music_note,
              ),
              title: Text(
                track.title,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              subtitle: Text(
                track.artistName,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
              trailing: Icon(
                Icons.play_arrow,
                size: 16,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicPlayer(musicId: track.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoBooks>>(
      stream: controller.searchBooks(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No books found for '${_searchController.text}'",
          );
        }

        var books = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: books.length,
          itemBuilder: (context, index) {
            var book = books[index];
            return ListTile(
              leading: _buildImageWithShimmer(
                imageUrl: book.coverUrl,
                width: 30,
                height: 45,
                borderRadius: 4,
                icon: Icons.menu_book,
              ),
              title: Text(
                book.title,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              subtitle: Text(
                book.author,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
              trailing: Icon(
                Icons.menu_book,
                size: 16,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              onTap: () {
                Get.to(() => FullScreenBookPage(book: book));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPodcastSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<MangoPlaylist>>(
      stream: controller.searchPodcasts(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No podcasts found for '${_searchController.text}'",
          );
        }

        var podcasts = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: podcasts.length,
          itemBuilder: (context, index) {
            var podcast = podcasts[index];
            return ListTile(
              leading: _buildImageWithShimmer(
                imageUrl: podcast.image,
                width: 40,
                height: 40,
                borderRadius: 6,
                icon: Icons.podcasts,
              ),
              title: Text(
                podcast.title,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              subtitle: Text(
                podcast.artiste,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
              trailing: Icon(
                Icons.podcasts,
                size: 16,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicPlayer(musicId: podcast.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSpaceSearchResults() {
    final themeController = ThemeController.to;

    return StreamBuilder<List<SpaceModel>>(
      stream: spaceController.searchSpaces(_searchController.text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSearchLoading();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoResults(
            "No spaces found for '${_searchController.text}'",
          );
        }

        var spaces = snapshot.data!;
        return OptimizedListView(
          padding: const EdgeInsets.all(8),
          itemCount: spaces.length,
          itemBuilder: (context, index) {
            var space = spaces[index];
            return ListTile(
              leading: _buildImageWithShimmer(
                imageUrl: space.image,
                width: 40,
                height: 40,
                borderRadius: 6,
                icon: Icons.people,
                isNetworkImage: space.image.isNotEmpty,
              ),
              title: Text(
                space.title,
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              subtitle: Text(
                '${space.members} members • ${space.category}',
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              onTap: () {
                Get.to(
                  () => SpaceDetailScreen(space),
                  arguments: {'id': space.id},
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchPostItem(MangoPost post) {
    final themeController = ThemeController.to;

    return FutureBuilder<MangoUser>(
      future: _getUserInfo(post.postCreator),
      builder: (context, userSnapshot) {
        return Card(
          color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userSnapshot.hasData)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(
                          userSnapshot.data!.profileImage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userSnapshot.data!.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeController.isDarkMode.value
                              ? Colors.white
                              : MangoPalette.black,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  post.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  timeAgo(post.timeStamp!.toDate()),
                  style: TextStyle(
                    fontSize: 12,
                    color: themeController.isDarkMode.value
                        ? MangoPalette.grey500
                        : MangoPalette.grey500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchLoading() {
    final themeController = ThemeController.to;

    return OptimizedListView(
      padding: const EdgeInsets.all(8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeController.isDarkMode.value
                        ? MangoPalette.grey800
                        : MangoPalette.grey300,
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 10,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey800
                            : MangoPalette.grey300,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 100,
                        height: 8,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey800
                            : MangoPalette.grey300,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoResults(String message) {
    final themeController = ThemeController.to;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey600
                : MangoPalette.grey400,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<MangoUser> _getUserInfo(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return MangoUser.fromMap(doc.data()!);
  }

  Widget _buildMainContent() {
    final themeController = ThemeController.to;

    return Obx(() {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: themeController.isDarkMode.value
                    ? MangoPalette.black
                    : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20),
                  _buildSectionHeader('How far na?'),
                  _buildHitListSection(),
                  _buildHotNewMusicSection(),
                  _buildTop10Section(),

                  // _buildTrendingNowSection(),
                  _buildTopShelfSection(),
                  _buildFreshlyMintedSection(),
                  _buildTrendingBooksSection(),
                  _buildTop10BooksSection(),
                  // _buildAwardWinningSection(),
                  // _buildMangoExclusivesSection(),
                  // _buildBookGenreSections(),
                  // _buildSectionWithSeeAll(
                  //   'Hot new music',
                  //   onSeeAll: () => Get.toNamed('/music-home'),
                  //   content: _buildPlaylistSection(),
                  // ),
                  // _buildSectionWithSeeAll(
                  //   'Top Shelf',
                  //   onSeeAll: () => Get.toNamed('/library-home'),
                  //   content: _buildBooksSection(),
                  // ),
                  // _buildSectionWithSeeAll(
                  //   'Freshly Minted',
                  //   onSeeAll: () => Get.toNamed('/library-home'),
                  //   content: _buildBooksSection(),
                  // ),
                  // _buildSectionHeader('Podcasts 🎙️'),
                  // _buildTrendingPodcastsSection(),
                  _buildNewPodcastsSection(),
                  // _buildTopPodcastsSection(),
                  // _buildPopularEpisodesSection(),
                  // _buildMangoExclusivePodcastsSection(),
                  // _buildShortFormPodcastsSection(),
                  // _buildRecentlyPlayedPodcastsSection(),
                  // _buildPodcastCategoriesSection(),
                  _buildSectionWithSeeAll(
                    'Discover Spaces',
                    onSeeAll: () {},
                    content: _buildSpacesSection(),
                  ),
                  // _buildSectionWithSeeAll(
                  //   'Podcasts',
                  //   onSeeAll: () => Get.toNamed('/music-music'),
                  //   content: _buildRecentPlayedSection(),
                  // ),
                  _buildProductsSection(),
                  SizedBox(height: 10),
                  _buildMarketplaceSection(),
                  // _buildSectionWithSeeAll(
                  //   'Hot 100',
                  //   onSeeAll: () => Get.toNamed('/music-music'),
                  //   content: _buildRecentPlayedSection(),
                  // ),
                  // _buildSectionWithSeeAll(
                  //   'Reading habit',
                  //   onSeeAll: () => Get.toNamed('/library-home'),
                  //   content: _buildBooksSection(),
                  // ),
                  _buildSectionWithSeeAll(
                    'You\'re going Spaces',
                    onSeeAll: () {},
                    content: _buildYourSpacesSection(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    final themeController = ThemeController.to;

    return Obx(() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 24,
            color: themeController.isDarkMode.value
                ? Colors.white
                : MangoPalette.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    });
  }

  Widget _buildSectionWithSeeAll(
    String title, {
    required VoidCallback onSeeAll,
    required Widget content,
  }) {
    final themeController = ThemeController.to;

    return Obx(() {
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
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                MangoPressable(
        semanticLabel: 'Next',
                  onTap: onSeeAll,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          content,
        ],
      );
    });
  }

  Widget _buildHitListSection() {
    return _buildSectionWithSeeAll(
      'Hit List',
      onSeeAll: () => Get.toNamed('/music-home'),
      content: StreamBuilder<List<Music>>(
        stream: controller.getHitList(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 180,
              width: 160,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyMusicSection('No trending music yet');
          }
          var music = snapshot.data!;
          return Container(
            height: 180,
            child: OptimizedListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: music.length,
              itemBuilder: (context, index) {
                var track = music[index];
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: _buildHitListCard(track, index + 1),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHotNewMusicSection() {
    return _buildSectionWithSeeAll(
      'Hot New Music',
      onSeeAll: () => Get.toNamed('/music-home'),
      content: StreamBuilder<List<Music>>(
        stream: controller.getHotNewMusic(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 160,
              width: 140,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyMusicSection('No new releases');
          }
          var music = snapshot.data!;
          return Container(
            padding: EdgeInsets.only(left: 10),
            height: 160,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: music.length,
              itemBuilder: (context, index) {
                var track = music[index];
                return _buildNewMusicCard(track);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTop10Section() {
    return _buildSectionWithSeeAll(
      'Top 10 Now',
      onSeeAll: () => Get.toNamed('/music-home'),
      content: StreamBuilder<List<Music>>(
        stream: controller.getTop10Songs(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 220,
              width: double.infinity,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyMusicSection('No top songs yet');
          }
          var music = snapshot.data!;

          List<Music> reorderedMusic = [];
          int halfLength = (music.length / 2).ceil();

          for (int i = 0; i < halfLength; i++) {
            reorderedMusic.add(music[i]);
            if (i + halfLength < music.length) {
              reorderedMusic.add(music[i + halfLength]);
            }
          }

          return OptimizedGridView(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 6 / 2,
            ),
            itemCount: reorderedMusic.length,
            itemBuilder: (context, index) {
              int originalRank;
              if (index.isEven) {
                originalRank = (index ~/ 2) + 1;
              } else {
                originalRank = (index ~/ 2) + 1 + halfLength;
              }

              var track = reorderedMusic[index];
              return _buildTop10Item(track, originalRank);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorSection(String message) {
    final themeController = ThemeController.to;

    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey600
                  : MangoPalette.grey400,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                controller.updateGenreStats();
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHitListCard(Music track, int rank) {
    final themeController = ThemeController.to;

    return MangoPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayer(musicId: track.id),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildImageWithShimmer(
                  imageUrl: track.artworkUrl,
                  width: 140,
                  height: 140,
                  borderRadius: 5,
                  icon: Icons.music_note,
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
                      '#$rank',
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
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: Text(
                      playValue(track.plays),
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
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              track.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              track.artistName,
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewMusicCard(Music track) {
    final themeController = ThemeController.to;

    return MangoPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayer(musicId: track.id),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildImageWithShimmer(
                  imageUrl: track.artworkUrl,
                  width: 120,
                  height: 120,
                  borderRadius: 8,
                  icon: Icons.music_note,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(MangoRadius.xs),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              track.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              track.artistName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.black,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop10Item(Music track, int rank) {
    final themeController = ThemeController.to;

    return MangoPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayer(musicId: track.id),
          ),
        );
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 20, right: 16),
        decoration: BoxDecoration(
          color: themeController.isDarkMode.value
              ? MangoPalette.grey800
              : MangoPalette.grey300,
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 7,
                    color: themeController.isDarkMode.value
                        ? MangoPalette.grey500
                        : MangoPalette.grey500,
                  ),
                  Text(
                    playValue(track.plays),
                    style: TextStyle(
                      fontSize: 12,
                      color: themeController.isDarkMode.value
                          ? MangoPalette.grey500
                          : MangoPalette.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: AlignmentDirectional.center,
                  children: [
                    Positioned(
                      left: -20,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: rank <= 5
                              ? themeController.primaryColorValue
                              : MangoPalette.grey500,
                        ),
                      ),
                    ),
                    _buildImageWithShimmer(
                      imageUrl: track.artworkUrl,
                      width: 40,
                      height: 40,
                      borderRadius: 2,
                      icon: Icons.music_note,
                    ),
                  ],
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: themeController.isDarkMode.value
                              ? Colors.white
                              : MangoPalette.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artistName,
                        style: TextStyle(
                          fontSize: 12,
                          color: themeController.isDarkMode.value
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopShelfSection() {
    return _buildSectionWithSeeAll(
      'Top Shelf',
      onSeeAll: () => Get.toNamed('/library-home'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getTopShelfBooks(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 240,
              width: 160,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No top books yet');
          }
          var books = snapshot.data!;
          return Container(
            height: 240,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return MangoLibraryList(book: book);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFreshlyMintedSection() {
    return _buildSectionWithSeeAll(
      'Freshly Minted',
      onSeeAll: () => Get.toNamed('/library-home'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getFreshlyMintedBooks(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 220,
              width: 140,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No new books');
          }
          var books = snapshot.data!;
          return Container(
            height: 220,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return _buildNewReleaseCard(book);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingBooksSection() {
    return _buildSectionWithSeeAll(
      'Trending Now 📈',
      onSeeAll: () => Get.toNamed('/library-trending'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getTrendingBooks(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 180,
              width: 300,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No trending books');
          }
          var books = snapshot.data!;
          return Container(
            height: 220,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return FrostedGlassWithTextAndImage(book: book);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTop10BooksSection() {
    return _buildSectionWithSeeAll(
      'Top 10 Bestsellers',
      onSeeAll: () => Get.toNamed('/library-bestsellers'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getTop10Books(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 280,
              width: double.infinity,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No bestsellers yet');
          }
          var books = snapshot.data!;

          List<MangoBooks> reorderedbooks = [];
          int halfLength = (books.length / 2).ceil();

          for (int i = 0; i < halfLength; i++) {
            reorderedbooks.add(books[i]);
            if (i + halfLength < books.length) {
              reorderedbooks.add(books[i + halfLength]);
            }
          }

          return OptimizedGridView(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 6 / 2,
            ),
            itemCount: reorderedbooks.length,
            itemBuilder: (context, index) {
              int originalRank;
              if (index.isEven) {
                originalRank = (index ~/ 2) + 1;
              } else {
                originalRank = (index ~/ 2) + 1 + halfLength;
              }

              var book = reorderedbooks[index];
              return _buildTop10BookItem(book, originalRank);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookGenreSections() {
    return Column(
      children: [
        _buildBookGenreSection('Business', '💼 Business & Career'),
        _buildBookGenreSection('Fiction', '📖 Fiction Bestsellers'),
        _buildBookGenreSection('African', '🌍 African Authors'),
        _buildBookGenreSection('Short-Read', '⚡ Short Reads'),
      ],
    );
  }

  Widget _buildBookGenreSection(String genre, String title) {
    return _buildSectionWithSeeAll(
      title,
      onSeeAll: () => Get.toNamed('/library-genre', arguments: genre),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getBooksByGenre(genre),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 200,
              width: 130,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return SizedBox.shrink();
          }
          var books = snapshot.data!;
          return Container(
            height: 200,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return _buildGenreBookCard(book, genre);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAwardWinningSection() {
    return _buildSectionWithSeeAll(
      '🏆 Award Winners',
      onSeeAll: () => Get.toNamed('/library-awards'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getAwardWinningBooks(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 240,
              width: 160,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No award winners');
          }
          var books = snapshot.data!;
          return Container(
            height: 240,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return MangoLibraryList(book: book);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangoExclusivesSection() {
    return _buildSectionWithSeeAll(
      '🥭 Mango Exclusives',
      onSeeAll: () => Get.toNamed('/library-exclusives'),
      content: StreamBuilder<List<MangoBooks>>(
        stream: controller.getMangoExclusiveBooks(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 240,
              width: 160,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyBookSection('No exclusives yet');
          }
          var books = snapshot.data!;
          return Container(
            height: 240,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                var book = books[index];
                return MangoLibraryList(book: book);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopShelfCard(MangoBooks book) {
    final themeController = ThemeController.to;

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildImageWithShimmer(
                imageUrl: book.coverUrl,
                width: 140,
                height: 180,
                borderRadius: 8,
                icon: Icons.menu_book,
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeController.primaryColorValue,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text(
                    'BESTSELLER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            book.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            book.author,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.star, size: 12, color: Colors.amber),
              SizedBox(width: 2),
              Text(
                '4.8',
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey600,
                ),
              ),
              Spacer(),
              Text(
                '${book.reads} reads',
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewReleaseCard(MangoBooks book) {
    final themeController = ThemeController.to;

    return Container(
      padding: EdgeInsets.only(left: 10),
      width: 105,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildImageWithShimmer(
                imageUrl: book.coverUrl,
                width: 100,
                height: 150,
                borderRadius: 6,
                icon: Icons.menu_book,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              book.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1,
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
              maxLines: 2,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 2),
          Text(
            book.author,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingBookCard(MangoBooks book) {
    final themeController = ThemeController.to;

    return Container(
      width: 300,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: _buildImageWithShimmer(
                  imageUrl: book.coverUrl,
                  width: 80,
                  height: 120,
                  borderRadius: 0,
                  icon: Icons.menu_book,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'TRENDING',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey500
                            : MangoPalette.grey600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 12,
                          color: themeController.isDarkMode.value
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${book.reads} reads',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeController.isDarkMode.value
                                ? MangoPalette.grey500
                                : MangoPalette.grey500,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: themeController.primaryColorValue
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(MangoRadius.md),
                          ),
                          child: Text(
                            'Read Now',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeController.primaryColorValue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTop10BookItem(MangoBooks book, int rank) {
    final themeController = ThemeController.to;

    return MangoPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenBookPage(book: book),
          ),
        );
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 20, right: 16),
        decoration: BoxDecoration(
          color: themeController.isDarkMode.value
              ? MangoPalette.grey800
              : MangoPalette.grey300,
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 7,
                    color: themeController.isDarkMode.value
                        ? MangoPalette.grey500
                        : MangoPalette.grey500,
                  ),
                  Text(
                    '${book.reads} reads',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeController.isDarkMode.value
                          ? MangoPalette.grey500
                          : MangoPalette.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: AlignmentDirectional.center,
                  children: [
                    Positioned(
                      left: -20,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: rank <= 5
                              ? themeController.primaryColorValue
                              : MangoPalette.grey500,
                        ),
                      ),
                    ),
                    _buildImageWithShimmer(
                      imageUrl: book.coverUrl,
                      width: 30,
                      height: 60,
                      borderRadius: 2,
                      icon: Icons.menu_book,
                    ),
                  ],
                ),

                const SizedBox(width: 5),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        book.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: themeController.isDarkMode.value
                              ? Colors.white
                              : MangoPalette.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        book.author == '' ? 'Unknown Author' : book.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: themeController.isDarkMode.value
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreBookCard(MangoBooks book, String genre) {
    final themeController = ThemeController.to;

    final genreStyles = {
      'Business': {'color': Colors.blue, 'emoji': '💼'},
      'Fiction': {'color': Colors.purple, 'emoji': '📖'},
      'African': {'color': MangoPalette.green500, 'emoji': '🌍'},
      'Short-Read': {'color': MangoPalette.green500, 'emoji': '⚡'},
    };

    final style = genreStyles[genre] ?? {'color': MangoPalette.grey500, 'emoji': '📚'};
    final color = style['color'] as Color;
    final emoji = style['emoji'] as String;

    return Container(
      width: 130,
      margin: EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                _buildImageWithShimmer(
                  imageUrl: book.coverUrl,
                  width: 100,
                  height: 140,
                  borderRadius: 6,
                  icon: Icons.menu_book,
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(MangoRadius.xs),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            book.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            book.author,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAwardWinningCard(MangoBooks book) {
    final themeController = ThemeController.to;

    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.amber[100]!, Colors.amber[50]!],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                    child: _buildImageWithShimmer(
                      imageUrl: book.coverUrl,
                      width: 104,
                      height: 144,
                      borderRadius: 4,
                      icon: Icons.menu_book,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.workspace_premium,
                  size: 20,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(MangoRadius.xs),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Text(
              'AWARD WINNER',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            book.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveBookCard(MangoBooks book) {
    final themeController = ThemeController.to;

    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  border: Border.all(
                    color: themeController.primaryColorValue,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MangoRadius.xs),
                  child: _buildImageWithShimmer(
                    imageUrl: book.coverUrl,
                    width: 100,
                    height: 130,
                    borderRadius: 4,
                    icon: Icons.menu_book,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeController.primaryColorValue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text('🥭', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'EXCLUSIVE',
            style: TextStyle(
              fontSize: 12,
              color: themeController.primaryColorValue,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            book.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBookSection(String message) {
    final themeController = ThemeController.to;

    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 32,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey400,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreCard(MangoPlaylist playlist, String genre) {
    final themeController = ThemeController.to;

    final genreColors = {
      'Afrobeats': MangoPalette.green500,
      'Hip Hop': Colors.purple,
      'Chill': Colors.blue,
      'Jazz': Colors.brown,
      'Pop': Colors.pink,
    };

    final color = genreColors[genre] ?? MangoPalette.grey500;

    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              image: DecorationImage(
                image: NetworkImage(playlist.image),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: color.withOpacity(0.6), width: 2),
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.xs),
            ),
            child: Text(
              genre,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            playlist.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingNowSection() {
    return _buildSectionWithSeeAll(
      'Trending Now',
      onSeeAll: () => Get.toNamed('/music-trending'),
      content: StreamBuilder<List<Music>>(
        stream: controller.getTrendingNow(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 200,
              width: 200,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyMusicSection('Nothing trending yet');
          }
          var playlists = snapshot.data!;
          return Container(
            height: 200,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                return _buildTrendingCard(playlists[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingCard(Music playlist) {
    return MangoPressable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MusicPlayer(musicId: playlist.id),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                  image: DecorationImage(
                    image: NetworkImage(playlist.artworkUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [MangoPalette.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      playlist.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      playlist.artistName.isEmpty
                          ? 'Unknown Artiste'
                          : playlist.artistName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          size: 10,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          playValue(playlist.plays),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
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
    );
  }

  Widget _buildEmptyMusicSection(String message) {
    final themeController = ThemeController.to;

    return Container(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 32,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey400,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSection() {
    return StreamBuilder<List<Music>>(
      stream: controller.getMusic(),
      builder: (context, snapshot) {
        final themeController = ThemeController.to;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 150,
            width: 150,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No music available",
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var music = snapshot.data!;
        return Container(
          padding: const EdgeInsets.only(left: 14),
          height: 150,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            itemCount: music.length,
            itemBuilder: (context, index) {
              var track = music[index];
              return MangoPressable(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicPlayer(musicId: track.id),
                    ),
                  );
                },
                child: MusicCard(
                  music: track,
                  pressDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MusicPlayer(musicId: track.id),
                      ),
                    );
                  },
                  pressPlay: () {},
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBooksSection() {
    return StreamBuilder<List<MangoBooks>>(
      stream: controller.getBooks(),
      builder: (context, snapshot) {
        final themeController = ThemeController.to;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 210,
            width: 130,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No books available",
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var books = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
          child: SizedBox(
            height: 210,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                return MangoLibraryList(book: books[index]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpacesSection() {
    return StreamBuilder<List<SpaceModel>>(
      stream: spaceController.fetchAllSpaces(),
      builder: (context, snapshot) {
        final themeController = ThemeController.to;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 400,
            width: 300,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No spaces available",
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var spaces = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
          child: SizedBox(
            height: 400,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: spaces.length,
              itemBuilder: (context, index) {
                var space = spaces[index];
                return SpacesPortrait(space: space);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPlayedSection() {
    return StreamBuilder<List<Music>>(
      stream: controller.getRecentMusic(),
      builder: (context, snapshot) {
        final themeController = ThemeController.to;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 100,
            width: 100,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No recent music",
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var music = snapshot.data!;
        return Container(
          padding: const EdgeInsets.only(left: 14),
          height: 100,
          child: OptimizedListView(
            scrollDirection: Axis.horizontal,
            itemCount: music.length,
            itemBuilder: (context, index) {
              var track = music[index];
              return RecentPlayedCard(
                music: track,
                pressDetails: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicPlayer(musicId: track.id),
                    ),
                  );
                },
                pressPlay: () {},
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsSection() {
    final themeController = ThemeController.to;
    if (!Get.isRegistered<HomeProductController>()) {
      Get.put(HomeProductController());
    }
    final homeProductController = Get.find<HomeProductController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Shop Now",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
              ),
              MangoPressable(
                onTap: () {
                  Get.to(
                    () => MarketPlace(),
                    transition: Transition.rightToLeft,
                  );
                },
                child: Text(
                  "See All",
                  style: TextStyle(
                    fontSize: 13,
                    color: MangoPalette.green500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Products Grid
        StreamBuilder<List<MangoProductItem>>(
          stream: homeProductController.getAllProductsStream(),
          builder: (context, snapshot) {
            // Handle waiting state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildProductsGridShimmer();
            }

            // Handle errors
            if (snapshot.hasError) {
              final error = snapshot.error.toString();
              final isDarkMode = themeController.isDarkMode.value;

              // Missing index error - this is the most likely cause
              if (error.contains('FAILED_PRECONDITION') ||
                  error.contains('index')) {
                // Show a loading state instead of error while index is being created
                // This prevents the UI from looking broken
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProductsGridShimmer(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.build_circle,
                            size: 32,
                            color: isDarkMode
                                ? MangoPalette.grey400
                                : MangoPalette.grey600,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Preparing products...",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : MangoPalette.grey600,
                              fontSize: 13,
                            ),
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Create index: isActive Ascending, createdAt Descending",
                              style: TextStyle(
                                color: MangoPalette.green300,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Network error
              if (error.contains('UNAVAILABLE') || error.contains('network')) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 48,
                        color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No internet connection",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : MangoPalette.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // For other errors, show the shimmer as fallback
              return _buildProductsGridShimmer();
            }

            // Check if we have data
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Show empty state or shimmer while waiting for first data
              if (snapshot.connectionState == ConnectionState.active) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey600
                            : MangoPalette.grey400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No products yet",
                        style: TextStyle(
                          color: themeController.isDarkMode.value
                              ? Colors.white70
                              : MangoPalette.grey600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
              // Still waiting for first data
              return _buildProductsGridShimmer();
            }

            final products = snapshot.data!;
            final displayProducts = products
                .take(4)
                .toList(); // Show 4 products

            return OptimizedGridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                return _buildProductGridCard(
                  displayProducts[index],
                  homeProductController,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductGridCard(
    MangoProductItem product,
    HomeProductController controller,
  ) {
    final themeController = ThemeController.to;
    final isDarkMode = themeController.isDarkMode.value;

    return MangoPressable(
      onTap: () => controller.navigateToProductDetail(product),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey850 : Colors.white,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: product.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 140,
                            color: isDarkMode
                                ? MangoPalette.grey800
                                : MangoPalette.grey200,
                            child: const Center(
                              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 140,
                            color: isDarkMode
                                ? MangoPalette.grey800
                                : MangoPalette.grey200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDarkMode
                                  ? MangoPalette.grey600
                                  : MangoPalette.grey400,
                            ),
                          ),
                        )
                      : Container(
                          height: 140,
                          color: isDarkMode
                              ? MangoPalette.grey800
                              : MangoPalette.grey200,
                          child: Icon(
                            Icons.image,
                            color: isDarkMode
                                ? MangoPalette.grey600
                                : MangoPalette.grey400,
                          ),
                        ),
                ),
                // Sale Badge
                if (product.onSale)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(MangoRadius.xs),
                      ),
                      child: Text(
                        '-${((product.price - product.salePrice!) / product.price * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Out of Stock Badge
                if (!product.inStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: MangoPalette.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? MangoPalette.grey400
                              : MangoPalette.grey600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Row(
                    children: [
                      Text(
                        '₦${product.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: MangoPalette.green500,
                        ),
                      ),
                      if (product.onSale)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '₦${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? MangoPalette.grey500
                                  : MangoPalette.grey400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
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

  Widget _buildProductsGridShimmer() {
    final themeController = ThemeController.to;
    final isDarkMode = themeController.isDarkMode.value;

    return MangoShimmer(
      baseColor: isDarkMode ? MangoPalette.grey850 : MangoPalette.grey300,
      highlightColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey100,
      child: OptimizedGridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: isDarkMode ? MangoPalette.grey800 : Colors.white,
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceSection() {
    final MangoDashboardController dashboardController = Get.find();
    final themeController = ThemeController.to;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: dashboardController.getVendors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Marketplace",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                ),
              ),
              SizedBox(height: 12),
              HorizontalShimmerList(
                height: 280,
                width: 180,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey800
                    : MangoPalette.grey300,
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 8),
                Text(
                  "Error loading marketplace",
                  style: TextStyle(
                    color: themeController.isDarkMode.value
                        ? Colors.white
                        : MangoPalette.black,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 48,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey600
                      : MangoPalette.grey400,
                ),
                SizedBox(height: 8),
                Text(
                  "No vendors available",
                  style: TextStyle(
                    color: themeController.isDarkMode.value
                        ? Colors.white70
                        : MangoPalette.grey600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Check back later for new vendors",
                  style: TextStyle(
                    fontSize: 12,
                    color: themeController.isDarkMode.value
                        ? Colors.white54
                        : MangoPalette.grey500,
                  ),
                ),
              ],
            ),
          );
        }

        final vendors = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Marketplace",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeController.isDarkMode.value
                          ? Colors.white
                          : MangoPalette.black,
                    ),
                  ),
                  MangoPressable(
                    onTap: () {
                      Get.to(
                        () => VendorsListPage(),
                        transition: Transition.rightToLeft,
                      );
                    },
                    child: Text(
                      "See All",
                      style: TextStyle(
                        fontSize: 13,
                        color: MangoPalette.green500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: OptimizedListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: vendors.length > 10
                    ? 10
                    : vendors.length, // Limit to 10 for home screen
                itemBuilder: (context, index) {
                  return MarketplaceCard(vendor: vendors[index], index: index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYourSpacesSection() {
    return StreamBuilder<List<SpaceModel>>(
      stream: spaceController.fetchAllSpaces(),
      builder: (context, snapshot) {
        final themeController = ThemeController.to;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return HorizontalShimmerList(
            height: 200,
            width: 250,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No spaces available",
              style: TextStyle(
                color: themeController.isDarkMode.value
                    ? Colors.white
                    : MangoPalette.black,
              ),
            ),
          );
        }
        var spaces = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
          child: SizedBox(
            height: 200,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: spaces.length,
              itemBuilder: (context, index) {
                var space = spaces[index];
                return MangoPressable(
                  onTap: () {
                    Get.to(
                      () => SpaceDetailScreen(space),
                      arguments: {'id': space.id},
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Stack(
                      children: [
                        Container(
                          width: 250,
                          margin: const EdgeInsets.only(right: 10, top: 50),
                          padding: const EdgeInsets.only(left: 25, right: 20),
                          decoration: BoxDecoration(
                            color: themeController.isDarkMode.value
                                ? MangoPalette.grey800
                                : MangoPalette.grey200,
                            borderRadius: BorderRadius.circular(29),
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0, 10),
                                blurRadius: 33,
                                color: themeController.primaryColorValue
                                    .withOpacity(0.3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 80.0),
                                child: Text(
                                  space.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: themeController.isDarkMode.value
                                        ? Colors.white
                                        : themeController.primaryColorValue,
                                  ),
                                ),
                              ),
                              Text(
                                space.category,
                                style: TextStyle(
                                  color: themeController.isDarkMode.value
                                      ? Colors.white
                                      : themeController.primaryColorValue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SpaceItems(
                                    name: "Price",
                                    value: space.price.isEmpty
                                        ? "0"
                                        : space.price,
                                  ),
                                  SpaceItems(
                                    name: "Members",
                                    value: space.members.toString(),
                                  ),
                                  SpaceItems(
                                    name: "Category",
                                    value: space.category,
                                  ),
                                  SpaceItems(
                                    name: "Rating",
                                    value: space.rating.isEmpty
                                        ? "0"
                                        : space.rating,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 30,
                          child: Hero(
                            tag: space.image.isEmpty
                                ? "space_image"
                                : space.image,
                            child: space.image.isEmpty
                                ? Image.asset(
                                    "asset/images/space3.png",
                                    height: 115,
                                  )
                                : Image.asset(
                                    "asset/images/space3.png",
                                    height: 115,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingPodcastsSection() {
    return _buildSectionWithSeeAll(
      'Trending Podcasts 🔥',
      onSeeAll: () => Get.toNamed('/podcasts-trending'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getTrendingPodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 200,
              width: 280,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No trending podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 200,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildTrendingPodcastCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewPodcastsSection() {
    return _buildSectionWithSeeAll(
      'New Podcasts',
      onSeeAll: () => Get.toNamed('/podcasts-new'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getNewPodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 180,
              width: 150,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No new podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 180,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildNewPodcastCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopPodcastsSection() {
    return _buildSectionWithSeeAll(
      'Top Podcasts 🏆',
      onSeeAll: () => Get.toNamed('/podcasts-top'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getTopPodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 240,
              width: double.infinity,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No top podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 240,
            child: OptimizedListView(
              physics: NeverScrollableScrollPhysics(),
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildTopPodcastItem(podcast, index + 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularEpisodesSection() {
    return _buildSectionWithSeeAll(
      'Popular Episodes',
      onSeeAll: () => Get.toNamed('/podcasts-episodes'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getPopularEpisodes(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 160,
              width: 300,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No popular episodes');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 160,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildEpisodeCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPodcastCategoriesSection() {
    return Column(
      children: [
        _buildPodcastCategorySection('Comedy', '😂 Comedy'),
        _buildPodcastCategorySection('Business', '💼 Business & Money'),
        _buildPodcastCategorySection('True Crime', '🔍 True Crime'),
        _buildPodcastCategorySection('African', '🌍 African Stories'),
      ],
    );
  }

  Widget _buildPodcastCategorySection(String category, String title) {
    return _buildSectionWithSeeAll(
      title,
      onSeeAll: () => Get.toNamed('/podcasts-category', arguments: category),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getPodcastsByCategory(category),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 140,
              width: 120,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return SizedBox.shrink();
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 140,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildCategoryPodcastCard(podcast, category);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMangoExclusivePodcastsSection() {
    return _buildSectionWithSeeAll(
      '🥭 Mango Exclusives',
      onSeeAll: () => Get.toNamed('/podcasts-exclusives'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getMangoExclusivePodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 220,
              width: 160,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No exclusive podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 220,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildExclusivePodcastCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildShortFormPodcastsSection() {
    return _buildSectionWithSeeAll(
      '⚡ Bite-sized Podcasts',
      onSeeAll: () => Get.toNamed('/podcasts-short'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getShortFormPodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 180,
              width: 140,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No short podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 180,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildShortFormPodcastCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyPlayedPodcastsSection() {
    return _buildSectionWithSeeAll(
      'Continue Listening',
      onSeeAll: () => Get.toNamed('/podcasts-history'),
      content: StreamBuilder<List<MangoPlaylist>>(
        stream: controller.getRecentlyPlayedPodcasts(),
        builder: (context, snapshot) {
          final themeController = ThemeController.to;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return HorizontalShimmerList(
              height: 100,
              width: double.infinity,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey800
                  : MangoPalette.grey300,
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPodcastSection('No recent podcasts');
          }
          var podcasts = snapshot.data!;
          return Container(
            height: 100,
            child: OptimizedListView(
              scrollDirection: Axis.horizontal,
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                var podcast = podcasts[index];
                return _buildRecentlyPlayedPodcastCard(podcast);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingPodcastCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 16),
      child: Card(
        elevation: 4,
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                        ),
                        child: Text(
                          'TRENDING',
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
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      podcast.artiste,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey500
                            : MangoPalette.grey600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.headset,
                          size: 12,
                          color: themeController.isDarkMode.value
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${podcast.plays} listens',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeController.isDarkMode.value
                                ? MangoPalette.grey500
                                : MangoPalette.grey500,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: themeController.primaryColorValue
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(MangoRadius.md),
                          ),
                          child: Text(
                            podcast.genre,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeController.primaryColorValue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPodcastCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 150,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            podcast.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            podcast.artiste,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPodcastItem(MangoPlaylist podcast, int rank) {
    final themeController = ThemeController.to;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Card(
        elevation: 2,
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        child: ListTile(
          leading: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? themeController.primaryColorValue
                        : MangoPalette.grey500,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            podcast.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            podcast.artiste,
            style: TextStyle(
              fontSize: 12,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey500,
            ),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.headset,
                size: 16,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey500,
              ),
              Text(
                '${podcast.plays}',
                style: TextStyle(
                  fontSize: 12,
                  color: themeController.isDarkMode.value
                      ? MangoPalette.grey500
                      : MangoPalette.grey500,
                ),
              ),
            ],
          ),
          onTap: () {
            context.read<MusicPlayerState>().playTrack(podcast);
          },
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 300,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeController.primaryColorValue.withOpacity(
                          0.2,
                        ),
                        borderRadius: BorderRadius.circular(MangoRadius.xs),
                      ),
                      child: Text(
                        'POPULAR EPISODE',
                        style: TextStyle(
                          fontSize: 12,
                          color: themeController.primaryColorValue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      podcast.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      podcast.artiste,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey500
                            : MangoPalette.grey600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: themeController.isDarkMode.value
                              ? MangoPalette.grey500
                              : MangoPalette.grey500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '45 min',
                          style: TextStyle(
                            fontSize: 12,
                            color: themeController.isDarkMode.value
                                ? MangoPalette.grey500
                                : MangoPalette.grey500,
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: themeController.primaryColorValue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
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
    );
  }

  Widget _buildCategoryPodcastCard(MangoPlaylist podcast, String category) {
    final themeController = ThemeController.to;

    final categoryStyles = {
      'Comedy': {'color': MangoPalette.green500, 'emoji': '😂'},
      'Business': {'color': Colors.blue, 'emoji': '💼'},
      'True Crime': {'color': Colors.red, 'emoji': '🔍'},
      'African': {'color': MangoPalette.green500, 'emoji': '🌍'},
    };

    final style =
        categoryStyles[category] ?? {'color': Colors.purple, 'emoji': '🎙️'};
    final color = style['color'] as Color;
    final emoji = style['emoji'] as String;

    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              border: Border.all(color: color, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              child: Image.network(podcast.image, fit: BoxFit.cover),
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.xs),
            ),
            child: Text(emoji, style: TextStyle(fontSize: 12)),
          ),
          SizedBox(height: 4),
          Text(
            podcast.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExclusivePodcastCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      themeController.primaryColorValue.withOpacity(0.2),
                      themeController.primaryColorValue.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                    child: Image.network(podcast.image, fit: BoxFit.cover),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeController.primaryColorValue,
                    borderRadius: BorderRadius.circular(MangoRadius.xs),
                  ),
                  child: Text('🥭', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: themeController.primaryColorValue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(MangoRadius.xs),
              border: Border.all(
                color: themeController.primaryColorValue.withOpacity(0.3),
              ),
            ),
            child: Text(
              'EXCLUSIVE',
              style: TextStyle(
                fontSize: 12,
                color: themeController.primaryColorValue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            podcast.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShortFormPodcastCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MangoPalette.green500,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flash_on, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: MangoPalette.green50,
              borderRadius: BorderRadius.circular(MangoRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 10, color: MangoPalette.green500),
                SizedBox(width: 2),
                Text(
                  '15 min',
                  style: TextStyle(
                    fontSize: 12,
                    color: MangoPalette.green700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Text(
            podcast.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: themeController.isDarkMode.value
                  ? Colors.white
                  : MangoPalette.black,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayedPodcastCard(MangoPlaylist podcast) {
    final themeController = ThemeController.to;

    return Container(
      width: 200,
      margin: EdgeInsets.only(right: 8),
      child: Card(
        elevation: 2,
        color: themeController.isDarkMode.value ? MangoPalette.black : Colors.white,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MangoRadius.sm),
                  image: DecorationImage(
                    image: NetworkImage(podcast.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: themeController.isDarkMode.value
                            ? Colors.white
                            : MangoPalette.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      podcast.artiste,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeController.isDarkMode.value
                            ? MangoPalette.grey500
                            : MangoPalette.grey500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(semanticsLabel: 'Loading', 
                      value: 0.7,
                      backgroundColor: themeController.isDarkMode.value
                          ? MangoPalette.grey800
                          : MangoPalette.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        themeController.primaryColorValue,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              IconButton(
        tooltip: 'Play',
                icon: Icon(
                  Icons.play_arrow,
                  size: 20,
                  color: themeController.isDarkMode.value
                      ? Colors.white
                      : MangoPalette.black,
                ),
                onPressed: () {
                  context.read<MusicPlayerState>().playTrack(podcast);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPodcastSection(String message) {
    final themeController = ThemeController.to;

    return Container(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.podcasts,
              size: 32,
              color: themeController.isDarkMode.value
                  ? MangoPalette.grey500
                  : MangoPalette.grey400,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: themeController.isDarkMode.value
                    ? MangoPalette.grey500
                    : MangoPalette.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum SearchState { collapsed, expandedNoResults, results }

class FrostedGlassWithTextAndImage extends StatefulWidget {
  final MangoBooks book;
  FrostedGlassWithTextAndImage({super.key, required this.book});

  @override
  _FrostedGlassWithTextAndImageState createState() =>
      _FrostedGlassWithTextAndImageState();
}

class _FrostedGlassWithTextAndImageState
    extends State<FrostedGlassWithTextAndImage>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _shimmerController;
  late Timer _shimmerTimer;
  bool _isShimmering = false;

  void _openFullScreen(BuildContext context, MangoBooks book) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenBookPage(book: book),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeInOut;
          var scaleTween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var scaleAnimation = animation.drive(scaleTween);
          return ScaleTransition(scale: scaleAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shimmerTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _triggerShimmer();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerShimmer());
  }

  void _triggerShimmer() {
    setState(() {
      _isShimmering = true;
    });

    _shimmerController.forward().then((_) {
      _shimmerController.reset();
      Future.delayed(const Duration(milliseconds: 200), () {
        _shimmerController.forward().then((_) {
          setState(() {
            _isShimmering = false;
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.to;

    return Obx(() {
      return Container(
        padding: EdgeInsets.only(left: 10, right: 10),
        width: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: _isExpanded ? 200 : 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                color: themeController.isDarkMode.value
                    ? MangoPalette.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.3),
                border: Border.all(
                  color: themeController.isDarkMode.value
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                          width: 120,
                          margin: const EdgeInsets.only(bottom: 10.0),
                          child: Text(
                            "Mango Best Sellers\n16th March 2024",
                            style: TextStyle(
                              fontSize: 12,
                              color: themeController.isDarkMode.value
                                  ? MangoPalette.grey500
                                  : MangoPalette.grey500,
                            ),
                          ),
                        ),
                        Text(
                          widget.book.title,
                          style: TextStyle(
                            color: themeController.isDarkMode.value
                                ? Colors.white
                                : themeController.primaryColorValue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          widget.book.author,
                          style: TextStyle(
                            color: themeController.isDarkMode.value
                                ? Colors.white
                                : themeController.primaryColorValue,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MangoPressable(
                              onTap: () {
                                setState(() {
                                  _isExpanded = !_isExpanded;
                                });
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'tap card for more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeController.isDarkMode.value
                                          ? Colors.white.withOpacity(0.8)
                                          : MangoPalette.black.withOpacity(0.8),
                                    ),
                                  ),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: themeController.isDarkMode.value
                                        ? Colors.white.withOpacity(0.8)
                                        : MangoPalette.black.withOpacity(0.8),
                                    size: 9,
                                  ),
                                ],
                              ),
                            ),
                            if (_isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.book.description,
                                      maxLines: 2,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: themeController.isDarkMode.value
                                            ? Colors.white.withOpacity(0.6)
                                            : MangoPalette.black.withOpacity(0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    MangoPressable(
                                      onTap: () {
                                        _openFullScreen(context, widget.book);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              themeController.primaryColorValue,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                          horizontal: 5,
                                        ),
                                        child: Text(
                                          "read now",
                                          style: TextStyle(fontFamily: 'Poppins', 
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Container(
                          width: 150,
                          height: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MangoRadius.lg),
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
                            child: _buildImageWithShimmer(
                              imageUrl: widget.book.coverUrl,
                              width: 150,
                              height: 240,
                              borderRadius: 5,
                              icon: Icons.menu_book,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(MangoRadius.sm),
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.5),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                      begin: Alignment(
                                        -1.0 + 2.0 * _shimmerController.value,
                                        0.0,
                                      ),
                                      end: Alignment(
                                        1.0 + 2.0 * _shimmerController.value,
                                        0.0,
                                      ),
                                      tileMode: TileMode.clamp,
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.overlay,
                                  child: Container(
                                    color: _isShimmering
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.transparent,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

Widget _buildImageWithShimmer({
  required String imageUrl,
  required double width,
  required double height,
  required double borderRadius,
  required IconData icon,
  bool isNetworkImage = true,
}) {
  final themeController = ThemeController.to;

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          ),
          child: Center(
            child: SizedBox(
              width: width * 0.3,
              height: height * 0.3,
              child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  themeController.primaryColorValue,
                ),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: themeController.isDarkMode.value
                ? MangoPalette.grey800
                : MangoPalette.grey300,
          ),
          child: Icon(
            icon,
            size: width * 0.4,
            color: themeController.isDarkMode.value
                ? MangoPalette.grey500
                : MangoPalette.grey600,
          ),
        );
      },
    ),
  );
}

Future<bool> _checkImageUrl(String url) async {
  if (url.isEmpty) return false;
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    client.close();
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

class _CompactTrendingChip extends StatelessWidget {
  final String label;

  const _CompactTrendingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.to;

    return Obx(() {
      return Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: themeController.isDarkMode.value
              ? MangoPalette.grey800
              : MangoPalette.grey100,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: themeController.isDarkMode.value
                ? MangoPalette.grey700
                : MangoPalette.grey300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: themeController.isDarkMode.value
                ? Colors.white
                : Colors.black87,
          ),
        ),
      );
    });
  }
}
