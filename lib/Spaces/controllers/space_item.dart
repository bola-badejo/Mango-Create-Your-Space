
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpaceItem {
  final String id;
  final String spaceId;
  final String itemType; 
  final String originalItemId;
  final String savedBy;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  SpaceItem({
    required this.id,
    required this.spaceId,
    required this.itemType,
    required this.originalItemId,
    required this.savedBy,
    required this.savedAt,
    required this.data,
  });

  factory SpaceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpaceItem(
      id: doc.id,
      spaceId: data['spaceId'] ?? '',
      itemType: data['itemType'] ?? '',
      originalItemId: data['originalItemId'] ?? '',
      savedBy: data['savedBy'] ?? '',
      savedAt: (data['savedAt'] as Timestamp).toDate(),
      data: data,
    );
  }

  
  String get title => data['title'] ?? data['name'] ?? 'Untitled';
  String get subtitle => data['artist'] ?? data['author'] ?? data['description'] ?? '';
  String get imageUrl => data['imageUrl'] ?? data['coverUrl'] ?? '';
  String get duration => data['duration'] ?? '';
  String get price => data['price']?.toString() ?? '';
}


class SpaceWithItems {
  final String spaceId;
  final String spaceTitle;
  final String spaceCategory;
  final List<SpaceItem> items;

  SpaceWithItems({
    required this.spaceId,
    required this.spaceTitle,
    required this.spaceCategory,
    required this.items,
  });
}

class SpaceItemsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  
  Future<List<SpaceItem>> getSpaceItems(String spaceId) async {
    try {
      final collections = [
        'space-music',
        'space-books', 
        'space-podcasts',
        'space-products',
        'space-vines',
      ];

      List<SpaceItem> allItems = [];

      for (final collection in collections) {
        final snapshot = await _firestore
            .collection('spaces')
            .doc(spaceId)
            .collection(collection)
            .orderBy('savedAt', descending: true)
            .get();

        final items = snapshot.docs.map((doc) {
          return SpaceItem.fromFirestore(doc);
        }).toList();

        allItems.addAll(items);
      }

      
      allItems.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      return allItems;
    } catch (e) {
      print('Error fetching space items: $e');
      return [];
    }
  }

  
  Future<List<SpaceItem>> getSpaceItemsByType(String spaceId, String itemType) async {
    try {
      final collectionName = _getCollectionName(itemType);
      
      final snapshot = await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection(itemType)
          .orderBy('savedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => SpaceItem.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching $itemType items: $e');
      return [];
    }
  }

  
  Future<List<SpaceWithItems>> getAllUserSpaceItems() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      
      final spacesSnapshot = await _firestore
          .collection('spaces')
          .where('postCreator', isEqualTo: currentUserId)
          .get();

      final collaboratorSpacesSnapshot = await _firestore
          .collection('spaces')
          .where('collaborators', arrayContains: currentUserId)
          .get();

      final allSpaces = [
        ...spacesSnapshot.docs,
        ...collaboratorSpacesSnapshot.docs,
      ];

      List<SpaceWithItems> spacesWithItems = [];

      for (final spaceDoc in allSpaces) {
        final spaceData = spaceDoc.data();
        final items = await getSpaceItems(spaceDoc.id);

        if (items.isNotEmpty) {
          spacesWithItems.add(SpaceWithItems(
            spaceId: spaceDoc.id,
            spaceTitle: spaceData['title'] ?? 'Untitled Space',
            spaceCategory: spaceData['category'] ?? 'General',
            items: items,
          ));
        }
      }

      return spacesWithItems;
    } catch (e) {
      print('Error fetching all user space items: $e');
      return [];
    }
  }

  
  Future<List<SpaceItem>> getRecentItems({int limit = 20}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    try {
      
      final spacesSnapshot = await _firestore
          .collection('spaces')
          .where('postCreator', isEqualTo: currentUserId)
          .get();

      final collaboratorSpacesSnapshot = await _firestore
          .collection('spaces')
          .where('collaborators', arrayContains: currentUserId)
          .get();

      final allSpaceIds = [
        ...spacesSnapshot.docs.map((doc) => doc.id),
        ...collaboratorSpacesSnapshot.docs.map((doc) => doc.id),
      ];

      List<SpaceItem> allItems = [];

      for (final spaceId in allSpaceIds) {
        final items = await getSpaceItems(spaceId);
        allItems.addAll(items);
      }

      
      allItems.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return allItems.take(limit).toList();
    } catch (e) {
      print('Error fetching recent items: $e');
      return [];
    }
  }

  
  
  
  
  
  
  
  
  

  
  
  
  
  
  
  
  
  
  
  
  

  
  
  
  
  
  
  

  
  Stream<List<SpaceItem>> getSpaceItemsByTypeStream(String spaceId, String itemType) {
    final collectionName = _getCollectionName(itemType);
    
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection(collectionName)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => SpaceItem.fromFirestore(doc)).toList());
  }

  
  Future<void> deleteSpaceItem(String spaceId, SpaceItem item) async {
    try {
      final collectionName = _getCollectionName(item.itemType);
      
      await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection(collectionName)
          .doc(item.id)
          .delete();
    } catch (e) {
      print('Error deleting space item: $e');
      throw e;
    }
  }

  
  Future<bool> isItemInAnySpace(String originalItemId, String itemType) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final spacesSnapshot = await _firestore
          .collection('spaces')
          .where('postCreator', isEqualTo: currentUserId)
          .get();

      final collaboratorSpacesSnapshot = await _firestore
          .collection('spaces')
          .where('collaborators', arrayContains: currentUserId)
          .get();

      final allSpaceIds = [
        ...spacesSnapshot.docs.map((doc) => doc.id),
        ...collaboratorSpacesSnapshot.docs.map((doc) => doc.id),
      ];

      final collectionName = _getCollectionName(itemType);

      for (final spaceId in allSpaceIds) {
        final snapshot = await _firestore
            .collection('spaces')
            .doc(spaceId)
            .collection(collectionName)
            .where('originalItemId', isEqualTo: originalItemId)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking if item exists: $e');
      return false;
    }
  }

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
}