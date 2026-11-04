import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class UploadMusicController extends GetxController {
  
  final String? contributorId;  
  final String? userId;          
  
  UploadMusicController({this.contributorId, this.userId});
  
  
  final currentStep = 0.obs;
  final uploadProgress = 0.0.obs;
  final downloadUrl = ''.obs;
  final errorMessage = ''.obs;
  final isUploading = false.obs;

  
  final title = ''.obs;
  final description = ''.obs;
  final label = ''.obs;
  final selectedGenre = ''.obs;
  final releaseYear = ''.obs;
  final isExplicit = false.obs;
  final mood = ''.obs;
  final language = ''.obs;
  final copyrightInfo = ''.obs;
  final credits = <Map<String, String>>[].obs;

  
  final selectedImage = Rxn<XFile>();
  final selectedTrackFile = Rxn<XFile>();
  
  
  Uint8List? _webImageBytes;
  Uint8List? _webTrackBytes;

  
  final isArtworkSelected = false.obs;
  final isTrackSelected = false.obs;
  final areDetailsComplete = false.obs;

  
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController labelController;
  late final TextEditingController releaseYearController;
  late final TextEditingController copyrightController;

  
  static const int maxImageSizeMB = 10;
  static const int maxAudioSizeMB = 50;
  static const int defaultDurationSec = 240;
  static const String storagePathAudios = 'audios';
  static const String storagePathArtworks = 'artworks';

  
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final List<String> genres = [
    'Pop', 'Rock', 'Hip Hop', 'Jazz', 'Classical',
    'Electronic', 'R&B', 'Alternative', 'Afrobeats', 'Amapiano',
  ];
  final List<String> moods = [
    'Energetic', 'Calm', 'Happy', 'Sad', 'Romantic', 'Dreamy', 'Mysterious',
  ];
  final List<String> languages = [
    'English', 'Spanish', 'French', 'German', 'Yoruba', 'Igbo', 'Hausa', 'Other',
  ];

  
  @override
  void onInit() {
    super.onInit();
    _initControllers();
    _setupListeners();
    _validateContributor();
  }

  void _initControllers() {
    titleController = TextEditingController(text: title.value);
    descriptionController = TextEditingController(text: description.value);
    labelController = TextEditingController(text: label.value);
    releaseYearController = TextEditingController(text: releaseYear.value);
    copyrightController = TextEditingController(text: copyrightInfo.value);
  }

  void _setupListeners() {
    titleController.addListener(() => title.value = titleController.text);
    descriptionController.addListener(() => description.value = descriptionController.text);
    labelController.addListener(() => label.value = labelController.text);
    releaseYearController.addListener(() => releaseYear.value = releaseYearController.text);
    copyrightController.addListener(() => copyrightInfo.value = copyrightController.text);
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      errorMessage.value = 'Contributor ID is required. Please register as a creator first.';
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    labelController.dispose();
    releaseYearController.dispose();
    copyrightController.dispose();
    super.onClose();
  }

  
  void _validateDetails() {
    areDetailsComplete.value =
        title.value.isNotEmpty &&
        selectedGenre.value.isNotEmpty &&
        releaseYear.value.isNotEmpty;
  }

  bool _validateAll(context) {
    
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Contributor Required',
        'Please register as a creator first to upload music.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return false;
    }

    
    if (title.value.isEmpty ||
        selectedImage.value == null ||
        selectedGenre.value.isEmpty ||
        releaseYear.value.isEmpty ||
        (selectedTrackFile.value == null && downloadUrl.value.isEmpty)) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return false;
    }
    return true;
  }

  
  Future<void> pickImage(context) async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.first.bytes != null) {
          final file = result.files.first;
          _webImageBytes = file.bytes;
          selectedImage.value = XFile.fromData(
            _webImageBytes!,
            name: file.name,
            mimeType: 'image/${file.extension}',
          );
          isArtworkSelected.value = true;
          _showSuccessSnackbar(context, 'Artwork Added', 'Image selected successfully');
        }
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1000,
          maxHeight: 1000,
          imageQuality: 85,
        );
        if (image != null) {
          selectedImage.value = image;
          _webImageBytes = await image.readAsBytes();
          isArtworkSelected.value = true;
          _showSuccessSnackbar(context, 'Artwork Added', 'Image selected successfully');
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
      _showErrorSnackbar(context, 'Error', 'Failed to select image: ${e.toString()}');
    }
  }

  
  Future<void> pickAndUploadAudio(context) async {
    if (isUploading.value) {
      _showWarningSnackbar(context, 'Upload in progress', 'Please wait...');
      return;
    }

    try {
      uploadProgress.value = 0.0;
      downloadUrl.value = '';

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'flac'],
        allowMultiple: false,
      );

      if (result == null) return;

      final file = result.files.first;

      
      if (file.size > maxAudioSizeMB * 1024 * 1024) {
        _showErrorSnackbar(context, 'File too large', 'Maximum size is ${maxAudioSizeMB}MB');
        return;
      }

      isUploading.value = true;

      if (kIsWeb) {
        if (file.bytes == null) throw Exception('No bytes available on web');
        _webTrackBytes = file.bytes;
        selectedTrackFile.value = XFile.fromData(
          _webTrackBytes!,
          name: file.name,
          mimeType: _getMimeType(file.extension ?? 'mp3'),
        );
        isTrackSelected.value = true;
        await _uploadAudioBytes(_webTrackBytes!, file.name, file.extension ?? 'mp3', context);
      } else {
        if (file.path == null) throw Exception('No file path');
        selectedTrackFile.value = XFile(file.path!);
        isTrackSelected.value = true;
        await _uploadAudioFile(file.path!, context);
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Upload Error', e.toString());
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _uploadAudioBytes(Uint8List bytes, String fileName, String ext, context) async {
    final storageRef = _storage.ref().child('$storagePathAudios/${Uuid().v4()}.$ext');
    final uploadTask = storageRef.putData(
      bytes,
      SettableMetadata(contentType: _getMimeType(ext)),
    );

    uploadTask.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
      }
    });

    await uploadTask;
    downloadUrl.value = await storageRef.getDownloadURL();
    uploadProgress.value = 1.0;
    _showSuccessSnackbar(context, 'Upload Complete', 'Track uploaded successfully');
  }

  Future<void> _uploadAudioFile(String path, context) async {
    final file = File(path);
    final ext = path.split('.').last;
    final storageRef = _storage.ref().child('$storagePathAudios/${Uuid().v4()}.$ext');
    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: _getMimeType(ext)),
    );

    uploadTask.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        uploadProgress.value = snapshot.bytesTransferred / snapshot.totalBytes;
      }
    });

    await uploadTask;
    downloadUrl.value = await storageRef.getDownloadURL();
    uploadProgress.value = 1.0;
    _showSuccessSnackbar(context, 'Upload Complete', 'Track uploaded successfully');
  }

  
  Future<int> getAudioDuration(String filePath) async {
    if (kIsWeb) return defaultDurationSec;
    final player = AudioPlayer();
    try {
      await player.setSource(DeviceFileSource(filePath));
      final duration = await player.getDuration();
      return duration?.inSeconds ?? defaultDurationSec;
    } catch (e) {
      return defaultDurationSec;
    } finally {
      player.dispose();
    }
  }

  
  Future<void> uploadMusic(context) async {
    if (isUploading.value) return;
    if (!_validateAll(context)) return;

    isUploading.value = true;
    try {
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      
      final artworkUrl = await _uploadArtwork();

      
      String trackUrl = downloadUrl.value;
      if (trackUrl.isEmpty) {
        if (kIsWeb && _webTrackBytes != null) {
          final ext = selectedTrackFile.value?.path.split('.').last ?? 'mp3';
          final ref = _storage.ref().child('$storagePathAudios/${Uuid().v4()}.$ext');
          await ref.putData(
            _webTrackBytes!,
            SettableMetadata(contentType: _getMimeType(ext)),
          );
          trackUrl = await ref.getDownloadURL();
        } else if (selectedTrackFile.value != null) {
          final path = selectedTrackFile.value!.path;
          final ext = path.split('.').last;
          final ref = _storage.ref().child('$storagePathAudios/${Uuid().v4()}.$ext');
          await ref.putFile(File(path));
          trackUrl = await ref.getDownloadURL();
        } else {
          throw Exception('No track selected');
        }
      }

      
      int durationSec = defaultDurationSec;
      if (!kIsWeb && selectedTrackFile.value != null) {
        durationSec = await getAudioDuration(selectedTrackFile.value!.path);
      }

      
      final musicData = {
        'title': title.value,
        'description': description.value,
        'label': label.value,
        'genre': selectedGenre.value,
        'releaseYear': releaseYear.value,
        'isExplicit': isExplicit.value,
        'mood': mood.value,
        'language': language.value,
        'copyrightInfo': copyrightInfo.value,
        'credits': credits.toList(),
        'artworkUrl': artworkUrl,
        'duration': durationSec,
        'trackUrl': trackUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'plays': 0,
        'likes': 0,
        
        
        'contributorId': contributorId,           
        'userId': currentUser.uid,                
        'creatorId': contributorId,               
        'artistName': await _getArtistName(),     
      };

      
      await _firestore.collection('music').add(musicData);

      
      await _updateContributorStats();

      Get.back();
      _showSuccessSnackbar(
        context,
        '🎵 Success!',
        'Your music has been uploaded successfully',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      _showErrorSnackbar(context, 'Upload Failed', e.toString());
    } finally {
      isUploading.value = false;
      reset();
    }
  }

  
  Future<String> _getArtistName() async {
    try {
      if (contributorId == null) return '';
      
      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();
      
      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? 'Unknown Artist';
      }
    } catch (e) {
      print('Error getting artist name: $e');
    }
    return 'Unknown Artist';
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null) return;
      
      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalSongs': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      
      print('Error updating contributor stats: $e');
    }
  }

  Future<String> _uploadArtwork() async {
    if (selectedImage.value == null) throw Exception('No artwork selected');
    final ref = _storage.ref().child('$storagePathArtworks/${Uuid().v4()}');

    if (kIsWeb && _webImageBytes != null) {
      await ref.putData(
        _webImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      await ref.putFile(File(selectedImage.value!.path));
    }
    return await ref.getDownloadURL();
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
    if (index >= 0 && index < credits.length) credits.removeAt(index);
  }

  
  void reset() {
    title.value = '';
    description.value = '';
    label.value = '';
    selectedGenre.value = '';
    releaseYear.value = '';
    isExplicit.value = false;
    mood.value = '';
    language.value = '';
    copyrightInfo.value = '';
    credits.clear();
    selectedImage.value = null;
    selectedTrackFile.value = null;
    _webImageBytes = null;
    _webTrackBytes = null;
    downloadUrl.value = '';
    uploadProgress.value = 0.0;
    currentStep.value = 0;
    isArtworkSelected.value = false;
    isTrackSelected.value = false;
    areDetailsComplete.value = false;

    titleController.text = '';
    descriptionController.text = '';
    labelController.text = '';
    releaseYearController.text = '';
    copyrightController.text = '';
  }

  
  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'flac': return 'audio/flac';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  void _showSuccessSnackbar(BuildContext context, String title, String message, {Duration duration = const Duration(seconds: 2)}) {
    UtilsService().showSnackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: duration,
      context: context,
    );
  }

  void _showErrorSnackbar(BuildContext context, String title, String message) {
    UtilsService().showSnackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      context: context,
    );
  }

  void _showWarningSnackbar(BuildContext context, String title, String message) {
    UtilsService().showSnackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      context: context,
    );
  }
}


class UploadSongPage extends StatefulWidget {
  final String? contributorId;  
  
  const UploadSongPage({super.key, this.contributorId});

  @override
  State<UploadSongPage> createState() => _UploadSongPageState();
}

class _UploadSongPageState extends State<UploadSongPage>
    with SingleTickerProviderStateMixin {
  late final UploadMusicController _controller;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = Get.put(UploadMusicController(
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    Get.delete<UploadMusicController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final cardColor = isDark ? Colors.grey[800]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return WillPopScope(
      onWillPop: () async => await _showExitDialog(context),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(isDark, textColor),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildHorizontalStepper(isDark),
                const SizedBox(height: 32),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Obx(() => _buildStepContent(isDark, cardColor, textColor)),
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
        'Upload Your Music',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textColor),
      actions: [
        Obx(() => _controller.isUploading.value
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: Lottie.asset('assets/loading.json', width: 30, height: 30),
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
          _buildStep(0, 'Artwork', Icons.photo_library, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Track', Icons.music_note, isDark),
          _buildStepDivider(isDark),
          _buildStep(2, 'Details', Icons.description, isDark),
          _buildStepDivider(isDark),
          _buildStep(3, 'Upload', Icons.cloud_upload, isDark),
        ],
      ),
    );
  }

  Widget _buildStep(int stepNumber, String title, IconData icon, bool isDark) {
    return Obx(() {
      final isActive = _controller.currentStep.value == stepNumber;
      final isCompleted = _controller.currentStep.value > stepNumber;
      final isAccessible = _controller.currentStep.value >= stepNumber;
      return GestureDetector(
        onTap: isAccessible ? () => _controller.currentStep.value = stepNumber : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.orange.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : (isActive ? Colors.orange : Colors.grey.withOpacity(0.2)),
                  shape: BoxShape.circle,
                ),
                child: Icon(isCompleted ? Icons.check : icon, color: Colors.white, size: 14),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(width: 16, height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]);
  }

  
  Widget _buildStepContent(bool isDark, Color cardColor, Color textColor) {
    switch (_controller.currentStep.value) {
      case 0: return _buildArtworkStep(isDark, cardColor);
      case 1: return _buildTrackStep(isDark, cardColor, textColor);
      case 2: return _buildDetailsStep(isDark, cardColor, textColor);
      case 3: return _buildReviewStep(isDark, cardColor, textColor);
      default: return const SizedBox();
    }
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Obx(
                  () => GestureDetector(
                    onTap: (){
                      _controller.pickImage(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _controller.isArtworkSelected.value ? Colors.transparent : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _controller.isArtworkSelected.value ? Colors.orange : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _controller.isArtworkSelected.value
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _buildArtworkImage(), 
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text('Add Artwork', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Upload Album Artwork', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                Text(
                  'Choose a square image for best results. Recommended: 1000x1000px',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildArtworkImage() {
    if (kIsWeb && _controller._webImageBytes != null) {
      return Image.memory(_controller._webImageBytes!, fit: BoxFit.cover);
    } else if (_controller.selectedImage.value != null) {
      return Image.file(File(_controller.selectedImage.value!.path), fit: BoxFit.cover);
    }
    return const SizedBox();
  }

  
  Widget _buildTrackStep(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Obx(
                  () => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _controller.isTrackSelected.value ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _controller.isTrackSelected.value ? Colors.green : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _controller.isTrackSelected.value ? Icons.check_circle : Icons.music_note,
                          size: 48,
                          color: _controller.isTrackSelected.value ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.isTrackSelected.value ? 'Track Ready!' : 'Upload Your Music',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.isTrackSelected.value
                              ? 'Your track has been selected and processed'
                              : 'Choose your audio file to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        if (_controller.uploadProgress.value > 0) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _controller.uploadProgress.value,
                            backgroundColor: Colors.grey[300],
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: (){_controller.isUploading.value ? null : _controller.pickAndUploadAudio(context);},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _controller.isUploading.value ? 'Uploading…' : 'Choose Audio File',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: MP3, WAV, M4A, AAC, FLAC (max 50MB)',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text('Track Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 24),
                _buildModernTextField(
                  _controller.titleController,
                  'Track Title',
                  Icons.title,
                  isDark: isDark,
                  onChanged: (_) => _controller._validateDetails(),
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  _controller.descriptionController,
                  'Description',
                  Icons.description,
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  _controller.labelController,
                  'Label',
                  Icons.business,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Genre',
                  Icons.category,
                  _controller.genres,
                  _controller.selectedGenre,
                  isDark: isDark,
                  onChanged: (_) => _controller._validateDetails(),
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  _controller.releaseYearController,
                  'Release Year',
                  Icons.calendar_today,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _controller._validateDetails(),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  'Explicit Content',
                  Icons.warning,
                  _controller.isExplicit.value,
                  (value) => _controller.isExplicit.value = value,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _buildCreditsSection(isDark, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildModernTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    bool isDark = false,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[400]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.orange)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
    );
  }

  
  Widget _buildModernDropdown(
    String label,
    IconData icon,
    List<String> items,
    RxString selectedValue, {
    bool isDark = false,
    void Function(String?)? onChanged,
  }) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: selectedValue.value.isEmpty ? null : selectedValue.value,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14)),
          );
        }).toList(),
        onChanged: (String? newValue) {
          selectedValue.value = newValue ?? '';
          onChanged?.call(newValue);
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.orange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[400]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.orange)),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        ),
      ),
    );
  }

  
  Widget _buildSwitchTile(String title, IconData icon, bool value, Function(bool) onChanged, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w500))),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.orange),
        ],
      ),
    );
  }

  
  Widget _buildCreditsSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credits & \nContributors', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                Text('Add everyone involved\nin your track', style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6))),
              ],
            ),
            _buildAddCreditButton(isDark),
          ],
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (_controller.credits.isEmpty) {
            return _buildEmptyCreditsState(isDark, textColor);
          }
          return _buildCreditsList(isDark, textColor);
        }),
      ],
    );
  }

  Widget _buildAddCreditButton(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton.icon(
        onPressed: () => _showCreditModal(),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 2,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        icon: const Icon(FontAwesomeIcons.plus, size: 14),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  Widget _buildEmptyCreditsState(bool isDark, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(FontAwesomeIcons.users, size: 48, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No credits added yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.7))),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add producers, vocalists, and contributors',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsList(bool isDark, Color textColor) {
    return Column(
      children: _controller.credits.asMap().entries.map((entry) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key('credit-${entry.key}'),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(FontAwesomeIcons.trash, color: Colors.red),
            ),
            confirmDismiss: (direction) async => await _showDeleteConfirmation(entry.key),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(_getRoleIcon(entry.value['role'] ?? ''), color: Colors.blue, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value['role'] ?? 'Unknown Role', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(entry.value['name'] ?? 'Unknown Name', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(FontAwesomeIcons.penToSquare, size: 14, color: Colors.grey.withOpacity(0.6)),
                      onPressed: () => _showCreditModal(editIndex: entry.key),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  
  void _showCreditModal({int? editIndex}) {
    final isEditing = editIndex != null;
    final credit = isEditing ? _controller.credits[editIndex] : null;
    final roleController = TextEditingController(text: credit?['role'] ?? '');
    final nameController = TextEditingController(text: credit?['name'] ?? '');

    final popularRoles = ['Producer', 'Vocalist', 'Writer', 'Guitarist', 'Engineer', 'Featured Artist'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Edit Credit' : 'Add Credit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(FontAwesomeIcons.xmark, size: 16), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: popularRoles.map((role) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(role, style: const TextStyle(fontSize: 11)),
                        onPressed: () => roleController.text = role,
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleController,
                readOnly: true,
                onTap: () => _showRoleSelection(roleController),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  hintText: 'Producer, Vocalist, etc.',
                  labelStyle: TextStyle(fontSize: 12),
                  hintStyle: TextStyle(fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Contributor name',
                  labelStyle: TextStyle(fontSize: 12),
                  hintStyle: TextStyle(fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final role = roleController.text.trim();
                    final name = nameController.text.trim();
                    if (role.isEmpty || name.isEmpty) {
                      _showErrorMessage('Please fill both fields');
                      return;
                    }
                    if (isEditing) {
                      _controller.updateCredit(editIndex, role, name);
                      _showSuccessMessage('Updated');
                    } else {
                      _controller.addCredit(role, name);
                      _showSuccessMessage('Added');
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: Text(isEditing ? 'Update Credit' : 'Add Credit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleSelection(TextEditingController roleController) {
    final popularRoles = [
      'Producer', 'Vocalist', 'Songwriter', 'Composer', 'Guitarist', 'Bassist',
      'Drummer', 'Keyboardist', 'Mixing Engineer', 'Mastering Engineer',
      'Featured Artist', 'Backing Vocalist', 'Arranger', 'Orchestrator',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularRoles.map((role) {
                return ActionChip(
                  label: Text(role),
                  onPressed: () {
                    roleController.text = role;
                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.grey.withOpacity(0.1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showCustomRoleInput(roleController);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.1), foregroundColor: Theme.of(context).textTheme.bodyLarge?.color),
                child: const Text('Custom Role'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomRoleInput(TextEditingController roleController) {
    final customController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Role'),
        content: TextField(controller: customController, decoration: const InputDecoration(hintText: 'Enter custom role', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (customController.text.trim().isNotEmpty) {
                roleController.text = customController.text.trim();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    final roleLower = role.toLowerCase();
    if (roleLower.contains('vocal') || roleLower.contains('singer')) return FontAwesomeIcons.microphone;
    if (roleLower.contains('producer')) return FontAwesomeIcons.music;
    if (roleLower.contains('writer') || roleLower.contains('composer')) return FontAwesomeIcons.pen;
    if (roleLower.contains('guitar') || roleLower.contains('bass') || roleLower.contains('drum')) return FontAwesomeIcons.guitar;
    if (roleLower.contains('engineer')) return FontAwesomeIcons.sliders;
    return FontAwesomeIcons.user;
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: Obx(
              () => Column(
                children: [
                  const Icon(Icons.task_alt, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('Ready to Upload!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(
                    'Review your track details before uploading',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11, height: 1.2),
                  ),
                  const SizedBox(height: 32),
                  _buildArtworkPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem('Title', _controller.title.value, Icons.title),
                  const SizedBox(height: 16),
                  _buildTrackPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem('Genre', _controller.selectedGenre.value, Icons.category),
                  _buildReviewItem('Release Year', _controller.releaseYear.value, Icons.calendar_today),
                  if (_controller.mood.value.isNotEmpty) _buildReviewItem('Mood', _controller.mood.value, Icons.mood),
                  if (_controller.credits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Credits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 10),
                    ..._controller.credits.map((credit) => _buildReviewItem(credit['role']!, credit['name']!, Icons.person)),
                  ],
                  const SizedBox(height: 32),
                  if (_controller.isUploading.value) Lottie.asset('assets/upload-animation.json', width: 100, height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _controller.selectedImage.value != null ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.image, color: _controller.selectedImage.value != null ? Colors.green : Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text('Artwork', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                const Spacer(),
                if (_controller.selectedImage.value != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.check, color: Colors.green, size: 10),
                        const SizedBox(width: 4),
                        Text('Ready', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedImage.value != null)
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildArtworkImage(), 
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_controller.selectedImage.value!.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Artwork selected', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(FontAwesomeIcons.trash, color: Colors.red, size: 14),
                    onPressed: () => _controller.selectedImage.value = null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              )
            else
              _buildArtworkEmptyState(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
          ),
          child: Icon(FontAwesomeIcons.image, color: Colors.grey.withOpacity(0.5), size: 24),
        ),
        const SizedBox(height: 8),
        Text('No artwork selected', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildTrackPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (_controller.selectedTrackFile.value != null || _controller.downloadUrl.value.isNotEmpty)
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FontAwesomeIcons.music,
                    color: (_controller.selectedTrackFile.value != null || _controller.downloadUrl.value.isNotEmpty) ? Colors.green : Colors.grey,
                    size: 16),
                const SizedBox(width: 8),
                Text('Audio Track', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                const Spacer(),
                if (_controller.selectedTrackFile.value != null || _controller.downloadUrl.value.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(FontAwesomeIcons.check, color: Colors.green, size: 10),
                        const SizedBox(width: 4),
                        Text('Ready', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedTrackFile.value != null || _controller.downloadUrl.value.isNotEmpty)
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(FontAwesomeIcons.music, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _controller.selectedTrackFile.value?.name ?? 'Uploaded track',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(_controller.selectedTrackFile.value != null ? 'Local file' : 'Cloud file',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(FontAwesomeIcons.trash, color: Colors.red, size: 14),
                    onPressed: () {
                      _controller.selectedTrackFile.value = null;
                      _controller.downloadUrl.value = '';
                      _controller.uploadProgress.value = 0.0;
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              )
            else
              _buildTrackEmptyState(isDark, textColor),
            if (_controller.uploadProgress.value > 0 && _controller.uploadProgress.value < 1) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _controller.uploadProgress.value, backgroundColor: Colors.grey.withOpacity(0.3), color: Colors.orange),
              const SizedBox(height: 4),
              Text('Uploading... ${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
          ),
          child: Icon(FontAwesomeIcons.music, color: Colors.grey.withOpacity(0.5), size: 24),
        ),
        const SizedBox(height: 8),
        Text('No audio file selected', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildNavigationButtons(bool isDark) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep.value > 0)
            ElevatedButton(
              onPressed: _controller.isUploading.value ? null : () => _controller.currentStep.value--,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
            )
          else
            const SizedBox(width: 100),
          ElevatedButton(
            onPressed: _canProceedToNextStep() && !_controller.isUploading.value ? _goToNextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canProceedToNextStep() && !_controller.isUploading.value ? Colors.orange : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _controller.currentStep.value == 3
                  ? (_controller.isUploading.value ? 'Uploading…' : 'Upload 🚀')
                  : 'Continue',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_controller.currentStep.value) {
      case 0: return _controller.isArtworkSelected.value;
      case 1: return _controller.isTrackSelected.value;
      case 2: return _controller.areDetailsComplete.value;
      case 3: return true;
      default: return false;
    }
  }

  void _goToNextStep() {
    if (_controller.currentStep.value < 3) {
      _controller.currentStep.value++;
    } else {
      _controller.uploadMusic(context);
    }
  }

  
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(int index) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FontAwesomeIcons.trash, color: Colors.red, size: 32),
            const SizedBox(height: 16),
            const Text('Remove Credit?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'This will remove ${_controller.credits[index]['name']} as ${_controller.credits[index]['role']}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Remove', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.4),
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
              ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(FontAwesomeIcons.circleXmark, color: Colors.red, size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Discard Upload?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your progress will be lost. This action cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6), height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                          icon: const Icon(FontAwesomeIcons.rotateLeft, size: 14),
                          label: Text('Continue', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _controller.reset();
                            Navigator.of(context).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(FontAwesomeIcons.trash, size: 14, color: Colors.white),
                          label: const Text('Discard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
}