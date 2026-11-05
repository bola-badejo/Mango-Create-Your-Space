
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/Models/customModel/mango_movies.dart';
import 'package:mango/Movies/controller/mango_movie_manger.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img; 

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class UploadMovieController extends GetxController {
  final RxDouble uploadProgress = 0.0.obs;
  final RxString downloadUrl = ''.obs;
  final RxString errorMessage = ''.obs;
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  final ImagePicker picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final String? contributorId;
  final String? userId;

  UploadMovieController({this.contributorId, this.userId});

  
  var selectedPoster = Rxn<XFile>();
  var selectedBackdrop = Rxn<XFile>();
  var selectedTrailer = Rxn<XFile>();
  var selectedVideoFilePath = ''.obs;
  
  
  Uint8List? webPosterBytes;
  Uint8List? webBackdropBytes;
  Uint8List? webTrailerBytes;
  Uint8List? webVideoBytes;
  String? webPosterFileName;
  String? webBackdropFileName;
  String? webTrailerFileName;
  String? webVideoFileName;

  
  var isPosterSelected = false.obs;
  var isVideoSelected = false.obs;
  var areDetailsComplete = false.obs;
  var isUploading = false.obs;

  
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final directorController = TextEditingController();
  final genreController = TextEditingController();
  final releaseYearController = TextEditingController();
  final languageController = TextEditingController();
  final runtimeController = TextEditingController();
  final ratingController = TextEditingController();
  final videoQualityController = TextEditingController();
  final productionCompanyController = TextEditingController();
  final budgetController = TextEditingController();
  final revenueController = TextEditingController();
  final countryController = TextEditingController();
  final audioLanguageController = TextEditingController();

  
  final List<String> genres = [
    'Action', 'Adventure', 'Animation', 'Biography', 'Comedy', 'Crime',
    'Documentary', 'Drama', 'Family', 'Fantasy', 'History', 'Horror',
    'Musical', 'Mystery', 'Romance', 'Sci-Fi', 'Sport', 'Thriller',
    'War', 'Western', 'Other',
  ];
  
  final List<String> languages = [
    'English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese',
    'Russian', 'Chinese', 'Japanese', 'Korean', 'Hindi', 'Arabic',
    'Yoruba', 'Igbo', 'Hausa', 'Other',
  ];
  
  final List<String> popularRatings = [
    'G', 'PG', 'PG-13', 'R', 'NC-17', 'Not Rated',
  ];
  
  final List<String> videoQualities = [
    'SD (480p)', 'HD (720p)', 'Full HD (1080p)', '2K', '4K UHD', '8K',
  ];
  
  final List<String> countries = [
    'USA', 'UK', 'Canada', 'Australia', 'Nigeria', 'South Africa',
    'France', 'Germany', 'Italy', 'Spain', 'China', 'Japan', 'India',
    'Brazil', 'Mexico', 'Other',
  ];
  
  final List<String> subtitles = <String>[].obs;

  
  final credits = <Map<String, String>>[].obs;

  
  final isFeatured = false.obs;
  final hasSubtitles = false.obs;

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    titleController.addListener(_validateDetails);
    directorController.addListener(_validateDetails);
    genreController.addListener(_validateDetails);
    releaseYearController.addListener(_validateDetails);
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      errorMessage.value = 'Contributor ID required. Please register as a creator first.';
    }
  }

  void _validateDetails() {
    areDetailsComplete.value =
        titleController.text.isNotEmpty &&
        directorController.text.isNotEmpty &&
        genreController.text.isNotEmpty &&
        releaseYearController.text.isNotEmpty;
    
    if (currentStep.value == 2) {
      isStepValid.value = areDetailsComplete.value;
    }
  }

  void _validateStep() {
    switch (currentStep.value) {
      case 0:
        isStepValid.value = isPosterSelected.value;
        break;
      case 1:
        isStepValid.value = isVideoSelected.value;
        break;
      case 2:
        isStepValid.value = areDetailsComplete.value;
        break;
      case 3:
        isStepValid.value = true;
        break;
    }
  }

  
  Future<void> pickPoster(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          webPosterBytes = result.files.first.bytes;
          webPosterFileName = result.files.first.name;
          selectedPoster.value = XFile.fromData(webPosterBytes!, name: webPosterFileName);
          isPosterSelected.value = true;
          _validateStep();

          UtilsService().showSnackbar(
            'Poster Added',
            'Movie poster selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            context: context,
          );
        }
      } else {
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1000,
          maxHeight: 1500,
          imageQuality: 85,
        );
        if (image != null) {
          selectedPoster.value = image;
          isPosterSelected.value = true;
          _validateStep();

          UtilsService().showSnackbar(
            'Poster Added',
            'Movie poster selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            context: context,
          );
        }
      }
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to select poster: ${e.toString()}',
        context: context,
      );
    }
  }

  void removePoster() {
    selectedPoster.value = null;
    webPosterBytes = null;
    webPosterFileName = null;
    isPosterSelected.value = false;
    _validateStep();
  }

  void validateDetails() {
  _validateDetails();
}

  Future<void> pickBackdrop(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          webBackdropBytes = result.files.first.bytes;
          webBackdropFileName = result.files.first.name;
          selectedBackdrop.value = XFile.fromData(webBackdropBytes!, name: webBackdropFileName);
        }
      } else {
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (image != null) selectedBackdrop.value = image;
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to select backdrop: ${e.toString()}', context: context);
    }
  }

  void removeBackdrop() {
    selectedBackdrop.value = null;
    webBackdropBytes = null;
    webBackdropFileName = null;
  }

  Future<void> pickTrailer(context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb && file.bytes != null) {
          webTrailerBytes = file.bytes;
          webTrailerFileName = file.name;
          selectedTrailer.value = XFile.fromData(webTrailerBytes!, name: file.name);
        } else if (file.path != null) {
          selectedTrailer.value = XFile(file.path!);
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to select trailer: ${e.toString()}', context: context);
    }
  }

  void removeTrailer() {
    selectedTrailer.value = null;
    webTrailerBytes = null;
    webTrailerFileName = null;
  }

  
  Future<void> pickAndUploadVideo(context) async {
    if (isUploading.value) {
      UtilsService().showSnackbar(
        'Upload in Progress',
        'Please wait for current upload to complete',
        context: context,
      );
      return;
    }

    if (isVideoSelected.value && downloadUrl.value.isNotEmpty) {
      UtilsService().showSnackbar(
        'Video Already Uploaded',
        'Movie video has already been uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    try {
      uploadProgress.value = 0.0;
      downloadUrl.value = '';
      isUploading.value = true;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null) {
        isUploading.value = false;
        return;
      }

      final file = result.files.first;
      
      
      if (file.size > 5 * 1024 * 1024 * 1024) {
        UtilsService().showSnackbar(
          'File too large',
          'Maximum video size is 5GB',
          context: context,
        );
        isUploading.value = false;
        return;
      }

      if (kIsWeb) {
        if (file.bytes != null) {
          webVideoBytes = file.bytes;
          webVideoFileName = file.name;
          selectedVideoFilePath.value = file.name;
          isVideoSelected.value = true;
          _validateStep();
          await _uploadVideoWeb(file.bytes!, file.name, file.extension ?? 'mp4', context);
        }
      } else {
        if (file.path == null) {
          isUploading.value = false;
          return;
        }

        selectedVideoFilePath.value = file.path!;
        isVideoSelected.value = true;
        _validateStep();

        UtilsService().showSnackbar(
          'Video Selected',
          'Starting upload...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          context: context,
        );

        final ext = file.extension ?? 'mp4';
        final storageRef = _storage.ref().child('movies/${Uuid().v4()}.$ext');
        final uploadTask = storageRef.putFile(File(file.path!));

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
          }
        });

        await uploadTask;
        final url = await storageRef.getDownloadURL();
        downloadUrl.value = url;
        uploadProgress.value = 1.0;

        UtilsService().showSnackbar(
          'Upload Complete',
          'Movie video uploaded successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          context: context,
        );
      }
    } catch (e) {
      UtilsService().showSnackbar('Upload Error', e.toString(), context: context);
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _uploadVideoWeb(Uint8List bytes, String fileName, String ext, context) async {
    try {
      final storageRef = _storage.ref().child('movies/${Uuid().v4()}.$ext');
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(ext)),
      );

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
        }
      });

      await uploadTask;
      final url = await storageRef.getDownloadURL();
      downloadUrl.value = url;
      uploadProgress.value = 1.0;

      UtilsService().showSnackbar(
        'Upload Complete',
        'Movie video uploaded successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        context: context,
      );
    } catch (e) {
      throw e;
    }
  }

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'mkv': return 'video/x-matroska';
      case 'avi': return 'video/x-msvideo';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  
  void addCredit(String role, String name) {
    credits.add({'role': role, 'name': name});
  }

  void updateCredit(int index, String role, String name) {
    if (index >= 0 && index < credits.length) {
      credits[index] = {'role': role, 'name': name};
    }
  }

  void removeCredit(int index) {
    if (index >= 0 && index < credits.length) {
      credits.removeAt(index);
    }
  }

  
  void addSubtitle(String language) {
    if (!subtitles.contains(language)) {
      subtitles.add(language);
    }
  }

  void removeSubtitle(String language) {
    subtitles.remove(language);
  }

  
  Future<String> _uploadImage(XFile? image, Uint8List? webBytes, String folder) async {
    if (image == null && webBytes == null) return '';
    
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    
    if (kIsWeb && webBytes != null) {
      await ref.putData(webBytes, SettableMetadata(contentType: 'image/jpeg'));
    } else if (image != null) {
      await ref.putFile(File(image.path));
    } else {
      return '';
    }
    
    return await ref.getDownloadURL();
  }

  Future<String> _uploadVideo(String path, Uint8List? webBytes, String folder) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    
    if (kIsWeb && webBytes != null) {
      await ref.putData(webBytes, SettableMetadata(contentType: 'video/mp4'));
    } else if (path.isNotEmpty) {
      await ref.putFile(File(path));
    } else {
      return '';
    }
    
    return await ref.getDownloadURL();
  }

  Future<String> _getDirectorName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return directorController.text;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        return data?['stageName'] ?? data?['fullName'] ?? directorController.text;
      }
    } catch (e) {
      debugPrint('Error getting director name: $e');
    }
    return directorController.text;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalMovies': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  
  Future<void> uploadMovie(context) async {
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Creator Required',
        'Please register as a creator first to upload movies.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    if (isUploading.value) {
      UtilsService().showSnackbar(
        'Upload in Progress',
        'Please wait for current upload to complete',
        context: context,
      );
      return;
    }

    if (titleController.text.isEmpty ||
        (selectedPoster.value == null && webPosterBytes == null) ||
        directorController.text.isEmpty ||
        genreController.text.isEmpty ||
        releaseYearController.text.isEmpty ||
        (selectedVideoFilePath.value.isEmpty && downloadUrl.value.isEmpty && webVideoBytes == null)) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields',
        context: context,
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      uploadProgress.value = 0.1;

      
      final posterUrl = await _uploadImage(
        selectedPoster.value,
        webPosterBytes,
        'movie_posters',
      );

      uploadProgress.value = 0.2;

      
      final backdropUrl = await _uploadImage(
        selectedBackdrop.value,
        webBackdropBytes,
        'movie_backdrops',
      );

      uploadProgress.value = 0.3;

      
      String trailerUrl = '';
      if (selectedTrailer.value != null || webTrailerBytes != null) {
        trailerUrl = await _uploadVideo(
          selectedTrailer.value?.path ?? '',
          webTrailerBytes,
          'movie_trailers',
        );
      }

      uploadProgress.value = 0.4;

      
      String videoUrl = downloadUrl.value;
      if (videoUrl.isEmpty) {
        if (kIsWeb && webVideoBytes != null) {
          final ext = webVideoFileName?.split('.').last ?? 'mp4';
          final ref = _storage.ref().child('movies/${Uuid().v4()}.$ext');
          await ref.putData(webVideoBytes!, SettableMetadata(contentType: 'video/mp4'));
          videoUrl = await ref.getDownloadURL();
        } else if (selectedVideoFilePath.value.isNotEmpty) {
          videoUrl = await _uploadVideo(
            selectedVideoFilePath.value,
            null,
            'movies',
          );
        } else {
          throw Exception('No video file available');
        }
      }

      uploadProgress.value = 0.5;

      
      int fileSize = 0;
      if (kIsWeb && webVideoBytes != null) {
        fileSize = webVideoBytes!.length;
      } else if (selectedVideoFilePath.value.isNotEmpty) {
        final videoFile = File(selectedVideoFilePath.value);
        fileSize = await videoFile.length();
      }

      uploadProgress.value = 0.6;

      
      final directorName = await _getDirectorName();

      uploadProgress.value = 0.7;

      
      await _firestore.collection('movies').add({
        'title': titleController.text,
        'description': descriptionController.text,
        'director': directorName,
        'genre': genreController.text,
        'releaseYear': int.tryParse(releaseYearController.text) ?? 2024,
        'language': languageController.text,
        'runtime': int.tryParse(runtimeController.text) ?? 0,
        'rating': ratingController.text,
        'videoQuality': videoQualityController.text,
        'productionCompany': productionCompanyController.text,
        'budget': budgetController.text,
        'revenue': revenueController.text,
        'country': countryController.text,
        'audioLanguage': audioLanguageController.text,
        'subtitles': subtitles.toList(),
        'hasSubtitles': hasSubtitles.value,
        'credits': credits.toList(),
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'trailerUrl': trailerUrl,
        'videoUrl': videoUrl,
        'fileSize': fileSize,
        'isFeatured': isFeatured.value,
        'timestamp': FieldValue.serverTimestamp(),
        'views': 0,
        'likes': 0,
        'favorites': 0,
        'shares': 0,
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
      });

      uploadProgress.value = 0.9;

      
      await _updateContributorStats();

      uploadProgress.value = 1.0;

      Get.back();

      UtilsService().showSnackbar(
        '🎬 Success!',
        'Your movie has been uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        context: context,
      );

      reset();
    } catch (e) {
      UtilsService().showSnackbar(
        'Upload Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
    }
  }

  
  void goToNextStep() {
    if (currentStep.value < 3 && isStepValid.value) {
      currentStep.value++;
      _validateStep();
    }
  }

  void goToPreviousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      _validateStep();
    }
  }

  
  void reset() {
    titleController.clear();
    descriptionController.clear();
    directorController.clear();
    genreController.clear();
    releaseYearController.clear();
    languageController.clear();
    runtimeController.clear();
    ratingController.clear();
    videoQualityController.clear();
    productionCompanyController.clear();
    budgetController.clear();
    revenueController.clear();
    countryController.clear();
    audioLanguageController.clear();
    
    selectedPoster.value = null;
    selectedBackdrop.value = null;
    selectedTrailer.value = null;
    selectedVideoFilePath.value = '';
    
    webPosterBytes = null;
    webBackdropBytes = null;
    webTrailerBytes = null;
    webVideoBytes = null;
    webPosterFileName = null;
    webBackdropFileName = null;
    webTrailerFileName = null;
    webVideoFileName = null;
    
    credits.clear();
    subtitles.clear();
    
    isPosterSelected.value = false;
    isVideoSelected.value = false;
    areDetailsComplete.value = false;
    isFeatured.value = false;
    hasSubtitles.value = false;
    
    downloadUrl.value = '';
    uploadProgress.value = 0.0;
    currentStep.value = 0;
    isStepValid.value = false;
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    directorController.dispose();
    genreController.dispose();
    releaseYearController.dispose();
    languageController.dispose();
    runtimeController.dispose();
    ratingController.dispose();
    videoQualityController.dispose();
    productionCompanyController.dispose();
    budgetController.dispose();
    revenueController.dispose();
    countryController.dispose();
    audioLanguageController.dispose();
    super.onClose();
  }
}