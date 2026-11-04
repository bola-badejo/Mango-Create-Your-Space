import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Contributors/models/contributors_profile.dart';

class ContributorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String contributorsCollection = 'contributors';

  // Get contributor by userId
  Future<ContributorProfile?> getContributorByUserId(String userId) async {
    try {
      final doc = await _firestore
          .collection(contributorsCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return ContributorProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting contributor: $e');
      return null;
    }
  }

  // Get contributor by contributorId
  Future<ContributorProfile?> getContributorById(String contributorId) async {
    try {
      final doc = await _firestore
          .collection(contributorsCollection)
          .doc(contributorId)
          .get();
      
      if (doc.exists) {
        return ContributorProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting contributor: $e');
      return null;
    }
  }

  // Stream contributor by userId
  Stream<ContributorProfile?> getContributorStream(String userId) {
    return _firestore
        .collection(contributorsCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? ContributorProfile.fromFirestore(doc) : null);
  }

  // Stream contributor by contributorId
  Stream<ContributorProfile?> getContributorStreamById(String contributorId) {
    return _firestore
        .collection(contributorsCollection)
        .doc(contributorId)
        .snapshots()
        .map((doc) => doc.exists ? ContributorProfile.fromFirestore(doc) : null);
  }

  // Check if user is a contributor
  Future<bool> isUserContributor(String userId) async {
    final doc = await _firestore
        .collection(contributorsCollection)
        .doc(userId)
        .get();
    return doc.exists;
  }

  // Get all contributors
  Stream<List<ContributorProfile>> getAllContributors() {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get contributors by type
  Stream<List<ContributorProfile>> getContributorsByType(String type) {
    return _firestore
        .collection(contributorsCollection)
        .where('type', isEqualTo: type.toLowerCase())
        .where('isActive', isEqualTo: true)
        .orderBy('followers', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get featured contributors
  Stream<List<ContributorProfile>> getFeaturedContributors() {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .where('isPremium', isEqualTo: true)
        .orderBy('followers', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get top contributors by category
  Stream<List<ContributorProfile>> getTopContributorsByCategory(String category) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('categories', arrayContains: category)
        .orderBy('rating', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Search contributors
  Stream<List<ContributorProfile>> searchContributors(String query) {
    final searchTerm = query.toLowerCase();
    
    // Note: For production, consider using Algolia or similar search service
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .where((profile) => 
                profile.displayName.toLowerCase().contains(searchTerm) ||
                profile.skill.toLowerCase().contains(searchTerm) ||
                profile.tags.any((tag) => tag.toLowerCase().contains(searchTerm)) ||
                profile.categories.any((cat) => cat.toLowerCase().contains(searchTerm))
            )
            .toList());
  }

  // Update contributor profile
  Future<void> updateContributorProfile(
    String userId, 
    Map<String, dynamic> updates
  ) async {
    try {
      await _firestore
          .collection(contributorsCollection)
          .doc(userId)
          .update({
            ...updates,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error updating contributor: $e');
      rethrow;
    }
  }

  // Update specific fields
  Future<void> updateProfileImage(String userId, String imageUrl) async {
    await updateContributorProfile(userId, {
      'profileImageUrl': imageUrl,
    });
  }

  Future<void> updateBannerImage(String userId, String imageUrl) async {
    await updateContributorProfile(userId, {
      'bannerImageUrl': imageUrl,
    });
  }

  Future<void> updateLogoImage(String userId, String imageUrl) async {
    await updateContributorProfile(userId, {
      'logoImageUrl': imageUrl,
    });
  }

  // Increment followers
  Future<void> incrementFollowers(String contributorId) async {
    final docRef = _firestore.collection(contributorsCollection).doc(contributorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentFollowers = snapshot.data()?['followers'] ?? 0;
        transaction.update(docRef, {'followers': currentFollowers + 1});
      }
    });
  }

  // Decrement followers
  Future<void> decrementFollowers(String contributorId) async {
    final docRef = _firestore.collection(contributorsCollection).doc(contributorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentFollowers = snapshot.data()?['followers'] ?? 0;
        if (currentFollowers > 0) {
          transaction.update(docRef, {'followers': currentFollowers - 1});
        }
      }
    });
  }

  // Update rating
  Future<void> updateRating(String contributorId, double newRating, int newReview) async {
    final docRef = _firestore.collection(contributorsCollection).doc(contributorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentRating = (snapshot.data()?['rating'] ?? 0.0).toDouble();
        final totalReviews = snapshot.data()?['totalReviews'] ?? 0;
        
        final newTotalReviews = totalReviews + newReview;
        final newAverageRating = ((currentRating * totalReviews) + (newRating * newReview)) / newTotalReviews;
        
        transaction.update(docRef, {
          'rating': newAverageRating,
          'totalReviews': newTotalReviews,
        });
      }
    });
  }

  // Update sales stats
  Future<void> updateSalesStats(String contributorId, int amount, int quantity) async {
    final docRef = _firestore.collection(contributorsCollection).doc(contributorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentEarnings = snapshot.data()?['totalEarnings'] ?? 0;
        final currentSales = snapshot.data()?['totalSales'] ?? 0;
        
        transaction.update(docRef, {
          'totalEarnings': currentEarnings + amount,
          'totalSales': currentSales + quantity,
        });
      }
    });
  }

  // Add achievement
  Future<void> addAchievement(String userId, String achievement) async {
    final docRef = _firestore.collection(contributorsCollection).doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentAchievements = List<String>.from(snapshot.data()?['achievements'] ?? []);
        if (!currentAchievements.contains(achievement)) {
          transaction.update(docRef, {
            'achievements': [...currentAchievements, achievement],
          });
        }
      }
    });
  }

  // Add social link
  Future<void> addSocialLink(String userId, String platform, String url) async {
    final docRef = _firestore.collection(contributorsCollection).doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentLinks = Map<String, String>.from(snapshot.data()?['socialLinks'] ?? {});
        currentLinks[platform] = url;
        transaction.update(docRef, {'socialLinks': currentLinks});
      }
    });
  }

  // Delete contributor profile (soft delete)
  Future<void> deactivateContributor(String userId) async {
    await updateContributorProfile(userId, {'isActive': false});
  }

  // Get contributors by location
  Stream<List<ContributorProfile>> getContributorsByLocation(String location) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('location', isEqualTo: location)
        .orderBy('followers', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get contributors by skill
  Stream<List<ContributorProfile>> getContributorsBySkill(String skill) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('skill', isEqualTo: skill)
        .orderBy('rating', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get top rated contributors
  Stream<List<ContributorProfile>> getTopRatedContributors({int limit = 20}) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get trending contributors (based on monthly listeners)
  Stream<List<ContributorProfile>> getTrendingContributors({int limit = 20}) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('monthlyListeners', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get contributors by tag
  Stream<List<ContributorProfile>> getContributorsByTag(String tag) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('tags', arrayContains: tag)
        .orderBy('followers', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get contributors by category
  Stream<List<ContributorProfile>> getContributorsByCategory(String category) {
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('categories', arrayContains: category)
        .orderBy('followers', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Get new contributors (last 30 days)
  Stream<List<ContributorProfile>> getNewContributors() {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _firestore
        .collection(contributorsCollection)
        .where('isActive', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContributorProfile.fromFirestore(doc))
            .toList());
  }

  // Batch update multiple contributors
  Future<void> batchUpdateContributors(List<Map<String, dynamic>> updates) async {
    final batch = _firestore.batch();
    
    for (final update in updates) {
      final docRef = _firestore.collection(contributorsCollection).doc(update['userId']);
      final data = Map<String, dynamic>.from(update);
      data.remove('userId');
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.update(docRef, data);
    }
    
    await batch.commit();
  }

  // Get contributor count by type
  Future<Map<String, int>> getContributorCountByType() async {
    final snapshot = await _firestore.collection(contributorsCollection).get();
    final counts = <String, int>{};
    
    for (final doc in snapshot.docs) {
      final type = doc.data()['type'] as String? ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    
    return counts;
  }

  // Listen to contributor changes
  Stream<DocumentSnapshot> listenToContributorChanges(String userId) {
    return _firestore.collection(contributorsCollection).doc(userId).snapshots();
  }
}