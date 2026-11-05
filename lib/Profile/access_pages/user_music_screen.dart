import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class MusicScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();

  MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Music'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (profileController.isLoading.value) {
          return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
        }

        final playlists = profileController.userMusic;

        if (playlists.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, size: 64, color: MangoPalette.grey500),
                SizedBox(height: 16),
                Text(
                  'No music playlists yet',
                  style: TextStyle(fontSize: 16, color: MangoPalette.grey500),
                ),
              ],
            ),
          );
        }

        return OptimizedListView(
          padding: const EdgeInsets.all(16),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.library_music, color: Colors.purple),
                title: Text(
                  playlist.title.isNotEmpty ? playlist.title : 'Untitled Playlist',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${playlist.plays} tracks',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.play_arrow, color: MangoPalette.green500),
                onTap: () {
                  
                  
                },
              ),
            );
          },
        );
      }),
    );
  }
}