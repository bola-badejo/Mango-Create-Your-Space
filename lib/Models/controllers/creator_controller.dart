import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Models/cloud/content.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';

class CreatorController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();
  final AuthController _auth = Get.find<AuthController>();

  RxList<Content> myContents = <Content>[].obs;
  RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _subscribeToMyContents();
  }

  void _subscribeToMyContents() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) return;
    _db
        .collection('contents')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      myContents.value = snap.docs.map((d) => Content.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList();
    });
  }

  Future<String> _uploadFile(dynamic file, String contentId) async {
    final String filename;
    
    if (kIsWeb && file is Uint8List) {
      
      filename = 'file_${DateTime.now().millisecondsSinceEpoch}';
    } else if (!kIsWeb && file is File) {
      
      filename = file.path.split('/').last;
    } else {
      throw Exception('Invalid file type for platform');
    }
    
    final path = _storage.generateContentPath(contentId, filename);
    
    if (kIsWeb && file is Uint8List) {
      
      final metadata = SettableMetadata(
        contentType: _getContentTypeFromBytes(file),
      );
      final task = _storage.uploadData(path: path, data: file, metadata: metadata);
      final snapshot = await task.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } else if (!kIsWeb && file is File) {
      
      final metadata = SettableMetadata(
        contentType: _getContentType(file.path),
      );
      final task = _storage.uploadFile(path: path, file: file, metadata: metadata);
      final snapshot = await task.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    }
    
    throw Exception('Platform not supported');
  }

  String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  
  String _getContentTypeFromBytes(Uint8List bytes) {
    if (bytes.length >= 2) {
      
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      
      if (bytes.length >= 12 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) return 'video/mp4';
      
      if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) return 'audio/mpeg';
    }
    return 'application/octet-stream';
  }

  
  Future<void> createContent({
    required ContentType type,
    required String title,
    required String description,
    required List<String> artists,
    required List<String> genres,
    required dynamic file, 
    required Map<String, dynamic> rights,
    int durationSeconds = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) throw Exception('Not authenticated');
    loading.value = true;
    try {
      final contentId = Uuid().v4();
      final uploadedUrl = await _uploadFile(file, contentId);

      final doc = {
        'type': type.toString().split('.').last,
        'title': title,
        'description': description,
        'coverUrl': '', 
        'files': {
          'original': {'url': uploadedUrl},
        },
        'manifestUrl': uploadedUrl, 
        'durationSeconds': durationSeconds,
        'artists': artists,
        'genres': genres,
        'createdAt': Timestamp.now(),
        'ownerId': uid,
        'status': 'processing',
        'playCount': 0,
      };

      await _db.collection('contents').doc(contentId).set(doc);
    } finally {
      loading.value = false;
    }
  }

  
  Future<void> createAlbum({
    required String albumTitle,
    required String albumDescription,
    required List<dynamic> trackFiles, 
    required List<String> trackTitles,
    required List<String> artists,
    required List<String> genres,
    required Map<String, dynamic> rights,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (uid == null) throw Exception('Not authenticated');
    if (trackFiles.length != trackTitles.length) throw Exception('Tracks and titles length mismatch');

    loading.value = true;
    final albumId = Uuid().v4();
    try {
      
      await _db.collection('contents').doc(albumId).set({
        'type': 'album',
        'title': albumTitle,
        'description': albumDescription,
        'coverUrl': '', 
        'files': {},
        'manifestUrl': '',
        'durationSeconds': 0,
        'artists': artists,
        'genres': genres,
        'createdAt': Timestamp.now(),
        'ownerId': uid,
        'status': 'processing',
        'trackIds': [],
        'trackOrder': [],
        'playCount': 0,
      });

      final List<String> trackIds = [];

      for (int i = 0; i < trackFiles.length; i++) {
        final file = trackFiles[i];
        final title = trackTitles[i].isNotEmpty ? trackTitles[i] : 'Track ${i + 1}';
        final trackId = Uuid().v4();

        final uploadedUrl = await _uploadFile(file, trackId);

        final trackDoc = {
          'type': 'track',
          'title': title,
          'description': '',
          'coverUrl': '',
          'files': {
            'original': {'url': uploadedUrl},
          },
          'manifestUrl': uploadedUrl,
          'durationSeconds': 0,
          'artists': artists,
          'genres': genres,
          'createdAt': Timestamp.now(),
          'ownerId': uid,
          'status': 'processing',
          'parentAlbumId': albumId,
          'playCount': 0,
        };

        await _db.collection('contents').doc(trackId).set(trackDoc);
        trackIds.add(trackId);
      }

      
      await _db.collection('contents').doc(albumId).update({
        'trackIds': trackIds,
        'trackOrder': trackIds, 
      });
    } finally {
      loading.value = false;
    }
  }

  
  Future<void> updateAlbumTrackOrder(String albumId, List<String> orderedTrackIds) async {
    await _db.collection('contents').doc(albumId).update({
      'trackOrder': orderedTrackIds,
    });
  }

  
  Future<void> publishContent(String contentId) async {
    await _db.collection('contents').doc(contentId).update({'status': 'published', 'publishedAt': Timestamp.now()});
  }

  Future<void> unpublishContent(String contentId) async {
    await _db.collection('contents').doc(contentId).update({'status': 'unpublished'});
  }

  Future<void> deleteContent(String contentId) async {
    
    await _db.collection('contents').doc(contentId).delete();
  }
}
