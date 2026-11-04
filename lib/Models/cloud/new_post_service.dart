import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mango/Models/customModel/post.dart';
import 'package:path_provider/path_provider.dart';

class PostCreationException implements Exception {
  final String message;
  PostCreationException(this.message);
  @override
  String toString() => 'PostCreationException: $message';
}

class ImageEdit {
  final int imageIndex;
  final String filter;
  final List<TextOverlay> textOverlays;
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;

  ImageEdit({
    required this.imageIndex,
    this.filter = 'normal',
    this.textOverlays = const [],
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.exposure = 0.0,
  });

  ImageEdit copyWith({
    int? imageIndex,
    String? filter,
    List<TextOverlay>? textOverlays,
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
  }) {
    return ImageEdit(
      imageIndex: imageIndex ?? this.imageIndex,
      filter: filter ?? this.filter,
      textOverlays: textOverlays ?? this.textOverlays,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageIndex': imageIndex,
      'filter': filter,
      'textOverlays': textOverlays.map((o) => o.toMap()).toList(),
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'exposure': exposure,
    };
  }

  factory ImageEdit.fromMap(Map<String, dynamic> map) {
    return ImageEdit(
      imageIndex: map['imageIndex'],
      filter: map['filter'] ?? 'normal',
      textOverlays: List<TextOverlay>.from(
        (map['textOverlays'] ?? []).map((x) => TextOverlay.fromMap(x)),
      ),
      brightness: (map['brightness'] ?? 1.0).toDouble(),
      contrast: (map['contrast'] ?? 1.0).toDouble(),
      saturation: (map['saturation'] ?? 1.0).toDouble(),
      exposure: (map['exposure'] ?? 0.0).toDouble(),
    );
  }
}

class TextOverlay {
  final String text;
  final double x;
  final double y;
  final String color;
  final double fontSize;
  final String fontFamily;
  final bool hasBackground;
  final String backgroundColor;

  TextOverlay({
    required this.text,
    required this.x,
    required this.y,
    this.color = '#FFFFFF',
    this.fontSize = 16.0,
    this.fontFamily = 'Arial',
    this.hasBackground = false,
    this.backgroundColor = '#000000',
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'hasBackground': hasBackground,
      'backgroundColor': backgroundColor,
    };
  }

  TextOverlay copyWith({
    String? text,
    double? x,
    double? y,
    String? color,
    double? fontSize,
    String? fontFamily,
    bool? hasBackground,
    String? backgroundColor,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      hasBackground: hasBackground ?? this.hasBackground,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  factory TextOverlay.fromMap(Map<String, dynamic> map) {
    return TextOverlay(
      text: map['text'],
      x: (map['x'] ?? 0).toDouble(),
      y: (map['y'] ?? 0).toDouble(),
      color: map['color'] ?? '#FFFFFF',
      fontSize: (map['fontSize'] ?? 16.0).toDouble(),
      fontFamily: map['fontFamily'] ?? 'Arial',
      hasBackground: map['hasBackground'] ?? false,
      backgroundColor: map['backgroundColor'] ?? '#000000',
    );
  }
}

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  
  Future<MangoPost> createPost({
    String text = "",
    List<File>? images,
    File? video,
    String? videoQuality, 
    String? link,
    String? linkType,
    bool isLinked = false,
    String? musicUrl,
    List<ImageEdit>? imageEdits,
    String? replyTo,
    String? repliedPostID,
    Function(double)? onUploadProgress,
    
    Map<String, Uint8List>? webImageBytesMap,
    Uint8List? webVideoBytes,
    String? webVideoFileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw PostCreationException('User not logged in');

    
    final hasMobileImages = images != null && images.isNotEmpty;
    final hasWebImages =
        webImageBytesMap != null && webImageBytesMap.isNotEmpty;
    final hasImages = hasMobileImages || hasWebImages;
    final hasVideo = (video != null) || (webVideoBytes != null);
    final hasMedia = hasImages || hasVideo;

    if (text.trim().isEmpty && !hasMedia) {
      throw PostCreationException('Post must contain text, images, or video');
    }
    if (hasMobileImages && images!.length > 10) {
      throw PostCreationException('Maximum 10 images allowed');
    }
    if (hasWebImages && webImageBytesMap!.length > 10) {
      throw PostCreationException('Maximum 10 images allowed');
    }

    
    final List<String> uploadedImageUrls = [];
    if (hasImages) {
      if (kIsWeb && webImageBytesMap != null) {
        
        final entries = webImageBytesMap.entries.toList();
        for (int i = 0; i < entries.length; i++) {
          final entry = entries[i];
          final bytes = entry.value;
          final fileName = entry.key; 
          final downloadUrl = await _uploadWebFile(
            bytes,
            'image',
            'image_${i}_$fileName.jpg',
            onProgress: (p) => _handleProgress(
              i,
              entries.length,
              hasVideo,
              p,
              onUploadProgress,
            ),
          );
          uploadedImageUrls.add(downloadUrl);
        }
      } else if (images != null) {
        for (int i = 0; i < images.length; i++) {
          final file = images[i];
          final edits = imageEdits?.firstWhere(
            (e) => e.imageIndex == i,
            orElse: () => ImageEdit(imageIndex: i),
          );
          final processedFile = await _applyImageEdits(file, edits!);
          final path =
              'posts/images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final url = await _uploadFile(
            processedFile,
            path,
            onProgress: (p) => _handleProgress(
              i,
              images.length,
              hasVideo,
              p,
              onUploadProgress,
            ),
          );
          uploadedImageUrls.add(url);
        }
      }
    }

    
    String? uploadedVideoUrl;
    if (hasVideo) {
      if (kIsWeb && webVideoBytes != null) {
        final fileName =
            webVideoFileName ??
            'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        uploadedVideoUrl = await _uploadWebFile(
          webVideoBytes,
          'video',
          fileName,
          onProgress: (p) {
            if (onUploadProgress != null) {
              final baseProgress = hasImages ? 0.7 : 0.0;
              onUploadProgress(baseProgress + p * 0.3);
            }
          },
        );
      } else if (video != null) {
        final path =
            'posts/videos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        uploadedVideoUrl = await _uploadFile(
          video,
          path,
          onProgress: (p) {
            if (onUploadProgress != null) {
              final baseProgress = hasImages ? 0.7 : 0.0;
              onUploadProgress(baseProgress + p * 0.3);
            }
          },
        );
      }
    }

    
    final isMultiImage = uploadedImageUrls.length > 1;
    final isReply = replyTo != null;

    final postRef = _firestore.collection('posts').doc();
    final now = Timestamp.now();

    final post = MangoPost(
      id: postRef.id,
      text: text.trim(),
      postCreator: user.uid,
      image: uploadedImageUrls.isNotEmpty && !isMultiImage
          ? uploadedImageUrls.first
          : '',
      video: uploadedVideoUrl ?? '',
      originalID: null,
      repliedPostID: repliedPostID,
      link: link,
      replyTo: replyTo,
      linkType: linkType,
      timeStamp: now,
      repost: false,
      multiMedia: isMultiImage,
      reply: isReply,
      isLinked: isLinked,
      likeCount: 0,
      replyCount: 0,
      repostCount: 0,
      multiImage: isMultiImage ? uploadedImageUrls : [],
      
      videoQuality: videoQuality,
      imageEdits: imageEdits?.map((e) => e.toMap()).toList(),
    );

    
    final batch = _firestore.batch();
    batch.set(postRef, post.toMap());

    
    final userRef = _firestore.collection('users').doc(user.uid);
    batch.update(userRef, {
      'postCount': FieldValue.increment(1),
      'lastPostTime': now,
    });

    
    if (repliedPostID != null) {
      final parentRef = _firestore.collection('posts').doc(repliedPostID);
      batch.update(parentRef, {'replyCount': FieldValue.increment(1)});
    }

    await batch.commit();

    
    final docSnapshot = await postRef.get();
    return MangoPost.fromDocument(docSnapshot);
  }

  
  Future<MangoPost> createTextPost({
    required String text,
    String? replyTo,
    String? repliedPostID,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw PostCreationException('User not logged in');
    if (text.trim().isEmpty)
      throw PostCreationException('Post text cannot be empty');

    final postRef = _firestore.collection('posts').doc();
    final now = Timestamp.now();

    final post = MangoPost(
      id: postRef.id,
      text: text.trim(),
      postCreator: user.uid,
      image: '',
      video: '',
      originalID: null,
      repliedPostID: repliedPostID,
      link: null,
      replyTo: replyTo,
      linkType: null,
      timeStamp: now,
      repost: false,
      multiMedia: false,
      reply: replyTo != null,
      isLinked: false,
      likeCount: 0,
      replyCount: 0,
      repostCount: 0,
      multiImage: [],
      videoQuality: null,
      imageEdits: [],
    );

    final batch = _firestore.batch();
    batch.set(postRef, post.toMap());
    batch.update(_firestore.collection('users').doc(user.uid), {
      'postCount': FieldValue.increment(1),
      'lastPostTime': now,
    });
    if (repliedPostID != null) {
      batch.update(_firestore.collection('posts').doc(repliedPostID), {
        'replyCount': FieldValue.increment(1),
      });
    }
    await batch.commit();

    final docSnapshot = await postRef.get();
    return MangoPost.fromDocument(docSnapshot);
  }

  
  Future<String> _uploadFile(
    File file,
    String path, {
    Function(double)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final task = ref.putFile(file);
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });
    }
    await task;
    return await ref.getDownloadURL();
  }

  Future<String> _uploadWebFile(
    Uint8List bytes,
    String type,
    String fileName, {
    Function(double)? onProgress,
  }) async {
    final user = _auth.currentUser!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _getFileExtension(fileName);
    final finalName = '${type}_$timestamp$ext';
    final path = 'posts/$type/${user.uid}/$finalName';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: _getContentType(type, ext),
      customMetadata: {
        'uploadedBy': user.uid,
        'uploadedAt': timestamp.toString(),
        'originalName': fileName,
      },
    );

    final task = ref.putData(bytes, metadata);
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });
    }
    await task;
    return await ref.getDownloadURL();
  }

  String _getFileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? '' : fileName.substring(dotIndex);
  }

  String _getContentType(String type, String ext) {
    final lowerExt = ext.toLowerCase();
    if (type == 'image') {
      if (lowerExt.contains('.jpg') || lowerExt.contains('.jpeg'))
        return 'image/jpeg';
      if (lowerExt.contains('.png')) return 'image/png';
      if (lowerExt.contains('.gif')) return 'image/gif';
      if (lowerExt.contains('.webp')) return 'image/webp';
      return 'image/jpeg';
    } else if (type == 'video') {
      if (lowerExt.contains('.mp4')) return 'video/mp4';
      if (lowerExt.contains('.mov')) return 'video/quicktime';
      if (lowerExt.contains('.avi')) return 'video/x-msvideo';
      if (lowerExt.contains('.mkv')) return 'video/x-matroska';
      return 'video/mp4';
    }
    return 'application/octet-stream';
  }

  void _handleProgress(
    int index,
    int total,
    bool hasVideo,
    double fileProgress,
    Function(double)? onUploadProgress,
  ) {
    if (onUploadProgress != null) {
      final overallProgress = (index + fileProgress) / total;
      onUploadProgress(overallProgress * (hasVideo ? 0.7 : 0.9));
    }
  }

  
  Future<File> _applyImageEdits(File original, ImageEdit edits) async {
    if (kIsWeb)
      return original; 
    try {
      final bytes = await original.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return original;

      
      if (edits.brightness != 1.0 ||
          edits.contrast != 1.0 ||
          edits.saturation != 1.0) {
        image = img.adjustColor(
          image,
          brightness: edits.brightness,
          contrast: edits.contrast,
          saturation: edits.saturation,
        );
      }

      
      image = _applyFilter(image, edits.filter);

      
      for (final overlay in edits.textOverlays) {
        image = _drawTextOverlay(image!, overlay);
      }

      final editedBytes = img.encodeJpg(image!, quality: 85);
      final tempDir = await getTemporaryDirectory();
      final editedFile = File(
        '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await editedFile.writeAsBytes(editedBytes);
      return editedFile;
    } catch (e) {
      debugPrint('Image edit failed: $e');
      return original;
    }
  }

  img.Image _applyFilter(img.Image image, String filter) {
    switch (filter) {
      case 'clarendon':
        return img.adjustColor(image, contrast: 1.2, saturation: 1.1);
      case 'gingham':
        return img.adjustColor(image, brightness: 0.9, contrast: 0.95);
      case 'moon':
        return img.grayscale(image);
      case 'lark':
        return img.adjustColor(image, brightness: 1.1, saturation: 1.2);
      case 'reyes':
        return img.adjustColor(image, brightness: 1.05, contrast: 0.9);
      case 'normal':
      default:
        return image;
    }
  }

  img.Image _drawTextOverlay(img.Image image, TextOverlay overlay) {
    
    final x = (overlay.x * image.width).toInt();
    final y = (overlay.y * image.height).toInt();

    
    final colorHex = overlay.color.replaceAll('#', '');
    final argb = int.parse(colorHex, radix: 16);
    final a = (argb >> 24) & 0xFF;
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final textColor = img.ColorRgb8(r, g, b);

    return img.drawString(
      image,
      overlay.text,
      x: x,
      y: y,
      font: img.arial24,
      color: textColor,
    );
  }

  
  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception('Post not found');
      if (postDoc['postCreator'] != user.uid) throw Exception('Not authorized');

      final post = MangoPost.fromDocument(postDoc);
      await _deletePostMedia(post);

      transaction.delete(postRef);
      final userRef = _firestore.collection('users').doc(user.uid);
      transaction.update(userRef, {'postCount': FieldValue.increment(-1)});
    });
  }

  Future<void> _deletePostMedia(MangoPost post) async {
    try {
      if (post.multiImage.isNotEmpty) {
        for (final url in post.multiImage) {
          await _storage.refFromURL(url).delete();
        }
      } else if (post.image.isNotEmpty) {
        await _storage.refFromURL(post.image).delete();
      }
      if (post.video.isNotEmpty) {
        await _storage.refFromURL(post.video).delete();
      }
    } catch (e) {
      debugPrint('Error deleting media: $e');
    }
  }

  
  Stream<List<MangoPost>> getPostsStream({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => MangoPost.fromQueryDocumentSnapshot(doc))
          .toList(),
    );
  }

  Future<List<MangoPost>> getFreshPosts({int limit = 10}) async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => MangoPost.fromQueryDocumentSnapshot(doc))
        .toList();
  }

  Future<List<MangoPost>> getPostsAfterTimestamp(
    Timestamp timestamp, {
    int limit = 10,
  }) async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .where('timeStamp', isGreaterThan: timestamp)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => MangoPost.fromQueryDocumentSnapshot(doc))
        .toList();
  }

  Stream<MangoPost> getNewPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty
              ? MangoPost.fromQueryDocumentSnapshot(snapshot.docs.first)
              : throw Exception('No posts found'),
        );
  }
}
