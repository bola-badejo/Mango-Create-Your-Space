
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/customModel/mango_movies.dart';

import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';
class MangoMovieManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'movies';

  
  Future<MangoMovie> createMovie(MangoMovie movie) async {
    try {
      final docRef = await _firestore
          .collection(collectionName)
          .add(movie.toFirestore());
      
      return movie.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create movie: $e');
    }
  }

  
  Future<MangoMovie?> getMovie(String id) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(id).get();
      if (doc.exists) {
        return MangoMovie.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get movie: $e');
    }
  }

  
  Future<void> updateMovie(MangoMovie movie) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(movie.id)
          .update(movie.toFirestore());
    } catch (e) {
      throw Exception('Failed to update movie: $e');
    }
  }

  
  Future<void> deleteMovie(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete movie: $e');
    }
  }

  
  Future<void> incrementViews(String id) async {
    // Playback started: open a server-timed session for MangoChain mining.
    MangoActivityTracker.startInBackground(contentType: 'movie', contentId: id);
    try {
      await _firestore
          .collection(collectionName)
          .doc(id)
          .update({'views': FieldValue.increment(1)});
    } catch (e) {
      throw Exception('Failed to increment views: $e');
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

  
  Stream<List<MangoMovie>> getAllPublishedMovies() {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getMoviesByUser(String userId) {
    return _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .where('isPublished', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getTrendingMovies() {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('views', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getFeaturedMovies() {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getMoviesByGenre(String genre) {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .where('genre', isEqualTo: genre)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> searchMovies(String query) {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .where((movie) =>
                movie.title.toLowerCase().contains(query.toLowerCase()) ||
                movie.description.toLowerCase().contains(query.toLowerCase()) ||
                movie.director.toLowerCase().contains(query.toLowerCase()) ||
                movie.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())))
            .toList());
  }

  
  Stream<List<MangoMovie>> getRecentMovies() {
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
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getMoviesByGenres(List<String> genres) {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .where('genre', whereIn: genres)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }

  
  Stream<List<MangoMovie>> getSimilarMovies(MangoMovie movie, {int limit = 10}) {
    return _firestore
        .collection(collectionName)
        .where('isPublished', isEqualTo: true)
        .where('genre', isEqualTo: movie.genre)
        .where(FieldPath.documentId, isNotEqualTo: movie.id)
        .orderBy('views', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MangoMovie.fromFirestore(doc))
            .toList());
  }
}


extension MangoMovieListExtensions on List<MangoMovie> {
  List<MangoMovie> sortByMostViewed() {
    return [...this]..sort((a, b) => b.views.compareTo(a.views));
  }

  List<MangoMovie> sortByMostLiked() {
    return [...this]..sort((a, b) => b.likes.compareTo(a.likes));
  }

  List<MangoMovie> sortByNewest() {
    return [...this]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<MangoMovie> sortByEngagement() {
    return [...this]..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));
  }

  List<MangoMovie> filterByGenre(String genre) {
    return where((movie) => movie.genre == genre).toList();
  }

  List<MangoMovie> filterByYear(String year) {
    return where((movie) => movie.releaseYear == year).toList();
  }

  List<MangoMovie> filterByRating(String minRating) {
    final rating = double.tryParse(minRating);
    if (rating == null) return this;
    return where((movie) => (movie.imdbRating ?? 0) >= rating).toList();
  }

  List<String> get uniqueGenres {
    return map((movie) => movie.genre).toSet().toList();
  }

  List<String> get uniqueYears {
    return map((movie) => movie.releaseYear).toSet().toList();
  }
}