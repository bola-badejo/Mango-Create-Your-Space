import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class Track {
  String id;
  String title;
  String filePath;
  String downloadUrl;
  RxList<Map<String, String>> credits;

  Track({
    required this.id,
    required this.title,
    required this.filePath,
    this.downloadUrl = '',
    List<Map<String, String>>? credits,
  }) : credits = (credits ?? []).obs;
}

class UploadAlbumController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  
  var albumTitle = ''.obs;
  var artist = ''.obs;
  var selectedGenre = ''.obs;
  var releaseDate = DateTime.now().obs;
  var projectType = 'Album'.obs; 

  
  var contributors = <String>[].obs;
  var newContributor = ''.obs;

  
  var coverImage = Rxn<XFile>();
  var coverDownloadUrl = ''.obs;

  var webCoverImageBytes = Rxn<Uint8List>();
  var webSongBytes = Rxn<Uint8List>();

  
  var tracks = <Track>[].obs;
  var newSongTitle = ''.obs;
  var newSongFilePath = ''.obs;

  
  var isUploading = false.obs;
  var uploadProgress = 0.0.obs;

  
  var currentStep = 0.obs;

  
  final List<String> genres = [
    'Pop','Rock','Hip Hop','Jazz','Classical','Electronic',
    'Blues','Country','Reggae','Metal','Folk','R&B','Punk',
    'Disco','Funk','Soul','Gospel','Techno','House','Trance',
    'Dubstep','Drum & Bass','Indie','Alternative','K-Pop',
    'J-Pop','Latin','World','Ambient','Experimental',
    'Soundtrack','Comedy','Children’s','Spoken Word',
    'Audiobook','Podcast','Other',
  ];

  Future<void> pickCoverImage(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          Uint8List? bytes = result.files.first.bytes;
          if (bytes != null) {
            webCoverImageBytes.value = bytes;
            
            coverImage.value = XFile.fromData(bytes, name: result.files.first.name);
          }
        }
      } else {
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) coverImage.value = picked;
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', e.toString(), context: context);
    }
  }

  
  Future<void> pickSongFile(context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg'],
      );
      
      if (result != null) {
        if (kIsWeb) {
          
          Uint8List? bytes = result.files.first.bytes;
          if (bytes != null) {
            webSongBytes.value = bytes;
            newSongFilePath.value = result.files.first.name;
          }
        } else {
          
          if (result.files.first.path != null) {
            newSongFilePath.value = result.files.first.path!;
          }
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', e.toString(), context: context);
    }
  }

  
  Future<String> _uploadFile(String path, String folder, [Uint8List? webBytes]) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    
    if (kIsWeb && webBytes != null) {
      
      final uploadTask = ref.putData(
        webBytes,
        SettableMetadata(contentType: 'application/octet-stream'),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      await uploadTask;
    } else {
      
      final uploadTask = ref.putFile(File(path));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      await uploadTask;
    }
    
    return await ref.getDownloadURL();
  }

  
  Future<void> uploadAlbum(context) async {
    if (albumTitle.value.isEmpty ||
        artist.value.isEmpty ||
        selectedGenre.value.isEmpty ||
        coverImage.value == null ||
        tracks.isEmpty) {
      UtilsService().showSnackbar('Missing Info', 'Album info, cover, and at least 1 track required', context: context);
      return;
    }

    isUploading.value = true;
    try {
      
      if (kIsWeb) {
        coverDownloadUrl.value = await _uploadFile(
          '', 
          'album_covers', 
          webCoverImageBytes.value
        );
      } else {
        coverDownloadUrl.value = await _uploadFile(
          coverImage.value!.path, 
          'album_covers'
        );
      }

      
      List<String> trackIds = [];
      for (int i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        final url = await _uploadFile(
          t.filePath, 
          'music',
          webSongBytes.value
        );
        
        DocumentReference musicRef = await _firestore.collection('music').add({
          'title': t.title,
          'artist': artist.value,
          'album': albumTitle.value,
          'order': i,
          'genre': selectedGenre.value,
          'releaseDate': releaseDate.value,
          'trackUrl': url,
          'credits': t.credits.toList(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        trackIds.add(musicRef.id);
      }

      
      await _firestore.collection('albums').add({
        'title': albumTitle.value,
        'artist': artist.value,
        'type': projectType.value,
        'genre': selectedGenre.value,
        'releaseDate': releaseDate.value,
        'contributors': contributors.toList(),
        'coverUrl': coverDownloadUrl.value,
        'trackIds': trackIds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      UtilsService().showSnackbar('Success', 'Album uploaded successfully',
          backgroundColor: MangoPalette.green500, colorText: Colors.white, context: context);

      _clearAll();
    } catch (e) {
      UtilsService().showSnackbar('Upload Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white, context: context);
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
    }
  }

  void addContributor() {
    if (newContributor.value.trim().isNotEmpty) {
      contributors.add(newContributor.value.trim());
      newContributor.value = '';
    }
  }

  void addSong(context) {
    if (newSongTitle.value.trim().isEmpty || newSongFilePath.value.isEmpty) {
      UtilsService().showSnackbar('Invalid', 'Song title and file required', context: context);
      return;
    }
    tracks.add(
      Track(
        id: Uuid().v4(),
        title: newSongTitle.value.trim(),
        filePath: newSongFilePath.value,
      ),
    );
    newSongTitle.value = '';
    newSongFilePath.value = '';
  }

  void removeSong(int index) {
    if (index >= 0 && index < tracks.length) {
      tracks.removeAt(index);
    }
  }

  void _clearAll() {
    albumTitle.value = '';
    artist.value = '';
    selectedGenre.value = '';
    releaseDate.value = DateTime.now();
    contributors.clear();
    coverImage.value = null;
    coverDownloadUrl.value = '';
    tracks.clear();
    projectType.value = 'Album';
    currentStep.value = 0;
  }
}
