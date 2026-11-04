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
import 'package:mango/Store/controller/cart_controller.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';

class ProductController extends GetxController {
  var name = ''.obs;
  var description = ''.obs;
  var price = 0.0.obs;
  var category = ''.obs;
  var stock = 0.obs;
  var imageUrl = ''.obs;
  var isUploading = false.obs;

  var webImageBytes = Rxn<Uint8List>();
  String? webImageFileName;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

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
            uploadImageWeb(bytes, context);
          }
        }
      } else {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          uploadImage(File(pickedFile.path), context);
        }
      }
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to pick image: $e',
        context: context,
      );
    }
  }

  Future<void> addToCart(MangoProductItem product) async {
    final cartController = Get.find<CartController>();

    await cartController.addToCart(
      productId: product.id,
      vendorId: product.vendorId,
      vendorName: product.vendorName,
      name: product.title,
      price: product.currentPrice,
      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      productDetails: {
        'description': product.description,
        'category': product.category,
        'brand': product.brand,
        'sku': product.sku,
      },
      quantity: 1,
    );
  }

  Stream<List<MangoProductItem>> getAllProductsStream() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  // Get products by vendor
  Stream<List<MangoProductItem>> getProductsByVendor(String vendorId) {
    return _firestore
        .collection('products')
        .where('vendorId', isEqualTo: vendorId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  // Get top offers (products on sale)
  Stream<List<MangoProductItem>> getTopOffersStream() {
    return _firestore
        .collection('products')
        .where('onSale', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  // Get best sellers
  Stream<List<MangoProductItem>> getBestSellersStream() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('soldCount', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoProductItem.fromFirestore(doc))
            .toList());
  }

  Future<void> uploadImage(File file, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child(
        'product_images/${DateTime.now().toIso8601String()}',
      );
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      imageUrl.value = url;
      UtilsService().showSnackbar(
        'Success',
        'Image uploaded successfully.',
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload image: $e',
        context: context,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> uploadImageWeb(Uint8List bytes, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child(
        'product_images/${DateTime.now().toIso8601String()}',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      imageUrl.value = url;
      UtilsService().showSnackbar(
        'Success',
        'Image uploaded successfully.',
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload image: $e',
        context: context,
      );
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> uploadProduct(context) async {
    if (name.value.isEmpty || price.value <= 0 || imageUrl.value.isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        'Please fill all fields correctly.',
        context: context,
      );
      return;
    }

    isUploading.value = true;
    try {
      await _firestore.collection('products').add({
        'name': name.value,
        'description': description.value,
        'price': price.value,
        'category': category.value,
        'stock': stock.value,
        'imageUrl': imageUrl.value,
        'createdAt': DateTime.now().toIso8601String(),
      });

      UtilsService().showSnackbar(
        'Success',
        'Product uploaded!',
        context: context,
      );
      resetForm();
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Upload failed: $e',
        context: context,
      );
    } finally {
      isUploading.value = false;
    }
  }

  void resetForm() {
    name.value = '';
    description.value = '';
    price.value = 0.0;
    category.value = '';
    stock.value = 0;
    imageUrl.value = '';
    webImageBytes.value = null;
    webImageFileName = null;
  }
}