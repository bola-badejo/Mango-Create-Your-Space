import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mango/Media/compose/mango_uploader.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/Models/customModel/mang0_episodes.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:http/http.dart' as http;
import 'package:mango/Services/notification_service.dart';
import 'package:quiver/iterables.dart';
import '../../utils.dart';
import 'package:image/image.dart' as img;

class UserService {
  final UtilsService _utilsService = UtilsService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  Stream<MangoUser?> getUserInfoAuth(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return MangoUser.fromDocument(snapshot);
      }
      return null;
    });
  }

  
  Future<MangoUser?> getUserInfoOnce(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return MangoUser.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user info once: $e');
      return null;
    }
  }

  
  Future<void> createUser(MangoUser user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  /// Uploads a new profile picture (bytes, File or XFile) through the Mango
  /// uploader, updates every field the app reads it from, and removes the
  /// previous picture.
  Future<String?> updateProfileImage(dynamic imageData, [String? fileName]) =>
      _replaceUserImage(imageData, area: 'profile', fields: const ['profileImage', 'profileImageUrl'], updateAuthPhoto: true);

  Future<Uint8List> _bytesOf(dynamic data) async {
    if (data is Uint8List) return data;
    if (data is XFile) return data.readAsBytes();
    if (!kIsWeb && data is File) return data.readAsBytes();
    throw Exception('Unsupported image data');
  }

  Future<String?> _replaceUserImage(dynamic imageData, {required String area, required List<String> fields, bool updateAuthPhoto = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final bytes = await _bytesOf(imageData);
    final up = await MangoUploader.uploadWithRetry(bytes: bytes, contentType: 'image/jpeg', path: MangoUploader.userPath(area, 'jpg'));
    final ref = _firestore.collection('users').doc(user.uid);
    final previous = (await ref.get()).data()?['${area}ImagePath'];
    await ref.set({
      for (final f in fields) f: up.url,
      '${area}ImagePath': up.path,
      '${area}ImageUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (updateAuthPhoto) {
      try {
        await user.updatePhotoURL(up.url);
      } catch (_) {}
    }
    if (previous is String && previous.startsWith('users/${user.uid}/') && previous != up.path) {
      await MangoUploader.delete(previous);
    }
    return up.url;
  }

  Future<Uint8List> compressImageForWeb(
    Uint8List imageBytes, {
    int maxWidth = 1080,
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      if (image.width > maxWidth) {
        final resized = img.copyResize(image, width: maxWidth);
        return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageBytes;
    }
  }

  
  /// Uploads a new banner through the Mango uploader.
  Future<String?> updateBannerImage(dynamic imageData, [String? fileName]) =>
      _replaceUserImage(imageData, area: 'banner', fields: const ['bannerImage', 'bannerImageUrl']);

  Future<void> updateDisplayName(String displayName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating display name: $e');
      rethrow;
    }
  }

  
  Future<void> updateUsername(String username) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating username: $e');
      rethrow;
    }
  }

  
  Future<void> updateBio(String bio) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'bio': bio,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating bio: $e');
      rethrow;
    }
  }

  
  Future<void> updateDOB(String dob) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'dob': dob,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating DOB: $e');
      rethrow;
    }
  }

  
  Future<void> updateProfession(String profession) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'profession': profession,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating profession: $e');
      rethrow;
    }
  }

  
  Future<void> updateHobbies(List<String> hobbies) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'hobbies': hobbies,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating hobbies: $e');
      rethrow;
    }
  }

  
  Future<void> updateCountry(String country) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'country': country,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating country: $e');
      rethrow;
    }
  }

  
  Future<void> updateState(String state) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'state': state,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating state: $e');
      rethrow;
    }
  }

  
  Future<void> updateCity(String city) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating city: $e');
      rethrow;
    }
  }

  
  Future<void> updatePhone(String phone) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating phone: $e');
      rethrow;
    }
  }

  MangoUser? _userFromFirebaseSnapshot(DocumentSnapshot snapshot) {
    return snapshot != null
        ? MangoUser(
            gender: (snapshot.data() as dynamic)['gender'] ?? '',
            password: (snapshot.data() as dynamic)['password'] ?? '',
            email: (snapshot.data() as dynamic)['email'] ?? '',
            profession: (snapshot.data() as dynamic)['profession'] ?? '',
            phone: (snapshot.data() as dynamic)['phone'] ?? '',
            country: (snapshot.data() as dynamic)['country'] ?? '',
            state: (snapshot.data() as dynamic)['state'] ?? '',
            city: (snapshot.data() as dynamic)['city'] ?? '',
            hobbies: (snapshot.data() as dynamic)['hobbies'] ?? [],
            distributorID:
                (snapshot.data() as dynamic)['distributorID'] ??
                '', 
            creatorID: (snapshot.data() as dynamic)['creatorID'] ?? '',
            vendorID: (snapshot.data() as dynamic)['vendorID'] ?? '',
            isDistributor:
                (snapshot.data() as dynamic)['isDistributor'] ?? false,
            isCreator: (snapshot.data() as dynamic)['isCreator'] ?? false,
            isVendor: (snapshot.data() as dynamic)['isVendor'] ?? false,
            bannerImageUrl:
                (snapshot.data() as dynamic)['bannerImageUrl'] ?? '',
            profileImage: (snapshot.data() as dynamic)['profileImage'] ?? '',
            bio: (snapshot.data() as dynamic)['bio'] ?? '',
            displayName: (snapshot.data() as dynamic)['displayName'] ?? '',
            username: (snapshot.data() as dynamic)['username'] ?? '',
            fcmToken: (snapshot.data() as dynamic)['fcmToken'] ?? '',
            dob: (snapshot.data() as dynamic)['dob'] ?? '',
            verified: (snapshot.data() as dynamic)['verified'] ?? false,
            id: snapshot.id,
          )
        : null;
  }

  List<Message> _lastMessageFirebaseSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Message(
        id: doc.id,
        text: (doc.data() as dynamic)['message'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        media: (doc.data() as dynamic)['media'] ?? false,
        image: (doc.data() as dynamic)['image'] ?? '',
        receiver: (doc.data() as dynamic)['id'] ?? '',
        sender: (doc.data() as dynamic)['sender'] ?? '',
      );
    }).toList();
  }

  List<Message> _messageListFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Message(
        id: doc.id,
        text: (doc.data() as dynamic)['message'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        replyMessage: (doc.data() as dynamic)['replyMessage'] ?? '',
        replyImage: (doc.data() as dynamic)['replyImage'] ?? '',
        media: (doc.data() as dynamic)['media'] ?? false,
        image: (doc.data() as dynamic)['image'] ?? '',
        receiver: (doc.data() as dynamic)['id'] ?? '',
        sender: (doc.data() as dynamic)['sender'] ?? '',
      );
    }).toList();
  }

  Stream<MangoUser?> getUserInfo(String? uid) {
    String id = ' ';
    if (uid!.isNotEmpty) {
      id = uid;
    }
    return FirebaseFirestore.instance
        .collection("users")
        .doc(id)
        .snapshots()
        .map(_userFromFirebaseSnapshot);
  }

  Future<List<MangoUser>> getUserbyUsername(String username) async {
    String cleanUsername = username.substring(1);
    var query = await FirebaseFirestore.instance
        .collection("users")
        .where('username', isEqualTo: cleanUsername)
        .get();

    return _usersFromSnapshots(query);
  }

  Stream<int> noFollowers(uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection("followers")
        .snapshots()
        .length
        .asStream();
  }

  Stream<int> noFollowing(uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection("following")
        .snapshots()
        .length
        .asStream();
  }

  Stream<bool> isFollowing(uid, otherUid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("following")
        .doc(otherUid)
        .snapshots()
        .map((snapshots) => snapshots.exists);
  }

  Future<void> bookGenres(String genre) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('books')
        .doc(genre)
        .set({});
  }

  Future<void> uploadMessage(uid, message, replyMessage, replyImage) async {
    if (message == '') {
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('chats')
          .doc(uid)
          .collection('messages')
          .add({
            'id': uid,
            'sender': FirebaseAuth.instance.currentUser!.uid,
            'message': message,
            'replyMessage': replyMessage,
            'replyImage': replyImage,
            'timeStamp': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('messages')
          .add({
            'id': uid,
            'sender': FirebaseAuth.instance.currentUser!.uid,
            'message': message,
            'replyMessage': replyMessage,
            'timeStamp': FieldValue.serverTimestamp(),
          });
      
    }
  }

  Future<void> uploadMessageWithMedia(
    uid,
    message,
    dynamic file,
    replyMessage,
    replyImage,
  ) async {
    var saveFile = await _utilsService.uploadFile(
      file,
      "chat/image/${FirebaseAuth.instance.currentUser!.uid}/${FieldValue.serverTimestamp()}/image",
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .add({
          'id': uid,
          'sender': FirebaseAuth.instance.currentUser!.uid,
          'message': message,
          'image': saveFile,
          'media': true,
          'replyMessage': replyMessage,
          'replyImage': replyImage,
          'timeStamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('messages')
        .add({
          'id': uid,
          'sender': FirebaseAuth.instance.currentUser!.uid,
          'message': message,
          'replyMessage': replyMessage,
          'timeStamp': FieldValue.serverTimestamp(),
        });
  }

  Future<void> registerConversation(uid, message) async {
    if (message == '') {
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('conversations')
          .doc(uid)
          .set({});

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('conversations')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set({});
    }
  }

  Stream<List<Message>> getMessages(uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(uid)
        .collection('messages')
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_messageListFromSnapshots);
  }

  Future<void> followUser(uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('following')
        .doc(uid)
        .set({});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({});
  }

  Future<List<String>> whoFollowsUser(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("followers")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    users.add(uid);
    return users;
  }

  Future<List<String>> whoUserFollows(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("following")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    users.add(uid);
    return users;
  }

  Future<List<String>> whoFollowsUser2(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("followers")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<String>> whoUserFollows2(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("following")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<void> unfollowUser(uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('following')
        .doc(uid)
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .delete();
  }

  Future<List<MangoUser>> getFollowers(String uid) async {
    List<String> usersFollowing = await UserService().whoFollowsUser2(uid);

    var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

    List<MangoUser> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("id", whereIn: splitUsersFollowing.elementAt(i))
          .get();

      feedList.addAll(_usersFromSnapshots(querySnapshot));
    }

    return feedList;
  }

  Future<List<MangoUser>> getFollowing(String uid) async {
    List<String> usersFollowing = await UserService().whoUserFollows2(uid);

    var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

    List<MangoUser> feedList = [];

    for (int i = 0; i < splitUsersFollowing.length; i++) {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("id", whereIn: splitUsersFollowing.elementAt(i))
          .get();

      feedList.addAll(_usersFromSnapshots(querySnapshot));
    }

    return feedList;
  }

  Stream<List<MangoUser?>> getUserByName(word) {
    return FirebaseFirestore.instance
        .collection("users")
        .where('username', isGreaterThanOrEqualTo: [word])
        .limit(10)
        .snapshots()
        .map(_userListFromSnapshot);
  }

  Stream<List<MangoUser?>> getUserByUserName(name) {
    return FirebaseFirestore.instance
        .collection("users")
        .where('username', isEqualTo: name)
        .limit(1)
        .snapshots()
        .map(_userListFromSnapshot);
  }

  List<MangoUser> _usersFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoUser(
        gender: (doc.data() as dynamic)['gender'] ?? '',
        password: (doc.data() as dynamic)['password'] ?? '',
        profession: (doc.data() as dynamic)['profession'] ?? '',
        phone: (doc.data() as dynamic)['phone'] ?? '',
        country: (doc.data() as dynamic)['country'] ?? '',
        state: (doc.data() as dynamic)['state'] ?? '',
        city: (doc.data() as dynamic)['city'] ?? '',
        hobbies: (doc.data() as dynamic)['hobbies'] ?? [],
        email: (doc.data() as dynamic)['email'] ?? '',
        bannerImageUrl: (doc.data() as dynamic)['bannerImageUrl'] ?? '',
        profileImage: (doc.data() as dynamic)['profileImage'] ?? '',
        bio: (doc.data() as dynamic)['bio'] ?? '',
        displayName: (doc.data() as dynamic)['displayName'] ?? '',
        username: (doc.data() as dynamic)['username'] ?? '',
        distributorID:
            (doc.data() as dynamic)['distributorID'] ??
            (doc.data() as dynamic)['contributorID'] ??
            '', 
        creatorID: (doc.data() as dynamic)['creatorID'] ?? '',
        vendorID: (doc.data() as dynamic)['vendorID'] ?? '',
        isDistributor: (doc.data() as dynamic)['isDistributor'] ?? false,
        isCreator: (doc.data() as dynamic)['isCreator'] ?? false,
        isVendor: (doc.data() as dynamic)['isVendor'] ?? false,
        verified: (doc.data() as dynamic)['verified'] ?? false,
        dob: (doc.data() as dynamic)['dob'] ?? '',
        id: doc.id,
        fcmToken: (doc.data() as dynamic)['fcmToken'] ?? '',
      );
    }).toList();
  }

  Future saveUser(a, b, c, d, e, f, g) async {
    await FirebaseFirestore.instance.collection("users").add({
      'id': a,
      'username': b,
      'password': c,
      'email': d,
      'gender': e,
      'timeCreated': f,
      'profileImage': g,
    });
  }

  Future<void> initializeUserInFirestore({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    try {
      final userData = {
        'uid': uid,
        'email': email,
        'displayName': displayName ?? '',
        'username': '',
        'bio': '',
        'phone': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      print('UserService: Initialized new user in Firestore');
    } catch (e) {
      print('UserService: Error initializing user in Firestore: $e');
      rethrow;
    }
  }

  
  
  
  
  
  
  

  
  

  
  
  
  
  

  
  
  
  
  
  
  

  
  

  
  
  
  
  

  Future<void> ensureUserDocumentExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      
      await userDoc.set({
        'id': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'username': '',
        'bio': '',
        'profileImage': user.photoURL ?? '',
        'bannerImageUrl': '',
        'phone': '',
        'profession': '',
        'city': '',
        'country': '',
        'state': '',
        'dob': '',
        'gender': '',
        'hobbies': [],
        'verified': false,
        'isCreator': false,
        'isVendor': false,
        'isDistributor': false,
        'creatorID': '',
        'vendorID': '',
        'contributorID': '',
        'fcmToken': '',
        'password': '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  
  
  
  

  
  
  
  
  

  Future<void> updateProfile(
    String? displayName,
    String? username,
    String? bio,
    String? gender,
  ) async {
    await ensureUserDocumentExists();

    Map<String, Object> data = HashMap();
    if (username != '') data['username'] = username!;
    if (displayName != '') data['displayName'] = displayName!;
    if (bio != '') data['bio'] = bio!;
    if (gender != '') data['gender'] = gender!;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set(data, SetOptions(merge: true));
  }

  Stream<List<MangoUser>> getAllUsers(uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .snapshots()
        .map(_usersFromSnapshots);
  }

  Future<List> getAllUserName() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();
    final allData = querySnapshot.docs
        .map((doc) => doc.get('username'))
        .toList();
    return allData;
  }

  Future<List<String>> usersWithInterest(
    String category,
    String interest,
  ) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users/$category/")
        .where("selectedGenres", arrayContains: interest)
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  List<MangoUser?> _userListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoUser(
        gender: (doc.data() as dynamic)['gender'] ?? '',
        password: (doc.data() as dynamic)['password'] ?? '',
        profession: (doc.data() as dynamic)['profession'] ?? '',
        phone: (doc.data() as dynamic)['phone'] ?? '',
        country: (doc.data() as dynamic)['country'] ?? '',
        state: (doc.data() as dynamic)['state'] ?? '',
        city: (doc.data() as dynamic)['city'] ?? '',
        hobbies: (doc.data() as dynamic)['hobbies'] ?? [],
        email: (doc.data() as dynamic)['email'] ?? '',
        bannerImageUrl: (doc.data() as dynamic)['bannerImageUrl'] ?? '',
        profileImage: (doc.data() as dynamic)['profileImage'] ?? '',
        bio: (doc.data() as dynamic)['bio'] ?? '',
        displayName: (doc.data() as dynamic)['displayName'] ?? '',
        username: (doc.data() as dynamic)['username'] ?? '',
        distributorID:
            (doc.data() as dynamic)['distributorID'] ??
            (doc.data() as dynamic)['contributorID'] ??
            '', 
        creatorID: (doc.data() as dynamic)['creatorID'] ?? '',
        vendorID: (doc.data() as dynamic)['vendorID'] ?? '',
        isDistributor: (doc.data() as dynamic)['isDistributor'] ?? false,
        isCreator: (doc.data() as dynamic)['isCreator'] ?? false,
        isVendor: (doc.data() as dynamic)['isVendor'] ?? false,
        verified: (doc.data() as dynamic)['verified'] ?? false,
        dob: (doc.data() as dynamic)['dob'] ?? '',
        id: doc.id,
        fcmToken: (doc.data() as dynamic)['fcmToken'] ?? '',
      );
    }).toList();
  }

  Future<List<String>> allUserId(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<String>> getData() async {
    
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .get();
    
    final allData = querySnapshot.docs.map((doc) => doc.id).toList();
    return allData;
  }

  Future<List<String>> userInterestList(uid) async {
    final result = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("interests")
        .get();

    final users = result.docs.map((doc) => doc.id).toList();
    
    
    return users;
  }

  Future<List<String>> getInterest(interest) async {
    List<String> interestList = [];
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('interests')
        .doc(interest)
        .get()
        .then((value) {
          
          for (var value in List.from(value.data()!['selectedGenres'])) {
            interestList.add(value);
          }
        });
    

    return interestList;
  }

  Future<List> checkUserInterest(category, interest) async {
    List<String> interestList = [];

    var uid = await getData();
    var val = [];
    for (int i = 0; i < uid.length; i++) {
      QuerySnapshot? querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid[i])
          .collection('interests')
          .doc(category)
          .get()
          .then((value) {
            
            for (var value in List.from(value.data()!['selectedGenres'])) {
              interestList.add(value);
            }
            return null;
          });
      if (interestList.contains(interest)) {
        val.add(uid[i]);
      } else {}
    }
    return val;
  }

  Future<String> doesUserHaveInterest(category, interest, uid) async {
    final DocumentReference result = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("interests")
        .doc(category);

    DocumentSnapshot value = await result.get();
    List<dynamic>? documents = value['selectedGenres'];
    if (documents!.isNotEmpty) {
      return uid;
    } else {
      return "uninterested";
    }
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  

  Future<List> whoIsInterestedFollowsUser(category, interest) async {
    var uid = await getData();
    var val = [];
    for (int i = 0; i < uid.length; i++) {
      var feedback = await doesUserHaveInterest(category, interest, uid[i]);
      if (feedback == "uninterested") {
      } else {
        val.add(feedback);
      }
    }

    return val;
  }

  Future<List<String>> getConversators(uid) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("conversations")
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<Message>> getConversationInfo(uid) async {
    {
      List<String> usersFollowing = await UserService().getConversators(uid);

      var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

      List<Message> feedList = [];

      for (int i = 0; i < usersFollowing.length; i++) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('chats')
            .doc(usersFollowing[i])
            .collection('messages')
            .orderBy('timeStamp', descending: true)
            .limit(1)
            .get();

        feedList.addAll(_lastMessageFirebaseSnapshot(querySnapshot));
      }

      feedList.sort((a, b) {
        var adate = a.timeStamp;
        var bdate = b.timeStamp;

        return bdate.compareTo(adate);
      });

      return feedList;
    }
  }

  List<MangoEpisodes> _episodesFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoEpisodes(
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        id: doc.id,
      );
    }).toList();
  }

  List<MangoEpisodes> _episodeListFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return MangoEpisodes(
        postCreator: (doc.data() as dynamic)['postCreator'] ?? '',
        image: (doc.data() as dynamic)['image'] ?? '',
        timeStamp: (doc.data() as dynamic)['timeStamp'] ?? 0,
        id: doc.id,
      );
    }).toList();
  }

  Future<List<MangoEpisodes>> getEpisodeInfo(uid) async {
    {
      List<String> usersFollowing = await UserService().whoUserFollows(uid);
      usersFollowing.add(FirebaseAuth.instance.currentUser!.uid);
      var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

      List<MangoEpisodes> feedList = [];

      for (int i = 0; i < usersFollowing.length; i++) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('episodes')
            .where("postCreator", isEqualTo: usersFollowing[i])
            .orderBy('timeStamp', descending: true)
            .limit(1)
            .get();
        feedList.addAll(_episodesFromSnapshots(querySnapshot));
      }

      feedList.sort((a, b) {
        var adate = a.timeStamp;
        var bdate = b.timeStamp;

        return bdate.compareTo(adate);
      });
      return feedList;
    }
  }

  Future<List<MangoUser>> findUsersWithEpisodes(uid) async {
    {
      List<String> usersFollowing = await UserService().whoUserFollows(uid);
      usersFollowing.add(FirebaseAuth.instance.currentUser!.uid);
      var splitUsersFollowing = partition<dynamic>(usersFollowing, 10);

      List<MangoEpisodes> feedList = [];
      List<MangoUser> userList = [];
      List uidList = [];

      final MangoUser user0 = MangoUser.empty();

      for (int i = 0; i < splitUsersFollowing.length; i++) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('episodes')
            .where("postCreator", isEqualTo: splitUsersFollowing.elementAt(i))
            .orderBy('timeStamp', descending: true)
            .limit(1)
            .get()
            .then((value) {
              if (value.docs.isNotEmpty) {
                
                uidList.add(splitUsersFollowing.elementAt(i));
              } else {}
              return value;
            });
        feedList.addAll(_episodesFromSnapshots(querySnapshot));
      }

      for (int j = 0; j < feedList.length; j++) {
        StreamBuilder<MangoUser?>(
          initialData: user0,
          stream: UserService().getUserInfo(uidList[j]),
          builder: (BuildContext context, AsyncSnapshot<MangoUser?> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
            }
            MangoUser? user = snapshot.data!;
            userList.add(user);
            return Container();
          },
        );
      }
      return userList;
    }
  }

  
  
  
  
  
  
  

  Future<List<String>> getUsersWithProfession(String profession) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('users')
        .where('profession', isEqualTo: profession)
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<String>> getUsersWithState(String state) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('users')
        .where('state', isEqualTo: state)
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<String>> getUsersWithCity(String city) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('users')
        .where('city', isEqualTo: city)
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Future<List<String>> getUsersWithCountry(String country) async {
    QuerySnapshot query = await FirebaseFirestore.instance
        .collection('users')
        .where('country', isEqualTo: country)
        .get();

    final users = query.docs.map((doc) => doc.id).toList();
    return users;
  }

  Stream<List<MangoUser>> getUsersWithHobbies(String hobby) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('hobbies', arrayContains: hobby)
        .snapshots()
        .map(_usersFromSnapshots);
  }

  Stream<List<MangoEpisodes>> getEpisodes(uid) {
    return FirebaseFirestore.instance
        .collection('episodes')
        .where('postCreator', isEqualTo: uid)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_episodeListFromSnapshots);
  }

  /// No longer sends anything from the app. It used a Firebase Cloud
  /// Messaging server key embedded in the app, which let anyone send pushes
  /// to anyone; that key must be revoked. Follows, likes, replies, mentions
  /// and Space activity are now notified by the server (functions/notify).
  @Deprecated('Notifications are sent by the server')
  Future sendNotification(
    var id,
    String page,
    String message,
    String title,
    String receiverID,
    String receiverToken,
  ) async {}

  Future sendNotificationToTopic(
    String message,
    String title,
    String receiverID,
  ) async {
    final data = {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'id': '1',
      'status': 'done',
      'body': message,
      'title': title,
    };

    try {
      http.Response response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization':
              'key=AAAA7NEUBtQ:APA91bFXJb8RWaNPOwdeu3Ih3Jlb3hvQWjp1eRSxMs2xpMuOcJMdzYQYqZHP82-hYCDErFrrQdfrZ9cGiTlkNKvrgJqmaRrNoVqjPKNx34E76tyqwg2GLrt8cR9qSJveJEn0zxyW6qgY',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{'title': title, 'body': message},
          'priority': 'high',
          'data': data,
          'to': '/topics/${FirebaseAuth.instance.currentUser!.uid}',
        }),
      );

      if (response.statusCode == 200) {
        
      } else {
        
      }
    } catch (e) {
      
    }
    return;
  }
}
