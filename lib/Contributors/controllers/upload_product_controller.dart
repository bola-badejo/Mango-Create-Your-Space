// lib/Store/controller/upload_product_controller.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Models/customModel/MangoProduct.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class UploadProductController extends GetxController {
  final RxDouble uploadProgress = 0.0.obs;
  final RxString errorMessage = ''.obs;
  final currentStep = 0.obs;
  final RxBool isStepValid = false.obs;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  final String? contributorId;
  final String? userId;

  UploadProductController({this.contributorId, this.userId});

  var selectedImages = <XFile>[].obs;
  var isUploading = false.obs;

  var webImageBytesList = <Uint8List>[].obs;
  var webImageFileNames = <String>[].obs;

  var areImagesSelected = false.obs;
  var areDetailsComplete = false.obs;
  var areVariantsComplete = false.obs;

  var title = ''.obs;
  var description = ''.obs;
  var category = ''.obs;
  var brand = ''.obs;
  var sku = ''.obs;
  var price = 0.0.obs;
  var salePrice = 0.0.obs;
  var stockQuantity = 0.obs;
  var weight = 0.0.obs;

  var variants = <ProductVariant>[].obs;
  var attributes = <ProductAttribute>[].obs;
  var selectedColors = <String>[].obs;
  var selectedSizes = <String>[].obs;

  var tags = <String>[].obs;
  final List<String> availableTags = [
    'New',
    'Best Seller',
    'Limited Edition',
    'Eco-Friendly',
    'Handmade',
    'Organic',
    'Vegan',
    'Gluten-Free',
    'Premium',
    'Budget',
    'Sale',
    'Featured',
  ];

  final categories = [
    'Fashion',
    'Electronics',
    'Books',
    'Music',
    'Home & Garden',
    'Beauty & Health',
    'Sports',
    'Toys & Games',
    'Automotive',
    'Services',
    'Other',
  ];

  final colorOptions = [
    'Red',
    'Blue',
    'Green',
    'Black',
    'White',
    'Yellow',
    'Purple',
    'Pink',
    'Orange',
    'Brown',
    'Gray',
    'Multi-color',
  ];

  final sizeOptions = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'XXXL',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    'One Size',
  ];

  bool get hasVariants => selectedColors.isNotEmpty || selectedSizes.isNotEmpty;
  bool get onSale => salePrice.value > 0 && salePrice.value < price.value;

  @override
  void onInit() {
    super.onInit();
    _validateContributor();
    _setupFieldListeners();
  }

  void _validateContributor() {
    if (contributorId == null || contributorId!.isEmpty) {
      errorMessage.value =
          'Contributor ID required. Please register as a vendor first.';
    }
  }

  void _setupFieldListeners() {
    ever(title, (_) => validateDetails());
    ever(category, (_) => validateDetails());
    ever(brand, (_) => validateDetails());
    ever(sku, (_) => validateDetails());
    ever(price, (_) => validateDetails());
    ever(stockQuantity, (_) => validateDetails());
  }

  void setTitle(String v) {
    title.value = v;
    validateDetails();
  }

  void setDescription(String v) => description.value = v;
  void setBrand(String v) {
    brand.value = v;
    validateDetails();
  }

  void setSku(String v) {
    sku.value = v;
    validateDetails();
  }

  void setPrice(String v) {
    price.value = double.tryParse(v) ?? 0.0;
    validateDetails();
  }

  void setSalePrice(String v) => salePrice.value = double.tryParse(v) ?? 0.0;

  void setStock(String v) {
    stockQuantity.value = int.tryParse(v) ?? 0;
    validateDetails();
  }

  void setWeight(String v) => weight.value = double.tryParse(v) ?? 0.0;

  void validateDetails() {
    areDetailsComplete.value =
        title.value.isNotEmpty &&
        category.value.isNotEmpty &&
        brand.value.isNotEmpty &&
        sku.value.isNotEmpty &&
        price.value > 0 &&
        stockQuantity.value >= 0;

    if (currentStep.value == 1) {
      isStepValid.value = areDetailsComplete.value;
    }
  }

  void _validateVariants() {
    if (hasVariants) {
      areVariantsComplete.value =
          variants.isNotEmpty &&
          variants.every(
            (variant) => variant.sku.isNotEmpty && variant.stockQuantity >= 0,
          );
    } else {
      areVariantsComplete.value = true;
    }

    if (currentStep.value == 2) {
      isStepValid.value = areVariantsComplete.value;
    }
  }

  void toggleColor(String color) {
    if (selectedColors.contains(color)) {
      selectedColors.remove(color);
    } else {
      selectedColors.add(color);
    }
    _generateVariants();
  }

  void toggleSize(String size) {
    if (selectedSizes.contains(size)) {
      selectedSizes.remove(size);
    } else {
      selectedSizes.add(size);
    }
    _generateVariants();
  }

  void toggleTag(String tag) {
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
  }

  void _generateVariants() {
    variants.clear();

    if (selectedColors.isEmpty && selectedSizes.isEmpty) {
      variants.add(
        ProductVariant(
          id: _uuid.v4(),
          sku: '${sku.value}-BASE',
          price: price.value,
          salePrice: onSale ? salePrice.value : null,
          stockQuantity: stockQuantity.value,
          attributes: {},
        ),
      );
    } else {
      final colorList = selectedColors.isNotEmpty
          ? selectedColors
          : ['One Color'];
      final sizeList = selectedSizes.isNotEmpty ? selectedSizes : ['One Size'];

      for (final color in colorList) {
        for (final size in sizeList) {
          final variantSku =
              '${sku.value}-${color.substring(0, 3).toUpperCase()}-${size.toUpperCase()}';
          variants.add(
            ProductVariant(
              id: _uuid.v4(),
              sku: variantSku,
              price: price.value,
              salePrice: onSale ? salePrice.value : null,
              stockQuantity: stockQuantity.value,
              attributes: {
                if (color != 'One Color') 'color': color,
                if (size != 'One Size') 'size': size,
              },
            ),
          );
        }
      }
    }
    _validateVariants();
  }

  void updateVariantStock(String variantId, int stock) {
    final index = variants.indexWhere((v) => v.id == variantId);
    if (index != -1) {
      final variant = variants[index];
      variants[index] = ProductVariant(
        id: variant.id,
        sku: variant.sku,
        price: variant.price,
        salePrice: variant.salePrice,
        stockQuantity: stock,
        attributes: variant.attributes,
        imageUrl: variant.imageUrl,
        weight: variant.weight,
      );
    }
    _validateVariants();
  }

  void updateVariantPrice(String variantId, double price) {
    final index = variants.indexWhere((v) => v.id == variantId);
    if (index != -1) {
      final variant = variants[index];
      variants[index] = ProductVariant(
        id: variant.id,
        sku: variant.sku,
        price: price,
        salePrice: variant.salePrice,
        stockQuantity: variant.stockQuantity,
        attributes: variant.attributes,
        imageUrl: variant.imageUrl,
        weight: variant.weight,
      );
    }
  }

  Future<void> pickImages(context) async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );

        if (result != null && result.files.isNotEmpty) {
          for (final file in result.files) {
            if (file.bytes != null) {
              webImageBytesList.add(file.bytes!);
              webImageFileNames.add(file.name);
              selectedImages.add(XFile.fromData(file.bytes!, name: file.name));
            }
          }

          areImagesSelected.value = true;

          if (currentStep.value == 0) {
            isStepValid.value = true;
          }

          UtilsService().showSnackbar(
            'Images Added',
            '${result.files.length} images selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            context: context,
          );
        }
      } else {
        final images = await _picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
        if (images.isNotEmpty) {
          selectedImages.addAll(images);
          areImagesSelected.value = true;

          if (currentStep.value == 0) {
            isStepValid.value = true;
          }

          UtilsService().showSnackbar(
            'Images Added',
            '${images.length} images selected',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: MangoPalette.green500,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            context: context,
          );
        }
      }
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to select images: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);
      if (kIsWeb && index < webImageBytesList.length) {
        webImageBytesList.removeAt(index);
        webImageFileNames.removeAt(index);
      }
      if (selectedImages.isEmpty) {
        areImagesSelected.value = false;
        if (currentStep.value == 0) {
          isStepValid.value = false;
        }
      }
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> urls = [];

    if (kIsWeb) {
      for (int i = 0; i < webImageBytesList.length; i++) {
        final ref = _storage.ref().child('products/${_uuid.v4()}');
        await ref.putData(
          webImageBytesList[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        urls.add(await ref.getDownloadURL());
      }
    } else {
      for (final img in selectedImages) {
        final ref = _storage.ref().child('products/${_uuid.v4()}');
        await ref.putFile(File(img.path));
        urls.add(await ref.getDownloadURL());
      }
    }

    return urls;
  }

  Future<String> _getVendorName() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return brand.value;

      final contributorDoc = await _firestore
          .collection('contributors')
          .doc(contributorId)
          .get();

      if (contributorDoc.exists) {
        final data = contributorDoc.data();

        return data?['storeName'] ??
            data?['companyName'] ??
            data?['fullName'] ??
            brand.value;
      }
    } catch (e) {
      debugPrint('Error getting vendor name: $e');
    }
    return brand.value;
  }

  Future<void> _updateContributorStats() async {
    try {
      if (contributorId == null || contributorId!.isEmpty) return;

      final contributorRef = _firestore
          .collection('contributors')
          .doc(contributorId);
      await contributorRef.update({
        'totalProducts': FieldValue.increment(1),
        'lastUpload': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating contributor stats: $e');
    }
  }

  Future<void> uploadProduct(context) async {
    if (contributorId == null || contributorId!.isEmpty) {
      UtilsService().showSnackbar(
        'Vendor Required',
        'Please register as a vendor first to upload products.',
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

    if (!areDetailsComplete.value ||
        !areImagesSelected.value ||
        !areVariantsComplete.value) {
      UtilsService().showSnackbar(
        'Missing Info',
        'Please complete all required fields and variants',
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
      final imageUrls = await _uploadImages();

      uploadProgress.value = 0.4;
      final vendorName = await _getVendorName();

      final productAttributes = <ProductAttribute>[];
      if (selectedColors.isNotEmpty) {
        productAttributes.add(
          ProductAttribute(
            name: 'color',
            options: selectedColors.toList(),
            isVariation: true,
          ),
        );
      }
      if (selectedSizes.isNotEmpty) {
        productAttributes.add(
          ProductAttribute(
            name: 'size',
            options: selectedSizes.toList(),
            isVariation: true,
          ),
        );
      }

      uploadProgress.value = 0.6;

      final product = MangoProductItem(
        id: _uuid.v4(),
        title: title.value,
        description: description.value,
        category: category.value,
        price: price.value,
        salePrice: onSale ? salePrice.value : null,
        sku: sku.value,
        brand: vendorName,
        stockQuantity: stockQuantity.value,
        imageUrls: imageUrls,
        variants: variants.toList(),
        attributes: productAttributes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vendorId: contributorId!,
        vendorName: vendorName,
        tags: tags.toList(),
      );

      uploadProgress.value = 0.8;

      await _firestore.collection('products').doc(product.id).set({
        ...product.toFirestore(),
        'contributorId': contributorId,
        'userId': currentUser.uid,
        'vendorId': contributorId,
        'vendorName': vendorName,
      });

      uploadProgress.value = 1.0;

      await _updateContributorStats();

      Get.back();

      UtilsService().showSnackbar(
        '🎉 Success!',
        'Your product "${product.title}" has been uploaded',
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

  void reset() {
    title.value = '';
    description.value = '';
    category.value = '';
    brand.value = '';
    sku.value = '';
    price.value = 0.0;
    salePrice.value = 0.0;
    stockQuantity.value = 0;
    weight.value = 0.0;
    variants.clear();
    attributes.clear();
    selectedColors.clear();
    selectedSizes.clear();
    selectedImages.clear();
    webImageBytesList.clear();
    webImageFileNames.clear();
    tags.clear();
    currentStep.value = 0;
    areImagesSelected.value = false;
    areDetailsComplete.value = false;
    areVariantsComplete.value = false;
    isStepValid.value = false;
  }
}