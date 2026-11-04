import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/utils.dart';

class PodcastController extends GetxController {
  
  var title = ''.obs;
  var description = ''.obs;
  var thumbnailUrl = ''.obs;
  var isUploading = false.obs;
  var webThumbnailBytes = Rxn<Uint8List>();
  var webAudioBytes = Rxn<Uint8List>();

  
  var episodes = <PodcastEpisode>[].obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  
  Future<void> pickThumbnail(context) async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        Uint8List? bytes = result.files.first.bytes;
        if (bytes != null) {
          webThumbnailBytes.value = bytes;
          await uploadThumbnailForWeb(bytes, result.files.first.name, context);
        }
      }
    } else {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        uploadThumbnail(File(pickedFile.path), context);
      }
    }
  }

  
  Future<void> uploadThumbnailForWeb(Uint8List bytes, String fileName, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('podcast_thumbnails/${DateTime.now().toIso8601String()}_$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      thumbnailUrl.value = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Thumbnail uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload thumbnail: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  
  Future<void> pickAudio(context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result != null) {
      if (kIsWeb) {
        Uint8List? bytes = result.files.single.bytes;
        if (bytes != null) {
          webAudioBytes.value = bytes;
          uploadAudioForWeb(bytes, result.files.single.name, context);
        }
      } else {
        if (result.files.single.path != null) {
          File audioFile = File(result.files.single.path!);
          uploadAudio(audioFile, context);
        }
      }
    } else {
      UtilsService().showSnackbar('Error', 'No audio file selected', context: context);
    }
  }

  
  Future<String> uploadAudioForWeb(Uint8List bytes, String fileName, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('podcast_audios/${DateTime.now().toIso8601String()}_$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'audio/mpeg'));
      final url = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Audio uploaded successfully.', context: context);
      return url;
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload audio: $e', context: context);
      return '';
    } finally {
      isUploading.value = false;
    }
  }

  
  Future<void> uploadThumbnail(File file, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('podcast_thumbnails/${DateTime.now().toIso8601String()}');
      await ref.putFile(file);
      thumbnailUrl.value = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Thumbnail uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload thumbnail: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }


  
  Future<String> uploadAudio(File file, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('podcast_audios/${DateTime.now().toIso8601String()}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Audio uploaded successfully.', context: context);
      return url;
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload audio: $e', context: context);
      return '';
    } finally {
      isUploading.value = false;
    }
  }

  
  void addEpisode(String title, String description, String audioUrl, Duration duration) {
    episodes.add(PodcastEpisode(
      title: title,
      description: description,
      audioUrl: audioUrl,
      duration: duration,
    ));
  }

  
  Future<void> addNewEpisode(String seriesId, String episodeTitle, String episodeDescription, File audioFile, Duration duration, context) async {
    try {
      isUploading.value = true;
      String audioUrl = await uploadAudio(audioFile, context);
      if (audioUrl.isEmpty) return;

      var newEpisode = {
        'title': episodeTitle,
        'description': episodeDescription,
        'audioUrl': audioUrl,
        'duration': duration.inSeconds,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('podcast_series').doc(seriesId).update({
        'episodes': FieldValue.arrayUnion([newEpisode]),
      });

      UtilsService().showSnackbar('Success', 'New episode added successfully!', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to add new episode: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> uploadPodcastSeries(context) async {
    if (title.value.isEmpty || description.value.isEmpty || thumbnailUrl.value.isEmpty || episodes.isEmpty) {
      UtilsService().showSnackbar('Error', 'Please fill all fields and add at least one episode.', context: context);
      return;
    }

    isUploading.value = true;
    try {
      await _firestore.collection('podcast_series').add({
        'title': title.value,
        'description': description.value,
        'thumbnailUrl': thumbnailUrl.value,
        'episodes': episodes.map((e) => e.toMap()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      UtilsService().showSnackbar('Success', 'Podcast series uploaded!', context: context);
      resetForm();
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Upload failed: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  
  void resetForm() {
    title.value = '';
    description.value = '';
    thumbnailUrl.value = '';
    episodes.clear();
  }
}

class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final Duration duration;

  PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'duration': duration.inSeconds,
    };
  }
}
