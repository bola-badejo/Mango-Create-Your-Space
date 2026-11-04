// lib/Store/services/product_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Models/customModel/MangoProduct.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  User? get currentUser => _auth.currentUser;

  // Get product stream (real-time updates)
  Stream<MangoProductItem> getProductStream(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .snapshots()
        .map((doc) => MangoProductItem.fromFirestore(doc));
  }

  // Get products with optional filters
  Future<List<MangoProductItem>> getProducts({
    String? category,
    String? vendorId,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null && category != 'all') {
        query = query.where('category', isEqualTo: category);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MangoProductItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  // Stream products for real-time updates
  Stream<List<MangoProductItem>> getProductsStream({
    String? category,
    String? vendorId,
  }) {
    Query query = _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    if (vendorId != null && vendorId.isNotEmpty) {
      query = query.where('vendorId', isEqualTo: vendorId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MangoProductItem.fromFirestore(doc))
          .toList();
    });
  }

  // Increment view count
  Future<void> incrementViewCount(String productId) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);
      await productRef.update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  // Toggle product like
  Future<void> toggleLike(String productId, String userId) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);
      final product = await productRef.get();

      if (!product.exists) return;

      final likedBy = List<String>.from(product.data()?['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        await productRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        await productRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  // Add comment to product
  Future<void> addComment(String productId, ProductComment comment) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);

      // Add comment to comments subcollection
      await productRef
          .collection('comments')
          .doc(comment.id)
          .set(comment.toMap());

      // Update product review count and rating
      await _updateProductStats(productId);
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  // Update comment
  Future<void> updateComment(String productId, ProductComment comment) async {
    try {
      final commentRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('comments')
          .doc(comment.id);

      await commentRef.update({
        'text': comment.text,
        'rating': comment.rating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _updateProductStats(productId);
    } catch (e) {
      print('Error updating comment: $e');
      rethrow;
    }
  }

  // Delete comment
  Future<void> deleteComment(String productId, String commentId) async {
    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await _updateProductStats(productId);
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  // Toggle comment like
  Future<void> toggleCommentLike(
    String productId,
    String commentId,
    String userId,
  ) async {
    try {
      final commentRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('comments')
          .doc(commentId);

      final comment = await commentRef.get();
      if (!comment.exists) return;

      final likedBy = List<String>.from(comment.data()?['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        await commentRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
        });
      } else {
        await commentRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      print('Error toggling comment like: $e');
      rethrow;
    }
  }

  // Update product statistics (rating, comment count)
  Future<void> _updateProductStats(String productId) async {
    try {
      final commentsSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('comments')
          .where(
            'parentId',
            isNull: true,
          ) // Only count top-level comments for rating
          .get();

      final comments = commentsSnapshot.docs;
      final commentCount = comments.length;

      double totalRating = 0;
      for (var doc in comments) {
        totalRating += (doc.data()['rating'] ?? 0).toDouble();
      }

      final averageRating = commentCount > 0 ? totalRating / commentCount : 0.0;

      await _firestore.collection('products').doc(productId).update({
        'reviewCount': commentCount,
        'rating': averageRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating product stats: $e');
    }
  }

  // Get comments stream for a product
  Stream<List<ProductComment>> getCommentsStream(String productId) {
    return _firestore
        .collection('products')
        .doc(productId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductComment.fromMap(doc.data());
          }).toList();
        });
  }

  // Get product by ID
  Future<MangoProductItem?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return MangoProductItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // Update stock after purchase
  Future<void> updateStock(String productId, int quantity) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);
      await productRef.update({
        'stockQuantity': FieldValue.increment(-quantity),
        'soldCount': FieldValue.increment(quantity),
      });
    } catch (e) {
      print('Error updating stock: $e');
      rethrow;
    }
  }
}
