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

class ProductItem {
  String id;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  String imagePath;
  String productDocId;
  RxDouble price;
  RxInt stock;
  DateTime? releaseDate;
  List<String> tags; // Add tags to product item

  Uint8List? webBytes;
  String? webFileName;

  ProductItem({
    required this.id,
    String title = '',
    String description = '',
    this.imagePath = '',
    this.productDocId = '',
    double? price,
    int? stock,
    this.releaseDate,
    this.webBytes,
    this.webFileName,
    this.tags = const [], // Initialize tags
  })  : titleController = TextEditingController(text: title),
        descriptionController = TextEditingController(text: description),
        this.price = (price ?? 0.0).obs,
        this.stock = (stock ?? 0).obs;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': titleController.text,
      'description': descriptionController.text,
      'imagePath': imagePath,
      'productDocId': productDocId,
      'price': price.value,
      'stock': stock.value,
      'releaseDate': releaseDate?.toIso8601String() ?? '',
      'tags': tags,
    };
  }

  static ProductItem fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] ?? Uuid().v4(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imagePath: json['imagePath'] ?? '',
      productDocId: json['productDocId'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      releaseDate: (json['releaseDate'] != null && (json['releaseDate'] as String).isNotEmpty)
          ? DateTime.tryParse(json['releaseDate'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
  }
}

class UploadProductCollectionController extends GetxController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String? contributorId;
  final String? userId;

  UploadProductCollectionController({this.contributorId, this.userId});

  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  final collectionTitle = ''.obs;
  final category = ''.obs;
  final language = ''.obs;
  final collectionReleaseDate = DateTime.now().obs;

  // Tags for collection
  final collectionTags = <String>[].obs;
  final newCollectionTag = ''.obs;
  final List<String> availableCollectionTags = [
    'New Arrival',
    'Best Seller',
    'Limited Edition',
    'Seasonal',
    'Holiday Special',
    'Clearance',
    'Featured',
    'Premium',
    'Eco-Friendly',
    'Handmade',
    'Organic',
    'Sustainable',
  ];

  final suppliers = <String>[].obs;
  final newSupplier = ''.obs;

  final ImagePicker _picker = ImagePicker();
  final coverImage = Rxn<XFile>();
  final coverDownloadUrl = ''.obs;
  Uint8List? webCoverBytes;
  String? webCoverFileName;

  final RxList<ProductItem> products = <ProductItem>[].obs;
  final newProductTitle = ''.obs;
  final newProductImagePath = ''.obs;
  Uint8List? newProductWebBytes;
  String? newProductWebFileName;
  
  // New product tags
  final newProductTags = <String>[].obs;
  final newProductTagInput = ''.obs;
  final List<String> availableProductTags = [
    'Electronics',
    'Fashion',
    'Home & Living',
    'Books',
    'Music',
    'Sports',
    'Toys',
    'Beauty',
    'Health',
    'Food',
    'Accessories',
    'Collectible',
    'Digital',
    'Physical',
  ];

  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;

  final isCollectionInfoComplete = false.obs;
  final isCoverSelected = false.obs;
  final hasProducts = false.obs;

  static const String _kDraftKey = 'upload_product_collection_draft_v1';

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    _loadDraft();
    _setupFieldListeners();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      uploadStatus.value = 'Contributor ID required. Please register as a vendor/creator first.';
    }
  }

  void _setupFieldListeners() {
    ever(collectionTitle, (_) => _validateCollectionInfo());
    ever(category, (_) => _validateCollectionInfo());
    ever(language, (_) => _validateCollectionInfo());
  }

  void _validateCollectionInfo() {
    isCollectionInfoComplete.value =
        collectionTitle.value.isNotEmpty &&
        category.value.isNotEmpty &&
        language.value.isNotEmpty;
    
    if (currentStep.value == 0) {
      isStepValid.value = isCollectionInfoComplete.value;
    }
  }

  void _validateStep() {
    switch (currentStep.value) {
      case 0:
        isStepValid.value = isCollectionInfoComplete.value;
        break;
      case 1:
        isStepValid.value = true; // Suppliers/Tags step
        break;
      case 2:
        isStepValid.value = isCoverSelected.value;
        break;
      case 3:
        isStepValid.value = hasProducts.value;
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
        'collectionTitle': collectionTitle.value,
        'category': category.value,
        'language': language.value,
        'collectionReleaseDate': collectionReleaseDate.value.toIso8601String(),
        'collectionTags': collectionTags.toList(),
        'suppliers': suppliers.toList(),
        'coverImagePath': coverImage.value?.path ?? '',
        'products': products.map((p) => p.toJson()).toList(),
        'currentStep': currentStep.value,
      };
      await prefs.setString(_kDraftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save product draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kDraftKey)) return;
      final raw = prefs.getString(_kDraftKey);
      if (raw == null) return;
      final Map<String, dynamic> data = jsonDecode(raw);
      collectionTitle.value = data['collectionTitle'] ?? '';
      category.value = data['category'] ?? '';
      language.value = data['language'] ?? '';
      collectionReleaseDate.value =
          DateTime.tryParse(data['collectionReleaseDate'] ?? '') ?? DateTime.now();
      collectionTags.assignAll((data['collectionTags'] as List<dynamic>?)?.cast<String>() ?? []);
      suppliers.assignAll((data['suppliers'] as List<dynamic>?)?.cast<String>() ?? []);
      final coverPath = data['coverImagePath'] ?? '';
      if (coverPath.isNotEmpty && File(coverPath).existsSync()) {
        coverImage.value = XFile(coverPath);
        isCoverSelected.value = true;
      }

      final loadedProducts = (data['products'] as List<dynamic>?)
              ?.map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      products.clear();
      for (final p in loadedProducts) {
        products.add(p);
      }
      hasProducts.value = products.isNotEmpty;

      currentStep.value = data['currentStep'] ?? 0;
      _validateCollectionInfo();
      _validateStep();
    } catch (e) {
      debugPrint('Failed to load product draft: $e');
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (e) {
      debugPrint('Failed to clear product draft: $e');
    }
  }

  // Collection methods
  void setCollectionTitle(String v) {
    collectionTitle.value = v;
    _validateCollectionInfo();
    _saveDraft();
  }

  void setCategory(String v) {
    category.value = v;
    _validateCollectionInfo();
    _saveDraft();
  }

  void setLanguage(String v) {
    language.value = v;
    _validateCollectionInfo();
    _saveDraft();
  }

  void setCollectionReleaseDate(DateTime d) {
    collectionReleaseDate.value = d;
    _saveDraft();
  }

  // Collection Tags methods
  void addCollectionTag() {
    final txt = newCollectionTag.value.trim();
    if (txt.isEmpty) return;
    if (!collectionTags.contains(txt)) {
      collectionTags.add(txt);
      newCollectionTag.value = '';
      _saveDraft();
    }
  }

  void addCollectionTagFromAvailable(String tag) {
    if (!collectionTags.contains(tag)) {
      collectionTags.add(tag);
      _saveDraft();
    }
  }

  void removeCollectionTag(int idx) {
    if (idx >= 0 && idx < collectionTags.length) {
      collectionTags.removeAt(idx);
      _saveDraft();
    }
  }

  // Suppliers methods
  void addSupplier() {
    final txt = newSupplier.value.trim();
    if (txt.isEmpty) return;
    suppliers.add(txt);
    newSupplier.value = '';
    _saveDraft();
  }

  void removeSupplierAt(int idx) {
    if (idx >= 0 && idx < suppliers.length) {
      suppliers.removeAt(idx);
      _saveDraft();
    }
  }

  // Cover image methods
  Future<void> pickCoverImage(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          webCoverBytes = result.files.first.bytes;
          webCoverFileName = result.files.first.name;
          coverImage.value = XFile.fromData(webCoverBytes!, name: webCoverFileName);
          isCoverSelected.value = true;
          _validateStep();
          _saveDraft();

          UtilsService().showSnackbar(
            'Cover Added',
            'Collection cover image selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            context: context,
          );
        }
      } else {
        final x = await _picker.pickImage(source: ImageSource.gallery);
        if (x != null) {
          coverImage.value = x;
          isCoverSelected.value = true;
          _validateStep();
          _saveDraft();

          UtilsService().showSnackbar(
            'Cover Added',
            'Collection cover image selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            context: context,
          );
        }
      }
    } catch (e) {
      UtilsService().showSnackbar('Cover Error', e.toString(), context: context);
    }
  }

  void removeCoverImage() {
    coverImage.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    isCoverSelected.value = false;
    _validateStep();
    _saveDraft();
  }

  // Product methods
  Future<void> pickProductImage(context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null) return;

      final pf = result.files.first;
      if (kIsWeb) {
        if (pf.bytes != null) {
          newProductWebBytes = pf.bytes;
          newProductWebFileName = pf.name;
          newProductImagePath.value = pf.name;
        }
      } else {
        if (pf.path != null) newProductImagePath.value = pf.path!;
      }
    } catch (e) {
      UtilsService().showSnackbar('File Error', e.toString(), context: context);
    }
  }

  void addProductTag() {
    final txt = newProductTagInput.value.trim();
    if (txt.isEmpty) return;
    if (!newProductTags.contains(txt)) {
      newProductTags.add(txt);
      newProductTagInput.value = '';
    }
  }

  void addProductTagFromAvailable(String tag) {
    if (!newProductTags.contains(tag)) {
      newProductTags.add(tag);
    }
  }

  void removeProductTag(int idx) {
    if (idx >= 0 && idx < newProductTags.length) {
      newProductTags.removeAt(idx);
    }
  }

  void addProduct(context) {
    if (newProductTitle.value.trim().isEmpty ||
        (kIsWeb ? newProductWebBytes == null : newProductImagePath.value.isEmpty)) {
      UtilsService().showSnackbar('Invalid', 'Product title and image required', context: context);
      return;
    }
    final p = ProductItem(
      id: Uuid().v4(),
      title: newProductTitle.value.trim(),
      description: '',
      imagePath: kIsWeb ? '' : newProductImagePath.value,
      webBytes: kIsWeb ? newProductWebBytes : null,
      webFileName: kIsWeb ? newProductWebFileName : null,
      tags: newProductTags.toList(),
    );
    products.add(p);
    hasProducts.value = true;
    _validateStep();
    newProductTitle.value = '';
    newProductImagePath.value = '';
    newProductWebBytes = null;
    newProductWebFileName = null;
    newProductTags.clear();
    newProductTagInput.value = '';
    _saveDraft();

    UtilsService().showSnackbar(
      'Product Added',
      '${p.titleController.text} has been added',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      context: context,
    );
  }

  void removeProduct(int idx) {
    if (idx >= 0 && idx < products.length) {
      products[idx].dispose();
      products.removeAt(idx);
      hasProducts.value = products.isNotEmpty;
      _validateStep();
      _saveDraft();
    }
  }

  void reorderProducts(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = products.removeAt(oldIndex);
    products.insert(newIndex, item);
    _saveDraft();
  }

  // Upload methods
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
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String> _getVendorName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return '';

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();
        return data?['storeName'] ?? data?['companyName'] ?? data?['fullName'] ?? '';
      }
    } catch (e) {
      debugPrint('Error getting vendor name: $e');
    }
    return '';
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore.collection('contributors').doc(contributorId);
      await contributorRef.update({
        'totalProductCollections': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadCollection(context) async {
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Vendor Required',
        'Please register as a vendor/creator first to upload product collections.',
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

    if (collectionTitle.value.isEmpty || products.isEmpty) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Collection title and at least one product required',
        context: context,
      );
      return;
    }

    isUploading.value = true;
    uploadProgress.value = 0.0;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      uploadStatus.value = 'Uploading cover image...';
      uploadProgress.value = 0.1;

      String coverUrl = '';
      if ((coverImage.value != null) || webCoverBytes != null) {
        coverUrl = await _uploadFile(
          coverImage.value?.path ?? '',
          webCoverBytes,
          'product_collection_covers',
          webCoverFileName,
        );
      }

      uploadStatus.value = 'Uploading products...';
      uploadProgress.value = 0.3;

      final List<Map<String, dynamic>> productsData = [];

      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        uploadStatus.value = 'Uploading: ${p.titleController.text}';

        if (kIsWeb && p.webBytes == null) {
          throw Exception('Product "${p.titleController.text}" has no image');
        }
        if (!kIsWeb && p.imagePath.isEmpty) {
          throw Exception('Product "${p.titleController.text}" has no image');
        }

        final imgUrl = await _uploadFile(
          p.imagePath,
          p.webBytes,
          'product_images',
          p.webFileName,
        );

        uploadProgress.value = 0.3 + ((i + 1) / products.length) * 0.4;

        final docRef = await _firestore.collection('products').add({
          'title': p.titleController.text,
          'description': p.descriptionController.text,
          'price': p.price.value,
          'stock': p.stock.value,
          'imageUrl': imgUrl,
          'tags': p.tags,
          'releaseDate': p.releaseDate ?? collectionReleaseDate.value,
          'timestamp': FieldValue.serverTimestamp(),
          'contributorId': contributorId,
          'userId': currentUser.uid,
          'vendorId': contributorId,
        });

        p.productDocId = docRef.id;

        productsData.add({
          'productId': docRef.id,
          'title': p.titleController.text,
          'order': i,
          'price': p.price.value,
          'stock': p.stock.value,
          'tags': p.tags,
          'releaseDate': p.releaseDate?.toIso8601String() ?? collectionReleaseDate.value.toIso8601String(),
        });

        _saveDraft();
      }

      uploadStatus.value = 'Saving collection...';
      uploadProgress.value = 0.8;

      final vendorName = await _getVendorName();

      await _firestore.collection('product_collections').add({
        'title': collectionTitle.value,
        'category': category.value,
        'language': language.value,
        'releaseDate': collectionReleaseDate.value,
        'tags': collectionTags.toList(),
        'suppliers': suppliers.toList(),
        'coverUrl': coverUrl,
        'products': productsData,
        'totalProducts': products.length,
        'timestamp': FieldValue.serverTimestamp(),
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'vendorId': contributorId,
        'vendorName': vendorName,
      });

      uploadProgress.value = 0.95;
      await _updateContributorStats();
      uploadProgress.value = 1.0;

      UtilsService().showSnackbar(
        '🎉 Success!',
        'Collection "${collectionTitle.value}" uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        context: context,
      );

      await clearDraft();
      _clearAll();
      Get.back();
    } catch (e, st) {
      debugPrint('Upload collection error: $e\n$st');
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
    collectionTitle.value = '';
    category.value = '';
    language.value = '';
    collectionReleaseDate.value = DateTime.now();
    collectionTags.clear();
    suppliers.clear();
    newSupplier.value = '';
    coverImage.value = null;
    webCoverBytes = null;
    webCoverFileName = null;
    coverDownloadUrl.value = '';
    for (final p in products) p.dispose();
    products.clear();
    newProductTitle.value = '';
    newProductImagePath.value = '';
    newProductWebBytes = null;
    newProductWebFileName = null;
    newProductTags.clear();
    newProductTagInput.value = '';
    currentStep.value = 0;
    isCoverSelected.value = false;
    hasProducts.value = false;
    isCollectionInfoComplete.value = false;
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
    for (final p in products) p.dispose();
    super.onClose();
  }
}

class UploadProductCollectionPage extends StatefulWidget {
  final String? contributorId;

  const UploadProductCollectionPage({super.key, this.contributorId});

  @override
  State<UploadProductCollectionPage> createState() => _UploadProductCollectionPageState();
}

class _UploadProductCollectionPageState extends State<UploadProductCollectionPage> {
  late final UploadProductCollectionController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(UploadProductCollectionController(
      contributorId: widget.contributorId,
      userId: FirebaseAuth.instance.currentUser?.uid,
    ));
  }

  @override
  void dispose() {
    Get.delete<UploadProductCollectionController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return WillPopScope(
      onWillPop: () async => await _showExitDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Product Collection'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Obx(() => Stepper(
          type: StepperType.vertical,
          currentStep: ctrl.currentStep.value,
          onStepContinue: ctrl.goToNextStep,
          onStepCancel: ctrl.goToPreviousStep,
          controlsBuilder: (context, details) {
            return Row(
              children: [
                ElevatedButton(
                  onPressed: ctrl.isStepValid.value && !ctrl.isUploading.value
                      ? details.onStepContinue
                      : null,
                  child: Text(
                    ctrl.currentStep.value == 4 ? 'Upload 🚀' : 'Next',
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              ],
            );
          },
          steps: [
            _collectionInfoStep(),
            _collectionTagsAndSuppliersStep(),
            _coverImageStep(context),
            _productsStep(context),
            _reviewUploadStep(context),
          ],
        )),
      ),
    );
  }

  Step _collectionInfoStep() {
    return Step(
      title: const Text('Collection Info'),
      isActive: ctrl.currentStep.value >= 0,
      state: ctrl.currentStep.value > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Collection Title *',
              border: OutlineInputBorder(),
            ),
            onChanged: ctrl.setCollectionTitle,
            controller: TextEditingController(text: ctrl.collectionTitle.value),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Category *',
              border: OutlineInputBorder(),
            ),
            onChanged: ctrl.setCategory,
            controller: TextEditingController(text: ctrl.category.value),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Language *',
              border: OutlineInputBorder(),
            ),
            onChanged: ctrl.setLanguage,
            controller: TextEditingController(text: ctrl.language.value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Release Date: '),
              TextButton(
                onPressed: () async {
                  final dt = await showDatePicker(
                    context: Get.context!,
                    initialDate: ctrl.collectionReleaseDate.value,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (dt != null) ctrl.setCollectionReleaseDate(dt);
                },
                child: Text(
                  '${ctrl.collectionReleaseDate.value.year}-${ctrl.collectionReleaseDate.value.month}-${ctrl.collectionReleaseDate.value.day}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Step _collectionTagsAndSuppliersStep() {
    return Step(
      title: const Text('Tags & Suppliers'),
      isActive: ctrl.currentStep.value >= 1,
      state: ctrl.currentStep.value > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection Tags Section
          const Text(
            'Collection Tags',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ctrl.availableCollectionTags.map((tag) {
              final isSelected = ctrl.collectionTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ctrl.addCollectionTagFromAvailable(tag);
                  } else {
                    final index = ctrl.collectionTags.indexOf(tag);
                    if (index != -1) ctrl.removeCollectionTag(index);
                  }
                },
                backgroundColor: Colors.grey[200],
                selectedColor: Colors.orange.withOpacity(0.2),
                checkmarkColor: Colors.orange,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.orange : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Custom Tag',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => ctrl.newCollectionTag.value = v,
                  onSubmitted: (_) => ctrl.addCollectionTag(),
                  controller: TextEditingController(text: ctrl.newCollectionTag.value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: ctrl.addCollectionTag,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(ctrl.collectionTags.length, (i) {
              final tag = ctrl.collectionTags[i];
              return Chip(
                label: Text(tag),
                onDeleted: () => ctrl.removeCollectionTag(i),
                deleteIcon: const Icon(Icons.close, size: 16),
              );
            }),
          )),
          const Divider(height: 32),
          // Suppliers Section
          const Text(
            'Suppliers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Supplier Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => ctrl.newSupplier.value = v,
                  onSubmitted: (_) => ctrl.addSupplier(),
                  controller: TextEditingController(text: ctrl.newSupplier.value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: ctrl.addSupplier,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(ctrl.suppliers.length, (i) {
              final s = ctrl.suppliers[i];
              return Chip(
                label: Text(s),
                onDeleted: () => ctrl.removeSupplierAt(i),
                deleteIcon: const Icon(Icons.close, size: 16),
              );
            }),
          )),
        ],
      ),
    );
  }

  Step _coverImageStep(context) {
    return Step(
      title: const Text('Cover Image'),
      isActive: ctrl.currentStep.value >= 2,
      state: ctrl.currentStep.value > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          Obx(() {
            if (ctrl.coverImage.value != null) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb && ctrl.webCoverBytes != null
                        ? Image.memory(ctrl.webCoverBytes!, height: 150, fit: BoxFit.cover)
                        : Image.file(File(ctrl.coverImage.value!.path), height: 150, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ctrl.removeCoverImage(),
                    child: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            }
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('No cover selected')),
            );
          }),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ctrl.pickCoverImage(context),
            child: const Text('Pick Cover Image'),
          ),
        ],
      ),
    );
  }

  Step _productsStep(context) {
    return Step(
      title: const Text('Products'),
      isActive: ctrl.currentStep.value >= 3,
      state: ctrl.currentStep.value > 3 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          // Add Product Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Product Title *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => ctrl.newProductTitle.value = v,
                  controller: TextEditingController(text: ctrl.newProductTitle.value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => ctrl.pickProductImage(context),
                        child: const Text('Pick Image'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(() => Expanded(
                      child: Text(
                        ctrl.newProductImagePath.value.isEmpty
                            ? 'No image'
                            : ctrl.newProductImagePath.value.split('/').last,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                // Product Tags
                const Text(
                  'Product Tags',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ctrl.availableProductTags.map((tag) {
                    final isSelected = ctrl.newProductTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ctrl.addProductTagFromAvailable(tag);
                        } else {
                          final index = ctrl.newProductTags.indexOf(tag);
                          if (index != -1) ctrl.removeProductTag(index);
                        }
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.orange.withOpacity(0.2),
                      checkmarkColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.orange : null,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Custom Tag',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => ctrl.newProductTagInput.value = v,
                        onSubmitted: (_) => ctrl.addProductTag(),
                        controller: TextEditingController(text: ctrl.newProductTagInput.value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: ctrl.addProductTag,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                Obx(() => ctrl.newProductTags.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: List.generate(ctrl.newProductTags.length, (i) {
                            return Chip(
                              label: Text(ctrl.newProductTags[i]),
                              onDeleted: () => ctrl.removeProductTag(i),
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              deleteIcon: const Icon(Icons.close, size: 14),
                            );
                          }),
                        ),
                      )
                    : const SizedBox()),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ctrl.addProduct(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Products List
          Obx(() => ctrl.products.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Text('No products added yet. Add your first product above.'),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ctrl.products.length,
                  onReorder: ctrl.reorderProducts,
                  itemBuilder: (context, index) {
                    final p = ctrl.products[index];
                    return Card(
                      key: ValueKey(p.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 40,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.titleController.text,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text('Price: '),
                                          SizedBox(
                                            width: 80,
                                            child: TextField(
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (v) => p.price.value = double.tryParse(v) ?? 0.0,
                                              controller: TextEditingController(text: p.price.value.toString()),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Stock: '),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              keyboardType: TextInputType.number,
                                              onChanged: (v) => p.stock.value = int.tryParse(v) ?? 0,
                                              controller: TextEditingController(text: p.stock.value.toString()),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (p.tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: p.tags.map((tag) => Chip(
                                              label: Text(tag, style: const TextStyle(fontSize: 10)),
                                              padding: EdgeInsets.zero,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            )).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => ctrl.removeProduct(index),
                                ),
                                const Icon(Icons.drag_handle, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
        ],
      ),
    );
  }

  Step _reviewUploadStep(context) {
    return Step(
      title: const Text('Review & Upload'),
      isActive: ctrl.currentStep.value >= 4,
      state: ctrl.currentStep.value > 4 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review your collection before upload:'),
          const SizedBox(height: 16),
          Obx(() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewItem('Collection Title', ctrl.collectionTitle.value),
              _buildReviewItem('Category', ctrl.category.value),
              _buildReviewItem('Language', ctrl.language.value),
              if (ctrl.collectionTags.isNotEmpty)
                _buildReviewItem('Tags', ctrl.collectionTags.join(', ')),
              if (ctrl.suppliers.isNotEmpty)
                _buildReviewItem('Suppliers', ctrl.suppliers.join(', ')),
              _buildReviewItem('Products', '${ctrl.products.length} items'),
              if (ctrl.coverImage.value != null)
                _buildReviewItem('Cover Image', 'Selected ✓'),
              const SizedBox(height: 16),
              const Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...ctrl.products.map((p) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ${p.titleController.text}'),
                    if (p.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('Tags: ${p.tags.join(", ")}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
              )),
            ],
          )),
          const SizedBox(height: 24),
          Obx(() {
            if (ctrl.isUploading.value) {
              return Column(
                children: [
                  LinearProgressIndicator(value: ctrl.uploadProgress.value),
                  const SizedBox(height: 8),
                  Text(
                    ctrl.uploadStatus.value,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(ctrl.uploadProgress.value * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }
            return ElevatedButton(
              onPressed: () => ctrl.uploadCollection(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Upload Collection 🚀'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    if (ctrl.currentStep.value == 0 && !ctrl.hasProducts.value && ctrl.collectionTitle.value.isEmpty) {
      return true;
    }

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
                      Icons.cancel,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Discard Collection?',
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
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
                            ctrl.clearDraft();
                            ctrl._clearAll();
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
}