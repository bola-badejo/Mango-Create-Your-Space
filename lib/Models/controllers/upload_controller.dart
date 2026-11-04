import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/cloud/content.dart';
import 'package:mango/Models/services/storage_service.dart';
import 'package:mango/utils.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class UploadController extends GetxController {
  final StorageService storageService = StorageService();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  var isUploading = false.obs;
  var progress = 0.0.obs;
  var currentTaskId = ''.obs;

  
  Future<void> startUpload({
    required ContentType type,
    required String title,
    required String description,
    required List<String> artistIds,
    required List<String> genres,
    required dynamic file, 
    required Map<String, dynamic> rights,
    required BuildContext context,
  }) async {
    final contentId = Uuid().v4();
    try {
      isUploading.value = true;
      progress.value = 0.0;
      
      String filename;
      if (kIsWeb && file is Uint8List) {
        
        filename = '${type.toString().split('.').last}_${DateTime.now().millisecondsSinceEpoch}';
        
        if (type == ContentType.track || type == ContentType.podcast) {
          filename += '.mp3';
        } else if (type == ContentType.movie) {
          filename += '.mp4';
        } else {
          filename += '.jpg'; 
        }
      } else if (!kIsWeb && file is File) {
        
        filename = p.basename(file.path);
      } else {
        throw Exception('Invalid file type for platform');
      }
      
      final storagePath = storageService.generateContentPath(
        contentId,
        filename,
      );
      
      UploadTask uploadTask;
      if (kIsWeb && file is Uint8List) {
        
        uploadTask = storageService.uploadData(
          path: storagePath,
          data: file,
          onStateChanged: (snapshot) {
            final prog = snapshot.bytesTransferred / (snapshot.totalBytes ?? 1);
            progress.value = prog;
          },
        );
      } else if (!kIsWeb && file is File) {
        
        uploadTask = storageService.uploadFile(
          path: storagePath,
          file: file,
          onStateChanged: (snapshot) {
            final prog = snapshot.bytesTransferred / (snapshot.totalBytes ?? 1);
            progress.value = prog;
          },
        );
      } else {
        throw Exception('Platform not supported');
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      
      final doc = Content(
        id: contentId,
        type: type,
        title: title,
        description: description,
        coverUrl: '', 
        manifestUrl: '', 
        durationSeconds: 0,
        artists: artistIds,
        releaseDate: DateTime.now(),
        genres: genres,
      );

      await firestore.collection('contents').doc(contentId).set(doc.toMap());

      
      await firestore.collection('ingestRequests').doc(contentId).set({
        'contentId': contentId,
        'status': 'queued',
        'createdAt': Timestamp.now(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });

      progress.value = 1.0;
      
      UtilsService().showSnackbar(
        'Success',
        'Upload completed successfully',
        snackPosition: SnackPosition.BOTTOM, context: context,
      );
    } catch (e, st) {
      print('Upload error: $e\n$st');
      UtilsService().showSnackbar(
        'Error',
        'Upload failed: $e',
        snackPosition: SnackPosition.BOTTOM, context: context,
      );
      rethrow;
    } finally {
      isUploading.value = false;
    }
  }

  
  String _getContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) {
      if (ext == 'mp3') return 'audio/mpeg';
      if (ext == 'm4a') return 'audio/mp4';
      return 'audio/$ext';
    }
    if (['mp4', 'mov', 'mkv', 'webm'].contains(ext)) {
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'mkv') return 'video/x-matroska';
      return 'video/$ext';
    }
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
      if (ext == 'png') return 'image/png';
      return 'image/$ext';
    }
    return 'application/octet-stream';
  }
}