import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/utils.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String thumbnailUrl;
  final String bookFileUrl;
  final double price;
  final String category;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.thumbnailUrl,
    required this.bookFileUrl,
    required this.price,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'bookFileUrl': bookFileUrl,
      'price': price,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Book.fromMap(String id, Map<String, dynamic> map) {
    return Book(
      id: id,
      title: map['title'],
      author: map['author'],
      description: map['description'],
      thumbnailUrl: map['thumbnailUrl'],
      bookFileUrl: map['bookFileUrl'],
      price: map['price'].toDouble(),
      category: map['category'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

class BookController extends GetxController {
  
  var title = ''.obs;
  var author = ''.obs;
  var description = ''.obs;
  var price = 0.0.obs;
  var category = ''.obs;
  var thumbnailUrl = ''.obs;
  var bookFileUrl = ''.obs;
  var isUploading = false.obs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  var webThumbnailBytes = Rxn<Uint8List>();
  var webBookBytes = Rxn<Uint8List>();

  
  Future<void> pickThumbnail(context) async {
    if (kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        Uint8List? bytes = result.files.first.bytes;
        if (bytes != null) {
          webThumbnailBytes.value = bytes;
          await uploadThumbnailForWeb(bytes, result.files.first.name, context);
        }
      }
    } else {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        await uploadThumbnail(File(pickedFile.path), context);
      }
    }
  }

  
  Future<void> uploadThumbnailForWeb(Uint8List bytes, String fileName, BuildContext context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('book_thumbnails/${DateTime.now().toIso8601String()}_$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      thumbnailUrl.value = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Thumbnail uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload thumbnail: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  
  Future<void> pickBookFile(context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      if (kIsWeb) {
        Uint8List? bytes = result.files.single.bytes;
        if (bytes != null) {
          webBookBytes.value = bytes;
          await uploadBookFileForWeb(bytes, result.files.single.name, context);
        }
      } else {
        if (result.files.single.path != null) {
          File pickedFile = File(result.files.single.path!);
          await uploadBookFile(pickedFile, context);
        }
      }
    }
  }

  
  Future<void> uploadBookFileForWeb(Uint8List bytes, String fileName, context) async {
    try {
      isUploading.value = true;
      String filePath = 'books/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      Reference ref = _storage.ref().child(filePath);
      
      UploadTask uploadTask = ref.putData(
        bytes, 
        SettableMetadata(contentType: 'application/pdf')
      );
      
      TaskSnapshot snapshot = await uploadTask;
      bookFileUrl.value = await snapshot.ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Book uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload book file: ${e.toString()}', context: context);
    } finally {
      isUploading.value = false;
    }
  }
  
  Future<void> uploadThumbnail(File file, context) async {
    try {
      isUploading.value = true;
      final ref = _storage.ref().child('book_thumbnails/${DateTime.now().toIso8601String()}');
      await ref.putFile(file);
      thumbnailUrl.value = await ref.getDownloadURL();
      UtilsService().showSnackbar('Success', 'Thumbnail uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload thumbnail: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

 
  Future<void> uploadBookFile(File file, context) async {
    try {
      isUploading.value = true;

      
      String fileName = 'books/${DateTime.now().millisecondsSinceEpoch}.pdf';
      Reference ref = _storage.ref().child(fileName);

      
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      
      bookFileUrl.value = await snapshot.ref.getDownloadURL();

      UtilsService().showSnackbar('Success', 'Book uploaded successfully.', context: context);
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload book file: ${e.toString()}', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  
  Future<void> uploadBook(context) async {
    if (title.isEmpty || author.isEmpty || description.isEmpty || thumbnailUrl.isEmpty || bookFileUrl.isEmpty || price.value <= 0 || category.isEmpty) {
      UtilsService().showSnackbar('Error', 'Please fill all fields correctly.', context: context);
      return;
    }

    try {
      isUploading.value = true;
      await _firestore.collection('books').add({
        'title': title.value,
        'author': author.value,
        'description': description.value,
        'thumbnailUrl': thumbnailUrl.value,
        'bookFileUrl': bookFileUrl.value,
        'price': price.value,
        'category': category.value,
        'createdAt': DateTime.now().toIso8601String(),
      });
      UtilsService().showSnackbar('Success', 'Book uploaded successfully.', context: context);
      resetForm();
    } catch (e) {
      UtilsService().showSnackbar('Error', 'Failed to upload book: $e', context: context);
    } finally {
      isUploading.value = false;
    }
  }

  
  void resetForm() {
    title.value = '';
    author.value = '';
    description.value = '';
    price.value = 0.0;
    category.value = '';
    thumbnailUrl.value = '';
    bookFileUrl.value = '';
  }
}
