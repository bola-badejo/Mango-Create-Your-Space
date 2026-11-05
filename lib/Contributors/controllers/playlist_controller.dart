import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class PlaylistController extends GetxController {
  var playlistTitle = ''.obs;
  var playlistDescription = ''.obs;
  var songs = <Map<String, String>>[].obs; 

  var isUploading = false.obs;
  var uploadProgress = 0.0.obs;

  final _firestore = FirebaseFirestore.instance;

  
  void addSong(String title, String artist) {
    if (title.isNotEmpty && artist.isNotEmpty) {
      songs.add({'title': title, 'artist': artist});
    }
  }

  
  void removeSong(int index) {
    songs.removeAt(index);
  }

  
  void updateSongOrder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
  }

  
  Future<void> uploadPlaylist(BuildContext context) async {
    if (playlistTitle.value.isEmpty || songs.isEmpty) {
      UtilsService().showSnackbar('Error', 'Please add a playlist title and at least one song.',
          backgroundColor: Colors.red, colorText: Colors.white, context: context);
      return;
    }

    isUploading.value = true;

    try {
      await _firestore.collection('playlists').add({
        'title': playlistTitle.value,
        'description': playlistDescription.value,
        'songs': songs.map((song) => {
          'title': song['title'],
          'artist': song['artist'],
        }).toList(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      UtilsService().showSnackbar('Success', 'Playlist uploaded successfully!',
          backgroundColor: MangoPalette.green500, colorText: Colors.white, context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload playlist: $e',
          backgroundColor: Colors.red, colorText: Colors.white, context: context);
    } finally {
      resetForm();
      isUploading.value = false;
    }
  }

  
  void resetForm() {
    playlistTitle.value = '';
    playlistDescription.value = '';
    songs.clear();
    uploadProgress.value = 0.0;
  }

  @override
  void onClose() {
    super.onClose();
    resetForm();
  }
}
