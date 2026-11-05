import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Home/dashboard.dart';
import 'package:mango/Home/pages/genre_video_player.dart';
import 'package:mango/Models/customModel/mango_genres.dart';
import 'package:mango/Utils/text_highlighter.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class GenreVideoCarousel extends StatefulWidget {
  final List<MangoGenre> genres;

  const GenreVideoCarousel({Key? key, required this.genres}) : super(key: key);

  @override
  _GenreVideoCarouselState createState() => _GenreVideoCarouselState();
}

class _GenreVideoCarouselState extends State<GenreVideoCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  final Map<int, bool> _shouldLoadVideo = {};
  final Map<int, bool> _shouldPlayVideo = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _initializeVideoStates();
    _startAutoPlay();
  }

  void _initializeVideoStates() {
    
    for (int i = 0; i < widget.genres.length; i++) {
      _shouldLoadVideo[i] = i == 0; 
      _shouldPlayVideo[i] = i == 0; 
    }
  }

  void _updateVideoStates(int newPage) {
    setState(() {
      
      for (int i = 0; i < widget.genres.length; i++) {
        final shouldLoad = i == newPage;
        final shouldPlay = i == newPage;
        
        if (_shouldLoadVideo[i] != shouldLoad) {
          _shouldLoadVideo[i] = shouldLoad;
        }
        if (_shouldPlayVideo[i] != shouldPlay) {
          _shouldPlayVideo[i] = shouldPlay;
        }
      }
      _currentPage = newPage;
    });
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_pageController.hasClients && widget.genres.length > 1) {
        final nextPage = (_currentPage + 1) % widget.genres.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  void _restartAutoPlay() {
    _stopAutoPlay();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    
    for (int i = 0; i < widget.genres.length; i++) {
      _shouldLoadVideo[i] = false;
      _shouldPlayVideo[i] = false;
    }
    super.dispose();
  }

  Widget _buildGenreVideoCard(MangoGenre mood, int index) {
    final shouldLoad = _shouldLoadVideo[index] ?? false;
    final shouldPlay = _shouldPlayVideo[index] ?? false;
    
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
      child: Stack(
        children: [
          
          Container(
            width: 200,
            height: 450,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: mood.color.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              child: GenreVideoPlayer(
                key: ValueKey('${mood.id}_$index'),
                videoUrl: mood.videoUrl,
                thumbnailUrl: "https://images.unsplash.com/photo-1657632843433-e6a8b7451ac6?ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8d2FsbHBhcGVyJTIwNGt8ZW58MHx8MHx8fDA%3D&fm=jpg&q=60&w=3000",
                isPlaying: shouldPlay,
                shouldLoad: shouldLoad, 
              ),
            ),
          ),

          
          Container(
            width: 200,
            height: 450,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, MangoPalette.black.withOpacity(0.8)],
                stops: const [0.4, 1.0],
              ),
            ),
          ),

          
          Positioned(
            top: 16,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MangoPalette.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(mood.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    mood.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [MangoPalette.black.withOpacity(0.9), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    
                    HighlightedMultilineText(
                      text: mood.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),

                    
                    Text(
                      mood.description,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),

                    const SizedBox(height: 8),

                    
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: mood.genres.take(3).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: mood.color.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(MangoRadius.sm),
                            border: Border.all(color: mood.color.withOpacity(0.5), width: 0.5),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    
                    Text(
                      '${mood.songCount} songs • ${playValue(mood.totalPlays)} total plays',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        height: 1,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 5),
                    const Divider(color: Colors.white, thickness: 0.6),
                    const SizedBox(height: 4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        
                        MangoPressable(
                          onTap: () {
                            Get.toNamed('/mood/${mood.id}', arguments: {
                              'mood': mood,
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(MangoRadius.xs),
                              border: Border.all(
                                color: MangoPalette.black.withOpacity(0.1),
                              ),
                            ),
                            child: const Text(
                              'Explore Mood',
                              style: TextStyle(
                                color: MangoPalette.black,
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
                              '${mood.songCount} songs',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            _buildStatItem(
                              icon: Icons.play_arrow,
                              value: playValue(mood.totalPlays),
                              label: 'Plays',
                              color: mood.color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final viewportFraction = 200 / screenWidth;

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollStartNotification) {
              _stopAutoPlay();
            } else if (scrollNotification is ScrollEndNotification) {
              _restartAutoPlay();
            }
            return false;
          },
          child: PageView.builder(
            controller: PageController(viewportFraction: viewportFraction),
            onPageChanged: (index) {
              _updateVideoStates(index);
            },
            itemCount: widget.genres.length,
            itemBuilder: (context, index) {
              final genre = widget.genres[index];
              final isCurrentPage = index == _currentPage;
              return Container(
                margin: EdgeInsets.zero,
                width: 200,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  scale: isCurrentPage ? 1.0 : 0.9,
                  child: _buildGenreVideoCard(genre, index),
                ),
              );
            },
          ),
        );
      },
    );
  }
}