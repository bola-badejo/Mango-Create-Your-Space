import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; 
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';

class CreatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  Future<Map<String, dynamic>?> getCreatorProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(user.uid)
          .get();

      if (contributorDoc.exists) {
        return contributorDoc.data();
      }
      return null;
    } catch (e) {
      print('Error fetching creator profile: $e');
      return null;
    }
  }

  
  Future<String> getArtistName() async {
    final profile = await getCreatorProfile();
    
    
    final stageName = profile?['stageName'] as String?;
    final fullName = profile?['fullName'] as String?;
    
    return stageName ?? fullName ?? 'Unknown Artist';
  }

  
  Future<bool> isUserCreator() async {
    final profile = await getCreatorProfile();
    return profile?['isCreator'] == true;
  }
}

class UploadMusicController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CreatorService _creatorService = CreatorService();

  var selectedImage = Rxn<XFile>(); 
  var selectedTrack = Rxn<XFile>(); 
  var credits = <Map<String, String>>[].obs; 
  var isUploading = false.obs; 
  var selectedGenre = ''.obs; 
  var isExplicit = false.obs; 
  var releaseYear = ''.obs; 
  var mood = ''.obs; 
  var language = ''.obs; 
  var copyrightInfo = ''.obs; 
  var uploadProgress = 0.0.obs; 

  
  var webImageBytes = Rxn<Uint8List>();
  var webTrackBytes = Rxn<Uint8List>();
  String? webImageFileName;
  String? webTrackFileName;

  
  var artistName = ''.obs;
  var isCreator = false.obs;
  var isLoadingCreatorInfo = true.obs;

  
  var isTrackValid = false.obs;
  var trackError = ''.obs;

  final List<String> genres = [
    'Pop', 'Rock', 'Hip Hop', 'Jazz', 'Classical', 'Electronic', 'Blues', 'Country',
    'Reggae', 'Metal', 'Folk', 'R&B', 'Punk', 'Disco', 'Funk', 'Soul', 'Gospel',
    'Techno', 'House', 'Trance', 'Dubstep', 'Drum & Bass', 'Indie', 'Alternative',
    'K-Pop', 'J-Pop', 'Latin', 'World', 'Ambient', 'Experimental', 'Soundtrack',
    'Comedy', 'Children\'s', 'Spoken Word', 'Audiobook', 'Podcast', 'Other'
  ]; 

  final List<String> moods = [
    'Energetic', 'Calm', 'Happy', 'Sad', 'Romantic', 'Aggressive', 'Dreamy', 'Mysterious'
  ]; 

  final List<String> languages = [
    'English', 'Spanish', 'French', 'German', 'Chinese', 'Hindi', 'Japanese', 'Other'
  ]; 

  
  String title = '';
  String subtitle = ''; 
  String description = '';
  String label = '';
  
  get context => context;

  @override
  void onInit() {
    super.onInit();
    _loadCreatorInfo(context);
  }

  
  Future<void> _loadCreatorInfo(context) async {
    try {
      isLoadingCreatorInfo.value = true;
      
      
      final creatorStatus = await _creatorService.isUserCreator();
      isCreator.value = creatorStatus;
      
      if (creatorStatus) {
        
        final name = await _creatorService.getArtistName();
        artistName.value = name;
      } else {
        artistName.value = 'Unknown Artist';
        UtilsService().showSnackbar(
          'Not Registered', 
          'You need to register as a creator to upload music',
          duration: Duration(seconds: 3), context: context,
        );
      }
    } catch (e) {
      print('Error loading creator info: $e');
      artistName.value = 'Unknown Artist';
    } finally {
      isLoadingCreatorInfo.value = false;
    }
  }

  
  void setTitle(String value) => title = value;
  void setSubtitle(String value) => subtitle = value; 
  void setDescription(String value) => description = value;
  void setLabel(String value) => label = value;
  void setCopyrightInfo(String value) => copyrightInfo.value = value;

  
  void addCredit(String role, String name) {
    credits.add({'role': role, 'name': name});
  }

  
  void removeCredit(int index) {
    credits.removeAt(index);
  }

  
  Future<void> pickImage(context) async {
    try {
      if (kIsWeb) {
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          Uint8List? bytes = result.files.first.bytes;
          if (bytes != null) {
            webImageBytes.value = bytes;
            webImageFileName = result.files.first.name;
            selectedImage.value = XFile.fromData(bytes, name: webImageFileName);
          }
        }
      } else {
        
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1024,
        );
        if (image != null) {
          selectedImage.value = image;
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to pick image: ${e.toString()}', context: context);
    }
  }

  
  Future<void> pickTrack(context) async {
    try {
      if (kIsWeb) {
        
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac'],
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          Uint8List? bytes = result.files.first.bytes;
          if (bytes != null) {
            webTrackBytes.value = bytes;
            webTrackFileName = result.files.first.name;
            
            
            selectedTrack.value = XFile.fromData(bytes, name: webTrackFileName);
            await _validateTrackFileWeb(bytes, webTrackFileName!, context);
          }
        }
      } else {
        
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
        );

        if (file != null) {
          await _validateTrackFile(file, context);
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to pick track: ${e.toString()}', context: context);
    }
  }

  
  Future<void> _validateTrackFile(XFile file, context) async {
    try {
      final filePath = file.path;
      final fileName = file.name.toLowerCase();
      
      
      final allowedExtensions = ['.mp3', '.wav', '.aac', '.m4a', '.flac'];
      final hasValidExtension = allowedExtensions.any(
        (ext) => fileName.endsWith(ext)
      );

      if (!hasValidExtension) {
        trackError.value = 'Invalid file type. Please select an audio file (MP3, WAV, AAC, M4A, FLAC)';
        isTrackValid.value = false;
        return;
      }

      
      final fileSize = await file.length();
      if (fileSize > 50 * 1024 * 1024) {
        trackError.value = 'File too large. Maximum size is 50MB';
        isTrackValid.value = false;
        return;
      }

      selectedTrack.value = file;
      isTrackValid.value = true;
      trackError.value = '';
      
      UtilsService().showSnackbar('Success', 'Track selected successfully', context: context);
    } catch (e) {
      trackError.value = 'Error validating file: ${e.toString()}';
      isTrackValid.value = false;
    }
  }

  
  Future<void> _validateTrackFileWeb(Uint8List bytes, String fileName, context) async {
    try {
      final fileNameLower = fileName.toLowerCase();
      
      
      final allowedExtensions = ['.mp3', '.wav', '.aac', '.m4a', '.flac'];
      final hasValidExtension = allowedExtensions.any(
        (ext) => fileNameLower.endsWith(ext)
      );

      if (!hasValidExtension) {
        trackError.value = 'Invalid file type. Please select an audio file (MP3, WAV, AAC, M4A, FLAC)';
        isTrackValid.value = false;
        return;
      }

      
      final fileSize = bytes.length;
      if (fileSize > 50 * 1024 * 1024) {
        trackError.value = 'File too large. Maximum size is 50MB';
        isTrackValid.value = false;
        return;
      }

      isTrackValid.value = true;
      trackError.value = '';
      
      UtilsService().showSnackbar('Success', 'Track selected successfully', context: context);
    } catch (e) {
      trackError.value = 'Error validating file: ${e.toString()}';
      isTrackValid.value = false;
    }
  }

  
  Future<void> uploadMusic(context) async {
    
    if (!isCreator.value) {
      UtilsService().showSnackbar(
        'Creator Account Required', 
        'You need to register as a creator to upload music',
        duration: Duration(seconds: 3), context: context,
      );
      return;
    }

    if (!_validateForm(context)) return;

    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      
      final artworkUrl = await _uploadFile(
        onProgress: (progress) {
          uploadProgress.value = progress * 0.25;
        }
      );

      
      final trackUrl = await _uploadFile(
        isTrack: true,
        onProgress: (progress) {
          uploadProgress.value = 0.25 + (progress * 0.75);
        }
      );

      
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final fileSize = kIsWeb 
          ? (webTrackBytes.value?.length ?? 0)
          : (await selectedTrack.value!.length());
      
      final music = Music(
        id: Uuid().v4(),
        title: title,
        subtitle: subtitle.isNotEmpty ? subtitle : null,
        description: description,
        label: label,
        genre: selectedGenre.value,
        releaseYear: releaseYear.value,
        isExplicit: isExplicit.value,
        mood: mood.value,
        language: language.value,
        copyrightInfo: copyrightInfo.value,
        credits: credits.toList(),
        artworkUrl: artworkUrl,
        trackUrl: trackUrl,
        timestamp: DateTime.now(),
        plays: 0,
        likes: 0,
        duration: null,
        artistId: userId,
        artistName: artistName.value,
        fileSize: fileSize,
      );

      
      await _firestore.collection('music').doc(music.id).set(music.toFirestore());

      UtilsService().showSnackbar('Success', 'Music uploaded successfully', context: context);
      _resetForm();
      Get.back();
    } catch (e) {
      UtilsService().showSnackbar('Upload Failed', 'Error: ${e.toString()}', context: context);
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
    }
  }

  bool _validateForm(context) {
    if (title.isEmpty) {
      UtilsService().showSnackbar('Error', 'Title is required', context: context);
      return false;
    }
    if (selectedImage.value == null && webImageBytes.value == null) {
      UtilsService().showSnackbar('Error', 'Artwork is required', context: context);
      return false;
    }
    if (selectedGenre.value.isEmpty) {
      UtilsService().showSnackbar('Error', 'Genre is required', context: context);
      return false;
    }
    if (releaseYear.value.isEmpty) {
      UtilsService().showSnackbar('Error', 'Release year is required', context: context);
      return false;
    }
    if ((selectedTrack.value == null && webTrackBytes.value == null) || !isTrackValid.value) {
      UtilsService().showSnackbar('Error', 'Valid track file is required', context: context);
      return false;
    }
    return true;
  }

  
  Future<String> _uploadFile({
    required Function(double) onProgress,
    bool isTrack = false,
  }) async {
    try {
      if (kIsWeb) {
        
        if (isTrack && webTrackBytes.value == null) {
          throw Exception('No track bytes available for upload');
        }
        if (!isTrack && webImageBytes.value == null) {
          throw Exception('No image bytes available for upload');
        }

        final bytes = isTrack ? webTrackBytes.value! : webImageBytes.value!;
        final fileName = isTrack ? webTrackFileName : webImageFileName;
        final folder = isTrack ? 'tracks' : 'artwork';
        final extension = path.extension(fileName ?? '');
        
        final ref = _storage.ref().child('$folder/${Uuid().v4()}$extension');
        final task = ref.putData(
          bytes,
          SettableMetadata(
            contentType: isTrack ? _getContentType(fileName ?? '') : 'image/jpeg',
          ),
        );

        
        task.snapshotEvents.listen((taskSnapshot) {
          if (taskSnapshot.totalBytes > 0) {
            final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
            onProgress(progress);
          }
        });

        await task;
        return await ref.getDownloadURL();
      } else {
        
        final file = isTrack ? selectedTrack.value! : selectedImage.value!;
        final folder = isTrack ? 'tracks' : 'artwork';
        
        final ref = _storage.ref().child('$folder/${Uuid().v4()}${path.extension(file.path)}');
        final task = ref.putFile(
          File(file.path),
          SettableMetadata(
            contentType: _getContentType(file.path),
          ),
        );

        
        task.snapshotEvents.listen((taskSnapshot) {
          if (taskSnapshot.totalBytes > 0) {
            final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
            onProgress(progress);
          }
        });

        await task;
        return await ref.getDownloadURL();
      }
    } catch (e) {
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
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

  void _resetForm() {
    title = '';
    subtitle = '';
    description = '';
    label = '';
    selectedImage.value = null;
    selectedTrack.value = null;
    webImageBytes.value = null;
    webTrackBytes.value = null;
    webImageFileName = null;
    webTrackFileName = null;
    credits.clear();
    selectedGenre.value = '';
    isExplicit.value = false;
    releaseYear.value = '';
    mood.value = '';
    language.value = '';
    copyrightInfo.value = '';
    isTrackValid.value = false;
    trackError.value = '';
  }

  
  Future<void> refreshCreatorInfo(context) async {
    await _loadCreatorInfo(context);
  }
}