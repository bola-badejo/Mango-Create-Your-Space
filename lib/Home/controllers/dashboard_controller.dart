import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/mango_genres.dart';
import 'package:mango/Models/customModel/mango_podcasts.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/utils.dart';

import '../../Models/customModel/post.dart';
import '../../Models/customModel/user.dart';
import '../../Models/customModel/vine.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  MangoUser _userFromFirebaseSnapshot(DocumentSnapshot snapshot) {
    return MangoUser.fromDocument(snapshot);
  }

  List<MangoBooks> _libraryFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
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
    }).toList();
  }

  Stream<List<MangoBooks>> getBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  // Add this to FirestoreService class
  List<Map<String, dynamic>> _contributorsFromSnapshots(
    QuerySnapshot snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['contributorId'] = doc.id; // Ensure ID is included
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getContributorsByType(String type) {
    return FirebaseFirestore.instance
        .collection('contributors')
        .where('type', isEqualTo: type.toLowerCase())
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_contributorsFromSnapshots);
  }

  Stream<Map<String, dynamic>> getContributorById(String contributorId) {
    return FirebaseFirestore.instance
        .collection('contributors')
        .doc(contributorId)
        .snapshots()
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['contributorId'] = doc.id;
          return data;
        });
  }

  // For fetching vendor items/products
  List<Map<String, dynamic>> _itemsFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['itemId'] = doc.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> getItemsByContributor(
    String contributorId,
    String itemType,
  ) {
    // itemType could be 'products', 'music', 'books', 'podcasts', etc.
    return FirebaseFirestore.instance
        .collection(itemType)
        .where('contributorId', isEqualTo: contributorId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(_itemsFromSnapshots);
  }

  List<Music> _musicFromSnapshots(QuerySnapshot snapshot) {
    print("Music fetched");
    print(snapshot.docs.length);
    print(snapshot.docs);
    return snapshot.docs.map((doc) {
      print(doc.data());
      return Music.fromFirestore(doc);
    }).toList();
  }

  Stream<List<Music>> getMusic() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  List<MangoPlaylist> _playListFromSnapshots(QuerySnapshot snapshot) {
    print("Im playlists fetched");
    print(snapshot.docs.length);
    print(snapshot.docs);
    return snapshot.docs.map((doc) {
      print(doc.data());
      return MangoPlaylist(
        text: (doc.data() as dynamic)['text'] ?? '',
        title: (doc.data() as dynamic)['title'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        plays: (doc.data() as dynamic)['plays'] ?? 0,
        id: doc.id,
        link: (doc.data() as dynamic)['link'] ?? '',
        record: (doc.data() as dynamic)['record'] ?? '',
        repost: (doc.data() as dynamic)['repost'] ?? false,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        tags: (doc.data() as dynamic)['tags'] ?? [],
        originalID: (doc.data() as dynamic)['originalID'] ?? '',
        replyCount: (doc.data() as dynamic)['replyCount'] ?? 0,
        repliedPlaylistID: (doc.data() as dynamic)['repliedPlaylistID'] ?? '',
        reply: (doc.data() as dynamic)['reply'] ?? false,
        type: (doc.data() as dynamic)['type'] ?? '',
        file: (doc.data() as dynamic)['file'] ?? '',
        filePreview: (doc.data() as dynamic)['filePreview'] ?? '',
        about: (doc.data() as dynamic)['about'] ?? '',
        artiste: (doc.data() as dynamic)['artiste'] ?? '',
        contributingArtistes:
            (doc.data() as dynamic)['contributingArtistes'] ?? '',
        writers: (doc.data() as dynamic)['writers'] ?? '',
        producers: (doc.data() as dynamic)['producers'] ?? '',
        releaseYear: (doc.data() as dynamic)['releaseYear'] ?? '',
        genre: (doc.data() as dynamic)['genre'] ?? '',
        label: (doc.data() as dynamic)['label'] ?? '',
        sellingPrice: (doc.data() as dynamic)['sellingPrice'] ?? '',
      );
    }).toList();
  }

  List<MangoPodcast> _podcastFromSnapshots(QuerySnapshot snapshot) {
    print("Im playlists fetched");
    print(snapshot.docs.length);
    print(snapshot.docs);
    return snapshot.docs.map((doc) {
      print(doc.data());
      return MangoPodcast.fromFirestore(doc);
    }).toList();
  }

  List<MangoPost> getPostsFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoPost(
        text: (doc.data() as dynamic)['text'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        video: (doc.data() as dynamic)['video'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        originalID: (doc.data() as dynamic)['originalID'] ?? '',
        link: (doc.data() as dynamic)['link'] ?? '',
        replyTo: (doc.data() as dynamic)['replyTo'] ?? '',
        linkType: (doc.data() as dynamic)['linkType'] ?? '',
        id: doc.id,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        multiImage: (doc.data() as dynamic)['multiImage'] ?? [],
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        repost: (doc.data() as dynamic)['repost'] ?? false,
        multiMedia: (doc.data() as dynamic)['multiMedia'] ?? false,
        isLinked: (doc.data() as dynamic)['isLinked'] ?? false,
        repliedPostID: (doc.data() as dynamic)['repliedPostID'] ?? '',
        reply: (doc.data() as dynamic)['reply'] ?? false,
        replyCount: (doc.data() as dynamic)['replyCount'] ?? 0,
      );
    }).toList();
  }

  MangoPost _postFromFirebaseSnapshot(DocumentSnapshot snapshot) {
    return MangoPost(
      text: (snapshot.data() as dynamic)['text'] ?? '',
      postCreator: (snapshot.data() as dynamic)['postCreator'] ?? '',
      image: (snapshot.data() as dynamic)['image'] ?? '',
      video: (snapshot.data() as dynamic)['video'] ?? '',
      timeStamp: (snapshot.data() as dynamic)['timeStamp'] ?? 0,
      originalID: (snapshot.data() as dynamic)['originalID'] ?? '',
      link: (snapshot.data() as dynamic)['link'] ?? '',
      replyTo: (snapshot.data() as dynamic)['replyTo'] ?? '',
      linkType: (snapshot.data() as dynamic)['linkType'] ?? '',
      id: snapshot.id,
      repostCount: (snapshot.data() as dynamic)['repostCount'] ?? 0,
      multiImage: (snapshot.data() as dynamic)['multiImage'] ?? [],
      likeCount: (snapshot.data() as dynamic)['likeCount'] ?? 0,
      repost: (snapshot.data() as dynamic)['repost'] ?? false,
      multiMedia: (snapshot.data() as dynamic)['multiMedia'] ?? false,
      isLinked: (snapshot.data() as dynamic)['isLinked'] ?? false,
      repliedPostID: (snapshot.data() as dynamic)['repliedPostID'] ?? '',
      reply: (snapshot.data() as dynamic)['reply'] ?? false,
      replyCount: (snapshot.data() as dynamic)['replyCount'] ?? 0,
    );
  }

  Stream<List<MangoPost>> fetchPostsByUser(uid) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('postCreator', isEqualTo: uid)
        .snapshots()
        .map(getPostsFromSnapshot);
  }

  Stream<MangoUser> getUserInfo(String? uid) {
    String id = '';
    if (uid!.isNotEmpty) {
      id = uid;
    }
    return FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .snapshots()
        .map(_userFromFirebaseSnapshot);
  }

  Stream<MangoPost> getPost(String? postId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map(_postFromFirebaseSnapshot);
  }

  List<MangoVine> _vinesFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoVine(
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        thumbnailUrl: (doc.data() as dynamic)['thumbnailUrl'] ?? '',
        videoUrl: (doc.data() as dynamic)['videoUrl'] ?? '',
        caption: (doc.data() as dynamic)['caption'] ?? '',
      );
    }).toList();
  }

  Stream<List<MangoPlaylist>> getPlaylists() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .orderBy("timeStamp", descending: true)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoPodcast>> getPodcasts() {
    return FirebaseFirestore.instance
        .collection("podcast")
        .orderBy("timeStamp", descending: true)
        .snapshots()
        .map(_podcastFromSnapshots);
  }

  Stream<List<MangoVine>> getVines() {
    return FirebaseFirestore.instance
        .collection("episodes")
        .orderBy("timeStamp", descending: true)
        .snapshots()
        .map(_vinesFromSnapshots);
  }

  Stream<List<MangoBooks>> getRecentlyReadBooks() {
    return _db
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('lastRead')
        .orderBy('timeStamp', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MangoBooks.fromDocument(doc)).toList(),
        );
  }

  Stream<List<MangoBooks>> getBestOfTheDayBooks() {
    return _db
        .collection('library')
        .orderBy('likeCount', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MangoBooks.fromDocument(doc)).toList(),
        );
  }
}

class MangoDashboardController extends GetxController {
  final FirestoreService firestoreService = FirestoreService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Music> _musicFromSnapshots(QuerySnapshot snapshot) {
    print("Music fetched");
    print(snapshot.docs.length);
    print(snapshot.docs);
    return snapshot.docs.map((doc) {
      print(doc.data());
      return Music.fromFirestore(doc);
    }).toList();
  }

  Stream<List<MangoBooks>> getBooks() {
    return firestoreService.getBooks();
  }

  Stream<MangoUser> getUserInfo(String uid) {
    return firestoreService.getUserInfo(uid);
  }

  Stream<MangoPost> getPost(String postId) {
    return firestoreService.getPost(postId);
  }

  Stream<List<MangoPost>> fetchPostsByUser(String uid) {
    return firestoreService.fetchPostsByUser(uid);
  }

  Stream<List<Music>> getMusic() {
    return firestoreService.getMusic();
  }

  Stream<List<Music>> getHitList() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("plays", descending: true)
        .limit(20)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getHotNewMusic() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("timestamp", descending: true)
        .limit(20)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getTop10Songs() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("plays", descending: true)
        .limit(10)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getTrendingNow() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPlaylists() {
    return firestoreService.getPlaylists();
  }

  Stream<List<MangoPodcast>> getPodcasts() {
    return firestoreService.getPodcasts();
  }

  Stream<List<MangoVine>> getVines() {
    return firestoreService.getVines();
  }

  Stream<List<MangoBooks>> getRecentlyReadBooks() {
    return firestoreService.getRecentlyReadBooks();
  }

  Stream<List<MangoBooks>> getBestOfTheDayBooks() {
    return firestoreService.getBestOfTheDayBooks();
  }

  Stream<List<Music>> getSongsByGenre(String genreName) {
    return FirebaseFirestore.instance
        .collection("music")
        .where('genre', isEqualTo: genreName)
        .orderBy("plays", descending: true)
        .limit(50)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  // Add to MangoDashboardController class

  // Get all vendors
  Stream<List<Map<String, dynamic>>> getVendors() {
    return firestoreService.getContributorsByType('vendor');
  }

  // Get all distributors
  Stream<List<Map<String, dynamic>>> getDistributors() {
    return firestoreService.getContributorsByType('distributor');
  }

  // Get a single contributor by ID
  Stream<Map<String, dynamic>> getContributorById(String contributorId) {
    return firestoreService.getContributorById(contributorId);
  }

  // Get vendor's products/items
  Stream<List<Map<String, dynamic>>> getVendorItems(
    String vendorId, {
    String itemType = 'products',
  }) {
    return firestoreService.getItemsByContributor(vendorId, itemType);
  }

  // Get distributor's content (music, books, podcasts, etc.)
  Stream<List<Map<String, dynamic>>> getDistributorContent(
    String distributorId,
    String contentType,
  ) {
    return firestoreService.getItemsByContributor(distributorId, contentType);
  }

  // Get all items from a vendor (can be extended to filter by type)
  Stream<List<Map<String, dynamic>>> getVendorProducts(String vendorId) {
    return firestoreService.getItemsByContributor(vendorId, 'products');
  }

  // For getting music tracks from a distributor
  Stream<List<Music>> getDistributorMusic(String distributorId) {
    return FirebaseFirestore.instance
        .collection('music')
        .where('contributorId', isEqualTo: distributorId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Music.fromFirestore(doc)).toList();
        });
  }

  // For getting books from a distributor
  Stream<List<MangoBooks>> getDistributorBooks(String distributorId) {
    return FirebaseFirestore.instance
        .collection('books')
        .where('contributorId', isEqualTo: distributorId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MangoBooks.fromFirestore(doc))
              .toList();
        });
  }

  Stream<List<Music>> getSongsByMultipleGenres(List<String> genreNames) {
    return FirebaseFirestore.instance
        .collection("music")
        .where('genre', whereIn: genreNames)
        .orderBy("plays", descending: true)
        .limit(50)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getChillVibes() {
    return FirebaseFirestore.instance
        .collection("music")
        .where('genre', whereIn: ['Chill', 'Lofi', 'Ambient', 'Acoustic'])
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getPartyStarters() {
    return FirebaseFirestore.instance
        .collection("music")
        .where('genre', whereIn: ['Afrobeats', 'Dance', 'Hip Hop', 'Pop'])
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getNewReleases() {
    DateTime monthAgo = DateTime.now().subtract(Duration(days: 30));
    return FirebaseFirestore.instance
        .collection("music")
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo),
        )
        .orderBy("timestamp", descending: true)
        .limit(15)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getMangoExclusives() {
    return FirebaseFirestore.instance
        .collection("music")
        .where('label', isEqualTo: 'Mango Exclusive')
        .orderBy("timestamp", descending: true)
        .limit(15)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getSongsForMood(MangoGenre mood) {
    return _firestore
        .collection("music")
        .where('genre', whereIn: mood.genres)
        .orderBy("plays", descending: true)
        .limit(50)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getPlaylistsForMood(MangoGenre mood) {
    return _firestore
        .collection("music")
        .where('genre', whereIn: mood.genres)
        .orderBy("plays", descending: true)
        .limit(50)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getPlaylistsForMultipleMoods(List<MangoGenre> moods) {
    final allGenres = moods.expand((mood) => mood.genres).toSet().toList();
    return _firestore
        .collection("music")
        .where('genre', whereIn: allGenres)
        .orderBy("plays", descending: true)
        .limit(50)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getFeaturedMoodPlaylists() {
    final featuredGenres = ['Afrobeats', 'Dance', 'Hip Hop', 'Pop', 'Amapiano'];
    return _firestore
        .collection("music")
        .where('genre', whereIn: featuredGenres)
        .orderBy("plays", descending: true)
        .limit(20)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<MangoUser>> searchUsers(String query) {
    if (query.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: query + 'z')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MangoUser.fromQueryDocumentSnapshot(doc))
              .toList(),
        );
  }

  List<MangoPlaylist> _playListFromSnapshots(QuerySnapshot snapshot) {
    print("Im playlists fetched");
    print(snapshot.docs.length);
    print(snapshot.docs);
    return snapshot.docs.map((doc) {
      print(doc.data());
      return MangoPlaylist(
        text: (doc.data() as dynamic)['text'] ?? '',
        title: (doc.data() as dynamic)['title'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        plays: (doc.data() as dynamic)['plays'] ?? 0,
        id: doc.id,
        link: (doc.data() as dynamic)['link'] ?? '',
        record: (doc.data() as dynamic)['record'] ?? '',
        repost: (doc.data() as dynamic)['repost'] ?? false,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        tags: (doc.data() as dynamic)['tags'] ?? [],
        originalID: (doc.data() as dynamic)['originalID'] ?? '',
        replyCount: (doc.data() as dynamic)['replyCount'] ?? 0,
        repliedPlaylistID: (doc.data() as dynamic)['repliedPlaylistID'] ?? '',
        reply: (doc.data() as dynamic)['reply'] ?? false,
        type: (doc.data() as dynamic)['type'] ?? '',
        file: (doc.data() as dynamic)['file'] ?? '',
        filePreview: (doc.data() as dynamic)['filePreview'] ?? '',
        about: (doc.data() as dynamic)['about'] ?? '',
        artiste: (doc.data() as dynamic)['artiste'] ?? '',
        contributingArtistes:
            (doc.data() as dynamic)['contributingArtistes'] ?? '',
        writers: (doc.data() as dynamic)['writers'] ?? '',
        producers: (doc.data() as dynamic)['producers'] ?? '',
        releaseYear: (doc.data() as dynamic)['releaseYear'] ?? '',
        genre: (doc.data() as dynamic)['genre'] ?? '',
        label: (doc.data() as dynamic)['label'] ?? '',
        sellingPrice: (doc.data() as dynamic)['sellingPrice'] ?? '',
      );
    }).toList();
  }

  Future<void> backfillArtistNames() async {
    try {
      final snapshot = await _firestore.collection('music').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final existingArtistName = data['artistName'];

        // Skip if artist name already exists
        if (existingArtistName != null &&
            existingArtistName.toString().isNotEmpty) {
          continue;
        }

        final contributorId = data['contributorId'];
        if (contributorId == null) continue;

        // Fetch contributor
        final contributorDoc = await _firestore
            .collection('contributors')
            .doc(contributorId)
            .get();

        if (contributorDoc.exists) {
          final contributorData = contributorDoc.data();
          final artistName =
              contributorData?['stageName'] ??
              contributorData?['fullName'] ??
              'Unknown Artist';

          // Update the music document
          await doc.reference.update({'artistName': artistName});

          print('Updated ${doc.id} with artist name: $artistName');
        }
      }

      print('Artist names backfilled successfully');
    } catch (e) {
      print('Error backfilling artist names: $e');
    }
  }

  Stream<List<MangoPost>> searchPosts(String query) {
    if (query.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('posts')
        .where('text', isGreaterThanOrEqualTo: query)
        .where('text', isLessThan: query + 'z')
        .orderBy('timeStamp', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MangoPost.fromQueryDocumentSnapshot(doc))
              .toList(),
        );
  }

  Future<void> updateGenreStats() async {
    try {
      final musicSnapshot = await FirebaseFirestore.instance
          .collection("music")
          .get();

      final music = musicSnapshot.docs.map((doc) {
        return Music.fromFirestore(doc);
      }).toList();

      final Map<String, GenreStats> genreStats = {};

      for (final track in music) {
        final genreKey = track.genre.toLowerCase().replaceAll(' ', '_');

        if (!genreStats.containsKey(genreKey)) {
          genreStats[genreKey] = GenreStats();
        }

        genreStats[genreKey]!.songCount += 1;
        genreStats[genreKey]!.totalPlays += track.plays;
      }

      final updates = <String, dynamic>{};

      genreStats.forEach((genreKey, stats) {
        updates['genres/$genreKey/songCount'] = stats.songCount;
        updates['genres/$genreKey/totalPlays'] = stats.totalPlays;
      });

      await _databaseRef.update(updates);

      print('Genre stats updated successfully with music-based calculation');
    } catch (e) {
      print('Error updating genre stats: $e');
    }
  }

  Stream<List<MangoGenre>> getGenresFromRealtimeDatabase() {
    return _databaseRef.child('genres').onValue.asyncMap((event) async {
      final Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        return <MangoGenre>[];
      }

      final List<MangoGenre> genres = [];

      for (var entry in data.entries) {
        try {
          final genreMap = Map<String, dynamic>.from(entry.value);
          final String videoUrl = genreMap['videoUrl'] ?? '';
          final String effectiveVideoUrl = await _getDownloadUrl(videoUrl);
          final genre = MangoGenre.fromJson(entry.key.toString(), genreMap);
          genres.add(genre);
        } catch (e) {
          print('Error parsing genre ${entry.key}: $e');
        }
      }

      genres.sort((a, b) => b.totalPlays.compareTo(a.totalPlays));
      return genres;
    });
  }

  Future<String> _getDownloadUrl(String videoUrl) async {
    try {
      if (videoUrl.startsWith('http')) {
        return videoUrl;
      }
      if (videoUrl.startsWith('gs://')) {
        final path = videoUrl.replaceFirst(
          'gs://mango-cloud-34e08.appspot.com/',
          '',
        );
        final ref = FirebaseStorage.instance.ref().child(path);
        final downloadUrl = await ref.getDownloadURL();

        print('Converted gs:// to: $downloadUrl');
        return downloadUrl;
      }
      return '';
    } catch (e) {
      print('Error getting download URL for $videoUrl: $e');
      return '';
    }
  }

  Stream<List<MangoBooks>> getTopShelfBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getTopShelfBooks: $e');
            return [];
          }
        });
  }

  Stream<List<MangoBooks>> getFreshlyMintedBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("timestamp", descending: true)
        .limit(15)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getFreshlyMintedBooks: $e');
            return [];
          }
        });
  }

  Stream<List<MangoBooks>> getTrendingBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("likes", descending: true)
        .limit(15)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getTrendingBooks: $e');
            return [];
          }
        });
  }

  Stream<List<MangoBooks>> getTop10Books() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("reads", descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getTop10Books: $e');
            return [];
          }
        });
  }

  Stream<List<MangoBooks>> getBooksByGenre(String genre) {
    return FirebaseFirestore.instance
        .collection("books")
        .where(
          'genre',
          isEqualTo: genre,
        ) // Use genre field instead of tags array
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getBooksByGenre: $e');
            return [];
          }
        });
  }

  // Alternative if you need to filter by tags array:
  Stream<List<MangoBooks>> getBooksByTag(String tag) {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: tag)
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => MangoBooks.fromFirestore(doc))
                .toList();
          } catch (e) {
            print('Error in getBooksByTag: $e');
            return [];
          }
        });
  }

  Stream<List<MangoGenre>> getMoodsFromRealtimeDatabase() {
    return _databaseRef.child('genres').onValue.asyncMap((event) async {
      final Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        return <MangoGenre>[];
      }

      final List<MangoGenre> moods = [];

      for (var entry in data.entries) {
        try {
          final genreMap = Map<String, dynamic>.from(entry.value);
          final mood = MangoGenre.fromJson(entry.key.toString(), genreMap);
          moods.add(mood);
        } catch (e) {
          print('Error parsing mood ${entry.key}: $e');
        }
      }

      moods.sort((a, b) => b.totalPlays.compareTo(a.totalPlays));
      return moods;
    });
  }

  Future<String> convertGsUrlToDownloadUrl(String gsUrl) async {
    if (gsUrl.startsWith('http')) return gsUrl;

    if (gsUrl.startsWith('gs://')) {
      try {
        final path = gsUrl.replaceFirst(
          'gs://mango-cloud-34e08.appspot.com/',
          '',
        );
        final ref = FirebaseStorage.instance.ref().child(path);
        return await ref.getDownloadURL();
      } catch (e) {
        print('Error converting URL: $e');
        return '';
      }
    }

    return '';
  }

  Stream<List<MangoBooks>> getAwardWinningBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'award-winning')
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getShortReads() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'short-read')
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getBusinessBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'business')
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getFictionBestsellers() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'fiction')
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getAfricanAuthors() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'african')
        .orderBy("reads", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getMangoExclusiveBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .where('tags', arrayContains: 'mango-exclusive')
        .orderBy("timeStamp", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getBookOfTheDay() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("likeCount", descending: true)
        .limit(1)
        .snapshots()
        .map(firestoreService._libraryFromSnapshots);
  }

  Stream<List<Music>> searchMusic(String query) {
    if (query.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('music')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: query + 'z')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Music.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Music>> getTrendingMusic() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("plays", descending: true)
        .limit(5)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<Music>> getRecentMusic() {
    return FirebaseFirestore.instance
        .collection("music")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .snapshots()
        .map(_musicFromSnapshots);
  }

  Stream<List<MangoBooks>> searchBooks(String query) {
    if (query.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('library')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: query + 'z')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MangoBooks.fromQueryDocumentSnapshot(doc))
              .toList(),
        );
  }

  Stream<List<MangoPlaylist>> searchPodcasts(String query) {
    if (query.isEmpty) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('playlists')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: query + 'z')
        .where('type', isEqualTo: 'podcast')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MangoPlaylist.fromQueryDocumentSnapshot(doc))
              .toList(),
        );
  }

  Stream<List<MangoPlaylist>> getTrendingPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getNewPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .orderBy("timeStamp", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getTopPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .orderBy("plays", descending: true)
        .limit(10)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPodcastsByCategory(String category) {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('genre', isEqualTo: category)
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getComedyPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('genre', isEqualTo: 'Comedy')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getBusinessPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('genre', isEqualTo: 'Business')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getTrueCrimePodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('genre', isEqualTo: 'True Crime')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getAfricanPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('genre', isEqualTo: 'African')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getMangoExclusivePodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('tags', arrayContains: 'mango-exclusive')
        .orderBy("timeStamp", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getShortFormPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .where('tags', arrayContains: 'short-form')
        .orderBy("plays", descending: true)
        .limit(15)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPopularEpisodes() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .orderBy("plays", descending: true)
        .limit(20)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getRecentlyPlayedPodcasts() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where('type', isEqualTo: 'podcast')
        .orderBy("timeStamp", descending: true)
        .limit(10)
        .snapshots()
        .map(firestoreService._playListFromSnapshots);
  }

  final RxList<MangoPost> posts = <MangoPost>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxBool isRefreshing = false.obs;

  DocumentSnapshot? _lastDocument;
  final int _postsPerPage = 15;

  Future<void> loadInitialPosts(context) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timeStamp', descending: true)
          .limit(_postsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        hasMore.value = snapshot.docs.length == _postsPerPage;

        final newPosts = snapshot.docs.map((doc) {
          return MangoPost.fromQueryDocumentSnapshot(doc);
        }).toList();

        posts.assignAll(newPosts);
      } else {
        hasMore.value = false;
        posts.clear();
      }
    } catch (e) {
      print('Error loading initial posts: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to load posts',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMorePosts(context) async {
    if (isLoading.value || !hasMore.value || _lastDocument == null) return;

    try {
      isLoading.value = true;

      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timeStamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        hasMore.value = snapshot.docs.length == _postsPerPage;

        final newPosts = snapshot.docs.map((doc) {
          return MangoPost.fromQueryDocumentSnapshot(doc);
        }).toList();

        posts.addAll(newPosts);
      } else {
        hasMore.value = false;
      }
    } catch (e) {
      print('Error loading more posts: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to load more posts',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshPosts(context) async {
    try {
      isRefreshing.value = true;
      _lastDocument = null;
      hasMore.value = true;

      await loadInitialPosts(context);

      UtilsService().showSnackbar(
        'Refreshed',
        'Posts updated',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        context: context,
      );
    } catch (e) {
      print('Error refreshing posts: $e');
    } finally {
      isRefreshing.value = false;
    }
  }

  Stream<List<MangoPost>> fetchPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .limit(_postsPerPage)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            hasMore.value = snapshot.docs.length == _postsPerPage;
          } else {
            hasMore.value = false;
          }

          return snapshot.docs.map((doc) {
            return MangoPost.fromQueryDocumentSnapshot(doc);
          }).toList();
        });
  }

  void addNewPost(MangoPost post) {
    posts.insert(0, post);
  }

  void updatePost(String postId, MangoPost updatedPost) {
    final index = posts.indexWhere((post) => post.id == postId);
    if (index != -1) {
      posts[index] = updatedPost;
    }
  }

  void removePost(String postId) {
    posts.removeWhere((post) => post.id == postId);
  }

  void clearPosts() {
    posts.clear();
    _lastDocument = null;
    hasMore.value = true;
    isLoading.value = false;
  }

  final RxList<MangoPost> _posts = <MangoPost>[].obs;

  final RxBool _isLoading = false.obs;

  final RxBool _hasMore = true.obs;
  final RxInt _lastVisibleIndex = 0.obs;
  int get lastVisibleIndex => _lastVisibleIndex.value;

  final RxBool _isRefreshing = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  Stream<List<MangoPost>> fetchPosts() {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timeStamp', descending: true)
        .limit(_postsPerPage)
        .snapshots()
        .asyncMap((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            _hasMore.value = snapshot.docs.length == _postsPerPage;
          } else {
            _hasMore.value = false;
          }

          final posts = snapshot.docs.map((doc) {
            return MangoPost.fromQueryDocumentSnapshot(doc);
          }).toList();

          _posts.assignAll(posts);
          return posts;
        });
  }

  Future<void> _loadInitialPosts(context) async {
    try {
      _isLoading.value = true;

      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timeStamp', descending: true)
          .limit(_postsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMore.value = snapshot.docs.length == _postsPerPage;

        final newPosts = snapshot.docs.map((doc) {
          return MangoPost.fromQueryDocumentSnapshot(doc);
        }).toList();

        _posts.assignAll(newPosts);
      } else {
        _hasMore.value = false;
        _posts.clear();
      }
    } catch (e) {
      print('Error loading initial posts: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to load posts',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void updateLastVisibleIndex(int index) {
    _lastVisibleIndex.value = index;
  }

  Future<List<MangoPost>> getPostsAfterIndex(int index) async {
    if (index >= _posts.length) return [];

    try {
      final startAfterPost = _posts[index];
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timeStamp', descending: true)
          .startAfter([startAfterPost.timeStamp])
          .limit(_postsPerPage)
          .get();

      return snapshot.docs.map((doc) {
        return MangoPost.fromQueryDocumentSnapshot(doc);
      }).toList();
    } catch (e) {
      print('Error getting posts after index: $e');
      return [];
    }
  }
}

class GenreStats {
  int songCount = 0;
  int totalPlays = 0;
}
