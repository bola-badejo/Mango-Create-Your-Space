import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/utils.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class MoviePart {
  String id;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  String filePath;
  String partDocId;
  RxList<Map<String, String>> credits;
  DateTime? releaseDate;

  
  Uint8List? webBytes;
  String? webFileName;

  MoviePart({
    required this.id,
    String title = '',
    String description = '',
    this.filePath = '',
    this.partDocId = '',
    List<Map<String, String>>? credits,
    this.releaseDate,
    this.webBytes,
    this.webFileName,
  })  : titleController = TextEditingController(text: title),
        descriptionController = TextEditingController(text: description),
        credits = (credits ?? []).obs;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleController.text,
      'description': descriptionController.text,
      'filePath': filePath,
      'partDocId': partDocId,
      'credits': credits.toList(),
      'releaseDate': releaseDate?.toIso8601String() ?? '',
    };
  }

  static MoviePart fromJson(Map<String, dynamic> json) {
    return MoviePart(
      id: json['id'] ?? Uuid().v4(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      filePath: json['filePath'] ?? '',
      partDocId: json['partDocId'] ?? '',
      credits: (json['credits'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
      releaseDate: (json['releaseDate'] != null && (json['releaseDate'] as String).isNotEmpty)
          ? DateTime.tryParse(json['releaseDate'])
          : null,
    );
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class UploadMovieSeriesController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final String? contributorId;
  final String? userId;

  UploadMovieSeriesController({this.contributorId, this.userId});

  
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  
  final seriesTitle = ''.obs;
  final director = ''.obs;
  final seriesGenre = ''.obs;
  final seriesLanguage = ''.obs;
  final seriesReleaseDate = DateTime.now().obs;

  
  final seriesContributors = <String>[].obs;
  final newSeriesContributor = ''.obs;

  
  final ImagePicker _picker = ImagePicker();
  final coverArt = Rxn<XFile>();
  final coverDownloadUrl = ''.obs;
  Uint8List? webCoverBytes;
  String? webCoverFileName;

  
  final RxList<MoviePart> parts = <MoviePart>[].obs;
  final newPartTitle = ''.obs;
  final newPartFilePath = ''.obs;
  Uint8List? newPartWebBytes;
  String? newPartWebFileName;

  
  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  
  final isCoverSelected = false.obs;
  final hasParts = false.obs;
  final isDetailsComplete = false.obs;

  
  static const String _kDraftKey = 'upload_movie_series_draft_v1';

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    _loadDraft();
    _setupFieldListeners();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      uploadStatus.value = 'Contributor ID required. Please register as a creator first.';
    }
  }

  void _setupFieldListeners() {
    ever(seriesTitle, (_) => _validateDetails());
    ever(director, (_) => _validateDetails());
  }

  void _validateDetails() {
    isDetailsComplete.value = seriesTitle.value.isNotEmpty && director.value.isNotEmpty;
    if (currentStep.value == 2) {
      isStepValid.value = isDetailsComplete.value;
    }
  }

  void _validateStep() {
    switch (currentStep.value) {
      case 0:
        isStepValid.value = isCoverSelected.value;
        break;
      case 1:
        isStepValid.value = hasParts.value;
        break;
      case 2:
        isStepValid.value = isDetailsComplete.value;
        break;
      case 3:
        isStepValid.value = true; 
        break;
      case 4:
        isStepValid.value = true;
        break;
    }
  }

  
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'seriesTitle': seriesTitle.value,
        'director': director.value,
        'seriesGenre': seriesGenre.value,
        'seriesLanguage': seriesLanguage.value,
        'seriesReleaseDate': seriesReleaseDate.value.toIso8601String(),
        'seriesContributors': seriesContributors.toList(),
        'coverArtPath': coverArt.value?.path ?? '',
        'parts': parts.map((e) => e.toJson()).toList(),
        'currentStep': currentStep.value,
      };
      await prefs.setString(_kDraftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save movie draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kDraftKey)) return;
      final raw = prefs.getString(_kDraftKey);
      if (raw == null) return;
      final Map<String, dynamic> data = jsonDecode(raw);
      seriesTitle.value = data['seriesTitle'] ?? '';
      director.value = data['director'] ?? '';
      seriesGenre.value = data['seriesGenre'] ?? '';
      seriesLanguage.value = data['seriesLanguage'] ?? '';
      seriesReleaseDate.value =
          DateTime.tryParse(data['seriesReleaseDate'] ?? '') ?? DateTime.now();
      seriesContributors.assignAll((data['seriesContributors'] as List<dynamic>?)?.cast<String>() ?? []);
      final coverPath = data['coverArtPath'] ?? '';
      if (coverPath.isNotEmpty && File(coverPath).existsSync()) {
        coverArt.value = XFile(coverPath);
        isCoverSelected.value = true;
      }
      final loadedParts = (data['parts'] as List<dynamic>?)
              ?.map((e) => MoviePart.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      parts.clear();
      for (final p in loadedParts) {
        parts.add(p);
      }
      hasParts.value = parts.isNotEmpty;
      currentStep.value = data['currentStep'] ?? 0;
      _validateDetails();
      _validateStep();
    } catch (e) {
      debugPrint('Failed to load movie draft: $e');
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (e) {
      debugPrint('Failed to clear movie draft: $e');
    }
  }

  
  void setSeriesTitle(String v) {
    seriesTitle.value = v;
    _validateDetails();
    _saveDraft();
  }

  void setDirector(String v) {
    director.value = v;
    _validateDetails();
    _saveDraft();
  }

  void setGenre(String v) {
    seriesGenre.value = v;
    _saveDraft();
  }

  void setLanguage(String v) {
    seriesLanguage.value = v;
    _saveDraft();
  }

  void setSeriesReleaseDate(DateTime d) {
    seriesReleaseDate.value = d;
    _saveDraft();
  }

  
  void addSeriesContributor() {
    final txt = newSeriesContributor.value.trim();
    if (txt.isEmpty) return;
    seriesContributors.add(txt);
    newSeriesContributor.value = '';
    _saveDraft();
  }

  void removeSeriesContributorAt(int idx) {
    if (idx >= 0 && idx < seriesContributors.length) {
      seriesContributors.removeAt(idx);
      _saveDraft();
    }
  }

  
  Future<void> pickCoverArt(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          webCoverBytes = result.files.first.bytes;
          webCoverFileName = result.files.first.name;
          coverArt.value = XFile.fromData(webCoverBytes!, name: webCoverFileName);
          isCoverSelected.value = true;
          _validateStep();
          _saveDraft();

          UtilsService().showSnackbar(
            'Cover Added',
            'Movie series cover art selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            context: context,
          );
        }
      } else {
        final x = await _picker.pickImage(source: ImageSource.gallery);
        if (x != null) {
          coverArt.value = x;
          isCoverSelected.value = true;
          _validateStep();
          _saveDraft();

          UtilsService().showSnackbar(
            'Cover Added',
            'Movie series cover art selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            context: context,
          );
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Cover Error', e.toString(), context: context);
    }
  }

  void removeCoverArt() {
    coverArt.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    isCoverSelected.value = false;
    _validateStep();
    _saveDraft();
  }

  
  Future<void> pickPartFile(context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'mkv', 'avi', 'webm'],
      );
      if (result == null) return;

      final pf = result.files.first;
      if (kIsWeb) {
        if (pf.bytes != null) {
          newPartWebBytes = pf.bytes;
          newPartWebFileName = pf.name;
          newPartFilePath.value = pf.name;
        }
      } else {
        if (pf.path != null) newPartFilePath.value = pf.path!;
      }
    } catch (e) {
      UtilsService().showSnackbar('File Error', e.toString(), context: context);
    }
  }

  void addPart(context) {
    if (newPartTitle.value.trim().isEmpty ||
        (kIsWeb ? newPartWebBytes == null : newPartFilePath.value.isEmpty)) {
      UtilsService().showSnackbar('Invalid', 'Movie part title and video file required', context: context);
      return;
    }
    final part = MoviePart(
      id: Uuid().v4(),
      title: newPartTitle.value.trim(),
      description: '',
      filePath: kIsWeb ? '' : newPartFilePath.value,
      webBytes: kIsWeb ? newPartWebBytes : null,
      webFileName: kIsWeb ? newPartWebFileName : null,
    );
    parts.add(part);
    hasParts.value = true;
    _validateStep();
    newPartTitle.value = '';
    newPartFilePath.value = '';
    newPartWebBytes = null;
    newPartWebFileName = null;
    _saveDraft();

    UtilsService().showSnackbar(
      'Part Added',
      '${part.titleController.text} has been added',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
    );
  }

  void removePart(int idx) {
    if (idx >= 0 && idx < parts.length) {
      parts[idx].dispose();
      parts.removeAt(idx);
      hasParts.value = parts.isNotEmpty;
      _validateStep();
      _saveDraft();
    }
  }

  void reorderParts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = parts.removeAt(oldIndex);
    parts.insert(newIndex, item);
    _saveDraft();
  }

  void addPartCredit(int partIndex, String role, String name) {
    if (partIndex < 0 || partIndex >= parts.length) return;
    parts[partIndex].credits.add({'role': role, 'name': name});
    _saveDraft();
  }

  void removePartCredit(int partIndex, int creditIndex) {
    if (partIndex < 0 || partIndex >= parts.length) return;
    final c = parts[partIndex].credits;
    if (creditIndex >= 0 && creditIndex < c.length) {
      c.removeAt(creditIndex);
      _saveDraft();
    }
  }

  
  Future<String> _uploadFile(String path, Uint8List? bytes, String folder, String? fileName) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');

    if (kIsWeb && bytes != null) {
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _getContentType(fileName ?? '')),
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

    final url = await ref.getDownloadURL();
    uploadProgress.value = 0.0;
    return url;
  }

  String _getContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'mkv': return 'video/x-matroska';
      case 'avi': return 'video/x-msvideo';
      case 'webm': return 'video/webm';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  Future<String> _getDirectorName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return director.value;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? director.value;
      }
    } catch (e) {
      debugPrint('Error getting director name: $e');
    }
    return director.value;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalMovieSeries': FieldValue.increment(1),
        'totalMovieParts': FieldValue.increment(parts.length),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadSeries(context) async {
    
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Creator Required',
        'Please register as a creator first to upload movie series.',
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
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    if (seriesTitle.value.isEmpty || director.value.isEmpty || parts.isEmpty) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Series title, director and at least one movie part required',
        context: context,
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      uploadStatus.value = 'Uploading cover art...';
      uploadProgress.value = 0.1;

      
      String coverUrl = '';
      if ((coverArt.value != null) || webCoverBytes != null) {
        coverUrl = await _uploadFile(
          coverArt.value?.path ?? '',
          webCoverBytes,
          'movie_series_covers',
          webCoverFileName,
        );
        coverDownloadUrl.value = coverUrl;
      }

      uploadStatus.value = 'Uploading movie parts...';
      uploadProgress.value = 0.2;

      final List<Map<String, dynamic>> partsData = [];
      final directorName = await _getDirectorName();

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        uploadStatus.value = 'Uploading: ${part.titleController.text}';

        if (kIsWeb && part.webBytes == null) {
          throw Exception('Movie part "${part.titleController.text}" has no video file');
        }
        if (!kIsWeb && part.filePath.isEmpty) {
          throw Exception('Movie part "${part.titleController.text}" has no video file');
        }

        final videoUrl = await _uploadFile(
          part.filePath,
          part.webBytes,
          'movie_parts',
          part.webFileName,
        );

        uploadProgress.value = 0.2 + ((i + 1) / parts.length) * 0.6;

        
        final docRef = await _firestore.collection('movie_parts').add({
          'title': part.titleController.text,
          'description': part.descriptionController.text,
          'director': directorName,  
          'credits': part.credits.toList(),
          'videoUrl': videoUrl,
          'coverUrl': coverUrl,
          'releaseDate': part.releaseDate ?? seriesReleaseDate.value,
          'timestamp': FieldValue.serverTimestamp(),
          'views': 0,
          
          
          'contributorId': contributorId,
          'userId': currentUser.uid,
          'creatorId': contributorId,
        });

        part.partDocId = docRef.id;

        partsData.add({
          'partId': docRef.id,
          'title': part.titleController.text,
          'order': i,
          'credits': part.credits.toList(),
          'releaseDate': part.releaseDate?.toIso8601String() ?? seriesReleaseDate.value.toIso8601String(),
        });

        _saveDraft();
      }

      uploadStatus.value = 'Saving series...';
      uploadProgress.value = 0.85;

      
      await _firestore.collection('movie_series').add({
        'title': seriesTitle.value,
        'director': directorName,  
        'genre': seriesGenre.value,
        'language': seriesLanguage.value,
        'releaseDate': seriesReleaseDate.value,
        'contributors': seriesContributors.toList(),
        'coverUrl': coverUrl,
        'parts': partsData,
        'totalParts': parts.length,
        'timestamp': FieldValue.serverTimestamp(),
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
      });

      uploadProgress.value = 0.95;

      
      await _updateContributorStats();

      uploadProgress.value = 1.0;

      UtilsService().showSnackbar(
        '🎬 Success!',
        'Movie series "${seriesTitle.value}" uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        context: context,
      );

      await clearDraft();
      _clearAll();
      Get.back();
    } catch (e, st) {
      debugPrint('Upload movie series error: $e\n$st');
      UtilsService().showSnackbar(
        'Upload Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  void _clearAll() {
    seriesTitle.value = '';
    director.value = '';
    seriesGenre.value = '';
    seriesLanguage.value = '';
    seriesReleaseDate.value = DateTime.now();
    seriesContributors.clear();
    newSeriesContributor.value = '';
    coverArt.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    coverDownloadUrl.value = '';
    for (final p in parts) p.dispose();
    parts.clear();
    newPartTitle.value = '';
    newPartFilePath.value = '';
    newPartWebBytes = null;
    newPartWebFileName = null;
    currentStep.value = 0;
    isCoverSelected.value = false;
    hasParts.value = false;
    isDetailsComplete.value = false;
    isStepValid.value = false;
  }

  
  void goToNextStep() {
    if (currentStep.value < 4 && isStepValid.value) {
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

  @override
  void onClose() {
    for (final p in parts) p.dispose();
    super.onClose();
  }
}

class UploadMovieSeriesPage extends StatefulWidget {
  final String? contributorId;

  const UploadMovieSeriesPage({super.key, this.contributorId});

  @override
  State<UploadMovieSeriesPage> createState() => _UploadMovieSeriesPageState();
}

class _UploadMovieSeriesPageState extends State<UploadMovieSeriesPage> {
  late final UploadMovieSeriesController controller;
  final TextEditingController _seriesReleaseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(UploadMovieSeriesController(
      contributorId: widget.contributorId,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ));
    _seriesReleaseController.text = controller.seriesReleaseDate.value.toLocal().toIso8601String().split('T').first;
  }

  @override
  void dispose() {
    _seriesReleaseController.dispose();
    Get.delete<UploadMovieSeriesController>();
    super.dispose();
  }

  Future<bool> _showDiscardDialog(BuildContext context) async {
    if (controller.currentStep.value == 0 &&
        !controller.hasParts.value &&
        controller.seriesTitle.value.isEmpty &&
        controller.director.value.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          barrierColor: MangoPalette.black.withOpacity(0.4),
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(MangoRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: MangoPalette.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Discard Movie Series?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your progress will be lost. This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.md),
                            ),
                            side: BorderSide(
                              color: MangoPalette.grey500.withOpacity(0.3),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: Text(
                            'Continue',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            controller.clearDraft();
                            controller._clearAll();
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.md),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                          label: const Text(
                            'Discard',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<bool> _onWillPop() async {
    await controller._saveDraft();
    final discard = await _showDiscardDialog(context);
    if (discard) {
      await controller.clearDraft();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Movie Series', style: TextStyle(fontSize: 16)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : MangoPalette.black),
          leading: IconButton(
        tooltip: 'Back',
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : MangoPalette.black),
            onPressed: () async {
              await controller._saveDraft();
              final discard = await _showDiscardDialog(context);
              if (discard) {
                await controller.clearDraft();
                Get.back();
              }
            },
          ),
        ),
        body: Obx(
          () => Stepper(
            type: StepperType.vertical,
            currentStep: controller.currentStep.value,
            onStepContinue: controller.goToNextStep,
            onStepCancel: controller.goToPreviousStep,
            controlsBuilder: (context, details) {
              final isLast = controller.currentStep.value == 4;
              return Row(
                children: [
                  ElevatedButton(
                    onPressed: controller.isStepValid.value && !controller.isUploading.value
                        ? details.onStepContinue
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLast ? MangoPalette.green500 : MangoPalette.green500,
                    ),
                    child: Obx(() => controller.isUploading.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(semanticsLabel: 'Loading', strokeWidth: 2, color: Colors.white))
                        : Text(isLast ? 'Upload Series' : 'Next')),
                  ),
                  const SizedBox(width: 8),
                  if (controller.currentStep.value > 0)
                    TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                ],
              );
            },
            steps: [
              Step(
                title: const Text('Cover Art', style: TextStyle(fontSize: 14)),
                content: _buildCoverStep(),
                isActive: controller.currentStep.value >= 0,
                state: controller.currentStep.value > 0 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Movie Parts', style: TextStyle(fontSize: 14)),
                content: _buildPartsStep(),
                isActive: controller.currentStep.value >= 1,
                state: controller.currentStep.value > 1 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Series Details', style: TextStyle(fontSize: 14)),
                content: _buildDetailsStep(),
                isActive: controller.currentStep.value >= 2,
                state: controller.currentStep.value > 2 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Contributors', style: TextStyle(fontSize: 14)),
                content: _buildContributorsStep(),
                isActive: controller.currentStep.value >= 3,
                state: controller.currentStep.value > 3 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Review & Upload', style: TextStyle(fontSize: 14)),
                content: _buildReviewStep(),
                isActive: controller.currentStep.value >= 4,
                state: controller.currentStep.value > 4 ? StepState.complete : StepState.indexed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverStep() {
    return Column(
      children: [
        Obx(() {
          final art = controller.coverArt.value;
          if (art != null) {
            return Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(File(art.path), width: 120, height: 120, fit: BoxFit.cover),
                Positioned(
                  top: 0,
                  right: 0,
                  child: MangoPressable(
                    onTap: controller.removeCoverArt,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: MangoPalette.grey200,
              borderRadius: BorderRadius.circular(MangoRadius.sm),
              border: Border.all(
                color: controller.isCoverSelected.value ? MangoPalette.green500 : MangoPalette.grey500,
                width: 2,
              ),
            ),
            child: const Icon(Icons.image, size: 60, color: MangoPalette.grey500),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => controller.pickCoverArt(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Pick Cover Art'),
        ),
      ],
    );
  }

  Widget _buildPartsStep() {
    return Column(
      children: [
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MangoPalette.grey100,
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => controller.newPartTitle.value = v,
                decoration: const InputDecoration(labelText: 'New Part Title *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => controller.pickPartFile(context),
                      icon: const Icon(Icons.video_file),
                      label: const Text('Pick Video'),
                      style: ElevatedButton.styleFrom(backgroundColor: MangoPalette.green500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Obx(() => Text(
                      controller.newPartFilePath.value.isEmpty
                          ? 'No file selected'
                          : controller.newPartFilePath.value.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => controller.addPart(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Part'),
                style: ElevatedButton.styleFrom(backgroundColor: MangoPalette.green500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        
        Obx(() {
          if (controller.parts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No parts added yet. Add your first movie part above.'),
              ),
            );
          }
          return ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.parts.length,
            onReorder: (oldIndex, newIndex) => controller.reorderParts(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final part = controller.parts[index];
              return Card(
                key: ValueKey(part.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.movie, color: MangoPalette.green500),
                  title: Text(part.titleController.text),
                  subtitle: Text(part.filePath.split('/').last),
                  trailing: IconButton(
        tooltip: 'Delete',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => controller.removePart(index),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      children: [
        TextField(
          onChanged: controller.setSeriesTitle,
          decoration: const InputDecoration(labelText: 'Series Title *'),
          controller: TextEditingController(text: controller.seriesTitle.value),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: controller.setDirector,
          decoration: const InputDecoration(labelText: 'Director *'),
          controller: TextEditingController(text: controller.director.value),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: controller.setGenre,
          decoration: const InputDecoration(labelText: 'Genre'),
          controller: TextEditingController(text: controller.seriesGenre.value),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: controller.setLanguage,
          decoration: const InputDecoration(labelText: 'Language'),
          controller: TextEditingController(text: controller.seriesLanguage.value),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _seriesReleaseController,
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Release Date'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: controller.seriesReleaseDate.value,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              controller.setSeriesReleaseDate(picked);
              _seriesReleaseController.text = picked.toLocal().toIso8601String().split('T').first;
            }
          },
        ),
      ],
    );
  }

  Widget _buildContributorsStep() {
    return Column(
      children: [
        Obx(() {
          if (controller.seriesContributors.isNotEmpty) {
            return Column(
              children: [
                const Text('Contributors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...controller.seriesContributors.asMap().entries.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(entry.value),
                    trailing: IconButton(
        tooltip: 'Delete',
                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                      onPressed: () => controller.removeSeriesContributorAt(entry.key),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          }
          return const SizedBox.shrink();
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => controller.newSeriesContributor.value = v,
                decoration: const InputDecoration(labelText: 'Add Contributor'),
              ),
            ),
            IconButton(
        tooltip: 'Add',
              icon: const Icon(Icons.add, color: MangoPalette.green500),
              onPressed: controller.addSeriesContributor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review your movie series before uploading:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('Series Title: ${controller.seriesTitle.value}'),
        Text('Director: ${controller.director.value}'),
        Text('Genre: ${controller.seriesGenre.value}'),
        Text('Language: ${controller.seriesLanguage.value}'),
        Text('Release Date: ${controller.seriesReleaseDate.value.toLocal().toIso8601String().split('T').first}'),
        if (controller.seriesContributors.isNotEmpty)
          Text('Contributors: ${controller.seriesContributors.join(', ')}'),
        const SizedBox(height: 8),
        const Text('Parts:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...controller.parts.asMap().entries.map((entry) => Text('  ${entry.key + 1}. ${entry.value.titleController.text}')),
        const SizedBox(height: 16),
        Obx(() => controller.isUploading.value
            ? Column(
                children: [
                  LinearProgressIndicator(semanticsLabel: 'Loading', value: controller.uploadProgress.value),
                  const SizedBox(height: 8),
                  Text(controller.uploadStatus.value),
                  Text('${(controller.uploadProgress.value * 100).toStringAsFixed(0)}%'),
                ],
              )
            : const SizedBox()),
      ],
    );
  }
}