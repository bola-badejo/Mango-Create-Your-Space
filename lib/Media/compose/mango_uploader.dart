// The one way files get into Mango. Every upload in the app (chat, posts,
// profile pictures, creator content) goes through here, so paths, content
// types, size limits, compression and progress behave the same everywhere,
// and match storage.rules.
//
//   users/{uid}/{area}/...       profile pictures, banners, post media
//   content/{uid}/{type}/...     songs, episodes, films, books, products
//   chats/{chatId}/{uid}/...     chat media (private to the chat)
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum MediaKind { image, video, audio, document, file }

class UploadedFile {
  const UploadedFile({required this.url, required this.path, required this.contentType, required this.size, this.width, this.height});

  final String url;

  /// Storage path; keep it on the document so deletion can clean up.
  final String path;
  final String contentType;
  final int size;
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() => {
        'url': url,
        'path': path,
        'mime': contentType,
        'size': size,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

class UploadTooLarge implements Exception {
  UploadTooLarge(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lets a screen cancel an upload in progress.
class UploadHandle {
  UploadTask? _task;
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  Future<void> cancel() async {
    _cancelled = true;
    await _task?.cancel();
  }
}

class MangoUploader {
  static const _mb = 1024 * 1024;
  static const Map<MediaKind, int> maxBytes = {
    MediaKind.image: 25 * _mb,
    MediaKind.video: 2000 * _mb,
    MediaKind.audio: 300 * _mb,
    MediaKind.document: 300 * _mb,
    MediaKind.file: 100 * _mb,
  };

  static MediaKind kindOf(String mime) {
    if (mime.startsWith('image/')) return MediaKind.image;
    if (mime.startsWith('video/')) return MediaKind.video;
    if (mime.startsWith('audio/')) return MediaKind.audio;
    if (mime == 'application/pdf' || mime == 'application/epub+zip' || mime == 'text/plain') return MediaKind.document;
    return MediaKind.file;
  }

  static String extensionFor(String mime, [String? name]) {
    final fromName = name != null && name.contains('.') ? name.split('.').last.toLowerCase() : null;
    if (fromName != null && fromName.length <= 5) return fromName;
    return switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'video/mp4' => 'mp4',
      'video/quicktime' => 'mov',
      'audio/mp4' || 'audio/aac' || 'audio/m4a' => 'm4a',
      'audio/mpeg' => 'mp3',
      'audio/wav' => 'wav',
      'application/pdf' => 'pdf',
      'application/epub+zip' => 'epub',
      _ => 'bin',
    };
  }

  static String mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'epub' => 'application/epub+zip',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  static String _id() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
  }

  static String userPath(String area, String ext) => 'users/${_uid()}/$area/${_id()}.$ext';
  static String contentPath(String type, String ext) => 'content/${_uid()}/$type/${_id()}.$ext';
  static String chatPath(String chatId, String ext) => 'chats/$chatId/${_uid()}/${_id()}.$ext';

  static String _uid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to upload.');
    return uid;
  }

  /// Shrinks large photos to [maxSide] and re-encodes them as JPEG.
  static Future<(Uint8List, int, int)> prepareImage(Uint8List bytes, {int maxSide = 2048, int quality = 85}) {
    return compute(_prepare, (bytes, maxSide, quality));
  }

  static (Uint8List, int, int) _prepare((Uint8List, int, int) args) {
    final (bytes, maxSide, quality) = args;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return (bytes, 0, 0);
    final oriented = img.bakeOrientation(decoded);
    final scale = max(oriented.width, oriented.height) > maxSide ? maxSide / max(oriented.width, oriented.height) : 1.0;
    final resized = scale < 1 ? img.copyResize(oriented, width: (oriented.width * scale).round(), height: (oriented.height * scale).round(), interpolation: img.Interpolation.average) : oriented;
    return (Uint8List.fromList(img.encodeJpg(resized, quality: quality)), resized.width, resized.height);
  }

  /// Uploads [bytes] to [path]. Images are compressed unless [raw] is set.
  static Future<UploadedFile> upload({
    required Uint8List bytes,
    required String contentType,
    required String path,
    void Function(double progress)? onProgress,
    UploadHandle? handle,
    bool raw = false,
  }) async {
    var data = bytes;
    var type = contentType;
    int? w;
    int? h;
    final kind = kindOf(type);
    if (kind == MediaKind.image && !raw && type != 'image/gif') {
      final (out, pw, ph) = await prepareImage(bytes);
      if (pw > 0) {
        data = out;
        type = 'image/jpeg';
        w = pw;
        h = ph;
      }
    }
    final limit = maxBytes[kind]!;
    if (data.length > limit) {
      throw UploadTooLarge('This file is ${(data.length / _mb).toStringAsFixed(1)} MB. The limit is ${limit ~/ _mb} MB.');
    }
    final finalPath = kind == MediaKind.image && type == 'image/jpeg' && !path.endsWith('.jpg') ? '${path.substring(0, path.lastIndexOf('.'))}.jpg' : path;
    final ref = FirebaseStorage.instance.ref(finalPath);
    final task = ref.putData(data, SettableMetadata(contentType: type, customMetadata: {'ownerId': _uid()}));
    handle?._task = task;
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    onProgress?.call(1);
    return UploadedFile(url: await ref.getDownloadURL(), path: finalPath, contentType: type, size: data.length, width: w, height: h);
  }

  /// Retries transient failures with backoff (not cancellations or size errors).
  static Future<UploadedFile> uploadWithRetry({
    required Uint8List bytes,
    required String contentType,
    required String path,
    void Function(double progress)? onProgress,
    UploadHandle? handle,
    int attempts = 3,
  }) async {
    for (var i = 1;; i++) {
      try {
        return await upload(bytes: bytes, contentType: contentType, path: path, onProgress: onProgress, handle: handle);
      } on UploadTooLarge {
        rethrow;
      } catch (e) {
        if ((handle?.cancelled ?? false) || i >= attempts) rethrow;
        await Future<void>.delayed(Duration(seconds: 2 * i));
      }
    }
  }

  /// Deletes a file the caller owns (used when replacing or removing media).
  static Future<void> delete(String path) async {
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {}
  }
}
