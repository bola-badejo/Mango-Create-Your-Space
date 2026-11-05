import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class UploadPodcastController extends GetxController {
  final RxDouble uploadProgress = 0.0.obs;
  final RxString downloadUrl = ''.obs;
  final RxString errorMessage = ''.obs;
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  final String? contributorId;
  final String? userId;

  UploadPodcastController({this.contributorId, this.userId});

  
  var selectedImage = Rxn<XFile>();
  var isUploading = false.obs;
  var selectedCategory = ''.obs;
  var language = ''.obs;
  var explicitContent = false.obs;
  var selectedAudioPath = ''.obs;

  
  Uint8List? webImageBytes;
  String? webImageFileName;
  Uint8List? webAudioBytes;
  String? webAudioFileName;

  
  var isArtworkSelected = false.obs;
  var isAudioSelected = false.obs;
  var areDetailsComplete = false.obs;

  final List<String> categories = [
    'Education', 'Technology', 'Comedy', 'News', 'Music',
    'Health', 'Business', 'Lifestyle', 'Sports', 'True Crime',
    'Interview', 'Storytelling', 'Other',
  ];

  final List<String> languages = [
    'English', 'Spanish', 'French', 'German', 'Chinese',
    'Hindi', 'Japanese', 'Korean', 'Other',
  ];

  
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController hostController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    titleController.addListener(_validateDetails);
    hostController.addListener(_validateDetails);
    _setupFieldListeners();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      errorMessage.value = 'Contributor ID required. Please register as a creator first.';
    }
  }

  void _setupFieldListeners() {
    ever(selectedCategory, (_) => _validateDetails());
  }

  @override
  void onClose() {
    titleController.dispose();
    descriptionController.dispose();
    hostController.dispose();
    super.onClose();
  }

  void _validateDetails() {
    areDetailsComplete.value =
        titleController.text.isNotEmpty &&
        selectedCategory.value.isNotEmpty &&
        hostController.text.isNotEmpty;
    
    
    if (currentStep.value == 2) {
      isStepValid.value = areDetailsComplete.value;
    }
  }

  void _validateStep() {
    switch (currentStep.value) {
      case 0:
        isStepValid.value = isArtworkSelected.value;
        break;
      case 1:
        isStepValid.value = isAudioSelected.value;
        break;
      case 2:
        isStepValid.value = areDetailsComplete.value;
        break;
      case 3:
        isStepValid.value = true;
        break;
    }
  }

  Future<void> pickImage(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          webImageBytes = result.files.first.bytes;
          webImageFileName = result.files.first.name;
          selectedImage.value = XFile.fromData(webImageBytes!, name: webImageFileName);
          isArtworkSelected.value = true;
          _validateStep();

          UtilsService().showSnackbar(
            'Artwork Added',
            'Podcast artwork selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            context: context,
          );
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
          isArtworkSelected.value = true;
          _validateStep();

          UtilsService().showSnackbar(
            'Artwork Added',
            'Podcast artwork selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            context: context,
          );
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
      UtilsService().showSnackbar(
        'Error',
        'Failed to select artwork: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    }
  }

  void removeImage() {
    selectedImage.value = null;
    webImageBytes = null;
    webImageFileName = null;
    isArtworkSelected.value = false;
    _validateStep();
  }

  Future<void> pickAndUploadAudio(context) async {
    
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

    
    if (isAudioSelected.value && downloadUrl.value.isNotEmpty) {
      UtilsService().showSnackbar(
        'Audio Already Uploaded',
        'Podcast audio has already been uploaded',
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
      errorMessage.value = '';
      isUploading.value = true;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
        allowMultiple: false,
      );

      if (result == null) {
        isUploading.value = false;
        return;
      }

      final PlatformFile file = result.files.first;

      if (kIsWeb) {
        if (file.bytes != null) {
          webAudioBytes = file.bytes;
          webAudioFileName = file.name;
          selectedAudioPath.value = file.name;
          isAudioSelected.value = true;
          _validateStep();
          await _uploadAudioFileWeb(file.bytes!, file.name, file.extension ?? 'mp3', context);
        }
      } else {
        if (file.path == null) {
          errorMessage.value = 'Invalid file path.';
          isUploading.value = false;
          return;
        }

        selectedAudioPath.value = file.path!;
        isAudioSelected.value = true;
        _validateStep();

        UtilsService().showSnackbar(
          'Audio Selected',
          'Starting upload...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          context: context,
        );

        final ext = file.extension ?? 'audio';
        final storageRef = _storage.ref().child('podcasts/${Uuid().v4()}.$ext');
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
          'Podcast audio uploaded successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: MangoPalette.green500,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          context: context,
        );
      }
    } catch (e) {
      UtilsService().showSnackbar(
        'Upload Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        context: context,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _uploadAudioFileWeb(Uint8List bytes, String fileName, String ext, context) async {
    try {
      UtilsService().showSnackbar(
        'Audio Selected',
        'Starting upload...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );

      final storageRef = _storage.ref().child('podcasts/${Uuid().v4()}.$ext');
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
        'Podcast audio uploaded successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );
    } catch (e) {
      throw e;
    }
  }

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'wav': return 'audio/wav';
      case 'aac': return 'audio/aac';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  Future<String> _uploadArtwork() async {
    if (selectedImage.value == null && webImageBytes == null) {
      throw Exception('No artwork selected');
    }
    
    final ref = _storage.ref().child('podcast_artworks/${Uuid().v4()}');

    if (kIsWeb && webImageBytes != null) {
      await ref.putData(
        webImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      await ref.putFile(File(selectedImage.value!.path));
    }
    return await ref.getDownloadURL();
  }

  Future<String> _getHostName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return hostController.text;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? hostController.text;
      }
    } catch (e) {
      debugPrint('Error getting host name: $e');
    }
    return hostController.text;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalPodcasts': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadPodcast(context) async {
    
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Creator Required',
        'Please register as a creator first to upload podcasts.',
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

    if (titleController.text.isEmpty ||
        (selectedImage.value == null && webImageBytes == null) ||
        selectedCategory.value.isEmpty ||
        hostController.text.isEmpty ||
        (selectedAudioPath.value.isEmpty && downloadUrl.value.isEmpty && webAudioBytes == null)) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      uploadProgress.value = 0.2;

      
      final artworkUrl = await _uploadArtwork();

      uploadProgress.value = 0.4;

      
      String audioUrl = downloadUrl.value;
      if (audioUrl.isEmpty) {
        if (kIsWeb && webAudioBytes != null) {
          final ext = webAudioFileName?.split('.').last ?? 'mp3';
          final ref = _storage.ref().child('podcasts/${Uuid().v4()}.$ext');
          await ref.putData(
            webAudioBytes!,
            SettableMetadata(contentType: _getContentType(ext)),
          );
          audioUrl = await ref.getDownloadURL();
        } else if (selectedAudioPath.value.isNotEmpty) {
          audioUrl = await _uploadFileFromPath(
            selectedAudioPath.value,
            folder: 'podcasts',
          );
        } else {
          throw Exception('No audio file available');
        }
      }

      uploadProgress.value = 0.6;

      
      int fileSize = 0;
      if (kIsWeb && webAudioBytes != null) {
        fileSize = webAudioBytes!.length;
      } else if (selectedAudioPath.value.isNotEmpty) {
        final audioFile = File(selectedAudioPath.value);
        fileSize = await audioFile.length();
      }

      uploadProgress.value = 0.7;

      
      final hostName = await _getHostName();

      uploadProgress.value = 0.8;

      
      await _firestore.collection('podcasts').add({
        'title': titleController.text,
        'description': descriptionController.text,
        'host': hostName,  
        'category': selectedCategory.value,
        'language': language.value.isNotEmpty ? language.value : 'English',
        'explicitContent': explicitContent.value,
        'artworkUrl': artworkUrl,
        'audioUrl': audioUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'plays': 0,
        'likes': 0,
        'favorites': 0,
        'shares': 0,
        'downloads': 0,
        'fileSize': fileSize,
        'duration': 0,
        'isPublished': true,
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
      });

      uploadProgress.value = 0.95;

      
      await _updateContributorStats();

      uploadProgress.value = 1.0;

      
      await Future.delayed(const Duration(milliseconds: 500));

      Get.back();

      UtilsService().showSnackbar(
        '🎙️ Success!',
        'Your podcast has been uploaded',
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

  Future<String> _uploadFileFromPath(
    String path, {
    String folder = 'podcasts',
  }) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    await ref.putFile(File(path));
    return await ref.getDownloadURL();
  }

  void reset() {
    titleController.clear();
    descriptionController.clear();
    hostController.clear();
    selectedImage.value = null;
    webImageBytes = null;
    webImageFileName = null;
    selectedCategory.value = '';
    language.value = '';
    explicitContent.value = false;
    selectedAudioPath.value = '';
    webAudioBytes = null;
    webAudioFileName = null;
    downloadUrl.value = '';
    uploadProgress.value = 0.0;
    currentStep.value = 0;
    isArtworkSelected.value = false;
    isAudioSelected.value = false;
    areDetailsComplete.value = false;
    isStepValid.value = false;
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
}

class UploadPodcastPage extends StatefulWidget {
  final String? contributorId;

  const UploadPodcastPage({super.key, this.contributorId});

  @override
  State<UploadPodcastPage> createState() => _UploadPodcastPageState();
}

class _UploadPodcastPageState extends State<UploadPodcastPage>
    with SingleTickerProviderStateMixin {
  late final UploadPodcastController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(UploadPodcastController(
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
    Get.delete<UploadPodcastController>();
    super.dispose();
  }

  void _updateStepValidation() {
    _controller._validateStep();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? MangoPalette.grey900 : MangoPalette.grey50;
    final cardColor = isDark ? MangoPalette.grey800 : Colors.white;
    final textColor = isDark ? Colors.white : MangoPalette.black;

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
        'Upload Your Podcast',
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
        Obx(
          () => _controller.isUploading.value
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Lottie.asset(
                    'assets/loading.json',
                    width: 30,
                    height: 30,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildHorizontalStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(0, 'Artwork', Icons.graphic_eq, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Audio', Icons.mic, isDark),
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

      bool isStepValid = false;
      switch (stepNumber) {
        case 0:
          isStepValid = _controller.isArtworkSelected.value;
          break;
        case 1:
          isStepValid = _controller.isAudioSelected.value;
          break;
        case 2:
          isStepValid = _controller.areDetailsComplete.value;
          break;
        case 3:
          isStepValid = true;
          break;
      }

      return MangoPressable(
        onTap: isAccessible
            ? () {
                _controller.currentStep.value = stepNumber;
                _updateStepValidation();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? MangoPalette.green500.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: isActive
                ? Border.all(color: MangoPalette.green500.withOpacity(0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? MangoPalette.green500
                      : (isActive
                            ? MangoPalette.green500
                            : (isStepValid && stepNumber < _controller.currentStep.value
                                ? MangoPalette.green500.withOpacity(0.5)
                                : MangoPalette.grey500.withOpacity(0.2))),
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
      switch (_controller.currentStep.value) {
        case 0:
          return _buildArtworkStep(isDark, cardColor);
        case 1:
          return _buildAudioStep(isDark, cardColor, textColor);
        case 2:
          return _buildDetailsStep(isDark, cardColor, textColor);
        case 3:
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
                Obx(
                  () => MangoPressable(
                    onTap: _showImagePicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _controller.isArtworkSelected.value
                            ? Colors.transparent
                            : MangoPalette.grey200,
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                        border: Border.all(
                          color: _controller.isArtworkSelected.value
                              ? MangoPalette.green500
                              : MangoPalette.grey300,
                          width: 2,
                        ),
                        image: _controller.selectedImage.value != null
                            ? DecorationImage(
                                image: FileImage(
                                  File(_controller.selectedImage.value!.path),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _controller.selectedImage.value == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.podcasts,
                                  size: 48,
                                  color: MangoPalette.grey400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Add Podcast Artwork',
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
                                      onPressed: _controller.removeImage,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Upload Podcast Artwork',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : MangoPalette.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a square image for best results. Recommended: 1000x1000px',
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

  Widget _buildAudioStep(bool isDark, Color cardColor, Color textColor) {
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
                Obx(
                  () => AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _controller.isAudioSelected.value
                          ? MangoPalette.green500.withOpacity(0.1)
                          : MangoPalette.green500.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      border: Border.all(
                        color: _controller.isAudioSelected.value
                            ? MangoPalette.green500
                            : MangoPalette.green500,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _controller.isAudioSelected.value
                              ? Icons.check_circle
                              : Icons.mic,
                          size: 48,
                          color: _controller.isAudioSelected.value
                              ? MangoPalette.green500
                              : MangoPalette.green500,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.isAudioSelected.value
                              ? 'Audio Ready!'
                              : 'Upload Your Podcast',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.isAudioSelected.value
                              ? 'Your podcast audio has been selected and processed'
                              : 'Choose your audio file to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                          ),
                        ),
                        if (_controller.uploadProgress.value > 0 &&
                            _controller.uploadProgress.value < 1) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(semanticsLabel: 'Loading', 
                            value: _controller.uploadProgress.value,
                            backgroundColor: MangoPalette.grey300,
                            color: MangoPalette.green500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: MangoPalette.green500,
                            ),
                          ),
                        ],
                        if (_controller.downloadUrl.value.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MangoPalette.green500.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(MangoRadius.sm),
                            ),
                            child: const Text(
                              'Upload Complete ✓',
                              style: TextStyle(
                                fontSize: 12,
                                color: MangoPalette.green500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _controller.isUploading.value || (_controller.isAudioSelected.value && _controller.downloadUrl.value.isNotEmpty)
                      ? null
                      : () => _controller.pickAndUploadAudio(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MangoPalette.green500,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _controller.isUploading.value
                        ? 'Uploading...'
                        : (_controller.isAudioSelected.value && _controller.downloadUrl.value.isNotEmpty
                            ? 'Audio Uploaded ✓'
                            : 'Choose Audio File'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: MP3, M4A, WAV, AAC',
                  style: TextStyle(
                    color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                    fontSize: 12,
                  ),
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
                  'Podcast Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  'Podcast Title *',
                  Icons.title,
                  _controller.titleController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Description',
                  Icons.description,
                  _controller.descriptionController,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Host *',
                  Icons.person,
                  _controller.hostController,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Category *',
                  Icons.category,
                  _controller.categories,
                  _controller.selectedCategory,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Language',
                  Icons.language,
                  _controller.languages,
                  _controller.language,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  'Explicit Content',
                  Icons.warning,
                  _controller.explicitContent.value,
                  (value) => _controller.explicitContent.value = value,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Text(
                  '* Required fields',
                  style: TextStyle(
                    color: MangoPalette.grey600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            child: Obx(
              () => Column(
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
                  Center(
                    child: Text(
                      'Review your podcast details before uploading',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? MangoPalette.grey400 : MangoPalette.grey600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildArtworkPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem('Title', _controller.titleController.text, Icons.title),
                  _buildReviewItem('Host', _controller.hostController.text, Icons.person),
                  const SizedBox(height: 16),
                  _buildAudioPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    'Category',
                    _controller.selectedCategory.value,
                    Icons.category,
                  ),
                  _buildReviewItem(
                    'Language',
                    _controller.language.value.isNotEmpty ? _controller.language.value : 'Not specified',
                    Icons.language,
                  ),
                  _buildReviewItem(
                    'Explicit Content',
                    _controller.explicitContent.value ? 'Yes' : 'No',
                    Icons.warning,
                  ),
                  if (_controller.descriptionController.text.isNotEmpty)
                    _buildReviewItem(
                      'Description',
                      _controller.descriptionController.text,
                      Icons.description,
                    ),
                  const SizedBox(height: 32),
                  if (_controller.isUploading.value)
                    Column(
                      children: [
                        LinearProgressIndicator(semanticsLabel: 'Loading', value: _controller.uploadProgress.value),
                        const SizedBox(height: 8),
                        Text(
                          'Uploading... ${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
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
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: _controller.selectedImage.value != null
                ? MangoPalette.green500.withOpacity(0.3)
                : MangoPalette.grey500.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  color: _controller.selectedImage.value != null
                      ? MangoPalette.green500
                      : MangoPalette.grey500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Podcast Artwork',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedImage.value != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MangoPalette.green500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: MangoPalette.green500,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.green500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedImage.value != null)
              _buildArtworkImagePreview(isDark)
            else
              _buildArtworkEmptyState(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkImagePreview(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            image: DecorationImage(
              image: FileImage(File(_controller.selectedImage.value!.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controller.selectedImage.value!.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Artwork selected',
                style: TextStyle(fontSize: 12, color: MangoPalette.grey600),
              ),
            ],
          ),
        ),
        IconButton(
        tooltip: 'Delete',
          icon: Icon(Icons.delete, color: Colors.red, size: 14),
          onPressed: _controller.removeImage,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildArtworkEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            border: Border.all(
              color: MangoPalette.grey500.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            Icons.podcasts,
            color: MangoPalette.grey500.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No artwork selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildAudioPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? MangoPalette.grey800 : MangoPalette.grey50,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color:
                (_controller.selectedAudioPath.value.isNotEmpty ||
                    _controller.downloadUrl.value.isNotEmpty)
                ? MangoPalette.green500.withOpacity(0.3)
                : MangoPalette.grey500.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color:
                      (_controller.selectedAudioPath.value.isNotEmpty ||
                          _controller.downloadUrl.value.isNotEmpty)
                      ? MangoPalette.green500
                      : MangoPalette.grey500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Podcast Audio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedAudioPath.value.isNotEmpty ||
                    _controller.downloadUrl.value.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MangoPalette.green500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: MangoPalette.green500,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 12,
                            color: MangoPalette.green500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedAudioPath.value.isNotEmpty ||
                _controller.downloadUrl.value.isNotEmpty)
              _buildAudioFilePreview(isDark, textColor)
            else
              _buildAudioEmptyState(isDark, textColor),
            if (_controller.uploadProgress.value > 0 &&
                _controller.uploadProgress.value < 1) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(semanticsLabel: 'Loading', 
                value: _controller.uploadProgress.value,
                backgroundColor: MangoPalette.grey500.withOpacity(0.3),
                color: MangoPalette.green500,
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading... ${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: MangoPalette.green500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioFilePreview(bool isDark, Color textColor) {
    final hasFile = _controller.selectedAudioPath.value.isNotEmpty;
    final fileName = hasFile
        ? _controller.selectedAudioPath.value.split('/').last
        : 'Uploaded podcast';

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: MangoPalette.green500.withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.sm),
          ),
          child: Icon(Icons.mic, color: MangoPalette.green500, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                hasFile ? 'Local file' : 'Cloud file',
                style: TextStyle(fontSize: 12, color: MangoPalette.grey600),
              ),
            ],
          ),
        ),
        IconButton(
        tooltip: 'Delete',
          icon: Icon(Icons.delete, color: Colors.red, size: 14),
          onPressed: () {
            _controller.selectedAudioPath.value = '';
            _controller.downloadUrl.value = '';
            _controller.uploadProgress.value = 0.0;
            _controller.isAudioSelected.value = false;
            _updateStepValidation();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildAudioEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
            borderRadius: BorderRadius.circular(MangoRadius.sm),
            border: Border.all(
              color: MangoPalette.grey500.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            Icons.audio_file,
            color: MangoPalette.grey500.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No audio file selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep.value > 0)
            ElevatedButton(
              onPressed: _controller.goToPreviousStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? MangoPalette.grey700 : MangoPalette.grey200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
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
            onPressed: _controller.isStepValid.value && !_controller.isUploading.value
                ? _controller.goToNextStep
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _controller.isStepValid.value && !_controller.isUploading.value
                  ? MangoPalette.green500
                  : MangoPalette.grey500,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
            ),
            child: Text(
              _controller.currentStep.value == 3
                  ? (_controller.isUploading.value ? 'Uploading...' : 'Upload 🚀')
                  : 'Continue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool isDark = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => _updateStepValidation(),
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
    RxString selectedValue, {
    bool isDark = false,
  }) {
    return Obx(
      () => DropdownButtonFormField<String>(
        value: selectedValue.value.isEmpty ? null : selectedValue.value,
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
          selectedValue.value = newValue ?? '';
          _updateStepValidation();
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

  Widget _buildReviewItem(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MangoPalette.grey100,
        borderRadius: BorderRadius.circular(MangoRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: MangoPalette.green500, size: 20),
          const SizedBox(width: 12),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: MangoPalette.green500),
              title: const Text('Choose from Gallery'),
              onTap: () {
                _controller.pickImage(context);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: MangoPalette.green500),
              title: const Text('Take a Photo'),
              onTap: () async {
                try {
                  final image = await _controller._picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    _controller.selectedImage.value = image;
                    _controller.isArtworkSelected.value = true;
                    _updateStepValidation();
                  }
                } catch (e) {
                  UtilsService().showSnackbar('Error', 'Could not access camera', context: context);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    
    if (_controller.currentStep.value == 0 &&
        !_controller.isArtworkSelected.value &&
        !_controller.isAudioSelected.value &&
        _controller.titleController.text.isEmpty &&
        _controller.hostController.text.isEmpty) {
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
                    'Discard Upload?',
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
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 14,
                          ),
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
                            _controller.reset();
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
                          icon: const Icon(
                            Icons.delete,
                            size: 14,
                            color: Colors.white,
                          ),
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
}