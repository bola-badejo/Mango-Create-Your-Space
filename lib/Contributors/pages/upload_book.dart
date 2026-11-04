import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';

class UploadBookController extends GetxController {
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

  UploadBookController({this.contributorId, this.userId});

  
  var selectedImage = Rxn<XFile>();
  var isUploading = false.obs;
  var selectedGenre = ''.obs;
  var releaseYear = ''.obs;
  var language = ''.obs;
  var copyrightInfo = ''.obs;
  var selectedBookFilePath = ''.obs;

  
  Uint8List? webImageBytes;
  String? webImageFileName;
  Uint8List? webBookBytes;
  String? webBookFileName;

  
  var isArtworkSelected = false.obs;
  var isBookSelected = false.obs;
  var areDetailsComplete = false.obs;
  
  
  final RxString title = ''.obs;
  final RxString author = ''.obs;
  final RxString publisher = ''.obs;
  final RxString isbn = ''.obs;
  final RxString pages = ''.obs;
  final RxString description = ''.obs;

  final List<String> genres = [
    'Fiction', 'Non-Fiction', 'Mystery', 'Thriller', 'Romance',
    'Science Fiction', 'Fantasy', 'Biography', 'History', 'Self-Help',
    'Business', 'Children\'s', 'Poetry', 'Other',
  ];

  final List<String> languages = [
    'English', 'Spanish', 'French', 'German', 'Chinese',
    'Hindi', 'Japanese', 'Other',
  ];

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    _setupFieldListeners();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      errorMessage.value = 'Contributor ID required. Please register as a creator first.';
    }
  }

  void _setupFieldListeners() {
    
    ever(title, (_) => _validateDetails());
    ever(author, (_) => _validateDetails());
    ever(selectedGenre, (_) => _validateDetails());
    ever(releaseYear, (_) => _validateDetails());
    ever(isbn, (_) => _validateDetails());
  }

  void _validateDetails() {
    areDetailsComplete.value =
        title.value.isNotEmpty &&
        author.value.isNotEmpty &&
        selectedGenre.value.isNotEmpty &&
        releaseYear.value.isNotEmpty &&
        isbn.value.isNotEmpty;
    
    
    if (currentStep.value == 2) {
      isStepValid.value = areDetailsComplete.value;
    }
  }

  void setTitle(String value) {
    title.value = value;
  }

  void setAuthor(String value) {
    author.value = value;
  }

  void setPublisher(String value) => publisher.value = value;
  void setISBN(String value) => isbn.value = value;
  void setPages(String value) => pages.value = value;
  void setDescription(String value) => description.value = value;
  void setCopyrightInfo(String value) => copyrightInfo.value = value;

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
          
          
          if (currentStep.value == 0) {
            isStepValid.value = true;
          }

          UtilsService().showSnackbar(
            'Cover Added',
            'Book cover selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
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
          
          
          if (currentStep.value == 0) {
            isStepValid.value = true;
          }

          UtilsService().showSnackbar(
            'Cover Added',
            'Book cover selected successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
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
        'Failed to select image: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    }
  }

  Future<void> pickAndUploadBookFile(context) async {
    
    if (isUploading.value) {
      UtilsService().showSnackbar(
        'Upload in Progress',
        'Please wait for current upload to complete',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return;
    }
    
    
    if (isBookSelected.value && downloadUrl.value.isNotEmpty) {
      UtilsService().showSnackbar(
        'File Already Uploaded',
        'Book file has already been uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
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
        allowedExtensions: ['pdf', 'epub'],
        allowMultiple: false,
      );

      if (result == null) {
        isUploading.value = false;
        return;
      }

      final PlatformFile file = result.files.first;
      
      if (kIsWeb) {
        if (file.bytes != null) {
          webBookBytes = file.bytes;
          webBookFileName = file.name;
          selectedBookFilePath.value = file.name;
          isBookSelected.value = true;
          
          
          if (currentStep.value == 1) {
            isStepValid.value = true;
          }
          
          await _uploadBookFileWeb(file.bytes!, file.name, file.extension ?? 'pdf', context);
        }
      } else {
        if (file.path == null) {
          errorMessage.value = 'Invalid file path.';
          isUploading.value = false;
          return;
        }

        selectedBookFilePath.value = file.path!;
        isBookSelected.value = true;
        
        
        if (currentStep.value == 1) {
          isStepValid.value = true;
        }

        UtilsService().showSnackbar(
          'File Selected',
          'Starting upload...',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
          context: context,
        );

        final ext = file.extension ?? 'book';
        final storageRef = _storage.ref().child('books/${Uuid().v4()}.$ext');
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
          'Book file uploaded successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
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

  Future<void> _uploadBookFileWeb(Uint8List bytes, String fileName, String ext, context) async {
    try {
      UtilsService().showSnackbar(
        'File Selected',
        'Starting upload...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );

      final storageRef = _storage.ref().child('books/${Uuid().v4()}.$ext');
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
        'Book file uploaded successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
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
      case 'pdf': return 'application/pdf';
      case 'epub': return 'application/epub+zip';
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
    
    final ref = _storage.ref().child('book_covers/${Uuid().v4()}');
    
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

  Future<String> _getAuthorName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return author.value;
      
      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();
      
      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        
        return data?['stageName'] ?? data?['fullName'] ?? author.value;
      }
    } catch (e) {
      debugPrint('Error getting author name: $e');
    }
    return author.value;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;
      
      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalBooks': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadBook(context) async {
    
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Contributor Required',
        'Please register as a creator first to upload books.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
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
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    
    if (title.value.isEmpty ||
        author.value.isEmpty ||
        (selectedImage.value == null && webImageBytes == null) ||
        selectedGenre.value.isEmpty ||
        releaseYear.value.isEmpty ||
        isbn.value.isEmpty ||
        (selectedBookFilePath.value.isEmpty && downloadUrl.value.isEmpty && webBookBytes == null)) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    isUploading.value = true;
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      
      final coverUrl = await _uploadArtwork();

      
      String bookUrl = downloadUrl.value;
      if (bookUrl.isEmpty) {
        if (kIsWeb && webBookBytes != null) {
          final ext = webBookFileName?.split('.').last ?? 'pdf';
          final ref = _storage.ref().child('books/${Uuid().v4()}.$ext');
          await ref.putData(
            webBookBytes!,
            SettableMetadata(contentType: _getContentType(ext)),
          );
          bookUrl = await ref.getDownloadURL();
        } else if (selectedBookFilePath.value.isNotEmpty) {
          bookUrl = await _uploadFileFromPath(
            selectedBookFilePath.value,
            folder: 'books',
          );
        } else {
          throw Exception('No book file available');
        }
      }

      
      final authorName = await _getAuthorName();

      
      await _firestore.collection('books').add({
        'title': title.value,
        'description': description.value,
        'author': authorName,  
        'publisher': publisher.value,
        'isbn': isbn.value,
        'pages': pages.value,
        'genre': selectedGenre.value,
        'releaseYear': releaseYear.value,
        'language': language.value,
        'copyrightInfo': copyrightInfo.value,
        'coverUrl': coverUrl,
        'fileUrl': bookUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'downloads': 0,
        'likes': 0,
        'reads': 0,
        
        
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'creatorId': contributorId,
      });

      
      await _updateContributorStats();

      
      await Future.delayed(const Duration(milliseconds: 500));

      Get.back();

      UtilsService().showSnackbar(
        '📚 Success!',
        'Your book has been uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
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
    }
  }

  Future<String> _uploadFileFromPath(
    String path, {
    String folder = 'books',
  }) async {
    final ref = _storage.ref().child('$folder/${Uuid().v4()}');
    await ref.putFile(File(path));
    return await ref.getDownloadURL();
  }

  void reset() {
    title.value = '';
    description.value = '';
    author.value = '';
    publisher.value = '';
    isbn.value = '';
    pages.value = '';
    selectedImage.value = null;
    webImageBytes = null;
    webImageFileName = null;
    selectedGenre.value = '';
    releaseYear.value = '';
    language.value = '';
    copyrightInfo.value = '';
    selectedBookFilePath.value = '';
    webBookBytes = null;
    webBookFileName = null;
    downloadUrl.value = '';
    uploadProgress.value = 0.0;
    currentStep.value = 0;
    isArtworkSelected.value = false;
    isBookSelected.value = false;
    areDetailsComplete.value = false;
    isStepValid.value = false;
  }
}

class UploadBookPage extends StatefulWidget {
  final String? contributorId;
  
  const UploadBookPage({super.key, this.contributorId});

  @override
  State<UploadBookPage> createState() => _UploadBookPageState();
}

class _UploadBookPageState extends State<UploadBookPage>
    with SingleTickerProviderStateMixin {
  late final UploadBookController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(UploadBookController(
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
    Get.delete<UploadBookController>();
    super.dispose();
  }

  
  void _updateStepValidation() {
    switch (_controller.currentStep.value) {
      case 0:
        _controller.isStepValid.value = _controller.isArtworkSelected.value;
        break;
      case 1:
        _controller.isStepValid.value = _controller.isBookSelected.value;
        break;
      case 2:
        _controller.isStepValid.value = _controller.areDetailsComplete.value;
        break;
      case 3:
        _controller.isStepValid.value = true;
        break;
    }
  }

  void _goToNextStep() {
    if (_controller.currentStep.value < 3 && _controller.isStepValid.value) {
      _controller.currentStep.value++;
      _updateStepValidation();
    } else if (_controller.currentStep.value == 3) {
      _controller.uploadBook(context);
    }
  }

  void _goToPreviousStep() {
    if (_controller.currentStep.value > 0) {
      _controller.currentStep.value--;
      _updateStepValidation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final cardColor = isDark ? Colors.grey[800]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return WillPopScope(
      onWillPop: () async {
        return await _showExitDialog(context);
      },
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
        'Upload Your Book',
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
          _buildStep(0, 'Cover', Icons.photo_library, isDark),
          _buildStepDivider(isDark),
          _buildStep(1, 'Book File', Icons.book, isDark),
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
          isStepValid = _controller.isBookSelected.value;
          break;
        case 2:
          isStepValid = _controller.areDetailsComplete.value;
          break;
        case 3:
          isStepValid = true;
          break;
      }

      return GestureDetector(
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
                ? Colors.orange.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: Colors.orange.withOpacity(0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : (isActive
                            ? Colors.orange
                            : (isStepValid && stepNumber < _controller.currentStep.value
                                ? Colors.green.withOpacity(0.5)
                                : Colors.grey.withOpacity(0.2))),
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
    return Container(
      width: 16,
      height: 1,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildStepContent(bool isDark, Color cardColor, Color textColor) {
    return Obx(() {
      switch (_controller.currentStep.value) {
        case 0:
          return _buildCoverStep(isDark, cardColor);
        case 1:
          return _buildBookFileStep(isDark, cardColor, textColor);
        case 2:
          return _buildDetailsStep(isDark, cardColor, textColor);
        case 3:
          return _buildReviewStep(isDark, cardColor, textColor);
        default:
          return const SizedBox();
      }
    });
  }

  Widget _buildCoverStep(bool isDark, Color cardColor) {
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
                    onTap: () => _controller.pickImage(context),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _controller.isArtworkSelected.value
                            ? Colors.transparent
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _controller.isArtworkSelected.value
                              ? Colors.orange
                              : Colors.grey[300]!,
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
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Add Book Cover',
                                  style: TextStyle(
                                    color: Colors.grey[600],
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
                                      icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                      onPressed: () {
                                        _controller.selectedImage.value = null;
                                        _controller.isArtworkSelected.value = false;
                                        _updateStepValidation();
                                      },
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
                  'Upload Book Cover',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a rectangular image for best results. Recommended: 1000x1500px',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookFileStep(bool isDark, Color cardColor, Color textColor) {
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
                      color: _controller.isBookSelected.value
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _controller.isBookSelected.value
                            ? Colors.green
                            : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _controller.isBookSelected.value
                              ? Icons.check_circle
                              : Icons.book,
                          size: 48,
                          color: _controller.isBookSelected.value
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _controller.isBookSelected.value
                              ? 'Book File Ready!'
                              : 'Upload Your Book',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.isBookSelected.value
                              ? 'Your book file has been selected and processed'
                              : 'Choose your book file to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (_controller.uploadProgress.value > 0 && 
                            _controller.uploadProgress.value < 1) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _controller.uploadProgress.value,
                            backgroundColor: Colors.grey[300],
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                        if (_controller.downloadUrl.value.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Upload Complete ✓',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
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
                  onPressed: _controller.isUploading.value || (_controller.isBookSelected.value && _controller.downloadUrl.value.isNotEmpty)
                      ? null
                      : () => _controller.pickAndUploadBookFile(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    _controller.isUploading.value
                        ? 'Uploading...'
                        : (_controller.isBookSelected.value && _controller.downloadUrl.value.isNotEmpty
                            ? 'File Uploaded ✓'
                            : 'Choose Book File'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: PDF, EPUB',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                Text(
                  'Book Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildModernTextField(
                  'Book Title *',
                  Icons.title,
                  (value) => _controller.setTitle(value),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Author *',
                  Icons.person,
                  (value) => _controller.setAuthor(value),
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Publisher',
                  Icons.business,
                  _controller.setPublisher,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'ISBN *',
                  Icons.confirmation_number,
                  _controller.setISBN,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Pages',
                  Icons.format_list_numbered,
                  _controller.setPages,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Description',
                  Icons.description,
                  _controller.setDescription,
                  maxLines: 3,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernDropdown(
                  'Genre *',
                  Icons.category,
                  _controller.genres,
                  _controller.selectedGenre,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  'Release Year *',
                  Icons.calendar_today,
                  (value) => _controller.releaseYear.value = value,
                  isDark: isDark,
                  keyboardType: TextInputType.number,
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
                _buildModernTextField(
                  'Copyright Info',
                  Icons.copyright,
                  _controller.setCopyrightInfo,
                  isDark: isDark,
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Obx(
              () => Column(
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.green),
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
                      'Review your book details before uploading',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildCoverPreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem('Title', _controller.title.value, Icons.title),
                  _buildReviewItem('Author', _controller.author.value, Icons.person),
                  if (_controller.publisher.value.isNotEmpty)
                    _buildReviewItem('Publisher', _controller.publisher.value, Icons.business),
                  _buildReviewItem('ISBN', _controller.isbn.value, Icons.confirmation_number),
                  if (_controller.pages.value.isNotEmpty)
                    _buildReviewItem('Pages', _controller.pages.value, Icons.format_list_numbered),
                  const SizedBox(height: 16),
                  _buildBookFilePreview(isDark, textColor),
                  const SizedBox(height: 16),
                  _buildReviewItem(
                    'Genre',
                    _controller.selectedGenre.value,
                    Icons.category,
                  ),
                  _buildReviewItem(
                    'Release Year',
                    _controller.releaseYear.value,
                    Icons.calendar_today,
                  ),
                  if (_controller.language.value.isNotEmpty)
                    _buildReviewItem(
                      'Language',
                      _controller.language.value,
                      Icons.language,
                    ),
                  if (_controller.description.value.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _controller.description.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_controller.isUploading.value)
                    Lottie.asset(
                      'assets/upload-animation.json',
                      width: 100,
                      height: 100,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _controller.selectedImage.value != null
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.image,
                  color: _controller.selectedImage.value != null
                      ? Colors.green
                      : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Book Cover',
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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.check,
                          color: Colors.green,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
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
              _buildCoverImagePreview(isDark)
            else
              _buildCoverEmptyState(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImagePreview(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
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
                'Cover selected',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(FontAwesomeIcons.trash, color: Colors.red, size: 14),
          onPressed: () {
            _controller.selectedImage.value = null;
            _controller.isArtworkSelected.value = false;
            _updateStepValidation();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildCoverEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 90,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            FontAwesomeIcons.image,
            color: Colors.grey.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No cover selected',
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildBookFilePreview(bool isDark, Color textColor) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                (_controller.selectedBookFilePath.value.isNotEmpty ||
                    _controller.downloadUrl.value.isNotEmpty)
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.book,
                  color:
                      (_controller.selectedBookFilePath.value.isNotEmpty ||
                          _controller.downloadUrl.value.isNotEmpty)
                      ? Colors.green
                      : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Book File',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_controller.selectedBookFilePath.value.isNotEmpty ||
                    _controller.downloadUrl.value.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.check,
                          color: Colors.green,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_controller.selectedBookFilePath.value.isNotEmpty ||
                _controller.downloadUrl.value.isNotEmpty)
              _buildBookFilePreviewContent(isDark, textColor)
            else
              _buildBookFileEmptyState(isDark, textColor),
            if (_controller.uploadProgress.value > 0 &&
                _controller.uploadProgress.value < 1) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _controller.uploadProgress.value,
                backgroundColor: Colors.grey.withOpacity(0.3),
                color: Colors.orange,
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading... ${(_controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookFilePreviewContent(bool isDark, Color textColor) {
    final hasFile = _controller.selectedBookFilePath.value.isNotEmpty;
    final fileName = hasFile
        ? _controller.selectedBookFilePath.value.split('/').last
        : 'Uploaded book';

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(FontAwesomeIcons.book, color: Colors.orange, size: 24),
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
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(FontAwesomeIcons.trash, color: Colors.red, size: 14),
          onPressed: () {
            _controller.selectedBookFilePath.value = '';
            _controller.downloadUrl.value = '';
            _controller.uploadProgress.value = 0.0;
            _controller.isBookSelected.value = false;
            _updateStepValidation();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildBookFileEmptyState(bool isDark, Color textColor) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            FontAwesomeIcons.book,
            color: Colors.grey.withOpacity(0.5),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No book file selected',
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
              onPressed: _goToPreviousStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 100),

          ElevatedButton(
            onPressed: _canProceedToNextStep() && !_controller.isUploading.value
                ? _goToNextStep
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canProceedToNextStep() && !_controller.isUploading.value
                  ? Colors.orange
                  : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _controller.currentStep.value == 3
                  ? (_controller.isUploading.value ? 'Uploading...' : 'Upload 📚')
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

  bool _canProceedToNextStep() {
    switch (_controller.currentStep.value) {
      case 0:
        return _controller.isArtworkSelected.value;
      case 1:
        return _controller.isBookSelected.value;
      case 2:
        return _controller.areDetailsComplete.value;
      case 3:
        return true;
      default:
        return false;
    }
  }

  Widget _buildModernTextField(
    String label,
    IconData icon,
    Function(String) onChanged, {
    int maxLines = 1,
    bool isDark = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      onChanged: (value) {
        onChanged(value);
        _updateStepValidation();
      },
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange),
        ),
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
                color: isDark ? Colors.white : Colors.black,
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
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          prefixIcon: Icon(icon, color: Colors.orange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orange),
          ),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('Choose from Gallery'),
              onTap: () {
                _controller.pickImage(context);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
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
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.4),
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                      FontAwesomeIcons.circleXmark,
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
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withOpacity(0.6),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          icon: const Icon(
                            FontAwesomeIcons.rotateLeft,
                            size: 14,
                          ),
                          label: Text(
                            'Continue',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            FontAwesomeIcons.trash,
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