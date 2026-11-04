import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Music {
  final String id;
  final String title;
  final String? subtitle; 
  final String? description;
  final String? label;
  final String genre;
  final String releaseYear;
  final bool isExplicit;
  final String? mood;
  final String? language;
  final String? copyrightInfo;
  final List<Map<String, String>> credits;
  final String artworkUrl;
  final String trackUrl;
  final DateTime timestamp;
  final int plays;
  final int likes;
  final String? lyrics;
  final Duration? duration;
  final String artistId; 
  final String artistName; 
  final int fileSize; 

  Color? songColor;
  String? artistImage;

  Music({
    required this.id,
    required this.title,
    this.subtitle, 
    this.description,
    this.label,
    required this.genre,
    required this.releaseYear,
    required this.isExplicit,
    this.mood,
    this.language,
    this.copyrightInfo,
    required this.credits,
    required this.artworkUrl,
    required this.trackUrl,
    required this.timestamp,
    required this.plays,
    required this.likes,
    this.lyrics,
    this.duration,
    required this.artistId, 
    required this.artistName, 
    required this.fileSize, 
    this.songColor,
    this.artistImage,
  });

  
  String get displayTitle {
    if (subtitle != null && subtitle!.isNotEmpty) {
      return '$title ($subtitle)';
    }
    return title;
  }

  
  String get primaryArtistName {
    
    if (artistName.isNotEmpty && artistName != 'Unknown Artist') {
      return artistName;
    }
    
    
    if (credits.isEmpty) return 'Unknown Artist';
    
    try {
      final mainArtist = credits.firstWhere(
        (credit) => _isArtistRole(credit['role']),
        orElse: () => credits.first,
      );
      return mainArtist['name'] ?? 'Unknown Artist';
    } catch (e) {
      return credits.isNotEmpty ? credits.first['name'] ?? 'Unknown Artist' : 'Unknown Artist';
    }
  }

  
  String get artists {
    
    if (artistName.isNotEmpty && artistName != 'Unknown Artist') {
      return artistName;
    }
    
    
    if (credits.isEmpty) return 'Unknown Artist';
    
    final artistCredits = credits.where((credit) => _isArtistRole(credit['role']));
    if (artistCredits.isEmpty) return credits.first['name'] ?? 'Unknown Artist';
    
    return artistCredits.map((credit) => credit['name'] ?? 'Unknown').where((name) => name.isNotEmpty).join(', ');
  }

  bool _isArtistRole(String? role) {
    if (role == null) return false;
    final lowerRole = role.toLowerCase();
    return lowerRole.contains('artist') || 
           lowerRole.contains('vocal') || 
           lowerRole.contains('singer') ||
           lowerRole.contains('performer');
  }

  Duration get durationWithFallback {
    return duration ?? const Duration(minutes: 4);
  }

  
  String get formattedDuration {
    if (duration == null) return 'Unknown';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
  }

  
  bool get hasCredits => credits.isNotEmpty;

  
  factory Music.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    
    Duration? duration;
    if (data['duration'] != null) {
      final seconds = data['duration'] as int;
      duration = Duration(seconds: seconds);
    }
    
    return Music(
      id: doc.id,
      title: data['title'] ?? 'Unknown Title',
      subtitle: data['subtitle'], 
      description: data['description'],
      label: data['label'],
      genre: data['genre'] ?? 'Unknown Genre',
      releaseYear: data['releaseYear'] ?? 'Unknown Year',
      isExplicit: data['isExplicit'] ?? false,
      mood: data['mood'],
      language: data['language'],
      copyrightInfo: data['copyrightInfo'],
      credits: _parseCredits(data['credits']),
      artworkUrl: data['artworkUrl'] ?? '',
      trackUrl: data['trackUrl'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      plays: data['plays'] ?? 0,
      likes: data['likes'] ?? 0,
      lyrics: data['lyrics'],
      duration: duration,
      artistId: data['artistId'] ?? '', 
      artistName: data['artistName'] ?? 'Unknown Artist', 
      fileSize: data['fileSize'] ?? 0, 
    );
  }

  static List<Map<String, String>> _parseCredits(dynamic creditsData) {
    if (creditsData == null) return [];
    
    if (creditsData is List) {
      return creditsData.map((credit) {
        if (credit is Map<String, dynamic>) {
          return credit.map((key, value) => MapEntry(key, value.toString()));
        } else if (credit is Map) {
          return credit.cast<String, String>();
        }
        return <String, String>{};
      }).toList();
    }
    
    return [];
  }

  
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle, 
      'description': description,
      'label': label,
      'genre': genre,
      'releaseYear': releaseYear,
      'isExplicit': isExplicit,
      'mood': mood,
      'language': language,
      'copyrightInfo': copyrightInfo,
      'credits': credits,
      'artworkUrl': artworkUrl,
      'trackUrl': trackUrl,
      'timestamp': timestamp,
      'plays': plays,
      'likes': likes,
      'lyrics': lyrics,
      'duration': duration?.inSeconds, 
      'artistId': artistId, 
      'artistName': artistName, 
      'fileSize': fileSize, 
    };
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'label': label,
      'genre': genre,
      'releaseYear': releaseYear,
      'isExplicit': isExplicit,
      'mood': mood,
      'language': language,
      'copyrightInfo': copyrightInfo,
      'credits': credits,
      'artworkUrl': artworkUrl,
      'trackUrl': trackUrl,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'plays': plays,
      'likes': likes,
      'lyrics': lyrics,
      'duration': duration?.inSeconds,
      'artistId': artistId,
      'artistName': artistName,
      'fileSize': fileSize,
    };
  }

  
  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      description: json['description'],
      label: json['label'],
      genre: json['genre'],
      releaseYear: json['releaseYear'],
      isExplicit: json['isExplicit'],
      mood: json['mood'],
      language: json['language'],
      copyrightInfo: json['copyrightInfo'],
      credits: _parseCredits(json['credits']),
      artworkUrl: json['artworkUrl'],
      trackUrl: json['trackUrl'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      plays: json['plays'],
      likes: json['likes'],
      lyrics: json['lyrics'],
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
      artistId: json['artistId'],
      artistName: json['artistName'],
      fileSize: json['fileSize'],
    );
  }

  
  Music copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? label,
    String? genre,
    String? releaseYear,
    bool? isExplicit,
    String? mood,
    String? language,
    String? copyrightInfo,
    List<Map<String, String>>? credits,
    String? artworkUrl,
    String? trackUrl,
    DateTime? timestamp,
    int? plays,
    int? likes,
    String? lyrics,
    Duration? duration,
    String? artistId,
    String? artistName,
    int? fileSize,
    Color? songColor,
    String? artistImage,
  }) {
    return Music(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      label: label ?? this.label,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      isExplicit: isExplicit ?? this.isExplicit,
      mood: mood ?? this.mood,
      language: language ?? this.language,
      copyrightInfo: copyrightInfo ?? this.copyrightInfo,
      credits: credits ?? this.credits,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      trackUrl: trackUrl ?? this.trackUrl,
      timestamp: timestamp ?? this.timestamp,
      plays: plays ?? this.plays,
      likes: likes ?? this.likes,
      lyrics: lyrics ?? this.lyrics,
      duration: duration ?? this.duration,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      fileSize: fileSize ?? this.fileSize,
      songColor: songColor ?? this.songColor,
      artistImage: artistImage ?? this.artistImage,
    );
  }

  
factory Music.fromDocument(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  
  
  Duration? duration;
  if (data['duration'] != null) {
    final seconds = data['duration'] as int;
    duration = Duration(seconds: seconds);
  }
  
  
  DateTime timestamp;
  if (data['timestamp'] is Timestamp) {
    timestamp = (data['timestamp'] as Timestamp).toDate();
  } else if (data['timestamp'] is int) {
    timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
  } else if (data['timestamp'] is String) {
    timestamp = DateTime.parse(data['timestamp']);
  } else {
    timestamp = DateTime.now();
  }
  
  List<Map<String, String>> credits = [];
  try {
    if (data['credits'] != null) {
      if (data['credits'] is List) {
        credits = (data['credits'] as List).map((credit) {
          if (credit is Map<String, dynamic>) {
            return credit.map((key, value) => MapEntry(key, value?.toString() ?? ''));
          } else if (credit is Map) {
            return credit.cast<String, String>();
          }
          return <String, String>{};
        }).where((credit) => credit.isNotEmpty).toList();
      }
    }
  } catch (e) {
    print('Error parsing credits: $e');
    credits = [];
  }
  
  return Music(
    id: doc.id,
    title: data['title']?.toString() ?? 'Unknown Title',
    subtitle: data['subtitle']?.toString(),
    description: data['description']?.toString(),
    label: data['label']?.toString(),
    genre: data['genre']?.toString() ?? 'Unknown Genre',
    releaseYear: data['releaseYear']?.toString() ?? 'Unknown Year',
    isExplicit: data['isExplicit'] == true,
    mood: data['mood']?.toString(),
    language: data['language']?.toString(),
    copyrightInfo: data['copyrightInfo']?.toString(),
    credits: credits,
    artworkUrl: data['artworkUrl']?.toString() ?? '',
    trackUrl: data['trackUrl']?.toString() ?? '',
    timestamp: timestamp,
    plays: (data['plays'] as int?) ?? 0,
    likes: (data['likes'] as int?) ?? 0,
    lyrics: data['lyrics']?.toString(),
    duration: duration,
    artistId: data['artistId']?.toString() ?? data['postCreator']?.toString() ?? '',
    artistName: data['artistName']?.toString() ?? 'Unknown Artist',
    fileSize: (data['fileSize'] as int?) ?? 0,
  );
}

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Music && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Music(id: $id, title: $displayTitle, artist: $artistName, genre: $genre)';
  }
}