import 'dart:ui';

import 'package:mango/constants.dart' as Colors;

class MangoGenre {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color color;
  final List<String> genres;
  final int songCount;
  final int totalPlays;
  final String videoUrl;

  MangoGenre({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    required this.genres,
    required this.songCount,
    required this.totalPlays,
    required this.videoUrl,
  });

  factory MangoGenre.fromJson(String id, Map<String, dynamic> json) {
    return MangoGenre(
      id: id,
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🎵',
      description: json['description'] ?? '',
      color: _parseColor(json['color'] ?? '#000000'),
      songCount: json['songCount'] ?? 0,
      genres: List<String>.from(json['genres'] ?? []),
      totalPlays: json['totalPlays'] ?? 0,
      videoUrl: json['videoUrl'] ?? '',
    );
  }

  static Color _parseColor(String colorString) {
    try {
      String hexColor = colorString.replaceAll('#', '');
      
      if (hexColor.length == 3) {
        hexColor = hexColor.split('').map((c) => '$c$c').join();
      }
      
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'emoji': emoji,
      'description': description,
      'color': '#${color.value.toRadixString(16).substring(2)}',
      'songCount': songCount, 
      'totalPlays': totalPlays,
      'videoUrl': videoUrl,
    };
  }
  
   bool matchesGenre(String playlistGenre) {
    return genres.any((moodGenre) => 
        playlistGenre.toLowerCase().contains(moodGenre.toLowerCase()) ||
        moodGenre.toLowerCase().contains(playlistGenre.toLowerCase()));
  }
}

class GenreDefinition {
  final String name;
  final String emoji;
  final String description;
  final Color color;

  GenreDefinition(this.name, this.emoji, this.description, this.color);
}