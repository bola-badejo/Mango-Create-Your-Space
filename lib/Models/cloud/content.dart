import 'package:cloud_firestore/cloud_firestore.dart';

enum ContentType { track, album, podcast, movie }

class Content {
  final String id;
  final ContentType type;
  final String title;
  final String description;
  final String coverUrl;
  final String manifestUrl;
  final int durationSeconds;
  final List<String> artists;
  final DateTime releaseDate;
  final List<String> genres;

  Content({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.manifestUrl,
    required this.durationSeconds,
    required this.artists,
    required this.releaseDate,
    required this.genres,
  });

  factory Content.fromFirestore(Map<String, dynamic> data, String id) {
    return Content(
      id: id,
      type: ContentType.values.firstWhere(
          (e) => e.toString() == 'ContentType.${data['type']}',
          orElse: () => ContentType.track),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      manifestUrl: data['manifestUrl'] ?? '',
      durationSeconds: data['durationSeconds'] ?? 0,
      artists: List<String>.from(data['artists'] ?? []),
      releaseDate: (data['releaseDate'] as Timestamp).toDate(),
      genres: List<String>.from(data['genres'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'manifestUrl': manifestUrl,
      'durationSeconds': durationSeconds,
      'artists': artists,
      'releaseDate': releaseDate,
      'genres': genres,
    };
  }
}
