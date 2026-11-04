import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mango/Utils/optimized_lists.dart';
import '../controllers/playlist_controller.dart';

class CreatePlaylistPage extends StatelessWidget {
  final PlaylistController controller = Get.put(PlaylistController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Playlist'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          if (controller.isUploading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFadingCircle(color: Colors.red, size: 50),
                  const SizedBox(height: 20),
                  Text(
                    'Uploading... ${(controller.uploadProgress.value * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Playlist Title', controller.playlistTitle),
                _buildTextField('Description', controller.playlistDescription),
                const SizedBox(height: 20),
                _buildAddSongForm(),
                const SizedBox(height: 20),
                const Text(
                  'Songs:',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 10),
                _buildSongList(),
                const SizedBox(height: 20),
                _buildSubmitButton(context),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextField(String label, RxString value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Obx(() => TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[900],
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) => value.value = text,
      )),
    );
  }

  Widget _buildAddSongForm() {
    final titleController = TextEditingController();
    final artistController = TextEditingController();

    return Column(
      children: [
        TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Song Title',
            filled: true,
            fillColor: Colors.grey[900],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: artistController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Artist',
            filled: true,
            fillColor: Colors.grey[900],
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            controller.addSong(titleController.text, artistController.text);
            titleController.clear();
            artistController.clear();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Add Song'),
        ),
      ],
    );
  }

  Widget _buildSongList() {
    return Obx(() {
      if (controller.songs.isEmpty) {
        return const Text(
          'No songs added yet.',
          style: TextStyle(color: Colors.white),
        );
      }

      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.songs.length,
        onReorder: (oldIndex, newIndex) =>
            controller.updateSongOrder(oldIndex, newIndex),
        itemBuilder: (context, index) {
          final song = controller.songs[index];
          return Card(
            key: ValueKey(index),
            color: Colors.grey[900],
            child: ListTile(
              title: Text(song['title']!, style: const TextStyle(color: Colors.white)),
              subtitle: Text(song['artist']!, style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => controller.removeSong(index),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSubmitButton(context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          controller.uploadPlaylist(context);
          },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Create Playlist'),
      ),
    );
  }
}
