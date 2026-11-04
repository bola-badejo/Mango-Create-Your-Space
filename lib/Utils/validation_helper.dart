
import 'dart:io';
import 'dart:math';

class FileUtils {
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  static Future<bool> validateFileSize(File file, int maxSizeInBytes) async {
    final stat = await file.stat();
    return stat.size <= maxSizeInBytes;
  }

  static String getFileType(String path) {
    final extension = path.split('.').last.toLowerCase();
    
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'image';
    } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'].contains(extension)) {
      return 'video';
    } else if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)) {
      return 'audio';
    } else {
      return 'file';
    }
  }
}