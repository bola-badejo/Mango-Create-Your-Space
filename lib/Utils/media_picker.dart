import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MediaPicker {
  static final ImagePicker _picker = ImagePicker();

  static Future<List<File>?> pickImages(
    BuildContext context, {
    int maxImages = 10,
    bool allowCamera = true,
  }) async {
    try {
      final source = await _showImageSourceSelection(context, allowCamera: allowCamera);
      if (source == null) return null;

      final files = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (files != null && files.isNotEmpty) {
        final fileList = files.take(maxImages).map((xfile) => File(xfile.path)).toList();
        return fileList;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to pick images: ${e.toString()}');
    }
  }

  static Future<File?> pickSingleImage(
    BuildContext context, {
    bool allowCamera = true,
  }) async {
    try {
      final source = await _showImageSourceSelection(context, allowCamera: allowCamera);
      if (source == null) return null;

      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      return file != null ? File(file.path) : null;
    } catch (e) {
      throw Exception('Failed to pick image: ${e.toString()}');
    }
  }

  static Future<File?> pickVideo(
    BuildContext context, {
    bool allowCamera = true,
    Duration maxDuration = const Duration(minutes: 5),
  }) async {
    try {
      final source = await _showImageSourceSelection(context, allowCamera: allowCamera);
      if (source == null) return null;

      final video = await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      return video != null ? File(video.path) : null;
    } catch (e) {
      throw Exception('Failed to pick video: ${e.toString()}');
    }
  }

  static Future<ImageSource?> _showImageSourceSelection(
    BuildContext context, {
    required bool allowCamera,
  }) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}