
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class MangoMovie {
  final String id;
  final String title;
  final String description;
  final String director;
  final String genre;
  final String releaseYear;
  final String language;
  final String runtime;
  final String rating;
  final List<Map<String, String>> credits;
  final String posterUrl;
  final String videoUrl;
  final String? trailerUrl;
  final String? backdropUrl;
  final Timestamp timestamp;
  final int views;
  final int likes;
  final int favorites;
  final int shares;
  final int downloads;
  final int fileSize;
  final String userId;
  final String userDisplayName;
  final bool isPublished;
  final List<String> tags;
  final double? imdbRating;
  final String? productionCompany;
  final String? country;
  final String? budget;
  final String? revenue;
  final List<String>? subtitles;
  final String? videoQuality;
  final String? audioLanguage;
  final bool? hasSubtitles;
  final bool? isFeatured;

  MangoMovie({
    String? id,
    required this.title,
    required this.description,
    required this.director,
    required this.genre,
    required this.releaseYear,
    required this.language,
    required this.runtime,
    required this.rating,
    required this.credits,
    required this.posterUrl,
    required this.videoUrl,
    this.trailerUrl,
    this.backdropUrl,
    Timestamp? timestamp,
    this.views = 0,
    this.likes = 0,
    this.favorites = 0,
    this.shares = 0,
    this.downloads = 0,
    this.fileSize = 0,
    required this.userId,
    required this.userDisplayName,
    this.isPublished = true,
    this.tags = const [],
    this.imdbRating,
    this.productionCompany,
    this.country,
    this.budget,
    this.revenue,
    this.subtitles,
    this.videoQuality,
    this.audioLanguage,
    this.hasSubtitles = false,
    this.isFeatured = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? Timestamp.now();

  factory MangoMovie.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MangoMovie(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      director: data['director'] ?? '',
      genre: data['genre'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      language: data['language'] ?? 'English',
      runtime: data['runtime'] ?? '',
      rating: data['rating'] ?? '',
      credits: List<Map<String, String>>.from(data['credits'] ?? []),
      posterUrl: data['posterUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      trailerUrl: data['trailerUrl'],
      backdropUrl: data['backdropUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      favorites: data['favorites'] ?? 0,
      shares: data['shares'] ?? 0,
      downloads: data['downloads'] ?? 0,
      fileSize: data['fileSize'] ?? 0,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      isPublished: data['isPublished'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
      imdbRating: data['imdbRating']?.toDouble(),
      productionCompany: data['productionCompany'],
      country: data['country'],
      budget: data['budget'],
      revenue: data['revenue'],
      subtitles: List<String>.from(data['subtitles'] ?? []),
      videoQuality: data['videoQuality'],
      audioLanguage: data['audioLanguage'],
      hasSubtitles: data['hasSubtitles'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'director': director,
      'genre': genre,
      'releaseYear': releaseYear,
      'language': language,
      'runtime': runtime,
      'rating': rating,
      'credits': credits,
      'posterUrl': posterUrl,
      'videoUrl': videoUrl,
      'trailerUrl': trailerUrl,
      'backdropUrl': backdropUrl,
      'timestamp': timestamp,
      'views': views,
      'likes': likes,
      'favorites': favorites,
      'shares': shares,
      'downloads': downloads,
      'fileSize': fileSize,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'isPublished': isPublished,
      'tags': tags,
      'imdbRating': imdbRating,
      'productionCompany': productionCompany,
      'country': country,
      'budget': budget,
      'revenue': revenue,
      'subtitles': subtitles,
      'videoQuality': videoQuality,
      'audioLanguage': audioLanguage,
      'hasSubtitles': hasSubtitles,
      'isFeatured': isFeatured,
    };
  }

  MangoMovie copyWith({
    String? id,
    String? title,
    String? description,
    String? director,
    String? genre,
    String? releaseYear,
    String? language,
    String? runtime,
    String? rating,
    List<Map<String, String>>? credits,
    String? posterUrl,
    String? videoUrl,
    String? trailerUrl,
    String? backdropUrl,
    Timestamp? timestamp,
    int? views,
    int? likes,
    int? favorites,
    int? shares,
    int? downloads,
    int? fileSize,
    String? userId,
    String? userDisplayName,
    bool? isPublished,
    List<String>? tags,
    double? imdbRating,
    String? productionCompany,
    String? country,
    String? budget,
    String? revenue,
    List<String>? subtitles,
    String? videoQuality,
    String? audioLanguage,
    bool? hasSubtitles,
    bool? isFeatured,
  }) {
    return MangoMovie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      language: language ?? this.language,
      runtime: runtime ?? this.runtime,
      rating: rating ?? this.rating,
      credits: credits ?? this.credits,
      posterUrl: posterUrl ?? this.posterUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      timestamp: timestamp ?? this.timestamp,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      favorites: favorites ?? this.favorites,
      shares: shares ?? this.shares,
      downloads: downloads ?? this.downloads,
      fileSize: fileSize ?? this.fileSize,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      isPublished: isPublished ?? this.isPublished,
      tags: tags ?? this.tags,
      imdbRating: imdbRating ?? this.imdbRating,
      productionCompany: productionCompany ?? this.productionCompany,
      country: country ?? this.country,
      budget: budget ?? this.budget,
      revenue: revenue ?? this.revenue,
      subtitles: subtitles ?? this.subtitles,
      videoQuality: videoQuality ?? this.videoQuality,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      hasSubtitles: hasSubtitles ?? this.hasSubtitles,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get formattedDuration {
    try {
      final minutes = int.tryParse(runtime) ?? 0;
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      
      if (hours > 0) {
        return '${hours}h ${remainingMinutes}m';
      } else {
        return '${remainingMinutes}m';
      }
    } catch (e) {
      return runtime;
    }
  }

  String get formattedTimestamp {
    final now = DateTime.now();
    final movieDate = timestamp.toDate();
    final difference = now.difference(movieDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${movieDate.day}/${movieDate.month}/${movieDate.year}';
    }
  }

  bool get isValidForPlayback => videoUrl.isNotEmpty && isPublished;
  bool get hasTrailer => trailerUrl != null && trailerUrl!.isNotEmpty;
  bool get hasBackdrop => backdropUrl != null && backdropUrl!.isNotEmpty;

  double get engagementScore {
    return (views * 1.0) + (likes * 2.0) + (favorites * 3.0) + (shares * 4.0);
  }

  bool get isTrending => engagementScore > 1000;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangoMovie &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MangoMovie{id: $id, title: $title, director: $director, views: $views, likes: $likes}';
  }
}