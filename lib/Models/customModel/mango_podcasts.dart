import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';
class MangoPodcast {
  final String id;
  final String title;
  final String description;
  final String host;
  final String category;
  final String language;
  final bool explicitContent;
  final String artworkUrl;
  final String audioUrl;
  final Timestamp timestamp;
  final int plays;
  final int likes;
  final int favorites;
  final int shares;
  final int downloads;
  final int fileSize;
  final int duration; 
  final String userId;
  final String userDisplayName;
  final bool isPublished;
  final List<String> tags;
  final String? episodeNumber;
  final String? seasonNumber;

  
  MangoPodcast({
    String? id,
    required this.title,
    required this.description,
    required this.host,
    required this.category,
    required this.language,
    required this.explicitContent,
    required this.artworkUrl,
    required this.audioUrl,
    Timestamp? timestamp,
    this.plays = 0,
    this.likes = 0,
    this.favorites = 0,
    this.shares = 0,
    this.downloads = 0,
    this.fileSize = 0,
    this.duration = 0,
    required this.userId,
    required this.userDisplayName,
    this.isPublished = true,
    this.tags = const [],
    this.episodeNumber,
    this.seasonNumber,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? Timestamp.now();

  
  factory MangoPodcast.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MangoPodcast(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      host: data['host'] ?? '',
      category: data['category'] ?? '',
      language: data['language'] ?? 'English',
      explicitContent: data['explicitContent'] ?? false,
      artworkUrl: data['artworkUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      plays: data['plays'] ?? 0,
      likes: data['likes'] ?? 0,
      favorites: data['favorites'] ?? 0,
      shares: data['shares'] ?? 0,
      downloads: data['downloads'] ?? 0,
      fileSize: data['fileSize'] ?? 0,
      duration: data['duration'] ?? 0,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      isPublished: data['isPublished'] ?? true,
      tags: List<String>.from(data['tags'] ?? []),
      episodeNumber: data['episodeNumber'],
      seasonNumber: data['seasonNumber'],
    );
  }

  
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'host': host,
      'category': category,
      'language': language,
      'explicitContent': explicitContent,
      'artworkUrl': artworkUrl,
      'audioUrl': audioUrl,
      'timestamp': timestamp,
      'plays': plays,
      'likes': likes,
      'favorites': favorites,
      'shares': shares,
      'downloads': downloads,
      'fileSize': fileSize,
      'duration': duration,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'isPublished': isPublished,
      'tags': tags,
      if (episodeNumber != null) 'episodeNumber': episodeNumber,
      if (seasonNumber != null) 'seasonNumber': seasonNumber,
    };
  }

  
  MangoPodcast copyWith({
    String? id,
    String? title,
    String? description,
    String? host,
    String? category,
    String? language,
    bool? explicitContent,
    String? artworkUrl,
    String? audioUrl,
    Timestamp? timestamp,
    int? plays,
    int? likes,
    int? favorites,
    int? shares,
    int? downloads,
    int? fileSize,
    int? duration,
    String? userId,
    String? userDisplayName,
    bool? isPublished,
    List<String>? tags,
    String? episodeNumber,
    String? seasonNumber,
  }) {
    return MangoPodcast(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      host: host ?? this.host,
      category: category ?? this.category,
      language: language ?? this.language,
      explicitContent: explicitContent ?? this.explicitContent,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      timestamp: timestamp ?? this.timestamp,
      plays: plays ?? this.plays,
      likes: likes ?? this.likes,
      favorites: favorites ?? this.favorites,
      shares: shares ?? this.shares,
      downloads: downloads ?? this.downloads,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      isPublished: isPublished ?? this.isPublished,
      tags: tags ?? this.tags,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
    );
  }

  

  
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  
  bool get isValidForPlayback {
    return audioUrl.isNotEmpty && isPublished;
  }

  
  bool isOwner(String userId) {
    return this.userId == userId;
  }

  
  double get engagementScore {
    return (plays * 1.0) + (likes * 2.0) + (favorites * 3.0) + (shares * 4.0);
  }

  
  bool get isTrending {
    return engagementScore > 1000; 
  }

  
  String get formattedTimestamp {
    final now = Timestamp.now().toDate();
    final podcastDate = timestamp.toDate();
    final difference = now.difference(podcastDate);

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
      return '${podcastDate.day}/${podcastDate.month}/${podcastDate.year}';
    }
  }

  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangoPodcast &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  
  @override
  String toString() {
    return 'MangoPodcast{id: $id, title: $title, host: $host, plays: $plays, likes: $likes}';
  }
}


class MangoPodcastManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'podcasts';

  
  Future<MangoPodcast> createPodcast(MangoPodcast podcast) async {
    try {
      final docRef = await _firestore
          .collection(collectionName)
          .add(podcast.toFirestore());
      
      return podcast.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create podcast: $e');
    }
  }

  
  Future<MangoPodcast?> getPodcast(String id) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(id).get();
      if (doc.exists) {
        return MangoPodcast.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get podcast: $e');
    }
  }

  
  Future<void> updatePodcast(MangoPodcast podcast) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(podcast.id)
          .update(podcast.toFirestore());
    } catch (e) {
      throw Exception('Failed to update podcast: $e');
    }
  }

  
  Future<void> deletePodcast(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete podcast: $e');
    }
  }

  
  Future<void> incrementPlays(String id) async {
    // Playback started: open a server-timed session for MangoChain mining.
    MangoActivityTracker.startInBackground(contentType: 'podcast', contentId: id);
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'plays': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment plays: $e');
    }
  }

  
  Future<void> incrementLikes(String id) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'likes': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment likes: $e');
    }
  }

  
  Future<void> incrementFavorites(String id) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'favorites': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment favorites: $e');
    }
  }

  
  Future<void> incrementShares(String id) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'shares': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment shares: $e');
    }
  }

  
  Future<void> incrementDownloads(String id) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'downloads': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment downloads: $e');
    }
  }

  
  Stream<List<MangoPodcast>> getPodcastsByUser(String userId) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('isPublished', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoPodcast>> getAllPublishedPodcasts() {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoPodcast>> getTrendingPodcasts() {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('plays', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoPodcast>> getPodcastsByCategory(String category) {
    return _firestore
        .collection(collectionName)
        .where('category', isEqualTo: category)
        .where('isPublished', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoPodcast>> searchPodcasts(String query) {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .where((podcast) =>
                podcast.title.toLowerCase().contains(query.toLowerCase()) ||
                podcast.description.toLowerCase().contains(query.toLowerCase()) ||
                podcast.host.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }

  
  Stream<List<MangoPodcast>> getRecentPodcasts() {
    final thirtyDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );

    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .where('timestamp', isGreaterThan: thirtyDaysAgo)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoPodcast.fromFirestore(doc))
            .toList());
  }
}


extension MangoPodcastListExtensions on List<MangoPodcast> {
  
  List<MangoPodcast> sortByMostPlayed() {
    return [...this]..sort((a, b) => b.plays.compareTo(a.plays));
  }

  
  List<MangoPodcast> sortByMostLiked() {
    return [...this]..sort((a, b) => b.likes.compareTo(a.likes));
  }

  
  List<MangoPodcast> sortByNewest() {
    return [...this]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  
  List<MangoPodcast> sortByEngagement() {
    return [...this]..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));
  }

  
  List<MangoPodcast> filterByCategory(String category) {
    return where((podcast) => podcast.category == category).toList();
  }

  
  List<MangoPodcast> filterByDuration({int? minDuration, int? maxDuration}) {
    return where((podcast) {
      if (minDuration != null && podcast.duration < minDuration) return false;
      if (maxDuration != null && podcast.duration > maxDuration) return false;
      return true;
    }).toList();
  }

  
  List<String> get uniqueCategories {
    return map((podcast) => podcast.category).toSet().toList();
  }
}