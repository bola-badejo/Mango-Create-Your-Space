
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Home/components/post_card.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/pages/levitating_icon.dart';
import 'package:mango/Home/pages/post_shimmer.dart';
import 'package:mango/Home/post_creation_box.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final MangoDashboardController controller = Get.find<MangoDashboardController>();
  final ThemeController themeController = Get.find<ThemeController>();
  final ScrollController _scrollController = ScrollController();
  final _scrollThreshold = 200.0;
  bool _isLoadingMore = false;
  bool _isInitialLoad = true;
  
  final _pageStorageKey = const PageStorageKey('feed_page');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitialData() async {
    if (controller.posts.isEmpty) {
      await controller.loadInitialPosts(context);
    }
    setState(() {
      _isInitialLoad = false;
    });
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    
    if (maxScroll - currentScroll <= _scrollThreshold && 
        !_isLoadingMore && 
        controller.hasMore.value &&
        !_isInitialLoad) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !controller.hasMore.value) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      await controller.loadMorePosts(context);
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    
    if (_isInitialLoad) return;
    
    try {
      await controller.refreshPosts(context);
    } catch (e) {
      print('Error refreshing posts: $e');
    }
  }

  void _onPostCreated() {
    _refreshPosts();
    
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDarkMode = themeController.isDarkMode.value;
      final scaffoldBackground = isDarkMode ? MangoPalette.black : Colors.white;
      final textColor = isDarkMode ? Colors.white : MangoPalette.black;
      
      return Scaffold(
        backgroundColor: scaffoldBackground,
        body: _isInitialLoad && controller.posts.isEmpty
            ? _buildInitialLoading(isDarkMode)
            : _buildContent(isDarkMode, textColor),
      );
    });
  }

  Widget _buildInitialLoading(bool isDarkMode) {
    return Container(
      color: isDarkMode ? MangoPalette.black : Colors.white,
      child: Column(
        children: List.generate(5, (index) => PostShimmer()),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, Color textColor) {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: themeController.primaryColorValue,
      backgroundColor: isDarkMode ? MangoPalette.black : Colors.white,
      child: CustomScrollView(
        key: _pageStorageKey,
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          
          SliverToBoxAdapter(
            child: PostCreationBox(onPostCreated: _onPostCreated),
          ),
          
          
          
          
          
          _buildPostsList(isDarkMode),
          
          
          _buildLoadingIndicator(isDarkMode, textColor),
          
          
          _buildEndOfListIndicator(isDarkMode, textColor),
        ],
      ),
    );
  }

  Widget _buildPostsList(bool isDarkMode) {
    return Obx(() {
      if (controller.posts.isEmpty && !controller.isLoading.value) {
        return SliverFillRemaining(
          child: Container(
            color: isDarkMode ? MangoPalette.black : Colors.white,
            child: const LevitatingIcon(),
          ),
        );
      }
      
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < controller.posts.length) {
              final post = controller.posts[index];
              return PostCard(
                key: ValueKey('post_${post.id}_${post.timeStamp}'),
                post: post,
              );
            }
            return null;
          },
          childCount: controller.posts.length,
        ),
      );
    });
  }

  Widget _buildLoadingIndicator(bool isDarkMode, Color textColor) {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _isLoadingMore ? 60.0 : 0.0,
        child: _isLoadingMore
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
                child: Center(
                  child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                    color: themeController.primaryColorValue,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildEndOfListIndicator(bool isDarkMode, Color textColor) {
    return Obx(() {
      if (!controller.hasMore.value && controller.posts.isNotEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No more posts',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    });
  }
}