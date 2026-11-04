import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage storage = FirebaseStorage.instance;

  
  Future<dynamic> pickFile({List<String>? allowedExtensions}) async {
    if (kIsWeb) {
      
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true, 
      );
      if (result == null) return null;
      
      final platformFile = result.files.first;
      
      return {
        'platformFile': platformFile,
        'bytes': platformFile.bytes,
        'name': platformFile.name,
        'size': platformFile.size,
        'extension': platformFile.extension,
      };
    } else {
      
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: false, 
      );
      if (result == null) return null;
      
      final platformFile = result.files.first;
      
      return {
        'platformFile': platformFile,
        'file': File(platformFile.path!),
        'name': platformFile.name,
        'size': platformFile.size,
        'extension': platformFile.extension,
      };
    }
  }

  
  UploadTask uploadFile({
    required String path,
    dynamic file, 
    SettableMetadata? metadata,
    void Function(TaskSnapshot)? onStateChanged,
  }) {
    final ref = storage.ref().child(path);
    
    if (kIsWeb && file is Uint8List) {
      
      final uploadTask = ref.putData(
        file, 
        metadata ?? SettableMetadata(contentType: _lookupContentType(path))
      );
      if (onStateChanged != null) {
        uploadTask.snapshotEvents.listen(onStateChanged);
      }
      return uploadTask;
    } else if (!kIsWeb && file is File) {
      
      final uploadTask = ref.putFile(
        file,
        metadata ?? SettableMetadata(contentType: _lookupContentType(path))
      );
      if (onStateChanged != null) {
        uploadTask.snapshotEvents.listen(onStateChanged);
      }
      return uploadTask;
    } else {
      throw Exception('Invalid file type for platform. Web requires Uint8List, mobile requires File.');
    }
  }

  
  Future<UploadTask> uploadFromPickResult({
    required dynamic pickResult,
    required String path,
    SettableMetadata? metadata,
    void Function(TaskSnapshot)? onStateChanged,
  }) async {
    if (kIsWeb) {
      
      if (pickResult is Map && pickResult['bytes'] is Uint8List) {
        return uploadFile(
          path: path,
          file: pickResult['bytes'],
          metadata: metadata,
          onStateChanged: onStateChanged,
        );
      }
    } else {
      
      if (pickResult is Map && pickResult['file'] is File) {
        return uploadFile(
          path: path,
          file: pickResult['file'],
          metadata: metadata,
          onStateChanged: onStateChanged,
        );
      }
    }
    throw Exception('Invalid pick result format');
  }

  
  UploadTask uploadFileMobile({
    required String path,
    required File file,
    void Function(TaskSnapshot)? onStateChanged,
  }) {
    if (kIsWeb) {
      throw Exception('uploadFileMobile is not available on web. Use uploadFile instead.');
    }
    return uploadFile(
      path: path,
      file: file,
      onStateChanged: onStateChanged,
    );
  }

  
  UploadTask uploadData({
    required String path,
    required Uint8List data,
    SettableMetadata? metadata,
    void Function(TaskSnapshot)? onStateChanged,
  }) {
    if (!kIsWeb) {
      throw Exception('uploadData is only available on web. Use uploadFile for mobile.');
    }
    return uploadFile(
      path: path,
      file: data,
      metadata: metadata,
      onStateChanged: onStateChanged,
    );
  }

  Future<String> getDownloadUrl(String path) async {
    return storage.ref().child(path).getDownloadURL();
  }

  String generateContentPath(String contentId, String filename) {
    final year = DateTime.now().year;
    return 'content/$year/$contentId/$filename';
  }

  
  String generateUniquePath(String folder, String filename) {
    final uuid = Uuid().v4();
    final ext = filename.split('.').last;
    return '$folder/$uuid.$ext';
  }

  
  String generateUserPath(String userId, String folder, String filename) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = filename.split('.').last;
    return 'users/$userId/$folder/${timestamp}_$filename';
  }

  String _lookupContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    
    
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
    
    
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      if (ext == 'jpg') return 'image/jpeg';
      if (ext == 'jpeg') return 'image/jpeg';
      return 'image/$ext';
    }
    
    
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc' || ext == 'docx') return 'application/msword';
    if (ext == 'xls' || ext == 'xlsx') return 'application/vnd.ms-excel';
    
    return 'application/octet-stream';
  }

  
  String getContentTypeFromFilename(String filename) {
    return _lookupContentType(filename);
  }

  
  Future<void> deleteFile(String path) async {
    await storage.ref().child(path).delete();
  }

  
  Future<bool> fileExists(String path) async {
    try {
      await storage.ref().child(path).getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }

  
  Future<FullMetadata> getFileMetadata(String path) async {
    return await storage.ref().child(path).getMetadata();
  }

  
  Future<void> updateFileMetadata(String path, SettableMetadata metadata) async {
    await storage.ref().child(path).updateMetadata(metadata);
  }

  
  Future<ListResult> listFiles(String path, {int maxResults = 100}) async {
    return await storage.ref().child(path).list(ListOptions(maxResults: maxResults));
  }

  
  Future<int> getFileSize(String path) async {
    final metadata = await getFileMetadata(path);
    return metadata.size ?? 0;
  }
}