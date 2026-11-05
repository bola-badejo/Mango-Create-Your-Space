import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class AlbumTrack {
  String id;
  final TextEditingController titleController;
  String filePath;
  String musicDocId;
  RxList<Map<String, String>> credits;
  RxInt duration;
  RxString fileSize;
  RxBool isUploading;
  RxDouble uploadProgress;
  
  
  Uint8List? webBytes;
  String? webFileName;

  AlbumTrack({
    required this.id,
    String title = '',
    this.filePath = '',
    this.musicDocId = '',
    List<Map<String, String>>? credits,
    int duration = 0,
    String fileSize = '',
    this.webBytes,
    this.webFileName,
  })  : titleController = TextEditingController(text: title),
        credits = (credits ?? []).obs,
        duration = duration.obs,
        fileSize = fileSize.obs,
        isUploading = false.obs,
        uploadProgress = 0.0.obs;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleController.text,
      'filePath': filePath,
      'musicDocId': musicDocId,
      'credits': credits.toList(),
      'duration': duration.value,
      'fileSize': fileSize.value,
    };
  }

  static AlbumTrack fromJson(Map<String, dynamic> json) {
    return AlbumTrack(
      id: json['id'] ?? Uuid().v4(),
      title: json['title'] ?? '',
      filePath: json['filePath'] ?? '',
      musicDocId: json['musicDocId'] ?? '',
      credits: (json['credits'] as List<dynamic>?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList() ?? [],
      duration: json['duration'] ?? 0,
      fileSize: json['fileSize'] ?? '',
    );
  }

  Future<void> loadAudioMetadata() async {
    if (kIsWeb) {
      if (webBytes == null) return;
      fileSize.value = '${(webBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB';
      duration.value = 0;
    } else {
      if (filePath.isEmpty) return;
      
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          final sizeInMB = stat.size / (1024 * 1024);
          fileSize.value = '${sizeInMB.toStringAsFixed(1)} MB';
        }

        final player = AudioPlayer();
        await player.setSource(DeviceFileSource(filePath));
        final audioDuration = await player.getDuration();
        duration.value = audioDuration?.inSeconds ?? 0;
        
        await player.dispose();
      } catch (e) {
        debugPrint('Error loading audio metadata: $e');
      }
    }
  }

  void dispose() {
    titleController.dispose();
  }
}

class UploadAlbumController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final String? contributorId;
  final String? userId;
  
  UploadAlbumController({this.contributorId, this.userId});

  
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  
  final albumTitle = ''.obs;
  final artist = ''.obs;
  final projectType = 'Album'.obs;
  final selectedGenre = ''.obs;
  final releaseDate = DateTime.now().obs;
  final description = ''.obs;
  final label = ''.obs;
  final isExplicit = false.obs;
  final copyrightInfo = ''.obs;

  
  final contributors = <Map<String, String>>[].obs;
  final newContributorRole = ''.obs;
  final newContributorName = ''.obs;

  
  final ImagePicker _picker = ImagePicker();
  final coverImage = Rxn<XFile>();
  final coverDownloadUrl = ''.obs;
  Uint8List? webCoverBytes;
  String? webCoverFileName;

  
  final RxList<AlbumTrack> tracks = <AlbumTrack>[].obs;
  final newSongTitle = ''.obs;
  final newSongFilePath = ''.obs;
  Uint8List? newSongWebBytes;
  String? newSongWebFileName;

  
  final isUploading = false.obs;
  final RxString uploadStatus = ''.obs;
  final RxInt currentUploadIndex = 0.obs;
  final RxDouble uploadProgress = 0.0.obs;

  
  final isArtworkSelected = false.obs;
  final hasTracks = false.obs;
  final areDetailsComplete = false.obs;

  
  final List<String> genres = [
    'Pop', 'Rock', 'Hip Hop', 'Jazz', 'Classical', 'Electronic', 'R&B', 
    'Alternative', 'Blues', 'Country', 'Reggae', 'Metal', 'Folk', 'Punk',
    'Disco', 'Funk', 'Soul', 'Gospel', 'Techno', 'House', 'Trance', 'Dubstep',
    'Drum & Bass', 'Indie', 'K-Pop', 'Latin', 'World', 'Ambient', 'Experimental',
    'Afrobeats', 'Amapiano', 'Afro-pop', 'Gospel', 'Highlife', 'Juju', 'Fuji'
  ];

  final List<String> popularRoles = [
    'Producer', 'Vocalist', 'Songwriter', 'Composer', 'Guitarist', 
    'Bassist', 'Drummer', 'Keyboardist', 'Mixing Engineer', 
    'Mastering Engineer', 'Featured Artist', 'Backing Vocalist'
  ];

  static const String _kDraftKey = 'upload_album_draft_v2';
  final RxBool hasDraft = false.obs;
  
  get context => context;

  @override
  void onInit() {
    super.onInit();
    _checkForDraft();
    _validateContributor();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      uploadStatus.value = 'Contributor ID required. Please register as a creator first.';
    }
  }

  Future<void> _checkForDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasDraft.value = prefs.containsKey(_kDraftKey);
    } catch (e) {
      debugPrint('Error checking draft: $e');
    }
  }

  Future<void> saveDraft(context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'albumTitle': albumTitle.value,
        'artist': artist.value,
        'projectType': projectType.value,
        'selectedGenre': selectedGenre.value,
        'releaseDate': releaseDate.value.toIso8601String(),
        'description': description.value,
        'label': label.value,
        'isExplicit': isExplicit.value,
        'copyrightInfo': copyrightInfo.value,
        'contributors': contributors.toList(),
        'coverImagePath': coverImage.value?.path ?? '',
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'currentStep': currentStep.value,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_kDraftKey, jsonEncode(data));
      hasDraft.value = true;
      
      UtilsService().showSnackbar(
        'Draft Saved',
        'Your album has been saved as draft',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );
    } catch (e) {
      debugPrint('Failed to save draft: $e');
      UtilsService().showSnackbar('Draft Error', 'Failed to save draft', context: context);
    }
  }

  Future<bool> loadDraft(context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kDraftKey)) return false;
      
      final raw = prefs.getString(_kDraftKey);
      if (raw == null) return false;
      
      final Map<String, dynamic> data = jsonDecode(raw);
      
      _clearFormData();
      
      albumTitle.value = data['albumTitle'] ?? '';
      artist.value = data['artist'] ?? '';
      projectType.value = data['projectType'] ?? 'Album';
      selectedGenre.value = data['selectedGenre'] ?? '';
      description.value = data['description'] ?? '';
      label.value = data['label'] ?? '';
      isExplicit.value = data['isExplicit'] ?? false;
      copyrightInfo.value = data['copyrightInfo'] ?? '';
      
      final releaseDateString = data['releaseDate'] ?? '';
      if (releaseDateString.isNotEmpty) {
        releaseDate.value = DateTime.tryParse(releaseDateString) ?? DateTime.now();
      }
      
      contributors.assignAll(
        (data['contributors'] as List<dynamic>?)
            ?.map((e) => Map<String, String>.from(e as Map))
            .toList() ?? []
      );
      
      final coverPath = data['coverImagePath'] ?? '';
      if (coverPath.isNotEmpty && File(coverPath).existsSync()) {
        coverImage.value = XFile(coverPath);
        isArtworkSelected.value = true;
      }
      
      final loadedTracks = (data['tracks'] as List<dynamic>?)
          ?.map((e) => AlbumTrack.fromJson(Map<String, dynamic>.from(e)))
          .toList() ?? [];
      
      for (final track in loadedTracks) {
        tracks.add(track);
        if (track.filePath.isNotEmpty) {
          track.loadAudioMetadata();
        }
      }
      hasTracks.value = tracks.isNotEmpty;
      
      currentStep.value = data['currentStep'] ?? 0;
      _validateCurrentStep();
      
      UtilsService().showSnackbar(
        'Draft Loaded',
        'Your previous work has been restored',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        context: context,
      );
      
      return true;
    } catch (e) {
      debugPrint('Failed to load draft: $e');
      UtilsService().showSnackbar('Draft Error', 'Failed to load draft', context: context);
      return false;
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
      hasDraft.value = false;
    } catch (e) {
      debugPrint('Failed to clear draft: $e');
    }
  }

  Future<void> deleteDraft(context) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Draft?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await clearDraft();
      UtilsService().showSnackbar('Draft Deleted', 'Your draft has been removed', context: context);
    }
  }

  void _validateCurrentStep() {
    switch (currentStep.value) {
      case 0:
        isStepValid.value = isArtworkSelected.value;
        break;
      case 1:
        isStepValid.value = hasTracks.value;
        break;
      case 2:
        isStepValid.value = albumTitle.value.isNotEmpty && 
                          artist.value.isNotEmpty && 
                          selectedGenre.value.isNotEmpty;
        areDetailsComplete.value = isStepValid.value;
        break;
      case 3:
        isStepValid.value = true;
        break;
      case 4:
        isStepValid.value = true;
        break;
    }
  }

  void goToNextStep() {
    if (currentStep.value < 4 && isStepValid.value) {
      currentStep.value++;
      _validateCurrentStep();
    }
  }

  void goToPreviousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      _validateCurrentStep();
    }
  }

  void setAlbumTitle(String value) {
    albumTitle.value = value;
    _validateCurrentStep();
    saveDraft(context);
  }

  void setArtist(String value) {
    artist.value = value;
    _validateCurrentStep();
    saveDraft(context);
  }

  void setProjectType(String value) {
    projectType.value = value;
    saveDraft(context);
  }

  void setGenre(String value) {
    selectedGenre.value = value;
    _validateCurrentStep();
    saveDraft(context);
  }

  void setReleaseDate(DateTime date) {
    releaseDate.value = date;
    saveDraft(context);
  }

  void setDescription(String value) {
    description.value = value;
    saveDraft(context);
  }

  void setLabel(String value) {
    label.value = value;
    saveDraft(context);
  }

  void setCopyrightInfo(String value) {
    copyrightInfo.value = value;
    saveDraft(context);
  }

  void toggleExplicit() {
    isExplicit.value = !isExplicit.value;
    saveDraft(context);
  }

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
            webCoverBytes = bytes;
            webCoverFileName = result.files.first.name;
            coverImage.value = XFile.fromData(bytes, name: webCoverFileName);
            isArtworkSelected.value = true;
            _validateCurrentStep();
            saveDraft(context);
            
            UtilsService().showSnackbar(
              'Cover Added',
              'Album artwork selected',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: MangoPalette.green500,
              colorText: Colors.white,
              context: context,
            );
          }
        }
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 90,
        );
        if (image != null) {
          coverImage.value = image;
          isArtworkSelected.value = true;
          _validateCurrentStep();
          saveDraft(context);
          
          UtilsService().showSnackbar(
            'Cover Added',
            'Album artwork selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            context: context,
          );
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Cover Error', 'Failed to select image: ${e.toString()}', context: context);
    }
  }

  void removeCoverImage(context) {
    coverImage.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    isArtworkSelected.value = false;
    _validateCurrentStep();
    saveDraft(context);
  }

  Future<void> pickSongFile(context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'flac'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      
      if (kIsWeb) {
        if (file.bytes != null) {
          newSongWebBytes = file.bytes;
          newSongWebFileName = file.name;
          newSongFilePath.value = file.name;
        }
      } else {
        if (file.path != null) {
          newSongFilePath.value = file.path!;
        }
      }
      
      if (newSongTitle.value.isEmpty) {
        final fileName = file.name.replaceAll(RegExp(r'\.(wav|mp3|m4a|aac|flac)$'), '');
        newSongTitle.value = fileName;
      }
    } catch (e) {
      UtilsService().showSnackbar('File Error', 'Failed to pick file: ${e.toString()}', context: context);
    }
  }

  Future<void> addSong(context) async {
    if (newSongTitle.value.trim().isEmpty || 
        (kIsWeb ? newSongWebBytes == null : newSongFilePath.value.isEmpty)) {
      UtilsService().showSnackbar('Invalid', 'Please provide both title and audio file', context: context);
      return;
    }

    final track = AlbumTrack(
      id: Uuid().v4(),
      title: newSongTitle.value.trim(),
      filePath: kIsWeb ? '' : newSongFilePath.value,
      webBytes: kIsWeb ? newSongWebBytes : null,
      webFileName: kIsWeb ? newSongWebFileName : null,
    );

    await track.loadAudioMetadata();
    
    tracks.add(track);
    newSongTitle.value = '';
    newSongFilePath.value = '';
    newSongWebBytes = null;
    newSongWebFileName = null;
    hasTracks.value = true;
    _validateCurrentStep();
    saveDraft(context);

    UtilsService().showSnackbar(
      'Track Added',
      '${track.titleController.text} has been added',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
    );
  }

  void removeSong(int index, context) {
    if (index >= 0 && index < tracks.length) {
      final trackName = tracks[index].titleController.text;
      tracks[index].dispose();
      tracks.removeAt(index);
      hasTracks.value = tracks.isNotEmpty;
      _validateCurrentStep();
      saveDraft(context);

      UtilsService().showSnackbar(
        'Track Removed',
        '$trackName has been removed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    }
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);
    saveDraft(context);
  }

  void addContributor(String role, String name, context) {
    if (role.isEmpty || name.isEmpty) return;
    
    contributors.add({'role': role, 'name': name});
    saveDraft(context);
    
    UtilsService().showSnackbar(
      'Contributor Added',
      '$name ($role)',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
    );
  }

  void removeContributor(int index, context) {
    if (index >= 0 && index < contributors.length) {
      contributors.removeAt(index);
      saveDraft(context);
    }
  }

  void addTrackCredit(int trackIndex, String role, String name, context) {
    if (trackIndex < 0 || trackIndex >= tracks.length) return;
    tracks[trackIndex].credits.add({'role': role, 'name': name});
    saveDraft(context);
  }

  void removeTrackCredit(int trackIndex, int creditIndex, context) {
    if (trackIndex < 0 || trackIndex >= tracks.length) return;
    final credits = tracks[trackIndex].credits;
    if (creditIndex >= 0 && creditIndex < credits.length) {
      credits.removeAt(creditIndex);
      saveDraft(context);
    }
  }

  Future<String> _uploadFile(String path, Uint8List? bytes, String folder, String? fileName) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    
    if (kIsWeb && bytes != null) {
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: _getContentType(fileName ?? ''),
        ),
      );
      
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          uploadProgress.value = progress;
          if (currentUploadIndex.value < tracks.length) {
            tracks[currentUploadIndex.value].uploadProgress.value = progress;
          }
        }
      });
      
      await uploadTask;
    } else {
      final uploadTask = ref.putFile(File(path));
      
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          uploadProgress.value = progress;
          if (currentUploadIndex.value < tracks.length) {
            tracks[currentUploadIndex.value].uploadProgress.value = progress;
          }
        }
      });
      
      await uploadTask;
    }
    
    return await ref.getDownloadURL();
  }

  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.mp3': return 'audio/mpeg';
      case '.wav': return 'audio/wav';
      case '.aac': return 'audio/aac';
      case '.m4a': return 'audio/mp4';
      case '.flac': return 'audio/flac';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  Future<String> _getArtistName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return artist.value;
      
      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();
      
      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? artist.value;
      }
    } catch (e) {
      debugPrint('Error getting artist name: $e');
    }
    return artist.value;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;
      
      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalAlbums': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadAlbum(context) async {
    
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Contributor Required',
        'Please register as a creator first to upload an album.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    if (albumTitle.value.isEmpty || artist.value.isEmpty || 
        selectedGenre.value.isEmpty || tracks.isEmpty) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields and add at least one track',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    isUploading.value = true;
    uploadStatus.value = 'Starting upload...';
    uploadProgress.value = 0.0;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      String coverUrl = '';
      if ((coverImage.value != null) || webCoverBytes != null) {
        uploadStatus.value = 'Uploading cover artwork...';
        coverUrl = await _uploadFile(
          coverImage.value?.path ?? '',
          webCoverBytes,
          'album_covers',
          webCoverFileName,
        );
        coverDownloadUrl.value = coverUrl;
      }

      final List<Map<String, dynamic>> albumTracksData = [];
      
      for (int i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        currentUploadIndex.value = i;
        track.isUploading.value = true;
        uploadStatus.value = 'Uploading: ${track.titleController.text}';

        if (kIsWeb && track.webBytes == null) {
          throw Exception('Track ${track.titleController.text} has no file');
        }
        if (!kIsWeb && track.filePath.isEmpty) {
          throw Exception('Track ${track.titleController.text} has no file');
        }

        final audioUrl = await _uploadFile(
          track.filePath,
          track.webBytes,
          'album_tracks',
          track.webFileName,
        );

        
        final docRef = await _firestore.collection('music').add({
          'title': track.titleController.text,
          'description': description.value,
          'label': label.value.isNotEmpty ? label.value : artist.value,
          'genre': selectedGenre.value,
          'releaseYear': releaseDate.value.year.toString(),
          'isExplicit': isExplicit.value,
          'mood': '',
          'language': '',
          'copyrightInfo': copyrightInfo.value,
          'credits': track.credits.toList(),
          'artworkUrl': coverUrl,
          'trackUrl': audioUrl,
          'duration': track.duration.value,
          'timestamp': FieldValue.serverTimestamp(),
          'plays': 0,
          'likes': 0,
          
          
          'contributorId': contributorId,
          'userId': currentUser.uid,
          'creatorId': contributorId,
          'artistName': await _getArtistName(),
          
          
          'albumContext': {
            'albumTitle': albumTitle.value,
            'artist': artist.value,
            'trackNumber': i + 1,
            'albumId': '', 
          },
        });

        track.musicDocId = docRef.id;
        track.isUploading.value = false;

        albumTracksData.add({
          'trackId': docRef.id,
          'title': track.titleController.text,
          'order': i,
          'duration': track.duration.value,
          'credits': track.credits.toList(),
        });

        await saveDraft(context);
      }

      uploadStatus.value = 'Creating album record...';
      
      
      final albumRef = await _firestore.collection('albums').add({
        'title': albumTitle.value,
        'artist': artist.value,
        'projectType': projectType.value,
        'genre': selectedGenre.value,
        'releaseDate': Timestamp.fromDate(releaseDate.value),
        'description': description.value,
        'label': label.value,
        'isExplicit': isExplicit.value,
        'copyrightInfo': copyrightInfo.value,
        'contributors': contributors.toList(),
        'coverUrl': coverUrl,
        'tracks': albumTracksData,
        'totalTracks': tracks.length,
        'totalDuration': albumTracksData.fold(0, (sum, track) => sum + (int.tryParse(track['duration']?.toString() ?? '0') ?? 0)),
        'timestamp': FieldValue.serverTimestamp(),
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
        'artistName': await _getArtistName(),
      });

      
      for (int i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        await _firestore.collection('music').doc(track.musicDocId).update({
          'albumContext.albumId': albumRef.id,
        });
      }

      
      await _updateContributorStats();

      await clearDraft();
      _clearFormData();

      UtilsService().showSnackbar(
        '🎉 Success!',
        '${albumTitle.value} has been uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        context: context,
      );

      Get.back();

    } catch (e, st) {
      debugPrint('Upload album error: $e\n$st');
      UtilsService().showSnackbar(
        'Upload Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        context: context,
      );
    } finally {
      isUploading.value = false;
      currentUploadIndex.value = 0;
      uploadStatus.value = '';
      uploadProgress.value = 0.0;
    }
  }

  void _clearFormData() {
    albumTitle.value = '';
    artist.value = '';
    projectType.value = 'Album';
    selectedGenre.value = '';
    releaseDate.value = DateTime.now();
    description.value = '';
    label.value = '';
    isExplicit.value = false;
    copyrightInfo.value = '';
    contributors.clear();
    coverImage.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    coverDownloadUrl.value = '';
    for (final t in tracks) t.dispose();
    tracks.clear();
    newSongFilePath.value = '';
    newSongTitle.value = '';
    newSongWebBytes = null;
    newSongWebFileName = null;
    currentStep.value = 0;
    isArtworkSelected.value = false;
    hasTracks.value = false;
    areDetailsComplete.value = false;
    isStepValid.value = false;
  }

  void resetForm() {
    _clearFormData();
    clearDraft();
  }

  @override
  void onClose() {
    for (final t in tracks) t.dispose();
    super.onClose();
  }
}


class UploadAlbumPage extends StatefulWidget {
  final String? contributorId;
  
  const UploadAlbumPage({super.key, this.contributorId});

  @override
  State<UploadAlbumPage> createState() => _UploadAlbumPageState();
}

class _UploadAlbumPageState extends State<UploadAlbumPage> with SingleTickerProviderStateMixin {
  late final UploadAlbumController controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _releaseDateController = TextEditingController();
  final TextEditingController _newContributorRoleController = TextEditingController();
  final TextEditingController _newContributorNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    controller = Get.put(UploadAlbumController(
      contributorId: widget.contributorId,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ));
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _releaseDateController.text = _formatDate(controller.releaseDate.value);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _releaseDateController.dispose();
    _newContributorRoleController.dispose();
    _newContributorNameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> _showExitDialog() async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Save Draft?'),
            content: const Text('Do you want to save your progress as a draft before leaving?'),
            actions: [
              TextButton(
                onPressed: () {
                  controller.clearDraft();
                  Get.back(result: true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await controller.saveDraft(context);
                  Get.back(result: true);
                },
                child: const Text('Save Draft'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildDraftAlert() {
    return Obx(() => controller.hasDraft.value
        ? Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.md),
              border: Border.all(color: Colors.blue),
            ),
            child: Row(
              children: [
                const Icon(Icons.save, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Draft Available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You have an unsaved album draft',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => controller.loadDraft(context),
                  child: const Text('Restore'),
                ),
                IconButton(
        tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => controller.deleteDraft(context),
                  color: Colors.red,
                ),
              ],
            ),
          )
        : const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? MangoPalette.grey900 : MangoPalette.grey50;
    final cardColor = isDark ? MangoPalette.grey800 : Colors.white;
    final textColor = isDark ? Colors.white : MangoPalette.black;

    return WillPopScope(
      onWillPop: _showExitDialog,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(isDark, textColor),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildDraftAlert(),
                _buildHorizontalStepper(isDark),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildStepContent(isDark, cardColor, textColor),
                  ),
                ),
                _buildNavigationButtons(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color textColor) {
    return AppBar(
      title: const Text(
        'Upload Album/EP',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textColor),
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: (){
            controller.saveDraft(context);
          },
          tooltip: 'Save Draft',
        ),
        Obx(() => controller.isUploading.value
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: Lottie.asset(
                  'assets/loading.json',
                  width: 30,
                  height: 30,
                ),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildHorizontalStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(0, 'Artwork', Icons.album, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Tracks', Icons.queue_music, isDark),
          _buildStepDivider(isDark),
          _buildStep(2, 'Details', Icons.description, isDark),
          _buildStepDivider(isDark),
          _buildStep(3, 'Credits', Icons.people, isDark),
          _buildStepDivider(isDark),
          _buildStep(4, 'Upload', Icons.cloud_upload, isDark),
        ],
      ),
    );
  }

  Widget _buildStep(int stepNumber, String title, IconData icon, bool isDark) {
    return Obx(() {
      final isActive = controller.currentStep.value == stepNumber;
      final isCompleted = controller.currentStep.value > stepNumber;
      final isAccessible = controller.currentStep.value >= stepNumber;

      return MangoPressable(
        onTap: isAccessible ? () => controller.currentStep.value = stepNumber : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? MangoPalette.green500.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: isActive ? Border.all(color: MangoPalette.green500.withOpacity(0.3)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? MangoPalette.green500
                      : (isActive ? MangoPalette.green500 : MangoPalette.grey500.withOpacity(0.2)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isDark ? Colors.white : MangoPalette.black,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(
      width: 16,
      height: 1,
      color: isDark ? MangoPalette.grey700 : MangoPalette.grey300,
    );
  }

  Widget _buildStepContent(bool isDark, Color cardColor, Color textColor) {
    return Obx(() {
      switch (controller.currentStep.value) {
        case 0:
          return _buildArtworkStep(isDark, cardColor);
        case 1:
          return _buildTracksStep(isDark, cardColor, textColor);
        case 2:
          return _buildDetailsStep(isDark, cardColor, textColor);
        case 3:
          return _buildContributorsStep(isDark, cardColor, textColor);
        case 4:
          return _buildReviewStep(isDark, cardColor, textColor);
        default:
          return const SizedBox();
      }
    });
  }

  Widget _buildArtworkStep(bool isDark, Color cardColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Obx(() => MangoPressable(
                  onTap: ()=> controller.pickCoverImage(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: controller.isArtworkSelected.value
                          ? Colors.transparent
                          : MangoPalette.grey200,
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      border: Border.all(
                        color: controller.isArtworkSelected.value
                            ? MangoPalette.green500
                            : MangoPalette.grey300,
                        width: 2,
                      ),
                      image: controller.coverImage.value != null
                          ? DecorationImage(
                              image: FileImage(File(controller.coverImage.value!.path)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: controller.coverImage.value == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.album,
                                size: 48,
                                color: MangoPalette.grey400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Add Album Artwork',
                                style: TextStyle(
                                  color: MangoPalette.grey600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
        tooltip: 'Close',
                                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                    onPressed: () => controller.removeCoverImage(context),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                )),
                const SizedBox(height: 24),
                Text(
                  'Album Cover Artwork',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a square image for best results. Recommended: 1200x1200px',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildAddTrackSection(isDark, textColor),
                const SizedBox(height: 24),
                _buildTracksList(isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTrackSection(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        children: [
          Text(
            'Add New Track',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: controller.newSongTitle.value)
              ..selection = TextSelection.collapsed(offset: controller.newSongTitle.value.length),
            onChanged: (value) => controller.newSongTitle.value = value,
            decoration: InputDecoration(
              labelText: 'Track Title',
              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MangoRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: MangoPalette.grey500),
              borderRadius: BorderRadius.circular(MangoRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.newSongFilePath.value.isEmpty 
                        ? 'No file selected' 
                        : controller.newSongFilePath.value.split('/').last,
                    style: TextStyle(
                      color: controller.newSongFilePath.value.isEmpty 
                          ? MangoPalette.grey500 
                          : textColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => controller.pickSongFile(context),
                  child: const Text('Choose File'),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: ()=> controller.addSong(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Track'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MangoPalette.green500,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksList(bool isDark, Color textColor) {
    return Obx(() {
      if (controller.tracks.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.music_note,
                size: 64,
                color: MangoPalette.grey400,
              ),
              const SizedBox(height: 16),
              Text(
                'No tracks added yet',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first track to continue',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      }
      
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.tracks.length,
        onReorder: controller.reorderTracks,
        itemBuilder: (context, index) {
          final track = controller.tracks[index];
          return Card(
            key: ValueKey(track.id),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: MangoPalette.green500,
                          borderRadius: BorderRadius.circular(MangoRadius.sm),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: track.titleController,
                          onChanged: (_) => controller.saveDraft,
                          decoration: const InputDecoration(
                            labelText: 'Track Title',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
        tooltip: 'Delete',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => controller.removeSong(index, context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.audiotrack, size: 16, color: MangoPalette.grey500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          track.filePath.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.grey600,
                          ),
                        ),
                      ),
                      if (track.duration.value > 0)
                        Text(
                          '${(track.duration.value ~/ 60)}:${(track.duration.value % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.grey600,
                          ),
                        ),
                    ],
                  ),
                  if (track.fileSize.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        track.fileSize.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: MangoPalette.grey500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildTrackCreditsSection(track, index, isDark, textColor, context),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildTrackCreditsSection(AlbumTrack track, int trackIndex, bool isDark, Color textColor, context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Track Credits',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add, size: 18),
              onPressed: () => _showAddTrackCreditDialog(trackIndex, context),
            ),
          ],
        ),
        Obx(() {
          if (track.credits.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
                borderRadius: BorderRadius.circular(MangoRadius.sm),
              ),
              child: Text(
                'No credits added for this track',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            );
          }
          
          return Column(
            children: track.credits.asMap().entries.map((entry) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.person,
                  size: 16,
                  color: MangoPalette.green500,
                ),
                title: Text(
                  entry.value['name'] ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  entry.value['role'] ?? '',
                  style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                ),
                trailing: IconButton(
        tooltip: 'Delete',
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () => controller.removeTrackCredit(trackIndex, entry.key, context),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildDetailsStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Album Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  'Album Title *',
                  Icons.title,
                  (value) => controller.setAlbumTitle(value),
                  initialValue: controller.albumTitle.value,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Artist *',
                  Icons.person,
                  (value) => controller.setArtist(value),
                  initialValue: controller.artist.value,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Description',
                  Icons.description,
                  controller.setDescription,
                  initialValue: controller.description.value,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Label',
                  Icons.business,
                  controller.setLabel,
                  initialValue: controller.label.value,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Obx(() => _buildModernDropdown(
                  'Project Type',
                  Icons.album,
                  ['Album', 'EP'],
                  controller.projectType.value,
                  (value) => controller.setProjectType(value),
                  isDark: isDark,
                )),
                const SizedBox(height: 16),
                Obx(() => _buildModernDropdown(
                  'Genre *',
                  Icons.category,
                  controller.genres,
                  controller.selectedGenre.value,
                  (value) => controller.setGenre(value),
                  isDark: isDark,
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: _releaseDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Release Date',
                    prefixIcon: Icon(Icons.calendar_today, color: MangoPalette.green500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    filled: true,
                    fillColor: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: controller.releaseDate.value,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      controller.setReleaseDate(picked);
                      _releaseDateController.text = _formatDate(picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Copyright Info',
                  Icons.copyright,
                  controller.setCopyrightInfo,
                  initialValue: controller.copyrightInfo.value,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  'Explicit Content',
                  Icons.warning,
                  controller.isExplicit.value,
                  (_) => controller.toggleExplicit(),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorsStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Album Contributors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildAddContributorSection(isDark, textColor, context),
                const SizedBox(height: 24),
                _buildContributorsList(isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddContributorSection(bool isDark, Color textColor, context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        children: [
          Text(
            'Add Contributor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newContributorNameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newContributorRoleController,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final name = _newContributorNameController.text.trim();
              final role = _newContributorRoleController.text.trim();
              if (name.isNotEmpty && role.isNotEmpty) {
                controller.addContributor(role, name, context);
                _newContributorNameController.clear();
                _newContributorRoleController.clear();
              } else {
                UtilsService().showSnackbar('Invalid', 'Please enter both name and role', context: context);
              }
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Add Contributor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MangoPalette.green500,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorsList(bool isDark, Color textColor) {
    return Obx(() {
      if (controller.contributors.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.people,
                size: 64,
                color: MangoPalette.grey400,
              ),
              const SizedBox(height: 16),
              Text(
                'No contributors added yet',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add people who contributed to this album',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contributors',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...controller.contributors.asMap().entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.person,
                  color: MangoPalette.green500,
                ),
                title: Text(entry.value['name'] ?? ''),
                subtitle: Text(entry.value['role'] ?? ''),
                trailing: IconButton(
        tooltip: 'Delete',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => controller.removeContributor(entry.key, context),
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _buildReviewStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.task_alt, size: 64, color: MangoPalette.green500),
                const SizedBox(height: 16),
                Text(
                  'Ready to Upload!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review your album details before uploading',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                  ),
                ),
                const SizedBox(height: 32),
                _buildAlbumPreview(isDark, textColor),
                const SizedBox(height: 24),
                _buildTracksPreview(isDark, textColor),
                const SizedBox(height: 24),
                _buildContributorsPreview(isDark, textColor),
                const SizedBox(height: 24),
                Obx(() {
                  if (controller.isUploading.value) {
                    return Column(
                      children: [
                        const SizedBox(height: 8),
                        LinearProgressIndicator(semanticsLabel: 'Loading', value: controller.uploadProgress.value),
                        const SizedBox(height: 8),
                        Text(
                          controller.uploadStatus.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumPreview(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Album Info',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildReviewItem('Title', controller.albumTitle.value, Icons.title),
          _buildReviewItem('Artist', controller.artist.value, Icons.person),
          _buildReviewItem('Type', controller.projectType.value, Icons.album),
          _buildReviewItem('Genre', controller.selectedGenre.value, Icons.category),
          _buildReviewItem('Release Date', _formatDate(controller.releaseDate.value), Icons.calendar_today),
          if (controller.description.value.isNotEmpty)
            _buildReviewItem('Description', controller.description.value, Icons.description),
          if (controller.label.value.isNotEmpty)
            _buildReviewItem('Label', controller.label.value, Icons.business),
          _buildReviewItem('Explicit', controller.isExplicit.value ? 'Yes' : 'No', Icons.warning),
        ],
      ),
    );
  }

  Widget _buildTracksPreview(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracks (${controller.tracks.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...controller.tracks.asMap().entries.map((entry) {
            final track = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? MangoPalette.grey700 : Colors.white,
                borderRadius: BorderRadius.circular(MangoRadius.sm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MangoPalette.green500,
                      borderRadius: BorderRadius.circular(MangoRadius.xs),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.titleController.text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (track.credits.isNotEmpty)
                          Text(
                            'Credits: ${track.credits.map((c) => c['name']).join(', ')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: MangoPalette.grey600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (track.duration.value > 0)
                    Text(
                      '${(track.duration.value ~/ 60)}:${(track.duration.value % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MangoPalette.grey600,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContributorsPreview(bool isDark, Color textColor) {
    return Obx(() {
      if (controller.contributors.isEmpty) {
        return const SizedBox();
      }
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contributors',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.contributors.map((contributor) {
                return Chip(
                  label: Text('${contributor['name']} (${contributor['role']})'),
                  backgroundColor: MangoPalette.green500.withOpacity(0.1),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MangoPalette.green500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: MangoPalette.grey500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (controller.currentStep.value > 0)
              ElevatedButton(
                onPressed: controller.goToPreviousStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: isDark ? Colors.white : MangoPalette.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(width: 100),

            ElevatedButton(
              onPressed: (){controller.isStepValid.value ? 
                (controller.currentStep.value == 4 ? controller.uploadAlbum : controller.goToNextStep) : null;},
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.isStepValid.value
                    ? (controller.currentStep.value == 4 ? MangoPalette.green500 : MangoPalette.green500)
                    : MangoPalette.grey500,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.md)),
              ),
              child: Text(
                controller.currentStep.value == 4 ? 'Upload Album 🚀' : 'Continue',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildModernTextField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    String initialValue = '',
    int maxLines = 1,
    bool isDark = false,
  }) {
    return TextField(
      onChanged: onChanged,
      maxLines: maxLines,
      controller: TextEditingController(text: initialValue)
        ..selection = TextSelection.collapsed(offset: initialValue.length),
      style: TextStyle(
        color: isDark ? Colors.white : MangoPalette.black,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
        ),
        prefixIcon: Icon(icon, color: MangoPalette.green500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: BorderSide(color: MangoPalette.grey400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: const BorderSide(color: MangoPalette.green500),
        ),
        filled: true,
        fillColor: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
      ),
    );
  }

  Widget _buildModernDropdown(
    String label,
    IconData icon,
    List<String> items,
    String selectedValue,
    Function(String) onChanged, {
    bool isDark = false,
  }) {
    return DropdownButtonFormField<String>(
      value: selectedValue.isEmpty ? null : selectedValue,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : MangoPalette.black,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) onChanged(newValue);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
        ),
        prefixIcon: Icon(icon, color: MangoPalette.green500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: BorderSide(color: MangoPalette.grey400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: const BorderSide(color: MangoPalette.green500),
        ),
        filled: true,
        fillColor: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(color: MangoPalette.grey400),
      ),
      child: Row(
        children: [
          Icon(icon, color: MangoPalette.green500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : MangoPalette.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: MangoPalette.green500,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTrackCreditDialog(int trackIndex, context) async {
    final roleController = TextEditingController();
    final nameController = TextEditingController();
    
    await Get.dialog(
      AlertDialog(
        title: const Text('Add Track Credit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final role = roleController.text.trim();
              final name = nameController.text.trim();
              if (role.isNotEmpty && name.isNotEmpty) {
                controller.addTrackCredit(trackIndex, role, name, context);
                Get.back();
              } else {
                UtilsService().showSnackbar('Invalid', 'Please enter both role and name', context: context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}