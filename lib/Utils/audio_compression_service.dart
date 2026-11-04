// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter/return_code.dart';

// class AudioCompressionService {
//   static const int maxSizeMB = 25; // Reduced from 50 for web stability
  
//   Future<File> compressAudio(File inputFile) async {
//     if (kIsWeb) {
//       // Web: Can't use FFmpeg, but we can warn and limit size
//       final sizeInMB = await inputFile.length() / (1024 * 1024);
//       if (sizeInMB > maxSizeMB) {
//         throw Exception('Audio file too large for web (max ${maxSizeMB}MB). Please use mobile app for large files.');
//       }
//       return inputFile;
//     }
    
//     // Mobile: Compress using FFmpeg
//     final outputDir = await getTemporaryDirectory();
//     final outputFile = File('${outputDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp3');
    
//     final command = '-i "${inputFile.path}" -b:a 128k -ac 2 -ar 44100 "${outputFile.path}"';
//     final session = await FFmpegKit.execute(command);
//     final returnCode = await session.getReturnCode();
    
//     if (ReturnCode.isSuccess(returnCode)) {
//       await inputFile.delete(); // Remove original
//       return outputFile;
//     } else {
//       throw Exception('Compression failed: ${await session.getCommandOutput()}');
//     }
//   }
  
//   Future<Uint8List> compressAudioBytes(Uint8List bytes, String fileName) async {
//     if (kIsWeb) {
//       final sizeInMB = bytes.lengthInBytes / (1024 * 1024);
//       if (sizeInMB > maxSizeMB) {
//         throw Exception('Audio too large for web upload');
//       }
//       return bytes;
//     }
    
//     // For mobile, write to temp, compress, then read back
//     final tempDir = await getTemporaryDirectory();
//     final tempFile = File('${tempDir.path}/temp_$fileName');
//     await tempFile.writeAsBytes(bytes);
//     final compressed = await compressAudio(tempFile);
//     return await compressed.readAsBytes();
//   }
// }