import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mango/Contributors/controllers/movies_upload_controller.dart';
import 'package:mango/Models/cloud/user_services.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/mango_movies.dart';
import 'package:mango/Models/customModel/mango_notifications.dart';
import 'package:mango/Models/customModel/my_books.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Services/notification_service.dart';
import 'package:mango/Models/customModel/reply_playlist.dart';
import 'package:quiver/iterables.dart';

import '../../utils.dart';
import '../customModel/MangoShop.dart';
import '../customModel/my_music.dart';
import '../customModel/my_vines.dart';
import '../customModel/recent_events.dart';
import '../customModel/reply_books.dart';
import '../customModel/vine.dart';

class PostService {
  final UtilsService _utilsService = UtilsService();

  List<MangoPost> _postListFromSnapshots(QuerySnapshot snapshot) {
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

  List<Message> _messageListFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Message(
        id: doc.id,
        text: (doc.data() as dynamic)['message'] ?? '',
        replyMessage: (doc.data() as dynamic)['replyMessage'] ?? '',
        replyImage: (doc.data() as dynamic)['replyImage'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        media: (doc.data() as dynamic)['media'] ?? false,
        image: (doc.data() as dynamic)['image'] ?? '',
        receiver: (doc.data() as dynamic)['id'] ?? '',
        sender: (doc.data() as dynamic)['sender'] ?? '',
      );
    }).toList();
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

  MangoPlaylist? _playlistFromFirebaseSnapshot(DocumentSnapshot snapshot) {
    print('we ouchere');
    print(snapshot.data());
    return snapshot != null
        ? MangoPlaylist(
            text: (snapshot.data() as dynamic)['text'] ?? '',
            title: (snapshot.data() as dynamic)['title'] ?? '',
            postCreator: (snapshot.data() as dynamic)['postCreator'] ?? '',
            image: (snapshot.data() as dynamic)['image'] ?? '',
            timeStamp: (snapshot.data() as dynamic)['timeStamp'] ?? 0,
            plays: (snapshot.data() as dynamic)['plays'] ?? 0,
            id: snapshot.id,
            link: (snapshot.data() as dynamic)['link'] ?? '',
            record: (snapshot.data() as dynamic)['record'] ?? '',
            repost: (snapshot.data() as dynamic)['repost'] ?? false,
            repostCount: (snapshot.data() as dynamic)['repostCount'] ?? 0,
            likeCount: (snapshot.data() as dynamic)['likeCount'] ?? 0,
            tags: (snapshot.data() as dynamic)['tags'] ?? [],
            originalID: (snapshot.data() as dynamic)['originalID'] ?? '',
            replyCount: (snapshot.data() as dynamic)['replyCount'] ?? 0,
            repliedPlaylistID:
                (snapshot.data() as dynamic)['repliedPlaylistID'] ?? '',
            reply: (snapshot.data() as dynamic)['reply'] ?? false,
            type: (snapshot.data() as dynamic)['type'] ?? '',
            file: (snapshot.data() as dynamic)['file'] ?? '',
            filePreview: (snapshot.data() as dynamic)['filePreview'] ?? '',
            about: (snapshot.data() as dynamic)['about'] ?? '',
            artiste: (snapshot.data() as dynamic)['artiste'] ?? '',
            contributingArtistes:
                (snapshot.data() as dynamic)['contributingArtistes'] ?? '',
            writers: (snapshot.data() as dynamic)['writers'] ?? '',
            producers: (snapshot.data() as dynamic)['producers'] ?? '',
            releaseYear: (snapshot.data() as dynamic)['releaseYear'] ?? '',
            genre: (snapshot.data() as dynamic)['genre'] ?? '',
            label: (snapshot.data() as dynamic)['label'] ?? '',
            sellingPrice: (snapshot.data() as dynamic)['sellingPrice'] ?? '',
          )
        : null;
  }

  List<MangoBooks> _libraryFromFirebaseSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) => MangoBooks.fromDocument(doc)).toList();
  }

  MangoMovie? _movieFromFirebaseSnapshot(DocumentSnapshot snapshot) {
    try {
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return null;

      return MangoMovie.fromFirestore(snapshot);
    } catch (e) {
      print('Error parsing movie from snapshot: $e');
      return null;
    }
  }

  Stream<List<MangoMovie>> getMoviesStream() {
    return FirebaseFirestore.instance
        .collection('movies')
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _movieFromFirebaseSnapshot(doc))
              .where((movie) => movie != null)
              .cast<MangoMovie>()
              .toList(),
        );
  }

  List<MangoBooks> _libraryFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) => MangoBooks.fromDocument(doc)).toList();
  }

  List<MangoShopItem> _shopItemFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoShopItem(
        text: (doc.data() as dynamic)['text'] ?? '',
        title: (doc.data() as dynamic)['title'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        tags: (doc.data() as dynamic)['tags'] ?? [],
        quantity: (doc.data() as dynamic)['quantity'] ?? '',
        id: doc.id,
        packageWidth: (doc.data() as dynamic)['packageWidth'] ?? '',
        packageHeight: (doc.data() as dynamic)['packageHeight'] ?? '',
        packageWeight: (doc.data() as dynamic)['packageWeight'] ?? '',
        releaseYear: (doc.data() as dynamic)['releaseYear'] ?? '',
        manufacturer: (doc.data() as dynamic)['manufacturer'] ?? '',
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        reply: (doc.data() as dynamic)['reply'] ?? false,
        repost: (doc.data() as dynamic)['repost'] ?? false,
        replyCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        price: (doc.data() as dynamic)['price'] ?? '',
        purchaseCount: (doc.data() as dynamic)['purchaseCount'] ?? 0,
      );
    }).toList();
  }

  List<MangoBookComment> _bookCommentsFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoBookComment(
        text: (doc.data() as dynamic)['text'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        id: doc.id,
        repliedCommentID: (doc.data() as dynamic)['repliedCommentID'] ?? '',
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        reply: (doc.data() as dynamic)['reply'] ?? false,
        repost: (doc.data() as dynamic)['repost'] ?? false,
        replyCount: (doc.data() as dynamic)['repostCount'] ?? 0,
      );
    }).toList();
  }

  List<MangoNotifications> _notificationsFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoNotifications(
        message: (doc.data() as dynamic)['message'] ?? '',
        sender: (doc.data() as dynamic)['sender'] ?? '',
        timeStamp: (doc.data() as dynamic)['time'] ?? 0,
        id: doc.id,
        receiver: (doc.data() as dynamic)['receiver'] ?? '',
        page: (doc.data() as dynamic)['page'] ?? '',
        pageId: (doc.data() as dynamic)['pageId'] ?? '',
        title: (doc.data() as dynamic)['title'] ?? '',
      );
    }).toList();
  }

  List<MyMusic> _myMusicFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      print(doc.id);
      return MyMusic(
        song_id: (doc.data() as dynamic)['song_id'] ?? '',
        type: (doc.data() as dynamic)['type'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        paymentStatus: (doc.data() as dynamic)['paymentStatus'] ?? '',
        isFav: (doc.data() as dynamic)['isFav'] ?? false,
      );
    }).toList();
  }

  List<MyBooks> _myBooksFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      print(doc.id);
      return MyBooks(
        bookId: (doc.data() as dynamic)['bookId'] ?? '',
        type: (doc.data() as dynamic)['type'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        paymentStatus: (doc.data() as dynamic)['paymentStatus'] ?? '',
        isFav: (doc.data() as dynamic)['isFav'] ?? false,
      );
    }).toList();
  }

  List<MyVines> _myVinesFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      print(doc.id);
      return MyVines(
        vineId: (doc.data() as dynamic)['vineId'] ?? '',
        type: (doc.data() as dynamic)['type'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        paymentStatus: (doc.data() as dynamic)['paymentStatus'] ?? '',
        isFav: (doc.data() as dynamic)['isFav'] ?? false,
      );
    }).toList();
  }

  List<MangoPlaylistComment> _playlistCommentsFromSnapshots(
    QuerySnapshot snapshot,
  ) {
    return snapshot.docs.map((doc) {
      return MangoPlaylistComment(
        text: (doc.data() as dynamic)['text'] ?? '',
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        id: doc.id,
        repliedCommentID: (doc.data() as dynamic)['repliedCommentID'] ?? '',
        likeCount: (doc.data() as dynamic)['likeCount'] ?? 0,
        repostCount: (doc.data() as dynamic)['repostCount'] ?? 0,
        reply: (doc.data() as dynamic)['reply'] ?? false,
        repost: (doc.data() as dynamic)['repost'] ?? false,
        replyCount: (doc.data() as dynamic)['repostCount'] ?? 0,
      );
    }).toList();
  }

  List<RecentEvent> _recentEventsFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return RecentEvent(
        recentId: (doc.data() as dynamic)['recentId'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        type: (doc.data() as dynamic)['type'] ?? '',
      );
    }).toList();
  }

  Future createPost(text, dynamic file, link, type, isLinked) async {
    List<String> upload = [];
    if (file != null) {
      if (kIsWeb && file is List<Uint8List>) {
        for (var imageBytes in file) {
          final saveFile = await _utilsService.uploadImage(
            imageBytes,
            "posts/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
          );
          upload.add(saveFile);
        }
      } else if (!kIsWeb && file is List<File>) {
        for (var image in file) {
          final saveFile = await _utilsService.uploadFile(
            image,
            "posts/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
          );
          upload.add(saveFile);
        }
      }
    }
    await FirebaseFirestore.instance.collection("posts").add({
      'text': text,
      'multiImage': upload,
      'image': null,
      'multiMedia': true,
      'link': link,
      'linkType': type,
      'isLinked': isLinked,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future createSingleMediaPost(text, dynamic file, link, type, isLinked) async {
    var saveFile = await _utilsService.uploadFile(
      file,
      "posts/image/${FirebaseAuth.instance.currentUser!.uid}/${Timestamp.now()}/image",
    );
    await FirebaseFirestore.instance.collection("posts").add({
      'text': text,
      'image': saveFile,
      'link': link,
      'multiMedia': false,
      'linkType': type,
      'isLinked': isLinked,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future createNoMediaPost(text) async {
    await FirebaseFirestore.instance.collection("posts").add({
      'text': text,
      'multiMedia': false,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future createVideoMediaPost(text, dynamic file, link, type, isLinked) async {
    String? detectedQuality;

    if (file != null) {
      detectedQuality = await _utilsService.detectVideoQuality(file);
    }

    var saveFile = await _utilsService.uploadFile(
      file,
      "posts/video/${FirebaseAuth.instance.currentUser!.uid}/${Timestamp.now()}/video",
    );

    await FirebaseFirestore.instance.collection("posts").add({
      'text': text,
      'video': saveFile,
      'videoQuality': detectedQuality ?? 'Unknown',
      'link': link,
      'multiMedia': false,
      'linkType': type,
      'isLinked': isLinked,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future saveEpisode(dynamic byteFile) async {
    if (kDebugMode) {
      print(byteFile);
    }
    var saveFile = await _utilsService.uploadImage(
      byteFile,
      "episodes/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
    );
    await FirebaseFirestore.instance.collection("episodes").add({
      'image': saveFile,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future savePlaylist(link, dynamic image, tags, title, text) async {
    var imageFile = await _utilsService.uploadFile(
      image,
      "playlists/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
    );
    await FirebaseFirestore.instance.collection("playlists").add({
      'link': link,
      'image': imageFile,
      'tags': tags,
      'title': title,
      'text': text,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'type': 'link',
    });
  }

  Future saveLibrary(link, dynamic image, tags, title, text, author) async {
    var imageFile = await _utilsService.uploadFile(
      image,
      "library/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/bookcover",
    );
    var imageBook = await _utilsService.uploadFile(
      link,
      "library/book/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/book",
    );
    await FirebaseFirestore.instance.collection("books").add({
      'link': imageBook,
      'image': imageFile,
      'tags': tags,
      'title': title,
      'text': text,
      'author': author,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future saveShopItem(
    dynamic image,
    manufacturer,
    tagString,
    title,
    about,
    quantity,
    packageHeight,
    releaseYear,
    packageWidth,
    packageWeight,
    sellingPrice,
  ) async {
    var imageFile = await _utilsService.uploadFile(
      image,
      "shop/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
    );

    await FirebaseFirestore.instance.collection("shopItems").add({
      'image': imageFile,
      'tags': tagString,
      'title': title,
      'text': about,
      'quantity': quantity,
      'price': sellingPrice,
      'manufacturer': manufacturer,
      'packageHeight': packageHeight,
      'releaseYear': releaseYear,
      'packageWidth': packageWidth,
      'packageWeight': packageWeight,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
    });
  }

  Future saveOriginalRecord(
    dynamic record,
    dynamic preview,
    dynamic image,
    tags,
    title,
    text,
    artiste,
    contributingArtistes,
    writers,
    producers,
    releaseYear,
    genre,
    label,
    sellingPrice,
  ) async {
    var imageFile = await _utilsService.uploadFile(
      image,
      "OriginalRecord/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/artcover",
    );
    var originalRecord = await _utilsService.uploadFile(
      record,
      "OriginalRecord/track/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/track",
    );

    var originalRecordPreview = await _utilsService.uploadFile(
      preview,
      "OriginalRecord/trackPreview/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/trackPreview",
    );
    await FirebaseFirestore.instance.collection("playlists").add({
      'record': originalRecord,
      'preview': originalRecordPreview,
      'image': imageFile,
      'tags': tags,
      'title': title,
      'text': text,
      'artiste': artiste,
      'contributingArtistes': contributingArtistes,
      'writers': writers,
      'producers': producers,
      'releaseYear': releaseYear,
      'genre': genre,
      'label': label,
      'sellingPrice': sellingPrice,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'type': 'file',
    });
  }

  Future saveOriginalBook(
    dynamic book,
    dynamic preview,
    dynamic image,
    tags,
    title,
    text,
    author,
    contributingAuthors,
    editor,
    designer,
    releaseYear,
    genre,
    publisher,
    sellingPrice,
  ) async {
    var imageFile = await _utilsService.uploadFile(
      image,
      "OriginalBook/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/artcover",
    );
    var originalBook = await _utilsService.uploadFile(
      book,
      "OriginalBook/book/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/book",
    );

    var originalBookPreview = await _utilsService.uploadFile(
      preview,
      "OriginalBook/bookPreview/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/bookPreview",
    );
    await FirebaseFirestore.instance.collection("books").add({
      'book': originalBook,
      'preview': originalBookPreview,
      'image': imageFile,
      'tags': tags,
      'title': title,
      'text': text,
      'author': author,
      'contributingAuthors': contributingAuthors,
      'editor': editor,
      'designer': designer,
      'releaseYear': releaseYear,
      'genre': genre,
      'publisher': publisher,
      'sellingPrice': sellingPrice,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'type': 'file',
    });
  }

  Stream<List<MangoPost>> getPostsByUser(uid) {
    return FirebaseFirestore.instance
        .collection("posts")
        .where("postCreator", isEqualTo: uid)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_postListFromSnapshots);
  }

  Stream<List<MangoPost>> getPostsByEverybody(uid) {
    return FirebaseFirestore.instance
        .collection("posts")
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_postListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPlaylistsByUser(uid) {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where("postCreator", isEqualTo: uid)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPlaylistsByID(uid) {
    return FirebaseFirestore.instance
        .collection("playlists")
        .where("id", isEqualTo: uid)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> mostPlayedMusic() {
    return FirebaseFirestore.instance
        .collection("playlists")
        .orderBy("plays", descending: true)
        .limit(20)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoPlaylist>?> getPlaylistsByEverybody() {
    print('fetching playlists');
    return FirebaseFirestore.instance
        .collection("playlists")
        .orderBy("timeStamp", descending: true)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoShopItem>?> getShopItemsByEverybody() {
    print('fetching playlists');
    return FirebaseFirestore.instance
        .collection("shopItems")
        .orderBy("timeStamp", descending: true)
        .snapshots()
        .map(_shopItemFromSnapshots);
  }

  Stream<List<MangoBooks>> getLibraryByUser(uid) {
    return FirebaseFirestore.instance
        .collection("books")
        .where("postCreator", isEqualTo: uid)
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoShopItem>> getItemsByUser(uid) {
    return FirebaseFirestore.instance
        .collection("shopItems")
        .where("postCreator", isEqualTo: uid)
        .snapshots()
        .map(_shopItemFromSnapshots);
  }

  Stream<List<MangoBooks>> mostReadBooks() {
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("reads", descending: true)
        .limit(20)
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoBooks>> getLibraryByEverybody(uid) {
    return FirebaseFirestore.instance
        .collection("books")
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoBooks?>> getBooksByName(word) {
    if (kDebugMode) {
      print("this is searching for $word");
    }
    return FirebaseFirestore.instance
        .collection("books")
        .orderBy("title")
        .startAt([word])
        .endAt([word + '\uf8ff'])
        .limit(10)
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoPlaylist?>> getPlaylistsByName(word) {
    if (kDebugMode) {
      print("this is searching for $word");
    }
    return FirebaseFirestore.instance
        .collection("playlists")
        .orderBy("title")
        .startAt([word])
        .endAt([word + '\uf8ff'])
        .limit(10)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoPost?>> getPostsByName(word) {
    if (kDebugMode) {
      print("this is searching for $word");
    }
    return FirebaseFirestore.instance
        .collection("posts")
        .orderBy("text")
        .startAt([word])
        .endAt([word + '\uf8ff'])
        .limit(10)
        .snapshots()
        .map(_postListFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getMusic(uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<bool> hasLikedPost(postID) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("liked")
        .doc(postID)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Stream<bool> hasRepostedPost(MangoPost post) {
    Stream<bool> value;
    if (post.repost) {
      value = FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection("reposts")
          .doc(post.originalID)
          .snapshots()
          .map((snapshots) => snapshots.exists);
    } else {
      value = FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection("reposts")
          .doc(post.id)
          .snapshots()
          .map((snapshots) => snapshots.exists);
    }
    return value;
  }

  Stream<bool> hasCommentedOnPost(postID) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("replies")
        .doc(postID)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<void> likePost(postID, creator) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('liked')
        .doc(postID)
        .set({});

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postID)
        .collection('likes')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});
  }

  Future<void> unlikePost(postID) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('liked')
        .doc(postID)
        .delete();

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(postID)
        .collection('likes')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();
  }

  Stream<bool> hasLikedBook(postID) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("likedBook")
        .doc(postID)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<void> likeBook(postID, creator) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedBook')
        .doc(postID)
        .set({});

    await FirebaseFirestore.instance
        .collection('library')
        .doc(postID)
        .collection('liked')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});
  }

  Future<void> unlikeBook(postID) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedBook')
        .doc(postID)
        .delete();

    await FirebaseFirestore.instance
        .collection('library')
        .doc(postID)
        .collection('liked')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();
  }

  Stream<bool> hasLikedItem(postID) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("shopItems")
        .doc(postID)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<void> likeItem(postID, creator) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedItem')
        .doc(postID)
        .set({});

    await FirebaseFirestore.instance
        .collection('shopItems')
        .doc(postID)
        .collection('liked')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});
  }

  Future<void> unlikeItem(postID) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedItem')
        .doc(postID)
        .delete();

    await FirebaseFirestore.instance
        .collection('shopItems')
        .doc(postID)
        .collection('liked')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();
  }

  Stream<bool> hasLikedPlaylist(postID) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("likedPlaylist")
        .doc(postID)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<void> likePlaylist(MangoPlaylist playlist) async {
    playlist.likeCount += 1;
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlist.id)
        .collection('likedPlaylist')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedPlaylist')
        .doc(playlist.id)
        .set({});
  }

  Future<void> unlikePlaylist(MangoPlaylist playlist) async {
    playlist.likeCount -= 1;
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlist.id)
        .collection('likedPlaylist')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('likedPlaylist')
        .doc(playlist.id)
        .delete();
  }

  Future repostPlaylist(MangoPlaylist playlist, bool current) async {
    if (current) {
      playlist.repostCount -= 1;
      await FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlist.id)
          .collection('repost')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('playlists')
          .where('originalID', isEqualTo: playlist.id)
          .where(
            'postCreator',
            isEqualTo: FirebaseAuth.instance.currentUser!.uid,
          )
          .get()
          .then((value) {
            if (value.docs.isEmpty) {
              return;
            }
            FirebaseFirestore.instance
                .collection('playlists')
                .doc(value.docs[0].id)
                .delete();
          });
      return;
    }

    playlist.repostCount += 1;
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlist.id)
        .collection('repost')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});

    await FirebaseFirestore.instance.collection("playlists").add({
      'link': playlist.link,
      'image': playlist.image,
      'title': playlist.title,
      'text': playlist.text,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': DateTime.now(),
      'retweet': true,
      'originalID': playlist.id,
    });
  }

  Future unrepostPlaylist(MangoPlaylist playlist) async {
    playlist.repostCount -= 1;
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlist.id)
        .collection('repost')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('playlists')
        .where('originalID', isEqualTo: playlist.id)
        .where('postCreator', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .get()
        .then((value) {
          if (value.docs.isEmpty) {
            return;
          }
          FirebaseFirestore.instance
              .collection('playlists')
              .doc(value.docs[0].id)
              .delete();
        });
  }

  Stream<bool> hasRepostedPlaylist(postID) {
    return FirebaseFirestore.instance
        .collection("playlists")
        .doc(postID)
        .collection("repost")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future repostBook(MangoBooks book, bool current) async {
    if (current) {
      book.downloads -= 1;
      await FirebaseFirestore.instance
          .collection('library')
          .doc(book.id)
          .collection('repost')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('library')
          .where('originalID', isEqualTo: book.id)
          .where(
            'postCreator',
            isEqualTo: FirebaseAuth.instance.currentUser!.uid,
          )
          .get()
          .then((value) {
            if (value.docs.isEmpty) {
              return;
            }
            FirebaseFirestore.instance
                .collection('library')
                .doc(value.docs[0].id)
                .delete();
          });
      return;
    }

    book.downloads += 1;

    await FirebaseFirestore.instance
        .collection('library')
        .doc(book.id)
        .collection('repost')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});

    await FirebaseFirestore.instance.collection("books").add({
      'link': book.fileUrl,
      'image': book.coverUrl,
      'title': book.title,
      'text': book.description,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': DateTime.now(),
      'retweet': true,
      'originalID': book.id,
    });
  }

  Future unrepostBook(MangoPlaylist playlist) async {
    playlist.repostCount -= 1;
    await FirebaseFirestore.instance
        .collection('library')
        .doc(playlist.id)
        .collection('repost')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('library')
        .where('originalID', isEqualTo: playlist.id)
        .where('postCreator', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .get()
        .then((value) {
          if (value.docs.isEmpty) {
            return;
          }
          FirebaseFirestore.instance
              .collection('library')
              .doc(value.docs[0].id)
              .delete();
        });
  }

  Stream<bool> hasRepostedBook(postID) {
    return FirebaseFirestore.instance
        .collection("books")
        .doc(postID)
        .collection("repost")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<List<MangoPost>> getFeeds() async {
    List<String> usersFollowing = await UserService().whoFollowsUser(
      FirebaseAuth.instance.currentUser!.uid,
    );

    var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

    List<MangoPost> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("posts")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_postListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate!.compareTo(adate!);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> getPlaylistByProfession(String profession) async {
    List<String> usersWithProfession = await UserService()
        .getUsersWithProfession(profession);

    var splitUsersFollowing = partition<dynamic>(usersWithProfession, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> getPlaylistByState(String profession) async {
    List<String> usersWithState = await UserService().getUsersWithState(
      profession,
    );

    var splitUsersFollowing = partition<dynamic>(usersWithState, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> getPlaylistByCity(String city) async {
    List<String> usersWithCity = await UserService().getUsersWithCity(city);

    var splitUsersFollowing = partition<dynamic>(usersWithCity, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> getPlaylistByCountry(String country) async {
    List<String> usersWithCountry = await UserService().getUsersWithCountry(
      country,
    );

    var splitUsersFollowing = partition<dynamic>(usersWithCountry, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoBooks>> getBooksByProfession(String profession) async {
    List<String> usersWithProfession = await UserService()
        .getUsersWithProfession(profession);

    var splitUsersFollowing = partition<dynamic>(usersWithProfession, 10);

    List<MangoBooks> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("books")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_libraryFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timestamp;
      var bdate = b.timestamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoBooks>> getBooksByState(String profession) async {
    List<String> usersWithState = await UserService().getUsersWithState(
      profession,
    );

    var splitUsersFollowing = partition<dynamic>(usersWithState, 10);

    List<MangoBooks> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("books")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_libraryFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timestamp;
      var bdate = b.timestamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoBooks>> getBooksByCity(String city) async {
    List<String> usersWithCity = await UserService().getUsersWithCity(city);

    var splitUsersFollowing = partition<dynamic>(usersWithCity, 10);

    List<MangoBooks> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("books")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_libraryFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timestamp;
      var bdate = b.timestamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoBooks>> getBooksByCountry(String country) async {
    List<String> usersWithCountry = await UserService().getUsersWithCountry(
      country,
    );

    var splitUsersFollowing = partition<dynamic>(usersWithCountry, 10);

    List<MangoBooks> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("books")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_libraryFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timestamp;
      var bdate = b.timestamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Stream<List<MangoPost>> getReplies(uid) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where("repliedPostID", isEqualTo: uid)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_postListFromSnapshots);
  }

  Stream<List<MangoBookComment>> getBookComments(uid) {
    return FirebaseFirestore.instance
        .collection('bookComments')
        .where("repliedCommentID", isEqualTo: uid)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_bookCommentsFromSnapshots);
  }

  Stream<List<MangoNotifications>> getNotifications() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where("receiver", isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map(_notificationsFromSnapshots);
  }

  Stream<List<MyMusic>> getUserMusicLibrary() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('my_music')
        .snapshots()
        .map(_myMusicFromSnapshots);
  }

  Stream<List<MyBooks>> getUserBooksLibrary() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('my_books')
        .snapshots()
        .map(_myBooksFromSnapshots);
  }

  Stream<List<MyVines>> getUserVinesLibrary() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('my_vines')
        .snapshots()
        .map(_myVinesFromSnapshots);
  }

  Stream<List<MangoPlaylistComment>> getPlaylistComments(uid) {
    return FirebaseFirestore.instance
        .collection('playlistComments')
        .where("repliedCommentID", isEqualTo: uid)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_playlistCommentsFromSnapshots);
  }

  Stream<List<RecentEvent>> getRecentEvents() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('recent_events')
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_recentEventsFromSnapshots);
  }

  Future<List<MangoPlaylist>> discoverPlaylistsByInterest(
    category,
    interest,
  ) async {
    List usersInterested = await UserService().checkUserInterest(
      category,
      interest,
    );

    var splitUsersFollowing = partition<dynamic>(usersInterested, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      if (kDebugMode) {
        print(splitUsersFollowing.elementAt(i));
      }
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> discoverPostsByInterest(
    category,
    interest,
  ) async {
    List usersInterested = await UserService().whoIsInterestedFollowsUser(
      category,
      interest,
    );

    var splitUsersFollowing = partition<dynamic>(usersInterested, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("posts")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoBooks>> discoverLibraryByInterest(category, interest) async {
    List usersInterested = await UserService().whoIsInterestedFollowsUser(
      category,
      interest,
    );

    var splitUsersFollowing = partition<dynamic>(usersInterested, 10);

    List<MangoBooks> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("library")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_libraryFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timestamp;
      var bdate = b.timestamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future<List<MangoPlaylist>> getPlaylistsByInterest(
    String category,
    String interest,
  ) async {
    List<String> usersFollowing = await UserService().usersWithInterest(
      category,
      interest,
    );

    var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

    List<MangoPlaylist> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("playlists")
          .where("postCreator", whereIn: splitUsersFollowing.elementAt(i))
          .orderBy('timeStamp', descending: true)
          .get();

      feedList.addAll(_playListFromSnapshots(querySnapshot));
    }

    feedList.sort((a, b) {
      var adate = a.timeStamp;
      var bdate = b.timeStamp;

      return bdate.compareTo(adate);
    });

    return feedList;
  }

  Future unrepostPost(MangoPost post, bool current) async {
    post.repostCount -= 1;
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(post.id)
        .collection('reposts')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('posts')
        .where('originalID', isEqualTo: post.id)
        .where('postCreator', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where('originalID', isEqualTo: post.originalID)
        .get()
        .then((value) {
          if (value.docs.isEmpty) {
            return;
          } else {
            FirebaseFirestore.instance
                .collection('posts')
                .doc(value.docs[0].id)
                .delete();
          }
        });
  }

  Future replyPost(String? text, dynamic file, MangoPost post) async {
    post.replyCount += 1;
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(post.id)
        .collection('replies')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .set({});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('replies')
        .doc(post.id)
        .set({});

    String? saveFile;
    if (file != null) {
      saveFile = await _utilsService.uploadFile(
        file,
        "posts/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
      );
    }
    await FirebaseFirestore.instance.collection("posts").add({
      'text': text,
      'image': saveFile,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'repliedPostID': post.id,
      'reply': true,
      'replyTo': post.id,
    });
  }

  MangoPost _postFromSnapshots(DocumentSnapshot snapshot) {
    return MangoPost(
      text: (snapshot.data() as dynamic)['text'] ?? '',
      postCreator: (snapshot.data() as dynamic)['postCreator'] ?? '',
      image: (snapshot.data() as dynamic)['image'] ?? '',
      video: (snapshot.data() as dynamic)['video'] ?? '',
      timeStamp: (snapshot.data() as dynamic)['timeStamp'] ?? 0,
      originalID: (snapshot.data() as dynamic)['originalID'] ?? '',
      multiImage: (snapshot.data() as dynamic)['multiImage'] ?? [],
      link: (snapshot.data() as dynamic)['link'] ?? '',
      replyTo: (snapshot.data() as dynamic)['replyTo'] ?? '',
      linkType: (snapshot.data() as dynamic)['linkType'] ?? '',
      id: snapshot.id,
      repostCount: (snapshot.data() as dynamic)['repostCount'] ?? 0,
      likeCount: (snapshot.data() as dynamic)['likeCount'] ?? 0,
      repost: (snapshot.data() as dynamic)['repost'] ?? false,
      isLinked: (snapshot.data() as dynamic)['isLinked'] ?? false,
      multiMedia: (snapshot.data() as dynamic)['multiMedia'] ?? false,
      reply: (snapshot.data() as dynamic)['reply'] ?? false,
      replyCount: (snapshot.data() as dynamic)['replyCount'] ?? 0,
      repliedPostID: (snapshot.data() as dynamic)['repliedPostID'] ?? '',
    );
  }

  Future<MangoPost?> getPostById(String? originalID) async {
    DocumentSnapshot postSnap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(originalID)
        .get();
    return _postFromSnapshots(postSnap);
  }

  Future<MangoPost?> getBookCommentById(String? originalID) async {
    DocumentSnapshot postSnap = await FirebaseFirestore.instance
        .collection('bookComments')
        .doc(originalID)
        .get();
    return _postFromSnapshots(postSnap);
  }

  Future sharePlaylist(MangoPlaylist playlist, bool current) async {
    if (kDebugMode) {
      print("this is current $current");
    }
    if (current) {
      playlist.repostCount -= 1;
      await FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlist.id)
          .collection('reposts')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('playlists')
          .where('originalID', isEqualTo: playlist.id)
          .where(
            'postCreator',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
          )
          .get()
          .then((value) {
            if (value.docs.isEmpty) {
              return;
            } else {
              FirebaseFirestore.instance
                  .collection('playlists')
                  .doc(value.docs[0].id)
                  .delete();
            }
          });
    } else {
      playlist.repostCount += 1;
      await FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlist.id)
          .collection('reposts')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .set({});

      await FirebaseFirestore.instance.collection('playlists').add({
        'postCreator': FirebaseAuth.instance.currentUser?.uid,
        'timeStamp': FieldValue.serverTimestamp(),
        'repost': true,
        'originalID': playlist.id,
      });
    }
  }

  Future replyPlaylist(
    String? text,
    dynamic file,
    MangoPlaylist playlist,
  ) async {
    playlist.replyCount += 1;
    await FirebaseFirestore.instance
        .collection('playlists')
        .doc(playlist.id)
        .collection('comments')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .set({});

    await FirebaseFirestore.instance.collection("playlistComments").add({
      'text': text,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'repliedCommentID': playlist.id,
    });
  }

  Future commentBook(
    String? text,
    dynamic file,
    MangoBooks mangoLibrary,
  ) async {
    mangoLibrary.reads += 1;
    await FirebaseFirestore.instance
        .collection('library')
        .doc(mangoLibrary.id)
        .collection('comments')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .set({});

    await FirebaseFirestore.instance.collection("bookComments").add({
      'text': text,
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
      'timeStamp': FieldValue.serverTimestamp(),
      'repliedCommentID': mangoLibrary.id,
    });
  }

  MangoPlaylist _playlistFromSnapshots(DocumentSnapshot snapshot) {
    print(snapshot.data());
    return MangoPlaylist(
      text: (snapshot.data() as dynamic)['text'] ?? '',
      postCreator: (snapshot.data() as dynamic)['postCreator'] ?? '',
      image: (snapshot.data() as dynamic)['image'] ?? '',
      timeStamp: (snapshot.data() as dynamic)['timeStamp'] ?? 0,
      originalID: (snapshot.data() as dynamic)['originalID'] ?? '',
      id: snapshot.id,
      repostCount: (snapshot.data() as dynamic)['repostCount'] ?? 0,
      plays: (snapshot.data() as dynamic)['plays'] ?? 0,
      likeCount: (snapshot.data() as dynamic)['likeCount'] ?? 0,
      tags: (snapshot.data() as dynamic)['tags'] ?? [],
      repost: (snapshot.data() as dynamic)['repost'] ?? false,
      reply: (snapshot.data() as dynamic)['reply'] ?? false,
      replyCount: (snapshot.data() as dynamic)['replyCount'] ?? 0,
      repliedPlaylistID: (snapshot.data() as dynamic)['repliedPostID'] ?? '',
      title: (snapshot.data() as dynamic)['title'] ?? '',
      link: (snapshot.data() as dynamic)['link'] ?? '',
      record: (snapshot.data() as dynamic)['record'] ?? '',
      type: (snapshot.data() as dynamic)['type'] ?? '',
      file: (snapshot.data() as dynamic)['file'] ?? '',
      filePreview: (snapshot.data() as dynamic)['filePreview'] ?? '',
      about: (snapshot.data() as dynamic)['about'] ?? '',
      artiste: (snapshot.data() as dynamic)['artiste'] ?? '',
      contributingArtistes:
          (snapshot.data() as dynamic)['contributingArtistes'] ?? '',
      writers: (snapshot.data() as dynamic)['writers'] ?? '',
      producers: (snapshot.data() as dynamic)['producers'] ?? '',
      releaseYear: (snapshot.data() as dynamic)['releaseYear'] ?? '',
      genre: (snapshot.data() as dynamic)['genre'] ?? '',
      label: (snapshot.data() as dynamic)['label'] ?? '',
      sellingPrice: (snapshot.data() as dynamic)['sellingPrice'] ?? '',
    );
  }

  MangoBooks _libraryBooksFromSnapshots(DocumentSnapshot doc) {
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

  Future<MangoPlaylist?> getPlaylistById(String originalID) async {
    print(originalID);
    DocumentSnapshot postSnap = await FirebaseFirestore.instance
        .collection('playlists')
        .doc(originalID)
        .get();
    return _playlistFromSnapshots(postSnap);
  }

  Stream<MangoPlaylist?> getPlaylistWithId(postId) {
    return FirebaseFirestore.instance
        .collection('playlists')
        .doc(postId)
        .snapshots()
        .map(_playlistFromFirebaseSnapshot);
  }

  Stream<MangoBooks?> getBookWithId(String postId) {
    return FirebaseFirestore.instance
        .collection('library')
        .doc(postId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return MangoBooks.fromDocument(snapshot);
          }
          return null;
        });
  }

  Stream<MangoMovie?> getMovieWithId(String postId) {
    return FirebaseFirestore.instance
        .collection('movies')
        .doc(postId)
        .snapshots()
        .map(_movieFromFirebaseSnapshot);
  }

  Future<MangoBooks?> getBooksById(String originalID) async {
    DocumentSnapshot postSnap = await FirebaseFirestore.instance
        .collection('library')
        .doc(originalID)
        .get();
    return _libraryBooksFromSnapshots(postSnap);
  }

  Stream<MangoPost?> getPostWithId(String postId) {
    return FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map(_postFromSnapshots);
  }

  Stream<List<MangoPlaylist>> getPlaylistWithTags(String tag) {
    return FirebaseFirestore.instance
        .collection('playlists')
        .where('tags', arrayContains: tag)
        .snapshots()
        .map(_playListFromSnapshots);
  }

  Stream<List<MangoBooks>> getBooksWithTags(String tag) {
    return FirebaseFirestore.instance
        .collection('library')
        .where('tags', arrayContains: tag)
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoBooks?>> getBookWithTags(String tag) {
    return FirebaseFirestore.instance
        .collection('library')
        .where('tags', arrayContains: tag)
        .snapshots()
        .map(_libraryFromSnapshots);
  }

  Stream<List<MangoPost?>> getPostWithTags(String tag) {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('tags', arrayContains: tag)
        .snapshots()
        .map(_postListFromSnapshots);
  }

  Future<List<MangoVine>> fetchMangoVinesFromFirebase() async {
    print("vines");
    final snapshot = await FirebaseFirestore.instance.collection('vines').get();
    final List<MangoVine> mangoVines = snapshot.docs.map((doc) {
      final data = doc.data();
      return MangoVine(
        postCreator: data['postCreator'] ?? '',
        thumbnailUrl: data['thumbnailUrl'] ?? '',
        videoUrl: data['videoUrl'],
        caption: data['caption'],
      );
    }).toList();
    return mangoVines;
  }

  Future<void> createMangoVine(
    BuildContext context,
    dynamic thumbnail,
    dynamic video,
    String caption,
  ) async {
    String? detectedQuality;
    if (video != null) {
      detectedQuality = await _utilsService.detectVideoQuality(video);
    }

    var saveVideoUrl = await _utilsService.uploadFile(
      video,
      "vine/video/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/video",
    );
    var thumbnailUrl = await _utilsService.uploadFile(
      thumbnail,
      "vine/video/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/thumbnail",
    );
    FirebaseFirestore.instance.collection('vines').add({
      'videoUrl': saveVideoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'videoQuality': detectedQuality ?? 'Unknown',
      'postCreator': FirebaseAuth.instance.currentUser!.uid,
    });
    Navigator.pop(context);
  }
}
