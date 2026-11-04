// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Models/customModel/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== SUBSCRIPTION METHODS ====================
  
  /// Check if current user is subscribed to a space
  Stream<bool> isSubscribed(String spaceId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(false);

    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('subscribers')
        .doc(currentUserId)
        .snapshots()
        .map((docSnapshot) => docSnapshot.exists);
  }

  /// Toggle subscription for a space
  Future<void> toggleSubscription(String spaceId, bool currentlySubscribed) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final spaceRef = _db.collection('spaces').doc(spaceId);
    final subscriberRef = spaceRef.collection('subscribers').doc(currentUserId);

    try {
      await _db.runTransaction((transaction) async {
        final spaceDoc = await transaction.get(spaceRef);
        if (!spaceDoc.exists) throw Exception("Space does not exist");

        final currentMembers = spaceDoc.data()?['members'] ?? 0;

        if (currentlySubscribed) {
          // Unsubscribe - delete subscriber and decrement member count
          transaction.delete(subscriberRef);
          transaction.update(spaceRef, {
            'members': (currentMembers - 1).clamp(0, double.infinity).toInt(),
          });
        } else {
          // Subscribe - add subscriber and increment member count
          transaction.set(subscriberRef, {
            'userId': currentUserId,
            'subscribedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(spaceRef, {
            'members': (currentMembers + 1).toInt(),
          });
        }
      });
    } catch (e) {
      print('Subscription error: $e');
      throw e;
    }
  }

  /// Get subscriber count for a space
  Stream<int> getSubscriberCount(String spaceId) {
    return _db
        .collection('spaces')
        .doc(spaceId)
        .collection('subscribers')
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.length);
  }

  /// Get all spaces the current user is subscribed to
  Stream<List<String>> getUserSubscriptions() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _db
        .collectionGroup('subscribers')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map(
          (querySnapshot) => querySnapshot.docs
              .map((doc) => doc.reference.parent.parent?.id)
              .where((id) => id != null)
              .cast<String>()
              .toList(),
        );
  }

  /// Check if user can join a space (checks payment if required)
  Future<bool> canUserJoinSpace(String spaceId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    final spaceDoc = await _db.collection('spaces').doc(spaceId).get();
    if (!spaceDoc.exists) return false;

    final spaceData = spaceDoc.data()!;
    final isFree = spaceData['price'] == null ||
        spaceData['price'].isEmpty ||
        spaceData['price'] == '0';

    if (isFree) return true;

    // Check if user has purchased access
    final purchaseDoc = await _db
        .collection('spaces')
        .doc(spaceId)
        .collection('purchases')
        .doc(currentUserId)
        .get();

    return purchaseDoc.exists;
  }

  // ==================== SPACE FETCHING METHODS ====================

  /// Convert snapshot to SpaceModel list
  List<SpaceModel> _spacesFromSnapshots(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return SpaceModel(
        id: doc.id,
        title: data['title'] ?? '',
        category: data['category'] ?? '',
        price: data['price']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        postCreator: data['postCreator'] ?? '',
        members: data['members'] ?? 0,
        rating: data['rating'] ?? '',
        spaceBackground: data['spaceBackground'] ?? '',
        iconUrl: data['iconUrl'] ?? '',
        image: data['image'] ?? '',
        isPrivate: data['isPrivate'] ?? false,
        hasMusic: data['hasMusic'] ?? false,
        hasShop: data['hasShop'] ?? false,
        hasBooks: data['hasBooks'] ?? false,
        hasMovies: data['hasMovies'] ?? false,
        hasVines: data['hasVines'] ?? false,
        hasLounge: data['hasLounge'] ?? false,
        hasPodcast: data['hasPodcast'] ?? false,
        collaborators: List<String>.from(data['collaborators'] ?? []),
      );
    }).toList();
  }

  /// Fetch spaces created by current user (Private Spaces)
  Stream<List<SpaceModel>> fetchPrivateSpaces() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    return _db
        .collection('spaces')
        .where('postCreator', isEqualTo: currentUserId)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_spacesFromSnapshots);
  }

  /// Fetch spaces where current user is a collaborator (Featured Spaces)
  Stream<List<SpaceModel>> fetchFeaturedSpaces() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    return _db
        .collection('spaces')
        .where('collaborators', arrayContains: currentUserId)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .handleError((error) {
          print('Firestore error in fetchFeaturedSpaces: $error');
          return [];
        })
        .map(_spacesFromSnapshots);
  }

  /// Fetch all public spaces (General Spaces)
  Stream<List<SpaceModel>> fetchGeneralSpaces() {
    return _db
        .collection('spaces')
        .where('isPrivate', isEqualTo: false)
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .map(_spacesFromSnapshots);
  }

  /// Fetch spaces user is subscribed to (Joined Spaces)
  Stream<List<SpaceModel>> fetchJoinedSpaces() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    // Get space IDs where user is subscribed
    return _db
        .collectionGroup('subscribers')
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((subscriberSnapshot) async {
          // Extract space IDs from subscriber documents
          final spaceIds = subscriberSnapshot.docs.map((doc) {
            // Document reference path: spaces/{spaceId}/subscribers/{userId}
            final path = doc.reference.path;
            return path.split('/')[1]; // Get spaceId from path
          }).toList();
          
          if (spaceIds.isEmpty) {
            return <SpaceModel>[];
          }
          
          // Fetch the actual space documents
          final spacesSnapshot = await _db
              .collection('spaces')
              .where(FieldPath.documentId, whereIn: spaceIds)
              .orderBy('timeStamp', descending: true)
              .get();
          
          return spacesSnapshot.docs.map((doc) {
            final data = doc.data();
            return SpaceModel(
              id: doc.id,
              title: data['title'] ?? '',
              category: data['category'] ?? '',
              price: data['price']?.toString() ?? '',
              spaceBackground: data['spaceBackground'] ?? '',
              members: data['members'] ?? 0,
              description: data['description']?.toString() ?? '',
              rating: data['rating'] ?? '',
              iconUrl: data['iconUrl'] ?? '',
              image: data['image'] ?? '',
              postCreator: data['postCreator'] ?? '',
              isPrivate: data['isPrivate'] ?? false,
              hasMusic: data['hasMusic'] ?? false,
              hasShop: data['hasShop'] ?? false,
              hasBooks: data['hasBooks'] ?? false,
              hasVines: data['hasVines'] ?? false,
              hasMovies: data['hasMovies'] ?? false,
              hasLounge: data['hasLounge'] ?? false,
              hasPodcast: data['hasPodcast'] ?? false,
              collaborators: List<String>.from(data['collaborators'] ?? []),
            );
          }).toList();
        })
        .handleError((error) {
          print('Firestore error in fetchJoinedSpaces: $error');
          return <SpaceModel>[];
        });
  }

  /// Fetch all spaces (for explore/admin)
  Stream<List<SpaceModel>> fetchAllSpaces() {
    return _db
        .collection('spaces')
        .orderBy('timeStamp', descending: true)
        .snapshots()
        .handleError((error) {
          print('Firestore error in fetchAllSpaces: $error');
          return [];
        })
        .map(_spacesFromSnapshots);
  }

  /// Search spaces by title
  Stream<List<SpaceModel>> searchSpaces(String query) {
    if (query.isEmpty) return Stream.value([]);
    
    return _db
        .collection('spaces')
        .where('isPrivate', isEqualTo: false)
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: query + 'z')
        .orderBy('title')
        .snapshots()
        .map(_spacesFromSnapshots);
  }

  // ==================== SPACE ITEM METHODS ====================

  /// Check if an item exists in a space
  Future<bool> isItemInSpace(String spaceId, String itemType, String itemId) async {
    final collectionName = _getCollectionName(itemType);
    
    final snapshot = await _db
        .collection('spaces')
        .doc(spaceId)
        .collection(collectionName)
        .where('originalItemId', isEqualTo: itemId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get collection name based on item type
  String _getCollectionName(String itemType) {
    switch (itemType) {
      case 'music':
        return 'space-music';
      case 'book':
        return 'space-books';
      case 'podcast':
        return 'space-podcasts';
      case 'product':
        return 'space-products';
      case 'vine':
        return 'space-vines';
      default:
        return 'space-items';
    }
  }

  // ==================== USER INFO METHODS ====================

  /// Get user info by user ID
  Stream<MangoUser?> getUserInfo(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return MangoUser.fromDocument(doc);
          }
          return null;
        });
  }

  // ==================== SPACE CREATION METHODS ====================

  /// Create a new space
  Future<String> createSpace(Map<String, dynamic> spaceData) async {
    try {
      final docRef = await _db.collection('spaces').add({
        ...spaceData,
        'timeStamp': FieldValue.serverTimestamp(),
        'members': 1, // Creator is first member
      });
      return docRef.id;
    } catch (e) {
      print('Error creating space: $e');
      throw e;
    }
  }

  /// Update space settings
  Future<void> updateSpaceSettings(String spaceId, Map<String, dynamic> updates) async {
    try {
      await _db.collection('spaces').doc(spaceId).update(updates);
    } catch (e) {
      print('Error updating space: $e');
      throw e;
    }
  }

  /// Delete a space
  Future<void> deleteSpace(String spaceId) async {
    try {
      await _db.collection('spaces').doc(spaceId).delete();
    } catch (e) {
      print('Error deleting space: $e');
      throw e;
    }
  }
}


class SpaceController extends GetxController {
  final FirestoreService firestoreService = FirestoreService();
  
  // Observable lists for UI
  var privateSpaces = <SpaceModel>[].obs;
  var featuredSpaces = <SpaceModel>[].obs;
  var joinedSpaces = <SpaceModel>[].obs;
  var generalSpaces = <SpaceModel>[].obs;
  var allSpaces = <SpaceModel>[].obs;
  
  var isLoading = false.obs;
  var error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeStreams();
  }
  
  void _initializeStreams() {
    // Listen to private spaces
    firestoreService.fetchPrivateSpaces().listen((spaces) {
      privateSpaces.value = spaces;
    }, onError: (err) {
      error.value = 'Error loading private spaces: $err';
      print('Private spaces error: $err');
    });
    
    // Listen to featured spaces (user is collaborator)
    firestoreService.fetchFeaturedSpaces().listen((spaces) {
      featuredSpaces.value = spaces;
    }, onError: (err) {
      error.value = 'Error loading featured spaces: $err';
      print('Featured spaces error: $err');
    });
    
    // Listen to joined spaces (user is subscribed)
    firestoreService.fetchJoinedSpaces().listen((spaces) {
      joinedSpaces.value = spaces;
    }, onError: (err) {
      error.value = 'Error loading joined spaces: $err';
      print('Joined spaces error: $err');
    });
    
    // Listen to general spaces (public spaces)
    firestoreService.fetchGeneralSpaces().listen((spaces) {
      generalSpaces.value = spaces;
    }, onError: (err) {
      error.value = 'Error loading general spaces: $err';
      print('General spaces error: $err');
    });
    
    // Listen to all spaces
    firestoreService.fetchAllSpaces().listen((spaces) {
      allSpaces.value = spaces;
    }, onError: (err) {
      error.value = 'Error loading all spaces: $err';
      print('All spaces error: $err');
    });
  }

  // ==================== SPACE FETCHING METHODS ====================
  
  Stream<List<SpaceModel>> fetchPrivateSpaces() {
    return firestoreService.fetchPrivateSpaces();
  }

  Stream<List<SpaceModel>> fetchFeaturedSpaces() {
    return firestoreService.fetchFeaturedSpaces();
  }

  Stream<List<SpaceModel>> fetchJoinedSpaces() {
    return firestoreService.fetchJoinedSpaces();
  }

  Stream<List<SpaceModel>> fetchGeneralSpaces() {
    return firestoreService.fetchGeneralSpaces();
  }

  Stream<List<SpaceModel>> fetchAllSpaces() {
    return firestoreService.fetchAllSpaces();
  }

  Stream<List<SpaceModel>> searchSpaces(String query) {
    return firestoreService.searchSpaces(query);
  }

  // ==================== SUBSCRIPTION METHODS ====================
  
  Stream<bool> isSubscribed(String spaceId) {
    return firestoreService.isSubscribed(spaceId);
  }

  Future<void> toggleSubscription(String spaceId, bool currentlySubscribed) {
    return firestoreService.toggleSubscription(spaceId, currentlySubscribed);
  }

  Stream<int> getSubscriberCount(String spaceId) {
    return firestoreService.getSubscriberCount(spaceId);
  }

  Future<bool> canUserJoinSpace(String spaceId) {
    return firestoreService.canUserJoinSpace(spaceId);
  }

  // ==================== USER INFO METHODS ====================
  
  Stream<MangoUser?> getUserInfo(String userId) {
    return firestoreService.getUserInfo(userId);
  }

  // ==================== SPACE ITEM METHODS ====================
  
  Future<bool> isItemInSpace(String spaceId, String itemType, String itemId) {
    return firestoreService.isItemInSpace(spaceId, itemType, itemId);
  }

  // ==================== SPACE CREATION METHODS ====================
  
  Future<String> createSpace(Map<String, dynamic> spaceData) {
    return firestoreService.createSpace(spaceData);
  }

  Future<void> updateSpaceSettings(String spaceId, Map<String, dynamic> updates) {
    return firestoreService.updateSpaceSettings(spaceId, updates);
  }

  Future<void> deleteSpace(String spaceId) {
    return firestoreService.deleteSpace(spaceId);
  }

  // ==================== HELPER METHODS ====================
  
  Future<void> refreshAllSpaces() async {
    isLoading.value = true;
    error.value = '';
    
    try {
      await Future.wait([
        fetchPrivateSpaces().first,
        fetchFeaturedSpaces().first,
        fetchJoinedSpaces().first,
        fetchGeneralSpaces().first,
        fetchAllSpaces().first,
      ]);
    } catch (e) {
      error.value = 'Failed to refresh spaces: $e';
      print('Refresh error: $e');
    } finally {
      isLoading.value = false;
    }
  }
}