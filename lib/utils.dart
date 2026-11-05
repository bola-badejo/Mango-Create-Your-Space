import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:mango/Core/theme/mango_context.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class UtilsService {
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  Future<Uint8List> compressImageForWeb(
    Uint8List imageBytes, {
    int maxWidth = 1080,
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      if (image.width > maxWidth) {
        final resized = img.copyResize(image, width: maxWidth);
        return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  void showSnackbar(
    String title,
    String message, {
    required BuildContext context,
    Color? colorText,
    Duration duration = const Duration(seconds: 3),
    SnackPosition snackPosition = SnackPosition.TOP,
    Widget? titleText,
    Widget? messageText,
    Widget? icon,
    bool shouldIconPulse = true,
    double? maxWidth,
    EdgeInsets margin = const EdgeInsets.all(16),
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 8,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 0,
    Color overlayColor = Colors.transparent,
    double overlayBlur = 0,
    Form? userInputForm,
    List<BoxShadow>? boxShadows,
    Gradient? backgroundGradient,
    VoidCallback? onTap,
    bool isDismissible = true,
    bool showProgressIndicator = false,
    AnimationController? progressIndicatorController,
    Color? progressIndicatorBackgroundColor,
    Animation<Color>? progressIndicatorValueColor,
    SnackbarStatusCallback? snackbarStatus,
    double barBlur = 0,
  }) {
    // Every feedback message shares one look. Tone (success, error,
    // warning, information) is inferred from the caller's colour and title
    // and shown with an icon and words, never colour alone. Caller colours
    // are used only to infer tone, so all 355 call sites stay consistent.
    final c = context.colors;
    final type = Theme.of(context).textTheme;
    final tone = _snackToneFor(backgroundColor, title);
    final (IconData toneIcon, Color toneFg, Color toneBg) = switch (tone) {
      _SnackTone.success =>
        (Icons.check_circle_outline_rounded, c.success, c.successContainer),
      _SnackTone.error =>
        (Icons.error_outline_rounded, c.error, c.errorContainer),
      _SnackTone.warning =>
        (Icons.warning_amber_rounded, c.warning, c.warningContainer),
      _SnackTone.info => (Icons.info_outline_rounded, c.info, c.infoContainer),
    };

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: icon ?? Icon(toneIcon, color: toneFg, size: 22),
        ),
        const SizedBox(width: MangoSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (titleText != null)
                titleText
              else if (title.trim().isNotEmpty)
                Text(
                  title,
                  style: type.titleSmall?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (messageText != null)
                messageText
              else if (message.trim().isNotEmpty)
                Text(
                  message,
                  style: type.bodyMedium?.copyWith(color: c.textPrimary),
                ),
            ],
          ),
        ),
      ],
    );

    // Errors stay long enough to read and act on.
    final effectiveDuration =
        tone == _SnackTone.error && duration < const Duration(seconds: 6)
            ? const Duration(seconds: 6)
            : duration;

    final snackBar = SnackBar(
      content: content,
      duration: effectiveDuration,
      behavior: SnackBarBehavior.floating,
      margin: snackPosition == SnackPosition.TOP
          ? EdgeInsets.only(
              top: margin.top,
              left: margin.left,
              right: margin.right,
            )
          : margin,
      padding: padding,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MangoRadius.md),
        side: BorderSide(color: toneFg.withValues(alpha: 0.4)),
      ),
      backgroundColor: toneBg,
      dismissDirection:
          isDismissible ? DismissDirection.down : DismissDirection.none,
      action: onTap != null
          ? SnackBarAction(label: 'OK', textColor: toneFg, onPressed: onTap)
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);

    // Call snackbarStatus callback if provided
    if (snackbarStatus != null) {
      snackbarStatus(SnackbarStatus.OPEN);
      Future.delayed(duration, () {
        snackbarStatus(SnackbarStatus.CLOSED);
      });
    }
  }

  Future<String> uploadFile(dynamic file, String path) async {
    try {
      Reference storageRef = _storage.ref().child(path);

      if (kIsWeb) {
        if (file is Uint8List) {
          final metadata = SettableMetadata(
            contentType: _getContentTypeFromBytes(file),
          );
          final processedBytes = await _processImageForWeb(file);
          final uploadTask = storageRef.putData(processedBytes, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('Web platform requires Uint8List for file upload');
        }
      } else {
        if (file is File) {
          final metadata = SettableMetadata(
            contentType: _getContentType(file.path),
          );
          final uploadTask = storageRef.putFile(file, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('Mobile platform requires File for file upload');
        }
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(
    dynamic imageData,
    String path, {
    int maxWidth = 1920,
    int quality = 85,
  }) async {
    try {
      Reference storageRef = _storage.ref().child(path);

      if (kIsWeb) {
        if (imageData is Uint8List) {
          final compressedBytes = await _compressImageForWeb(
            imageData,
            maxWidth: maxWidth,
            quality: quality,
          );

          debugPrint(
            'Compressed image from ${imageData.length} to ${compressedBytes.length} bytes',
          );

          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final uploadTask = storageRef.putData(compressedBytes, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('Web platform requires Uint8List for image upload');
        }
      } else {
        if (imageData is File) {
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          final uploadTask = storageRef.putFile(imageData, metadata);
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('Mobile platform requires File for image upload');
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<Uint8List> _compressImageForWeb(
    Uint8List imageBytes, {
    int maxWidth = 1920,
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      if (image.width > maxWidth) {
        final resized = img.copyResize(
          image,
          width: maxWidth,
          maintainAspect: true,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  Future<Uint8List> _processImageForWeb(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image != null) {
        return await _compressImageForWeb(bytes);
      }
      return bytes;
    } catch (e) {
      return bytes;
    }
  }

  String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
      case 'mov':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _getContentTypeFromBytes(Uint8List bytes) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';

      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';

      if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'image/gif';

      if (bytes.length >= 12 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70)
        return 'video/mp4';

      if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0))
        return 'audio/mpeg';
    }
    return 'application/octet-stream';
  }

  Future<String> detectVideoQuality(dynamic videoFile) async {
    try {
      if (kIsWeb && videoFile is Uint8List) {
        final sizeMB = videoFile.length / (1024 * 1024);
        if (sizeMB > 100) return '4K';
        if (sizeMB > 50) return '1080p';
        if (sizeMB > 20) return '720p';
        return '480p';
      } else if (!kIsWeb && videoFile is File) {
        return await _detectVideoQualityMobile(videoFile);
      } else {
        return 'Unknown';
      }
    } catch (e) {
      debugPrint('Error detecting video quality: $e');
      return 'Unknown';
    }
  }

  Future<String> _detectVideoQualityMobile(File videoFile) async {
    return '1080p';
  }
}

enum _SnackTone { success, error, warning, info }

/// Infers a message's tone from its title, then from the hue of the colour
/// the caller passed (red = error, amber = warning, green = success).
_SnackTone _snackToneFor(Color? background, String title) {
  final t = title.toLowerCase();
  if (t.contains('error') || t.contains('fail') || t.contains('oops') ||
      t.contains('denied') || t.contains('invalid')) {
    return _SnackTone.error;
  }
  if (t.contains('warn') || t.contains('caution')) return _SnackTone.warning;
  if (t.contains('success') || t.contains('done') || t.contains('saved') ||
      t.contains('sent') || t.contains('added') || t.contains('updated')) {
    return _SnackTone.success;
  }
  if (background == null || background.a < 0.5) return _SnackTone.info;
  final hsv = HSVColor.fromColor(background);
  if (hsv.saturation < 0.25) return _SnackTone.info;
  final h = hsv.hue;
  if (h < 20 || h >= 330) return _SnackTone.error;
  if (h < 65) return _SnackTone.warning;
  if (h < 175) return _SnackTone.success;
  return _SnackTone.info;
}
