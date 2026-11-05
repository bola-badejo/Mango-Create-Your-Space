import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/utils.dart' show UtilsService;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class PodcastEpisode {
  String id;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  String filePath;
  String episodeDocId;
  RxList<Map<String, String>> credits;
  DateTime? releaseDate;

  
  Uint8List? webBytes;
  String? webFileName;

  PodcastEpisode({
    required this.id,
    String title = '',
    String description = '',
    this.filePath = '',
    this.episodeDocId = '',
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
      'episodeDocId': episodeDocId,
      'credits': credits.toList(),
      'releaseDate': releaseDate?.toIso8601String() ?? '',
    };
  }

  static PodcastEpisode fromJson(Map<String, dynamic> json) {
    return PodcastEpisode(
      id: json['id'] ?? Uuid().v4(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      filePath: json['filePath'] ?? '',
      episodeDocId: json['episodeDocId'] ?? '',
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

class UploadPodcastSeriesController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final String? contributorId;
  final String? userId;

  UploadPodcastSeriesController({this.contributorId, this.userId});

  
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  
  final seriesTitle = ''.obs;
  final host = ''.obs;
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

  
  final RxList<PodcastEpisode> episodes = <PodcastEpisode>[].obs;
  final newEpisodeTitle = ''.obs;
  final newEpisodeFilePath = ''.obs;
  Uint8List? newEpisodeWebBytes;
  String? newEpisodeWebFileName;

  
  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  
  final isCoverSelected = false.obs;
  final hasEpisodes = false.obs;
  final isDetailsComplete = false.obs;

  
  static const String _kDraftKey = 'upload_podcast_series_draft_v1';

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
    ever(host, (_) => _validateDetails());
  }

  void _validateDetails() {
    isDetailsComplete.value = seriesTitle.value.isNotEmpty && host.value.isNotEmpty;
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
        isStepValid.value = hasEpisodes.value;
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
        'host': host.value,
        'seriesGenre': seriesGenre.value,
        'seriesLanguage': seriesLanguage.value,
        'seriesReleaseDate': seriesReleaseDate.value.toIso8601String(),
        'seriesContributors': seriesContributors.toList(),
        'coverArtPath': coverArt.value?.path ?? '',
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'currentStep': currentStep.value,
      };
      await prefs.setString(_kDraftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save podcast draft: $e');
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
      host.value = data['host'] ?? '';
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
      final loadedEpisodes = (data['episodes'] as List<dynamic>?)
              ?.map((e) => PodcastEpisode.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      episodes.clear();
      for (final ep in loadedEpisodes) {
        episodes.add(ep);
      }
      hasEpisodes.value = episodes.isNotEmpty;
      currentStep.value = data['currentStep'] ?? 0;
      _validateDetails();
      _validateStep();
    } catch (e) {
      debugPrint('Failed to load podcast draft: $e');
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (e) {
      debugPrint('Failed to clear podcast draft: $e');
    }
  }

  
  void setSeriesTitle(String v) {
    seriesTitle.value = v;
    _validateDetails();
    _saveDraft();
  }

  void setHost(String v) {
    host.value = v;
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
            'Podcast series cover art selected',
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
            'Podcast series cover art selected',
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

  
  Future<void> pickEpisodeFile(context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg'],
      );
      if (result == null) return;

      final pf = result.files.first;
      if (kIsWeb) {
        if (pf.bytes != null) {
          newEpisodeWebBytes = pf.bytes;
          newEpisodeWebFileName = pf.name;
          newEpisodeFilePath.value = pf.name;
        }
      } else {
        if (pf.path != null) newEpisodeFilePath.value = pf.path!;
      }
    } catch (e) {
      UtilsService().showSnackbar('File Error', e.toString(), context: context);
    }
  }

  void addEpisode(context) {
    if (newEpisodeTitle.value.trim().isEmpty ||
        (kIsWeb ? newEpisodeWebBytes == null : newEpisodeFilePath.value.isEmpty)) {
      UtilsService().showSnackbar('Invalid', 'Episode title and audio file required', context: context);
      return;
    }
    final ep = PodcastEpisode(
      id: Uuid().v4(),
      title: newEpisodeTitle.value.trim(),
      description: '',
      filePath: kIsWeb ? '' : newEpisodeFilePath.value,
      webBytes: kIsWeb ? newEpisodeWebBytes : null,
      webFileName: kIsWeb ? newEpisodeWebFileName : null,
    );
    episodes.add(ep);
    hasEpisodes.value = true;
    _validateStep();
    newEpisodeTitle.value = '';
    newEpisodeFilePath.value = '';
    newEpisodeWebBytes = null;
    newEpisodeWebFileName = null;
    _saveDraft();

    UtilsService().showSnackbar(
      'Episode Added',
      '${ep.titleController.text} has been added',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white,
      context: context,
    );
  }

  void removeEpisode(int idx) {
    if (idx >= 0 && idx < episodes.length) {
      episodes[idx].dispose();
      episodes.removeAt(idx);
      hasEpisodes.value = episodes.isNotEmpty;
      _validateStep();
      _saveDraft();
    }
  }

  void reorderEpisodes(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = episodes.removeAt(oldIndex);
    episodes.insert(newIndex, item);
    _saveDraft();
  }

  void addEpisodeCredit(int episodeIndex, String role, String name) {
    if (episodeIndex < 0 || episodeIndex >= episodes.length) return;
    episodes[episodeIndex].credits.add({'role': role, 'name': name});
    _saveDraft();
  }

  void removeEpisodeCredit(int episodeIndex, int creditIndex) {
    if (episodeIndex < 0 || episodeIndex >= episodes.length) return;
    final c = episodes[episodeIndex].credits;
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
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'wav': return 'audio/wav';
      case 'flac': return 'audio/flac';
      case 'ogg': return 'audio/ogg';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  Future<String> _getHostName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return host.value;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? host.value;
      }
    } catch (e) {
      debugPrint('Error getting host name: $e');
    }
    return host.value;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalPodcastSeries': FieldValue.increment(1),
        'totalPodcastEpisodes': FieldValue.increment(episodes.length),
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
        'Please register as a creator first to upload podcast series.',
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

    if (seriesTitle.value.isEmpty || host.value.isEmpty || episodes.isEmpty) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Series title, host and at least one episode required',
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
          'podcast_covers',
          webCoverFileName,
        );
        coverDownloadUrl.value = coverUrl;
      }

      uploadStatus.value = 'Uploading episodes...';
      uploadProgress.value = 0.2;

      final List<Map<String, dynamic>> episodesData = [];
      final hostName = await _getHostName();

      for (int i = 0; i < episodes.length; i++) {
        final ep = episodes[i];
        uploadStatus.value = 'Uploading: ${ep.titleController.text}';

        if (kIsWeb && ep.webBytes == null) {
          throw Exception('Episode "${ep.titleController.text}" has no audio file');
        }
        if (!kIsWeb && ep.filePath.isEmpty) {
          throw Exception('Episode "${ep.titleController.text}" has no audio file');
        }

        final audioUrl = await _uploadFile(
          ep.filePath,
          ep.webBytes,
          'podcast_episodes',
          ep.webFileName,
        );

        uploadProgress.value = 0.2 + ((i + 1) / episodes.length) * 0.6;

        
        final docRef = await _firestore.collection('episodes').add({
          'title': ep.titleController.text,
          'description': ep.descriptionController.text,
          'host': hostName,  
          'credits': ep.credits.toList(),
          'audioUrl': audioUrl,
          'coverUrl': coverUrl,
          'releaseDate': ep.releaseDate ?? seriesReleaseDate.value,
          'timestamp': FieldValue.serverTimestamp(),
          'plays': 0,
          
          
          'contributorId': contributorId,
          'userId': currentUser.uid,
          'creatorId': contributorId,
        });

        ep.episodeDocId = docRef.id;

        episodesData.add({
          'episodeId': docRef.id,
          'title': ep.titleController.text,
          'order': i,
          'credits': ep.credits.toList(),
          'releaseDate': ep.releaseDate?.toIso8601String() ?? seriesReleaseDate.value.toIso8601String(),
        });

        _saveDraft();
      }

      uploadStatus.value = 'Saving series...';
      uploadProgress.value = 0.85;

      
      await _firestore.collection('podcast_series').add({
        'title': seriesTitle.value,
        'host': hostName,  
        'genre': seriesGenre.value,
        'language': seriesLanguage.value,
        'releaseDate': seriesReleaseDate.value,
        'contributors': seriesContributors.toList(),
        'coverUrl': coverUrl,
        'episodes': episodesData,
        'totalEpisodes': episodes.length,
        'timestamp': FieldValue.serverTimestamp(),
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
      });

      uploadProgress.value = 0.95;

      
      await _updateContributorStats();

      uploadProgress.value = 1.0;

      UtilsService().showSnackbar(
        '🎉 Success!',
        'Podcast series "${seriesTitle.value}" uploaded',
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
      debugPrint('Upload series error: $e\n$st');
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
    host.value = '';
    seriesGenre.value = '';
    seriesLanguage.value = '';
    seriesReleaseDate.value = DateTime.now();
    seriesContributors.clear();
    newSeriesContributor.value = '';
    coverArt.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    coverDownloadUrl.value = '';
    for (final e in episodes) e.dispose();
    episodes.clear();
    newEpisodeTitle.value = '';
    newEpisodeFilePath.value = '';
    newEpisodeWebBytes = null;
    newEpisodeWebFileName = null;
    currentStep.value = 0;
    isCoverSelected.value = false;
    hasEpisodes.value = false;
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
    for (final e in episodes) e.dispose();
    super.onClose();
  }
}

class UploadPodcastSeriesPage extends StatefulWidget {
  final String? contributorId;

  const UploadPodcastSeriesPage({super.key, this.contributorId});

  @override
  State<UploadPodcastSeriesPage> createState() => _UploadPodcastSeriesPageState();
}

class _UploadPodcastSeriesPageState extends State<UploadPodcastSeriesPage> {
  late final UploadPodcastSeriesController controller;
  final TextEditingController _seriesReleaseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(UploadPodcastSeriesController(
      contributorId: widget.contributorId,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ));
    _seriesReleaseController.text = controller.seriesReleaseDate.value.toLocal().toIso8601String().split('T').first;
  }

  @override
  void dispose() {
    _seriesReleaseController.dispose();
    Get.delete<UploadPodcastSeriesController>();
    super.dispose();
  }

  Future<bool> _showDiscardDialog(BuildContext context) async {
    if (controller.currentStep.value == 0 &&
        !controller.hasEpisodes.value &&
        controller.seriesTitle.value.isEmpty &&
        controller.host.value.isEmpty) {
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
                    'Discard Podcast Series?',
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
          title: const Text('Upload Podcast Series', style: TextStyle(fontSize: 16)),
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
                title: const Text('Episodes', style: TextStyle(fontSize: 14)),
                content: _buildEpisodesStep(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(
          () => MangoPressable(
            onTap: () => controller.pickCoverArt(context),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: MangoPalette.grey200,
                borderRadius: BorderRadius.circular(MangoRadius.sm),
                image: controller.coverArt.value != null
                    ? DecorationImage(image: FileImage(File(controller.coverArt.value!.path)), fit: BoxFit.cover)
                    : null,
                border: Border.all(
                  color: controller.isCoverSelected.value ? MangoPalette.green500 : MangoPalette.grey500,
                  width: 2,
                ),
              ),
              child: controller.coverArt.value == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 36, color: MangoPalette.grey500),
                        const SizedBox(height: 8),
                        const Text('Tap to add cover', style: TextStyle(fontSize: 12)),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: MangoPressable(
                            onTap: () => controller.removeCoverArt(),
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
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Tap to choose cover art for the series (recommended square).', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildEpisodesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFieldForNewEpisode(),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => controller.pickEpisodeFile(context),
              icon: const Icon(Icons.audiotrack),
              label: const Text('Pick Audio'),
              style: ElevatedButton.styleFrom(backgroundColor: MangoPalette.green500),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => controller.addEpisode(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Episode'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(
          () => ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.episodes.length,
            onReorder: (oldIndex, newIndex) => controller.reorderEpisodes(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final ep = controller.episodes[index];
              return Card(
                key: ValueKey(ep.id),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: ep.titleController,
                      decoration: const InputDecoration(labelText: 'Episode Title', border: OutlineInputBorder()),
                      onChanged: (_) => controller._saveDraft(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ep.descriptionController,
                      decoration: const InputDecoration(labelText: 'Episode Description', border: OutlineInputBorder()),
                      maxLines: 3,
                      onChanged: (_) => controller._saveDraft(),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text(ep.filePath.isEmpty ? 'No audio selected' : ep.filePath.split('/').last, style: const TextStyle(fontSize: 12))),
                      IconButton(
        tooltip: 'Delete',icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {
                        ep.filePath = '';
                        controller._saveDraft();
                      }),
                    ]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Episode Credits', style: TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.person_add), onPressed: () => _showAddEpisodeCreditDialog(index)),
                    ]),
                    Obx(() => Column(
                          children: ep.credits
                              .asMap()
                              .entries
                              .map((entry) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.value['role'] ?? '', style: const TextStyle(fontSize: 12)),
                                    subtitle: Text(entry.value['name'] ?? '', style: const TextStyle(fontSize: 12)),
                                    trailing: IconButton(
        tooltip: 'Delete',icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => controller.removeEpisodeCredit(index, entry.key)),
                                  ))
                              .toList(),
                        )),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(labelText: 'Episode Release Date', border: const OutlineInputBorder()),
                          controller: TextEditingController(text: ep.releaseDate != null ? ep.releaseDate!.toLocal().toIso8601String().split('T').first : ''),
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: ep.releaseDate ?? controller.seriesReleaseDate.value, firstDate: DateTime(1950), lastDate: DateTime(2100));
                            if (picked != null) {
                              ep.releaseDate = picked;
                              controller._saveDraft();
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(onPressed: () { controller.removeEpisode(index); }, icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Remove', style: TextStyle(color: Colors.red))),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldForNewEpisode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: TextEditingController(text: controller.newEpisodeTitle.value)..selection = TextSelection.collapsed(offset: controller.newEpisodeTitle.value.length),
        decoration: const InputDecoration(labelText: 'Episode Title', border: OutlineInputBorder(), isDense: true),
        onChanged: (v) => controller.newEpisodeTitle.value = v,
      ),
      const SizedBox(height: 8),
      Obx(() => Text(controller.newEpisodeFilePath.value.isEmpty ? 'No file selected' : controller.newEpisodeFilePath.value.split('/').last, style: const TextStyle(fontSize: 12))),
    ]);
  }

  Widget _buildDetailsStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildTextField('Series Title', controller.seriesTitle, onChanged: controller.setSeriesTitle),
      const SizedBox(height: 8),
      _buildTextField('Host', controller.host, onChanged: controller.setHost),
      const SizedBox(height: 8),
      _buildTextField('Genre', controller.seriesGenre, onChanged: controller.setGenre),
      const SizedBox(height: 8),
      _buildTextField('Language', controller.seriesLanguage, onChanged: controller.setLanguage),
      const SizedBox(height: 8),
      TextField(
        controller: _seriesReleaseController,
        readOnly: true,
        decoration: const InputDecoration(labelText: 'Series Release Date', border: OutlineInputBorder()),
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: controller.seriesReleaseDate.value, firstDate: DateTime(1950), lastDate: DateTime(2100));
          if (picked != null) {
            controller.setSeriesReleaseDate(picked);
            _seriesReleaseController.text = picked.toLocal().toIso8601String().split('T').first;
          }
        },
      ),
    ]);
  }

  Widget _buildContributorsStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _buildTextField('Add Contributor', controller.newSeriesContributor, onChanged: (v) => controller.newSeriesContributor.value = v)),
        IconButton(
        tooltip: 'Add',icon: const Icon(Icons.add), onPressed: controller.addSeriesContributor),
      ]),
      const SizedBox(height: 8),
      Obx(() => Wrap(spacing: 8, children: controller.seriesContributors.map((c) => Chip(label: Text(c), onDeleted: () { final idx = controller.seriesContributors.indexOf(c); if (idx>=0) controller.removeSeriesContributorAt(idx); })).toList())),
    ]);
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review your podcast series before uploading:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildReviewItem('Series', controller.seriesTitle.value),
        _buildReviewItem('Host', controller.host.value),
        _buildReviewItem('Genre', controller.seriesGenre.value),
        _buildReviewItem('Language', controller.seriesLanguage.value),
        if (controller.seriesContributors.isNotEmpty)
          _buildReviewItem('Contributors', controller.seriesContributors.join(', ')),
        const SizedBox(height: 8),
        const Text('Episodes:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...controller.episodes.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Text('${entry.key + 1}. ${entry.value.titleController.text}'),
        )),
        const SizedBox(height: 12),
        Obx(() => controller.isUploading.value
            ? Column(
                children: [
                  LinearProgressIndicator(semanticsLabel: 'Loading', value: controller.uploadProgress.value),
                  const SizedBox(height: 8),
                  Text(controller.uploadStatus.value),
                  Text('${(controller.uploadProgress.value * 100).toStringAsFixed(0)}%'),
                ],
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text('$label: $value', style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildTextField(String label, RxString value, {required Function(String) onChanged}) {
    return TextField(
      controller: TextEditingController(text: value.value)..selection = TextSelection.collapsed(offset: value.value.length),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(MangoRadius.sm)), isDense: true, filled: true, fillColor: MangoPalette.grey100),
      onChanged: (v) {
        onChanged(v);
      },
    );
  }

  Future<void> _showAddEpisodeCreditDialog(int episodeIndex) async {
    final roleController = TextEditingController();
    final nameController = TextEditingController();
    final res = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Add Episode Credit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Add')),
        ],
      ),
    );
    if (res == true) {
      final role = roleController.text.trim();
      final name = nameController.text.trim();
      if (role.isNotEmpty && name.isNotEmpty) {
        controller.addEpisodeCredit(episodeIndex, role, name);
      } else {
        UtilsService().showSnackbar('Invalid', 'Role and name required', context: context);
      }
    }
  }
}