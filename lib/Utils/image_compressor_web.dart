import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> compressImageForWeb(Uint8List imageBytes, {int maxWidth = 1080, int quality = 85}) async {
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