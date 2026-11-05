// lib/MusicPlayer/music_player_page.dart
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/MusicPlayer/artwork_image.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/Media/core/play_queue.dart';
import 'package:mango/Media/ui/queue_sheet.dart';
import 'package:mango/MusicPlayer/lyrics_page.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Spaces/common/space_it.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class MusicPlayer extends StatefulWidget {
  final String musicId;
  final List<Music>? playlist;
  final int initialIndex;

  const MusicPlayer({
    super.key,
    required this.musicId,
    this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  final GlobalMusicController musicController = Get.find<GlobalMusicController>();
  Color? backgroundColor;
  
  @override
  void initState() {
    super.initState();
    _initializeOrSync();
  }
  
  @override
  void dispose() {
    // Don't dispose the controller here as it's global
    super.dispose();
  }
  
  Future<void> _initializeOrSync() async {
    // If no music is playing or different music, initialize new
    if (musicController.currentMusic.value == null || 
        musicController.currentMusic.value!.id != widget.musicId) {
      await musicController.initializePlayer(
        widget.musicId,
        initialPlaylist: widget.playlist,
        initialIndex: widget.initialIndex,
      );
    }
    
    // Extract background color
    if (musicController.currentMusic.value != null) {
      await _extractBackgroundColor(musicController.currentMusic.value!.artworkUrl);
    }
  }
  
  Future<void> _extractBackgroundColor(String imageUrl) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
      );
      if (mounted) {
        setState(() {
          backgroundColor = paletteGenerator.dominantColor?.color;
        });
      }
      musicController.setBackgroundColor(backgroundColor);
    } catch (e) {
      debugPrint('Error extracting color: $e');
    }
  }
  
  void _showPlaylistInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? MangoPalette.grey900 
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Obx(() {
          final playlistLength = musicController.playlist.length;
          final upcomingLength = musicController.upcomingTracks.length;
          
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Queue',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
        tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: OptimizedListView(
                    itemCount: playlistLength + upcomingLength,
                    itemBuilder: (context, index) {
                      final isCurrent = index == musicController.currentIndex.value;
                      final isPlayed = index < musicController.currentIndex.value;
                      final isUpcoming = index >= playlistLength;
                      
                      final music = index < playlistLength 
                          ? musicController.playlist[index] 
                          : musicController.upcomingTracks[index - playlistLength];
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MangoRadius.sm),
                            image: DecorationImage(
                              image: NetworkImage(music.artworkUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(
                          music.displayTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent 
                                ? Theme.of(context).primaryColor 
                                : (isPlayed ? MangoPalette.grey500 : null),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          music.artistName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MangoPalette.grey500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isUpcoming 
                            ? const Icon(Icons.schedule, size: 16, color: MangoPalette.grey500)
                            : (isCurrent ? Icon(Icons.play_arrow, size: 16, color: Theme.of(context).primaryColor) : null),
                        onTap: () {
                          musicController.playSpecificTrack(index);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveBgColor = backgroundColor ?? musicController.backgroundColor.value ?? 
        (isDarkMode ? MangoPalette.grey900 : MangoPalette.grey50);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white60 : Colors.black54;
    final iconSize = 24.0;
    
    return Obx(() {
      if (musicController.isLoading.value) {
        return _buildShimmerLoader(isDarkMode);
      }
      
      final music = musicController.currentMusic.value;
      if (music == null) {
        return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
      }
      
      return Scaffold(
        backgroundColor: effectiveBgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
        tooltip: 'Back',
                      icon: Icon(Icons.arrow_back, color: textColor, size: 28),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Column(
                      children: [
                        Text(
                          'PLAYING NOW',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: music.artistImage != null
                                    ? DecorationImage(
                                        image: NetworkImage(music.artistImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: secondaryTextColor.withOpacity(0.2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${musicController.currentIndex.value + 1} of ${musicController.totalTracks}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
        tooltip: 'Queue',
                      icon: Icon(Icons.queue_music, color: textColor, size: 24),
                      onPressed: _showPlaylistInfo,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Artwork
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MangoRadius.md),
                            boxShadow: [
                              BoxShadow(
                                color: MangoPalette.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(MangoRadius.md),
                            child: ArtWorkImage(image: music.artworkUrl),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Track info and controls
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  music.displayTitle,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  music.artistName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: secondaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (music.genre.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      music.genre,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor.withOpacity(0.8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  // Like functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Liked ${music.displayTitle}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.favorite_outline,
                                  color: textColor,
                                  size: 22,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                              SpaceItButton(
                                itemId: music.id,
                                itemType: 'music',
                                itemData: {
                                  'title': music.title,
                                  'subtitle': music.subtitle,
                                  'artist': music.artistName,
                                  'album': music.label,
                                  'duration': music.duration?.inSeconds,
                                  'imageUrl': music.artworkUrl,
                                  'audioUrl': music.trackUrl,
                                  'genre': music.genre,
                                  'fileSize': music.fileSize,
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress bar
                      Obx(() {
                        final position = musicController.currentPosition.value;
                        final total = musicController.totalDuration.value != Duration.zero 
                            ? musicController.totalDuration.value 
                            : music.durationWithFallback;
                        
                        return ProgressBar(
                          progress: position,
                          total: total,
                          bufferedBarColor: secondaryTextColor.withOpacity(0.3),
                          baseBarColor: secondaryTextColor.withOpacity(0.1),
                          thumbColor: Theme.of(context).primaryColor,
                          timeLabelTextStyle: TextStyle(
                            fontSize: 12,
                            color: textColor,
                          ),
                          progressBarColor: Theme.of(context).primaryColor,
                          onSeek: (duration) {
                            musicController.seekTo(duration);
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                      
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Obx(() => _buildControlButton(
                            icon: musicController.isSmartShuffled.value ? Icons.auto_awesome : Icons.shuffle,
                            isActive: musicController.isShuffled.value,
                            tooltip: musicController.isSmartShuffled.value
                                ? 'AI shuffle on. Tap to turn shuffle off'
                                : musicController.isShuffled.value
                                    ? 'Shuffle on. Tap for AI shuffle'
                                    : 'Shuffle',
                            onPressed: () {
                              if (!musicController.isShuffled.value) {
                                musicController.toggleShuffle();
                              } else if (!musicController.isSmartShuffled.value) {
                                musicController.smartShuffle();
                              } else {
                                musicController.toggleShuffle();
                              }
                            },
                            color: textColor,
                            activeColor: Theme.of(context).primaryColor,
                            size: iconSize,
                          )),
                          _buildControlButton(
                            icon: Icons.skip_previous,
                            tooltip: 'Previous',
                            onPressed: () => musicController.playPreviousTrack(),
                            color: textColor,
                            size: iconSize + 4,
                          ),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                            ),
                            child: Obx(() => IconButton(
                              tooltip: musicController.isPlaying.value ? 'Pause' : 'Play',
                              icon: Icon(
                                musicController.isPlaying.value ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: musicController.togglePlayPause,
                              padding: EdgeInsets.zero,
                            )),
                          ),
                          _buildControlButton(
                            icon: Icons.skip_next,
                            tooltip: 'Next',
                            onPressed: () => musicController.playNextTrack(),
                            color: textColor,
                            size: iconSize + 4,
                          ),
                          _buildControlButton(
                            icon: Icons.lyrics,
                            tooltip: 'Lyrics',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LyricsPage(
                                    music: music,
                                    player: musicController.audioPlayer,
                                    musicId: music.id,
                                  ),
                                ),
                              );
                            },
                            color: textColor,
                            size: iconSize,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(() {
                            final mode = musicController.repeatMode.value;
                            return _buildControlButton(
                              icon: mode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                              isActive: mode != RepeatMode.off,
                              tooltip: switch (mode) { RepeatMode.off => 'Repeat off', RepeatMode.all => 'Repeat all', RepeatMode.one => 'Repeat one' },
                              onPressed: musicController.cycleRepeat,
                              color: textColor,
                              activeColor: Theme.of(context).primaryColor,
                              size: iconSize,
                            );
                          }),
                          Expanded(
                            child: Obx(() => Text(
                                  'Playing from ${musicController.source.value.label}',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                )),
                          ),
                          _buildControlButton(
                            icon: Icons.queue_music,
                            tooltip: 'Queue',
                            onPressed: () => showQueueSheet(context),
                            color: textColor,
                            size: iconSize,
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
    });
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    double size = 24,
    bool isActive = false,
    Color? activeColor,
    String? tooltip,
  }) {
    return Semantics(
      toggled: activeColor != null ? isActive : null,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: isActive ? activeColor : color,
          size: size,
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
  
  Widget _buildShimmerLoader(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? MangoPalette.grey900 : MangoPalette.grey50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildShimmerHeader(),
              Expanded(
                flex: 2,
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 80,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: MangoPalette.grey300,
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildShimmerText(),
                    const SizedBox(height: 20),
                    _buildShimmerProgressBar(),
                    const SizedBox(height: 20),
                    _buildShimmerControls(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildShimmerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(width: 40, height: 40, color: MangoPalette.grey300),
        Column(
          children: [
            Container(width: 80, height: 12, color: MangoPalette.grey300),
            const SizedBox(height: 8),
            Container(width: 60, height: 12, color: MangoPalette.grey300),
          ],
        ),
        Container(width: 40, height: 40, color: MangoPalette.grey300),
      ],
    );
  }
  
  Widget _buildShimmerText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 200, height: 20, color: MangoPalette.grey300),
                  const SizedBox(height: 8),
                  Container(width: 150, height: 16, color: MangoPalette.grey300),
                ],
              ),
            ),
            Row(
              children: [
                Container(width: 40, height: 40, color: MangoPalette.grey300),
                const SizedBox(width: 8),
                Container(width: 40, height: 40, color: MangoPalette.grey300),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildShimmerProgressBar() {
    return Container(
      height: 40,
      child: Row(
        children: [
          Container(width: 30, height: 12, color: MangoPalette.grey300),
          Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: MangoPalette.grey300,
            ),
          ),
          Container(width: 30, height: 12, color: MangoPalette.grey300),
        ],
      ),
    );
  }
  
  Widget _buildShimmerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) => 
        Container(
          width: index == 2 ? 56 : 40,
          height: index == 2 ? 56 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MangoPalette.grey300,
          ),
        ),
      ),
    );
  }
}