import 'package:cloud_firestore/cloud_firestore.dart';

class MangoBooks {
  final String id;
  final String title;
  final String description;
  final String author;
  final String genre;
  final String isbn;
  final String pages;
  final String publisher;
  final String language;
  final String releaseYear;
  final String copyrightInfo;
  final String coverUrl;
  final String fileUrl;
  final String contributorId;
  final String creatorId;
  final String userId;
  final Timestamp timestamp;
  int downloads;
  int likes;
  int reads;

  MangoBooks({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.genre,
    required this.isbn,
    required this.pages,
    required this.publisher,
    required this.language,
    required this.releaseYear,
    required this.copyrightInfo,
    required this.coverUrl,
    required this.fileUrl,
    required this.contributorId,
    required this.creatorId,
    required this.userId,
    required this.timestamp,
    required this.downloads,
    required this.likes,
    required this.reads,
  });

  static MangoBooks fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MangoBooks(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      author: data['author'] ?? '',
      genre: data['genre'] ?? '',
      isbn: data['isbn'] ?? '',
      pages: data['pages'] ?? '',
      publisher: data['publisher'] ?? '',
      language: data['language'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      copyrightInfo: data['copyrightInfo'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      contributorId: data['contributorId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      downloads: (data['downloads'] ?? 0) as int,
      likes: (data['likes'] ?? 0) as int,
      reads: (data['reads'] ?? 0) as int,
    );
  }

  factory MangoBooks.fromMap(Map<String, dynamic> data, [String? id]) {
    return MangoBooks(
      id: id ?? data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      author: data['author'] ?? '',
      genre: data['genre'] ?? '',
      isbn: data['isbn'] ?? '',
      pages: data['pages'] ?? '',
      publisher: data['publisher'] ?? '',
      language: data['language'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      copyrightInfo: data['copyrightInfo'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      contributorId: data['contributorId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      downloads: (data['downloads'] ?? 0) as int,
      likes: (data['likes'] ?? 0) as int,
      reads: (data['reads'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'author': author,
      'genre': genre,
      'isbn': isbn,
      'pages': pages,
      'publisher': publisher,
      'language': language,
      'releaseYear': releaseYear,
      'copyrightInfo': copyrightInfo,
      'coverUrl': coverUrl,
      'fileUrl': fileUrl,
      'contributorId': contributorId,
      'creatorId': creatorId,
      'userId': userId,
      'timestamp': timestamp,
      'downloads': downloads,
      'likes': likes,
      'reads': reads,
    };
  }

  MangoBooks copyWith({
    String? id,
    String? title,
    String? description,
    String? author,
    String? genre,
    String? isbn,
    String? pages,
    String? publisher,
    String? language,
    String? releaseYear,
    String? copyrightInfo,
    String? coverUrl,
    String? fileUrl,
    String? contributorId,
    String? creatorId,
    String? userId,
    Timestamp? timestamp,
    int? downloads,
    int? likes,
    int? reads,
  }) {
    return MangoBooks(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      genre: genre ?? this.genre,
      isbn: isbn ?? this.isbn,
      pages: pages ?? this.pages,
      publisher: publisher ?? this.publisher,
      language: language ?? this.language,
      releaseYear: releaseYear ?? this.releaseYear,
      copyrightInfo: copyrightInfo ?? this.copyrightInfo,
      coverUrl: coverUrl ?? this.coverUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      contributorId: contributorId ?? this.contributorId,
      creatorId: creatorId ?? this.creatorId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      downloads: downloads ?? this.downloads,
      likes: likes ?? this.likes,
      reads: reads ?? this.reads,
    );
  }

  factory MangoBooks.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MangoBooks(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      author: data['author'] ?? '',
      genre: data['genre'] ?? '',
      isbn: data['isbn'] ?? '',
      pages: data['pages'] ?? '',
      publisher: data['publisher'] ?? '',
      language: data['language'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      copyrightInfo: data['copyrightInfo'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      contributorId: data['contributorId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      downloads: (data['downloads'] ?? 0) as int,
      likes: (data['likes'] ?? 0) as int,
      reads: (data['reads'] ?? 0) as int,
    );
  }

  factory MangoBooks.fromQueryDocumentSnapshot(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MangoBooks(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      author: data['author'] ?? '',
      genre: data['genre'] ?? '',
      isbn: data['isbn'] ?? '',
      pages: data['pages'] ?? '',
      publisher: data['publisher'] ?? '',
      language: data['language'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      copyrightInfo: data['copyrightInfo'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      contributorId: data['contributorId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      downloads: (data['downloads'] ?? 0) as int,
      likes: (data['likes'] ?? 0) as int,
      reads: (data['reads'] ?? 0) as int,
    );
  }

  bool get isPublished => true;
  String get displayTitle => title;

  @override
  String toString() {
    return 'MangoBooks{id: $id, title: $title, author: $author, reads: $reads}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangoBooks && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
