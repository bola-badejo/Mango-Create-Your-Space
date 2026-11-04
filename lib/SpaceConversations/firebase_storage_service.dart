import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UploadResult> uploadFile({
    required dynamic file, 
    required String userId,
    required String spaceId,
    required String conversationId,
    required String fileType, 
    Function(double)? onProgress,
    String? fileName,
  }) async {
    try {
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String extension;
      final String generatedFileName;

      if (kIsWeb && file is Uint8List) {
        
        extension = _getExtensionForFileType(fileType);
        generatedFileName = fileName ?? '${fileType}_$timestamp$extension';
      } else if (!kIsWeb && file is File) {
        
        extension = path.extension(file.path);
        generatedFileName = fileName ?? '${fileType}_$timestamp$extension';
      } else {
        throw Exception('Invalid file type for platform');
      }

      
      final Reference storageRef = _storage.ref()
        .child('spaces')
        .child(spaceId)
        .child('conversations')
        .child(conversationId)
        .child(fileType)
        .child(generatedFileName);

      
      final SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(fileType, extension),
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': timestamp.toString(),
          'originalName': generatedFileName,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      UploadTask uploadTask;
      
      if (kIsWeb && file is Uint8List) {
        
        uploadTask = storageRef.putData(file, metadata);
      } else if (!kIsWeb && file is File) {
        
        uploadTask = storageRef.putFile(file, metadata);
      } else {
        throw Exception('Platform not supported');
      }
      
      
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      
      final TaskSnapshot snapshot = await uploadTask;
      
      
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return UploadResult(
        success: true,
        url: downloadUrl,
        fileName: generatedFileName,
        fileSize: snapshot.totalBytes,
        contentType: _getContentType(fileType, extension),
      );
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');
      
      return UploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  
  String _getExtensionForFileType(String fileType) {
    switch (fileType) {
      case 'audio':
        return '.m4a';
      case 'image':
        return '.jpg';
      case 'video':
        return '.mp4';
      default:
        return '.dat';
    }
  }

  String _getContentType(String fileType, String extension) {
    switch (fileType) {
      case 'audio':
        if (extension.contains('m4a')) return 'audio/m4a';
        if (extension.contains('mp3')) return 'audio/mpeg';
        if (extension.contains('wav')) return 'audio/wav';
        return 'audio/m4a';
      case 'image':
        if (extension.contains('jpg') || extension.contains('jpeg')) return 'image/jpeg';
        if (extension.contains('png')) return 'image/png';
        if (extension.contains('gif')) return 'image/gif';
        return 'image/jpeg';
      case 'video':
        if (extension.contains('mp4')) return 'video/mp4';
        if (extension.contains('mov')) return 'video/quicktime';
        if (extension.contains('mkv')) return 'video/x-matroska';
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final Reference storageRef = _storage.refFromURL(fileUrl);
      await storageRef.delete();
      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  
  Future<FileMetadata?> getFileMetadata(String fileUrl) async {
    try {
      final Reference storageRef = _storage.refFromURL(fileUrl);
      final metadata = await storageRef.getMetadata();
      return FileMetadata.fromFirebase(metadata);
    } catch (e) {
      print('Metadata error: $e');
      return null;
    }
  }

  
  Future<int> getUserStorageUsage(String userId) async {
    try {
      
      
      return 0;
    } catch (e) {
      return 0;
    }
  }
}

class UploadResult {
  final bool success;
  final String? url;
  final String? fileName;
  final int? fileSize;
  final String? contentType;
  final String? error;

  UploadResult({
    required this.success,
    this.url,
    this.fileName,
    this.fileSize,
    this.contentType,
    this.error,
  });
}

class FileMetadata {
  final String name;
  final int size;
  final String contentType;
  final DateTime updated;
  final String? customMetadata;

  FileMetadata({
    required this.name,
    required this.size,
    required this.contentType,
    required this.updated,
    this.customMetadata,
  });

  factory FileMetadata.fromFirebase(FullMetadata metadata) {
    return FileMetadata(
      name: metadata.name ?? 'Unknown',
      size: metadata.size ?? 0,
      contentType: metadata.contentType ?? 'application/octet-stream',
      updated: metadata.updated ?? DateTime.now(),
      customMetadata: metadata.customMetadata?['originalName'],
    );
  }
}