import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/cloud/user_services.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class ProfileController extends GetxController {
  static ProfileController get instance => Get.find();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final UtilsService _utilsService = UtilsService();

  var userData = Rxn<MangoUser>();
  var userPosts = <MangoPost>[].obs;
  var userBooks = <MangoBooks>[].obs;
  var userMusic = <Music>[].obs;
  var userSpaces = <SpaceModel>[].obs;

  var isLoading = true.obs;
  var postsCount = 0.obs;
  var booksCount = 0.obs;
  var musicCount = 0.obs;
  var spacesCount = 0.obs;
  var followersCount = 0.obs;
  var followingCount = 0.obs;
  var podcastsCount = 0.obs;
  var moviesCount = 0.obs;
  var productsCount = 0.obs;
  var isUpdating = false.obs;
  
  
  var isCreator = false.obs;
  var isVendor = false.obs;
  var isDistributor = false.obs;
  var contributorData = {}.obs;

  
  var creatorImageUrl = ''.obs;
  var creatorLogoUrl = ''.obs;
  var distributorImageUrl = ''.obs;
  var distributorLogoUrl = ''.obs;
  var vendorImageUrl = ''.obs;
  var vendorLogoUrl = ''.obs;

  Uint8List? webProfileImageBytes;
  Uint8List? webBannerImageBytes;
  String? webProfileImageName;
  String? webBannerImageName;

  @override
  void onInit() {
    super.onInit();
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        loadUserData(user.uid);
      }
    });
  }

  Future<void> loadUserData(String userId) async {
    try {
      isLoading.value = true;
      print('Loading user data for userId: $userId');
      
      
      await _ensureUserDocumentExists(userId);
      
      
      await _loadUserProfile(userId);

      if (userData.value != null) {
        await Future.wait([
          _loadContributorStatus(userId),
          _loadUserPosts(userId),
          _loadUserBooks(userData.value!.creatorID),
          _loadUserMusic(userData.value!.creatorID),
          _loadUserSpaces(userId),
          _loadUserPodcasts(userData.value!.creatorID),
          _loadUserMovies(userData.value!.creatorID),
          _loadUserProducts(userData.value!.vendorID),
          _loadUserStats(userId),
        ]);
      }
    } catch (e) {
      print('Error loading user data: $e');
      Get.snackbar(
        'Error',
        'Failed to load profile data: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _ensureUserDocumentExists(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('User document not found. Creating new user document for: $userId');
        
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          
          final newUser = MangoUser(
            id: userId,
            email: currentUser.email ?? '',
            gender: '',
            password: '',
            bannerImageUrl: '',
            profileImage: currentUser.photoURL ?? '',
            bio: '',
            displayName: currentUser.displayName ?? 'User',
            dob: '',
            country: '',
            city: '',
            state: '',
            profession: '',
            phone: currentUser.phoneNumber ?? '',
            username: _generateUsername(currentUser.email ?? 'user'),
            fcmToken: '',
            creatorID: '',
            vendorID: '',
            distributorID: '',
            hobbies: [],
            verified: currentUser.emailVerified,
            isCreator: false,
            isVendor: false,
            isDistributor: false,
            creatorName: '',
            vendorName: '',
            distributorName: '',
            creatorImageUrl: '',
            vendorImageUrl: '',
            distributorImageUrl: '',
            creatorLogoUrl: '',
            vendorLogoUrl: '',
            distributorLogoUrl: '',
          );
          
          await _firestore.collection('users').doc(userId).set(newUser.toMap());
          print('User document created successfully');
        }
      }
    } catch (e) {
      print('Error ensuring user document exists: $e');
    }
  }

  String _generateUsername(String email) {
    if (email.contains('@')) {
      final localPart = email.split('@')[0];
      
      final cleanName = localPart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final random = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      return '$cleanName$random';
    }
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        userData.value = MangoUser.fromDocument(doc);
        print('User profile loaded successfully for: $userId');
      } else {
        print('User document still not found after creation attempt: $userId');
        
        final currentUser = _auth.currentUser;
        userData.value = MangoUser(
          id: userId,
          email: currentUser?.email ?? '',
          gender: '',
          password: '',
          bannerImageUrl: '',
          profileImage: currentUser?.photoURL ?? '',
          bio: '',
          displayName: currentUser?.displayName ?? 'User',
          dob: '',
          country: '',
          city: '',
          state: '',
          profession: '',
          phone: currentUser?.phoneNumber ?? '',
          username: _generateUsername(currentUser?.email ?? 'user'),
          fcmToken: '',
          creatorID: '',
          vendorID: '',
          distributorID: '',
          hobbies: [],
          verified: currentUser?.emailVerified ?? false,
          isCreator: false,
          isVendor: false,
          isDistributor: false,
          creatorName: '',
          vendorName: '',
          distributorName: '',
          creatorImageUrl: '',
          vendorImageUrl: '',
          distributorImageUrl: '',
          creatorLogoUrl: '',
          vendorLogoUrl: '',
          distributorLogoUrl: '',
        );
      }
    } catch (e) {
      print('Error loading user profile: $e');
      rethrow;
    }
  }

  Future<void> _loadContributorStatus(String userId) async {
    try {
      
      isCreator.value = false;
      isVendor.value = false;
      isDistributor.value = false;
      creatorImageUrl.value = '';
      creatorLogoUrl.value = '';
      distributorImageUrl.value = '';
      distributorLogoUrl.value = '';
      vendorImageUrl.value = '';
      vendorLogoUrl.value = '';
      contributorData.clear();

      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('contributors')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] as String?)?.toLowerCase() ?? '';
        final contributorId = data['contributorId'] ?? doc.id;

        contributorData[contributorId] = data;

        switch (type) {
          case 'creator':
            isCreator.value = true;
            creatorImageUrl.value = data['profileImageUrl'] ?? data['creatorImageUrl'] ?? '';
            creatorLogoUrl.value = data['logoImageUrl'] ?? data['creatorLogoUrl'] ?? '';
            if (userData.value != null) {
              userData.value!.creatorID = contributorId;
            }
            break;
          case 'distributor':
            isDistributor.value = true;
            distributorImageUrl.value = data['profileImageUrl'] ?? data['distributorImageUrl'] ?? '';
            distributorLogoUrl.value = data['logoImageUrl'] ?? data['distributorLogoUrl'] ?? '';
            if (userData.value != null) {
              userData.value!.distributorID = contributorId;
            }
            break;
          case 'vendor':
            isVendor.value = true;
            vendorImageUrl.value = data['profileImageUrl'] ?? data['vendorImageUrl'] ?? '';
            vendorLogoUrl.value = data['logoImageUrl'] ?? data['vendorLogoUrl'] ?? '';
            if (userData.value != null) {
              userData.value!.vendorID = contributorId;
            }
            break;
        }
      }

      
      if (userData.value != null && (isCreator.value || isVendor.value || isDistributor.value)) {
        userData.refresh();
      }
    } catch (e) {
      print('Error loading contributor status: $e');
    }
  }

  Future<void> refreshContributorStatus(String userId) async {
    await _loadContributorStatus(userId);
  }

  Future<void> _loadUserPosts(String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('postCreator', isEqualTo: userId)
          .orderBy('timeStamp', descending: true)
          .limit(20)
          .get();

      userPosts.value = query.docs
          .map((doc) => MangoPost.fromDocument(doc))
          .toList();
      postsCount.value = userPosts.length;
    } catch (e) {
      print('Error loading posts: $e');
      userPosts.value = [];
    }
  }

  Future<void> _loadUserBooks(String creatorId) async {
    try {
      if (creatorId.isEmpty) {
        userBooks.value = [];
        booksCount.value = 0;
        return;
      }

      final query = await _firestore
          .collection('library')
          .where('postCreator', isEqualTo: creatorId)
          .orderBy('timeStamp', descending: true)
          .limit(10)
          .get();

      userBooks.value = query.docs
          .map((doc) => MangoBooks.fromDocument(doc))
          .toList();
      booksCount.value = userBooks.length;
    } catch (e) {
      print('Error loading books: $e');
      userBooks.value = [];
    }
  }

  Future<void> _loadUserMusic(String creatorId) async {
    try {
      if (creatorId.isEmpty) {
        userMusic.value = [];
        musicCount.value = 0;
        return;
      }

      final query = await _firestore
          .collection('music')
          .where('artistId', isEqualTo: creatorId)
          .orderBy('timeStamp', descending: true)
          .limit(10)
          .get();

      userMusic.value = query.docs.map((doc) => Music.fromDocument(doc)).toList();
      musicCount.value = userMusic.length;
    } catch (e) {
      print('Error loading music: $e');
      userMusic.value = [];
    }
  }

  Future<void> _loadUserPodcasts(String creatorId) async {
    try {
      if (creatorId.isEmpty) {
        podcastsCount.value = 0;
        return;
      }

      final query = await _firestore
          .collection('podcasts')
          .where('postCreator', isEqualTo: creatorId)
          .count()
          .get();

      podcastsCount.value = query.count ?? 0;
    } catch (e) {
      print('Error loading podcasts count: $e');
      podcastsCount.value = 0;
    }
  }

  Future<void> _loadUserMovies(String creatorId) async {
    try {
      if (creatorId.isEmpty) {
        moviesCount.value = 0;
        return;
      }

      final query = await _firestore
          .collection('movies')
          .where('postCreator', isEqualTo: creatorId)
          .count()
          .get();

      moviesCount.value = query.count ?? 0;
    } catch (e) {
      print('Error loading movies count: $e');
      moviesCount.value = 0;
    }
  }

  Future<void> _loadUserProducts(String vendorId) async {
    try {
      if (vendorId.isEmpty) {
        productsCount.value = 0;
        return;
      }

      final query = await _firestore
          .collection('products')
          .where('postCreator', isEqualTo: vendorId)
          .count()
          .get();

      productsCount.value = query.count ?? 0;
    } catch (e) {
      print('Error loading products count: $e');
      productsCount.value = 0;
    }
  }

  Future<void> _loadUserSpaces(String userId) async {
    try {
      final query = await _firestore
          .collection('spaces')
          .where('postCreator', isEqualTo: userId)
          .limit(10)
          .get();

      userSpaces.value = query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SpaceModel(
          id: doc.id,
          title: data['title'] ?? 'Untitled Space',
          category: data['category'] ?? '',
          description: data['description'] ?? '',
          price: data['price']?.toString() ?? '',
          members: data['members'] ?? 0,
          rating: '0',
          iconUrl: data['iconUrl'] ?? '',
          image: data['image'] ?? '',
          spaceBackground: data['spaceBackground'] ?? '',
          postCreator: data['postCreator'] ?? userId,
          isPrivate: data['isPrivate'] ?? false,
          hasMusic: data['hasMusic'] ?? false,
          hasMovies: data['hasMovies'] ?? false,
          hasBooks: data['hasBooks'] ?? false,
          hasVines: data['hasVines'] ?? false,
          hasShop: data['hasShop'] ?? false,
          hasLounge: data['hasLounge'] ?? false,
          hasPodcast: data['hasPodcast'] ?? false,
          collaborators: data['collaborators'] ?? [],
        );
      }).toList();

      spacesCount.value = userSpaces.length;
    } catch (e) {
      print('Error loading spaces: $e');
      userSpaces.value = [];
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      final followersQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();
      followersCount.value = followersQuery.count ?? 0;

      final followingQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();
      followingCount.value = followingQuery.count ?? 0;
    } catch (e) {
      print('Error loading stats: $e');
      followersCount.value = 0;
      followingCount.value = 0;
    }
  }

  Future<void> updateProfileField(String field, String newValue, BuildContext context) async {
    try {
      isUpdating.value = true;
      final userId = _auth.currentUser!.uid;

      Map<String, dynamic> updateData = {};

      switch (field) {
        case 'Name':
        case 'Display Name':
          updateData['displayName'] = newValue;
          break;
        case 'Username':
          await _checkUsernameAvailability(newValue);
          updateData['username'] = newValue;
          break;
        case 'Bio':
          updateData['bio'] = newValue;
          break;
        case 'Location':
          final locationParts = newValue.split(',');
          if (locationParts.length >= 2) {
            updateData['city'] = locationParts[0].trim();
            updateData['country'] = locationParts[1].trim();
          } else {
            updateData['city'] = newValue;
          }
          break;
        case 'Email':
          await _updateEmail(newValue, context);
          return;
        case 'Password':
          return;
        case 'Phone':
          updateData['phone'] = newValue;
          break;
        case 'Profession':
          updateData['profession'] = newValue;
          break;
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      await _loadUserProfile(userId);

      _utilsService.showSnackbar(
        'Success',
        '$field updated successfully',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      print('Error updating $field: $e');
      _utilsService.showSnackbar(
        'Error',
        'Failed to update $field: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
      rethrow;
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    String cleanUsername = username.startsWith('@')
        ? username.substring(1)
        : username;

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty &&
        query.docs.first.id != _auth.currentUser!.uid) {
      throw 'Username @$cleanUsername is already taken';
    }
  }

  Future<void> _updateEmail(String newEmail, BuildContext context) async {
    try {
      final user = _auth.currentUser!;

      await user.verifyBeforeUpdateEmail(newEmail);
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
      });

      await _loadUserProfile(user.uid);

      _utilsService.showSnackbar(
        'Success',
        'Verification email sent to $newEmail. Please verify your new email address.',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        context: context,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please re-authenticate to change your email';
      } else if (e.code == 'email-already-in-use') {
        throw 'This email is already in use by another account';
      } else if (e.code == 'invalid-email') {
        throw 'Please enter a valid email address';
      }
      throw e.message ?? 'Failed to update email';
    }
  }

  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
    BuildContext context,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No user logged in';

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _utilsService.showSnackbar(
        'Success',
        'Password updated successfully',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Current password is incorrect';
      }
      throw e.message ?? 'Failed to update password';
    }
  }

  /// Saves a picture chosen with [pickImage] (Mango composer bytes) or an
  /// XFile, through the shared upload path in UserService.
  Future<void> updateProfileImage(dynamic imageData, BuildContext context) async {
    try {
      isUpdating.value = true;
      final userId = _auth.currentUser!.uid;
      final data = imageData is Map ? imageData['bytes'] : imageData;
      await UserService().updateProfileImage(data);
      await _loadUserProfile(userId);
      _utilsService.showSnackbar(
        'Success',
        'Profile picture updated',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      _utilsService.showSnackbar(
        'Error',
        "Couldn't update your profile picture. Try again.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      isUpdating.value = false;
    }
  }

  /// Saves a picture chosen with [pickImage] (Mango composer bytes) or an
  /// XFile, through the shared upload path in UserService.
  Future<void> updateBannerImage(dynamic imageData, BuildContext context) async {
    try {
      isUpdating.value = true;
      final userId = _auth.currentUser!.uid;
      final data = imageData is Map ? imageData['bytes'] : imageData;
      await UserService().updateBannerImage(data);
      await _loadUserProfile(userId);
      _utilsService.showSnackbar(
        'Success',
        'Banner updated',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      _utilsService.showSnackbar(
        'Error',
        "Couldn't update your banner. Try again.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      isUpdating.value = false;
    }
  }

  Future<String> _uploadImageForWeb(
    Uint8List bytes,
    String path,
    String fileName,
  ) async {
    try {
      final Reference storageRef = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'platform': 'web',
        },
      );

      final UploadTask uploadTask = storageRef.putData(bytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image for web: $e');
      throw Exception('Failed to upload image');
    }
  }

  Future<String> uploadImage(XFile imageFile, String path) async {
    try {
      final Reference storageRef = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      File file = File(imageFile.path);
      final UploadTask uploadTask = storageRef.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image');
    }
  }

  /// Picks a picture through the Mango composer (preview, crop, filters).
  /// Returns {'bytes', 'name', 'size'} on every platform, or null.
  Future<dynamic> pickImage(BuildContext context) async {
    final media = await MangoComposer.pick(context, allowCaption: false, actionLabel: 'Use');
    if (media == null) return null;
    return {'bytes': media.bytes, 'name': media.name, 'size': media.size};
  }

  Future<void> updateProfileType(String type, BuildContext context) async {
    try {
      final userId = _auth.currentUser!.uid;
      Map<String, dynamic> updateData = {
        'isCreator': false,
        'isVendor': false,
        'isDistributor': false,
      };

      switch (type.toLowerCase()) {
        case 'creator':
          updateData['isCreator'] = true;
          break;
        case 'vendor':
          updateData['isVendor'] = true;
          break;
        case 'distributor':
          updateData['isDistributor'] = true;
          break;
      }

      await _firestore.collection('users').doc(userId).update(updateData);
      await _loadUserProfile(userId);

      _utilsService.showSnackbar(
        'Success',
        'Profile type updated to $type',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      _utilsService.showSnackbar(
        'Error',
        'Failed to update profile type: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
      rethrow;
    }
  }

  
  String get displayName => userData.value?.displayName ?? 'Unknown User';
  String get username => userData.value?.username ?? 'unknown';
  String get bio => userData.value?.bio ?? 'No bio yet';
  String get location {
    final city = userData.value?.city ?? '';
    final country = userData.value?.country ?? '';
    if (city.isEmpty && country.isEmpty) return '';
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }
  String get profileImageUrl => userData.value?.profileImage ?? '';
  String get bannerImageUrl => userData.value?.bannerImageUrl ?? '';
  String get email => userData.value?.email ?? _auth.currentUser?.email ?? '';
  String get phoneNumber => userData.value?.phone ?? '';
  String get profession => userData.value?.profession ?? '';
  String get gender => userData.value?.gender ?? '';

  String get profileType {
    if (userData.value?.isCreator == true) return 'creator';
    if (userData.value?.isVendor == true) return 'vendor';
    if (userData.value?.isDistributor == true) return 'distributor';
    return 'user';
  }

  Future<void> refreshData(String userId) async {
    await loadUserData(userId);
  }

  bool isCurrentUser(String userId) {
    return _auth.currentUser?.uid == userId;
  }

  Future<void> debugCheckUserState(String userId) async {
    print('=== DEBUG USER STATE ===');
    print('User ID: $userId');
    
    
    final authUser = _auth.currentUser;
    print('Auth user exists: ${authUser != null}');
    if (authUser != null) {
      print('Auth UID: ${authUser.uid}');
      print('Auth Email: ${authUser.email}');
      print('Auth Display Name: ${authUser.displayName}');
      print('Auth UID matches userId: ${authUser.uid == userId}');
    }
    
    
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      print('Firestore document exists: ${doc.exists}');
      if (doc.exists) {
        print('Firestore data keys: ${doc.data()?.keys}');
      }
    } catch (e) {
      print('Error checking Firestore: $e');
    }
    
    print('=== END DEBUG ===');
  }
}