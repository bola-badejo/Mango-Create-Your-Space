// lib/MusicPlayer/mini_player.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/MusicPlayer/music_player.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalMusicController musicController = Get.find<GlobalMusicController>();
    
    return Obx(() {
      if (!musicController.showMiniPlayer.value || musicController.currentMusic.value == null) {
        return const SizedBox.shrink();
      }
      
      if (!musicController.isMiniPlayerVisible.value) {
        return _buildCollapsedMiniPlayer(context, musicController);
      }
      
      return _buildExpandedMiniPlayer(context, musicController);
    });
  }
  
  Widget _buildExpandedMiniPlayer(BuildContext context, GlobalMusicController musicController) {
    final music = musicController.currentMusic.value!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return MangoPressable(
      onTap: () {
        Get.to(() => MusicPlayer(
          musicId: music.id,
          playlist: musicController.playlist.toList(),
          initialIndex: musicController.currentIndex.value,
        ));
      },
      child: Container(
        height: 70,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey900 : Colors.white,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              child: Image.network(
                music.artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: 50,
                    color: MangoPalette.grey800,
                    child: const Icon(Icons.music_note, color: Colors.white),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // Track info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.displayTitle,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    music.artistName,
                    style: TextStyle(
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Progress bar
                  Obx(() {
                    final progress = musicController.totalDuration.value.inMilliseconds > 0 
                        ? musicController.currentPosition.value.inMilliseconds / musicController.totalDuration.value.inMilliseconds 
                        : 0.0;
                    
                    return Container(
                      height: 2,
                      margin: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(semanticsLabel: 'Loading', 
                        value: progress,
                        backgroundColor: isDarkMode ? MangoPalette.grey800 : MangoPalette.grey200,
                        valueColor: const AlwaysStoppedAnimation<Color>(MangoPalette.green500),
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            // Play/Pause button
            Obx(() => IconButton(
        tooltip: 'Pause',
              icon: Icon(
                musicController.isPlaying.value ? Icons.pause : Icons.play_arrow,
                color: MangoPalette.green500,
                size: 28,
              ),
              onPressed: musicController.togglePlayPause,
            )),
            
            // Close button
            IconButton(
        tooltip: 'Close',
              icon: const Icon(Icons.close, color: MangoPalette.grey500, size: 20),
              onPressed: musicController.stopMusic,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollapsedMiniPlayer(BuildContext context, GlobalMusicController musicController) {
    final music = musicController.currentMusic.value!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return MangoPressable(
      onTap: musicController.toggleMiniPlayer,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? MangoPalette.grey900 : Colors.white,
          borderRadius: BorderRadius.circular(MangoRadius.lg),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Obx(() => Icon(
              musicController.isPlaying.value ? Icons.play_arrow : Icons.pause,
              color: MangoPalette.green500,
              size: 16,
            )),
            const SizedBox(width: 8),
            Text(
              music.displayTitle,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: MangoPalette.green500,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}