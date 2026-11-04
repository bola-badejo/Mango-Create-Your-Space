import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mango/Home/components/imageViewerDialog.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/pages/post_shimmer.dart';
import 'package:mango/Models/customModel/library.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Models/customModel/timeago.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:mango/Profile/profile.dart';
import 'package:mango/Profile/public_profile.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/utils.dart';
import 'package:video_player/video_player.dart';
import 'package:mango/Utils/optimized_lists.dart';

enum PostErrorType {
  network,
  permission,
  notFound,
  invalidData,
  unauthorized,
  quotaExceeded,
  documentAlreadyExists,
  documentDoesNotExist,
}

class PostError implements Exception {
  final PostErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  PostError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'PostError[${type.name}]: $message';
  }

  bool get isNetworkError => type == PostErrorType.network;
  bool get isPermissionError => type == PostErrorType.permission;
  bool get isUnauthorized => type == PostErrorType.unauthorized;
}

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final Timestamp timestamp;
  final int likeCount;
  final String? parentCommentId;
  int depth;
  final List<String> replies;
  bool isLiked;
  bool isExpanded;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.timestamp,
    required this.likeCount,
    this.parentCommentId,
    this.depth = 0,
    this.replies = const [],
    this.isLiked = false,
    this.isExpanded = true,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String id) {
    return Comment(
      id: id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likeCount: data['likeCount'] ?? 0,
      parentCommentId: data['parentCommentId'],
      depth: data['depth'] ?? 0,
      replies: List<String>.from(data['replies'] ?? []),
      isLiked: data['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'text': text,
      'timestamp': timestamp,
      'likeCount': likeCount,
      'parentCommentId': parentCommentId,
      'depth': depth,
      'replies': replies,
    };
  }
}

class PostCardService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PostCardService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  Future<void> toggleLike({
    required String postId,
    required bool currentLikeStatus,
    required int currentLikeCount,
    required Function(bool, int) onStateChange,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to like posts',
      );
    }

    final isLiked = !currentLikeStatus;
    final newLikeCount = isLiked ? currentLikeCount + 1 : currentLikeCount - 1;

    onStateChange(isLiked, newLikeCount);

    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUser.uid);

      final batch = _firestore.batch();

      if (isLiked) {
        batch.set(likeRef, {
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(_firestore.collection('posts').doc(postId), {
          'likeCount': FieldValue.increment(1),
        });
      } else {
        batch.delete(likeRef);
        batch.update(_firestore.collection('posts').doc(postId), {
          'likeCount': FieldValue.increment(-1),
        });
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      onStateChange(currentLikeStatus, currentLikeCount);

      throw PostError(
        type: _mapFirebaseError(e),
        message: _getErrorMessage(e),
        originalError: e,
      );
    } catch (e, stack) {
      onStateChange(currentLikeStatus, currentLikeCount);
      throw PostError(
        type: PostErrorType.network,
        message: 'Failed to update like',
        originalError: e,
        stackTrace: stack,
      );
    }
  }

  Future<bool> checkIfLiked(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final likeDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUser.uid)
          .get();

      return likeDoc.exists;
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to check like status',
        originalError: e,
      );
    }
  }

  Future<void> toggleBookmark({
    required String postId,
    required bool currentBookmarkStatus,
    required Function(bool) onStateChange,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to bookmark posts',
      );
    }

    final isBookmarked = !currentBookmarkStatus;
    onStateChange(isBookmarked);

    try {
      final bookmarkRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(postId);

      if (isBookmarked) {
        await bookmarkRef.set({
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await bookmarkRef.delete();
      }
    } on FirebaseException catch (e) {
      onStateChange(currentBookmarkStatus);
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to update bookmark',
        originalError: e,
      );
    }
  }

  Future<bool> checkIfBookmarked(String postId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final bookmarkDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('bookmarks')
          .doc(postId)
          .get();

      return bookmarkDoc.exists;
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to check bookmark status',
        originalError: e,
      );
    }
  }

  Stream<List<Comment>> getCommentsStream(
    String postId, [
    String? parentCommentId,
  ]) {
    Query query = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('timestamp', descending: false);

    return query.snapshots().asyncMap((snapshot) async {
      final comments = <Comment>[];
      final currentUser = _auth.currentUser;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final comment = Comment.fromMap(data, doc.id);

        if (currentUser != null) {
          final likeDoc = await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(comment.id)
              .collection('likes')
              .doc(currentUser.uid)
              .get();

          comment.isLiked = likeDoc.exists;
        }

        comments.add(comment);
      }

      return comments;
    });
  }

  Future<void> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to comment',
      );
    }

    if (text.trim().isEmpty) {
      throw PostError(
        type: PostErrorType.invalidData,
        message: 'Comment cannot be empty',
      );
    }

    try {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc();

      final batch = _firestore.batch();

      int depth = 0;
      if (parentCommentId != null) {
        final parentDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(parentCommentId)
            .get();
        if (parentDoc.exists) {
          final parentComment = Comment.fromMap(
            parentDoc.data()!,
            parentCommentId,
          );
          depth = parentComment.depth + 1;

          batch.update(parentDoc.reference, {
            'replies': FieldValue.arrayUnion([commentRef.id]),
          });
        }
      }

      batch.set(commentRef, {
        'postId': postId,
        'userId': currentUser.uid,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'parentCommentId': parentCommentId,
        'depth': depth,
        'replies': [],
      });

      batch.update(_firestore.collection('posts').doc(postId), {
        'replyCount': FieldValue.increment(1),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to add comment',
        originalError: e,
      );
    }
  }

  Future<Map<String, Comment>> getCommentThread(
    String postId,
    String rootCommentId,
  ) async {
    final comments = <String, Comment>{};

    Future<void> fetchReplies(String commentId, int currentDepth) async {
      final querySnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .where('parentCommentId', isEqualTo: commentId)
          .orderBy('timestamp', descending: false)
          .get();

      for (var doc in querySnapshot.docs) {
        final comment = Comment.fromMap(doc.data(), doc.id);
        comment.depth = currentDepth;
        comments[comment.id] = comment;

        await fetchReplies(comment.id, currentDepth + 1);
      }
    }

    final rootDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(rootCommentId)
        .get();

    if (rootDoc.exists) {
      final rootComment = Comment.fromMap(rootDoc.data()!, rootCommentId);
      rootComment.depth = 0;
      comments[rootComment.id] = rootComment;
      await fetchReplies(rootCommentId, 1);
    }

    return comments;
  }

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
    required bool currentLikeStatus,
    required int currentLikeCount,
    required Function(bool, int) onStateChange,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to like comments',
      );
    }

    final isLiked = !currentLikeStatus;
    final newLikeCount = isLiked ? currentLikeCount + 1 : currentLikeCount - 1;

    onStateChange(isLiked, newLikeCount);

    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(currentUser.uid);

      final batch = _firestore.batch();

      if (isLiked) {
        batch.set(likeRef, {
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(
          _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId),
          {'likeCount': FieldValue.increment(1)},
        );
      } else {
        batch.delete(likeRef);
        batch.update(
          _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId),
          {'likeCount': FieldValue.increment(-1)},
        );
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      onStateChange(currentLikeStatus, currentLikeCount);

      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to update comment like',
        originalError: e,
      );
    }
  }

  Future<DocumentSnapshot> fetchLinkedContent(
    String linkId,
    String linkType,
  ) async {
    final collectionName = switch (linkType.toLowerCase()) {
      'book' => 'library',
      'playlist' => 'playlists',
      'product' => 'products',
      'podcast' => 'podcasts',
      'movie' => 'movies',
      _ => throw PostError(
        type: PostErrorType.invalidData,
        message: 'Unknown link type: $linkType',
      ),
    };

    try {
      return await _firestore.collection(collectionName).doc(linkId).get();
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to fetch linked content',
        originalError: e,
      );
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to delete post',
        originalError: e,
      );
    }
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to report posts',
      );
    }

    try {
      await _firestore.collection('reports').add({
        'postId': postId,
        'reporterId': currentUser.uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to submit report',
        originalError: e,
      );
    }
  }

  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw PostError(
        type: PostErrorType.unauthorized,
        message: 'Please login to block users',
      );
    }

    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blockedUsers')
          .doc(userId)
          .set({'blockedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      throw PostError(
        type: _mapFirebaseError(e),
        message: 'Failed to block user',
        originalError: e,
      );
    }
  }

  PostErrorType _mapFirebaseError(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PostErrorType.permission,
      'not-found' => PostErrorType.notFound,
      'unauthenticated' => PostErrorType.unauthorized,
      'resource-exhausted' => PostErrorType.quotaExceeded,
      'already-exists' => PostErrorType.documentAlreadyExists,
      'aborted' => PostErrorType.documentDoesNotExist,
      _ => PostErrorType.network,
    };
  }

  String _getErrorMessage(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' =>
        'You do not have permission to perform this action',
      'not-found' => 'The requested resource was not found',
      'unauthenticated' => 'Please login to continue',
      'resource-exhausted' => 'Rate limit exceeded. Please try again later',
      'already-exists' => 'This resource already exists',
      'aborted' => 'The operation was aborted',
      _ => 'An error occurred. Please try again',
    };
  }
}

class CommentWidget extends StatefulWidget {
  final Comment comment;
  final String postId;
  final PostCardService service;
  final ThemeController themeController;
  final VoidCallback? onReply;
  final VoidCallback? onViewReplies;
  final int depth;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.postId,
    required this.service,
    required this.themeController,
    this.onReply,
    this.onViewReplies,
    this.depth = 0,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  final RxBool _isLiked = false.obs;
  final RxInt _likeCount = 0.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _showReplies = false.obs;
  final RxList<Comment> _nestedReplies = <Comment>[].obs;

  late Color _textColor;
  late Color _secondaryTextColor;
  late Color _surfaceColor;
  late Color _primaryColor;
  late Color _threadLineColor;

  @override
  void initState() {
    super.initState();
    _isLiked.value = widget.comment.isLiked;
    _likeCount.value = widget.comment.likeCount;

    _updateColors();

    if (widget.comment.replies.isNotEmpty) {
      _loadReplies();
    }
  }

  void _updateColors() {
    _textColor = widget.themeController.isDarkMode.value
        ? Colors.white
        : Colors.black;
    _secondaryTextColor = widget.themeController.isDarkMode.value
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF666666);
    _surfaceColor = widget.themeController.isDarkMode.value
        ? const Color(0xFF2D2D2D)
        : const Color(0xFFF5F5F5);
    _primaryColor = widget.themeController.primaryColorValue;
    _threadLineColor = widget.themeController.isDarkMode.value
        ? const Color(0xFF444444)
        : const Color(0xFFE5E5E5);
  }

  Future<void> _toggleLike() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    try {
      await widget.service.toggleCommentLike(
        postId: widget.postId,
        commentId: widget.comment.id,
        currentLikeStatus: _isLiked.value,
        currentLikeCount: _likeCount.value,
        onStateChange: (isLiked, likeCount) {
          _isLiked.value = isLiked;
          _likeCount.value = likeCount;
        },
      );
    } on PostError catch (e) {
      UtilsService().showSnackbar(
        'Error',
        e.message,
        backgroundColor: const Color(0xFFF44336),
        colorText: Colors.white, context: context,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _loadReplies() async {
    try {
      final replies = await widget.service
          .getCommentsStream(widget.postId, widget.comment.id)
          .first;
      _nestedReplies.value = replies;
    } catch (e) {}
  }

  void _toggleReplies() {
    if (_showReplies.value) {
      _showReplies.value = false;
    } else {
      _showReplies.value = true;
      if (_nestedReplies.isEmpty) {
        _loadReplies();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MangoUser?>(
      stream: Get.find<MangoDashboardController>().getUserInfo(
        widget.comment.userId,
      ),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasReplies = widget.comment.replies.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.only(
                left: 16 + (widget.depth * 24),
                right: 16,
                top: 12,
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.depth > 0) ...[
                    Container(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 2,
                            height: 40,
                            color: _threadLineColor,
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _threadLineColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _primaryColor.withOpacity(0.2),
                    backgroundImage: user?.profileImage != null
                        ? NetworkImage(user!.profileImage)
                        : null,
                    child: user?.profileImage == null
                        ? Icon(Icons.person, size: 16, color: _primaryColor)
                        : null,
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.displayName ?? 'Unknown User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            Text(
                              timeAgo(widget.comment.timestamp.toDate()),
                              style: TextStyle(
                                fontSize: 10,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        Text(
                          widget.comment.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Obx(
                              () => GestureDetector(
                                onTap: _toggleLike,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _surfaceColor,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isLiked.value
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 14,
                                        color: _isLiked.value
                                            ? Colors.red
                                            : _secondaryTextColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatCount(_likeCount.value),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _isLiked.value
                                              ? Colors.red
                                              : _secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            GestureDetector(
                              onTap: widget.onReply,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: _surfaceColor,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: 14,
                                      color: _secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reply',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (hasReplies) ...[
                              const SizedBox(width: 12),
                              Obx(
                                () => GestureDetector(
                                  onTap: _toggleReplies,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: _surfaceColor,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showReplies.value
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          size: 14,
                                          color: _primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${widget.comment.replies.length} ${widget.comment.replies.length == 1 ? 'reply' : 'replies'}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Obx(
              () => _showReplies.value
                  ? Padding(
                      padding: EdgeInsets.only(left: 40 + (widget.depth * 24)),
                      child: Column(
                        children: [
                          if (_nestedReplies.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            ..._nestedReplies
                                .map(
                                  (reply) => CommentWidget(
                                    comment: reply,
                                    postId: widget.postId,
                                    service: widget.service,
                                    themeController: widget.themeController,
                                    depth: widget.depth + 1,
                                    onReply: widget.onReply,
                                    onViewReplies: widget.onViewReplies,
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    )
                  : const SizedBox(),
            ),

            if (widget.depth == 0) Divider(height: 1, color: _threadLineColor),
          ],
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class CommentsModalSheet extends StatefulWidget {
  final String postId;
  final PostCardService service;
  final ThemeController themeController;
  final MangoDashboardController dashboardController;
  final String? parentCommentId;
  final String? replyingToUsername;

  const CommentsModalSheet({
    super.key,
    required this.postId,
    required this.service,
    required this.themeController,
    required this.dashboardController,
    this.parentCommentId,
    this.replyingToUsername,
  });

  @override
  State<CommentsModalSheet> createState() => _CommentsModalSheetState();
}

class _CommentsModalSheetState extends State<CommentsModalSheet> {
  final TextEditingController _commentController = TextEditingController();
  final RxBool _isSubmitting = false.obs;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();

  late Color _cardColor;
  late Color _textColor;
  late Color _secondaryTextColor;
  late Color _surfaceColor;
  late Color _primaryColor;
  late Color _dividerColor;

  final RxString _replyingToCommentId = ''.obs;
  final RxString _replyingToUsername = ''.obs;
  final Map<String, String> _userNames = {}; // Cache for usernames

  @override
  void initState() {
    super.initState();
    _updateColors();

    if (widget.replyingToUsername != null) {
      _replyingToUsername.value = widget.replyingToUsername!;
      _commentController.text = '@${widget.replyingToUsername!} ';
      _commentFocusNode.requestFocus();
    }
    if (widget.parentCommentId != null) {
      _replyingToCommentId.value = widget.parentCommentId!;
    }

    _commentFocusNode.addListener(_scrollToBottomOnFocus);
  }

  void _scrollToBottomOnFocus() {
    if (_commentFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<String> _getUsername(String userId) async {
    // Return from cache if available
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final username = userDoc.data()?['username'] ?? 'Unknown User';
        _userNames[userId] = username;
        return username;
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
    
    return 'Unknown User';
  }

  void _updateColors() {
    _cardColor = widget.themeController.isDarkMode.value
        ? const Color(0xFF1E1E1E)
        : Colors.white;
    _textColor = widget.themeController.isDarkMode.value
        ? Colors.white
        : Colors.black;
    _secondaryTextColor = widget.themeController.isDarkMode.value
        ? const Color(0xFFB0B0B0)
        : const Color(0xFF666666);
    _surfaceColor = widget.themeController.isDarkMode.value
        ? const Color(0xFF2D2D2D)
        : const Color(0xFFF5F5F5);
    _primaryColor = widget.themeController.primaryColorValue;
    _dividerColor = widget.themeController.isDarkMode.value
        ? const Color(0xFF333333)
        : const Color(0xFFE0E0E0);
  }

  void _startReply(Comment comment) async {
    final username = await _getUsername(comment.userId);
    _replyingToCommentId.value = comment.id;
    _replyingToUsername.value = username;
    _commentController.text = '@$username ';
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    _replyingToCommentId.value = '';
    _replyingToUsername.value = '';
    _commentController.clear();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _isSubmitting.value = true;
    try {
      await widget.service.addComment(
        postId: widget.postId,
        text: text,
        parentCommentId: _replyingToCommentId.value.isEmpty
            ? null
            : _replyingToCommentId.value,
      );

      _commentController.clear();
      _cancelReply();

      // Scroll to bottom after posting
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on PostError catch (e) {
      UtilsService().showSnackbar(
        'Error',
        e.message,
        backgroundColor: const Color(0xFFF44336),
        colorText: Colors.white,
        context: context,
      );
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _secondaryTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(
                  () => _replyingToCommentId.value.isNotEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.reply,
                              color: _primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Replying to ${_replyingToUsername.value}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textColor,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                ),
                Row(
                  children: [
                    if (_replyingToCommentId.value.isNotEmpty) ...[
                      IconButton(
                        onPressed: _cancelReply,
                        icon: Icon(
                          Icons.close,
                          color: _secondaryTextColor,
                          size: 20,
                        ),
                        tooltip: 'Cancel reply',
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: _textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Comments list - Expanded with flexible height
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: widget.service.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _primaryColor,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: _secondaryTextColor,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load comments',
                          style: TextStyle(color: _secondaryTextColor),
                        ),
                      ],
                    ),
                  );
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: _secondaryTextColor,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: _secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: _secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return OptimizedListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentWidget(
                      comment: comment,
                      postId: widget.postId,
                      service: widget.service,
                      themeController: widget.themeController,
                      onReply: () => _startReply(comment),
                      onViewReplies: () {
                        _showNestedReplies(comment);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Reply indicator bar
          Obx(
            () => _replyingToCommentId.value.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      border: Border(
                        top: BorderSide(color: _dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.reply, color: _primaryColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Replying to ${_replyingToUsername.value}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: Icon(
                            Icons.close,
                            color: _secondaryTextColor,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),

          // Input section - NO bottom padding, floats above keyboard
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _dividerColor),
              ),
              color: _surfaceColor,
            ),
            child: SafeArea(
              top: false, // Remove top safe area padding
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: TextStyle(color: _textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _replyingToCommentId.value.isNotEmpty
                                ? 'Write your reply...'
                                : 'Write a comment...',
                            hintStyle: TextStyle(
                              color: _secondaryTextColor,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => _isSubmitting.value
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: _submitComment,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _commentController.text.trim().isNotEmpty
                                      ? _primaryColor
                                      : _secondaryTextColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNestedReplies(Comment comment) async {
    final username = await _getUsername(comment.userId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModalSheet(
        postId: widget.postId,
        service: widget.service,
        themeController: widget.themeController,
        dashboardController: widget.dashboardController,
        parentCommentId: comment.id,
        replyingToUsername: username,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.removeListener(_scrollToBottomOnFocus);
    _commentFocusNode.dispose();
    super.dispose();
  }
}

class PostCard extends StatefulWidget {
  final MangoPost post;
  final PostCardService? service;

  const PostCard({super.key, required this.post, this.service});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late final MangoDashboardController controller;
  late final ThemeController themeController;
  late final PostCardService _service;

  VideoPlayerController? _videoController;
  final RxBool _isVideoInitialized = false.obs;
  final RxBool _isVideoPlaying = false.obs;
  final RxString _videoError = ''.obs;
  final RxBool _isLiked = false.obs;
  final RxInt _likeCount = 0.obs;
  final RxBool _isBookmarked = false.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isFollowing = false.obs;
  final RxBool _followLoading = false.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.find<MangoDashboardController>();
    if (widget.post.video.isNotEmpty) {
      _initializeVideoPlayer();
    }
    themeController = Get.find<ThemeController>();

    _service =
        widget.service ??
        PostCardService(
          firestore: FirebaseFirestore.instance,
          auth: FirebaseAuth.instance,
        );

    _likeCount.value = widget.post.likeCount;
    _initializePostState();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.video),
      );
      await _videoController!.initialize();
      _videoController!.setLooping(false);
      _isVideoInitialized.value = true;
      _videoError.value = '';
      print('✅ Video initialised');
    } catch (e, stack) {
      print('❌ Video init failed: $e\n$stack');
      _isVideoInitialized.value = true; 
      _videoError.value = 'Video unavailable';
    }
  }

  Future<void> _initializePostState() async {
    try {
      final [liked, bookmarked, following] = await Future.wait([
        _service.checkIfLiked(widget.post.id),
        _service.checkIfBookmarked(widget.post.id),
        _checkIfFollowing(widget.post.postCreator),
      ]);

      _isLiked.value = liked;
      _isBookmarked.value = bookmarked;
      _isFollowing.value = following;
    } on PostError catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      _showErrorSnackbar(e);
      });
    }
  }

  Future<bool> _checkIfFollowing(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == uid) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(uid)
        .get();
    return doc.exists;
  }

  Future<void> _toggleFollow() async {
    if (_followLoading.value) return;
    if (FirebaseAuth.instance.currentUser?.uid == widget.post.postCreator)
      return;

    _followLoading.value = true;
    try {
      if (_isFollowing.value) {
        await _unfollowUser(widget.post.postCreator);
        _isFollowing.value = false;
      } else {
        await _followUser(widget.post.postCreator);
        _isFollowing.value = true;
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      _showErrorSnackbar(
        PostError(
          type: PostErrorType.network,
          message: 'Failed to ${_isFollowing.value ? 'unfollow' : 'follow'}',
          originalError: e,
        ),
      );
      });
    } finally {
      _followLoading.value = false;
    }
  }

  Future<void> _followUser(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(uid)
        .set({});
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(currentUser.uid)
        .set({});
  }

  Future<void> _unfollowUser(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(uid)
        .delete();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(currentUser.uid)
        .delete();
  }

  Color get _cardColor =>
      themeController.isDarkMode.value ? const Color(0xFF1E1E1E) : Colors.white;

  Color get _profileSegmentColor => themeController.primaryColorValue;

  Color get _textColor =>
      themeController.isDarkMode.value ? Colors.white : Colors.black;

  Color get _secondaryTextColor => themeController.isDarkMode.value
      ? const Color(0xFFB0B0B0)
      : const Color(0xFF666666);

  Color get _surfaceColor => themeController.isDarkMode.value
      ? const Color(0xFF2D2D2D)
      : const Color(0xFFF5F5F5);

  Color get _dividerColor => themeController.isDarkMode.value
      ? const Color(0xFF333333)
      : const Color(0xFFE0E0E0);

  Color get _primaryColor => themeController.primaryColorValue;

  Color get _successColor => const Color(0xFF4CAF50);
  Color get _errorColor => const Color(0xFFF44336);
  Color get _warningColor => const Color(0xFFFF9800);

  Color get _profileTextColor => Colors.white;

  Future<void> _toggleLike() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    try {
      await _service.toggleLike(
        postId: widget.post.id,
        currentLikeStatus: _isLiked.value,
        currentLikeCount: _likeCount.value,
        onStateChange: (isLiked, likeCount) {
          _isLiked.value = isLiked;
          _likeCount.value = likeCount;
        },
      );
    } on PostError catch (e) {
      _showErrorSnackbar(e);
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    try {
      await _service.toggleBookmark(
        postId: widget.post.id,
        currentBookmarkStatus: _isBookmarked.value,
        onStateChange: (isBookmarked) {
          _isBookmarked.value = isBookmarked;
          UtilsService().showSnackbar(
            isBookmarked ? 'Bookmarked' : 'Removed',
            isBookmarked
                ? 'Post added to bookmarks'
                : 'Post removed from bookmarks',
            backgroundColor: _successColor,
            colorText: Colors.white, context: context,
          );
        },
      );
    } on PostError catch (e) {
      _showErrorSnackbar(e);
    } finally {
      _isLoading.value = false;
    }
  }

  void _openImageViewer(
    BuildContext context,
    List<dynamic> images,
    int initialIndex,
  ) {
    try {
      final imageUrls = images.map((image) => image.toString()).toList();

      showDialog(
        context: context,
        builder: (context) => ImageViewerDialog(
          images: imageUrls,
          initialIndex: initialIndex,
          caption: widget.post.text,
        ),
      );
    } catch (e) {
      _showErrorSnackbar(
        PostError(
          type: PostErrorType.invalidData,
          message: 'Could not open image viewer',
          originalError: e,
        ),
      );
    }
  }

  void _sharePost() {
    final shareText = '${widget.post.text}\n\nShared from Mango App';
    UtilsService().showSnackbar(
      'Share',
      'Post shared to clipboard',
      backgroundColor: _surfaceColor, context: context,
    );
  }

  void _commentOnPost() {
    final currentUser = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModalSheet(
        postId: widget.post.id,
        service: _service,
        themeController: themeController,
        dashboardController: controller,
      ),
    );
  }

  void _repost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Repost', style: TextStyle(color: _textColor)),
        content: Text(
          'Do you want to repost this?',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performRepost();
            },
            child: Text('Repost', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performRepost() async {
    _isLoading.value = true;
    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'text': widget.post.text,
        'image': widget.post.image,
        'multiImage': widget.post.multiImage,
        'video': widget.post.video,
        'originalID': widget.post.id,
        'postCreator': FirebaseAuth.instance.currentUser!.uid,
        'timeStamp': FieldValue.serverTimestamp(),
        'repost': true,
        'multiMedia': widget.post.multiMedia,
        'reply': false,
        'isLinked': widget.post.isLinked,
        'link': widget.post.link,
        'linkType': widget.post.linkType,
        'likeCount': 0,
        'replyCount': 0,
        'repostCount': 0,
      });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .update({'repostCount': FieldValue.increment(1)});

      UtilsService().showSnackbar(
        'Success',
        'Post reposted',
        backgroundColor: _successColor,
        colorText: Colors.white, context: context,
      );
    } on FirebaseException catch (e) {
      _showErrorSnackbar(
        PostError(
          type: PostErrorType.network,
          message: 'Failed to repost',
          originalError: e,
        ),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void _showErrorSnackbar(PostError error) {
    Color backgroundColor;

    switch (error.type) {
      case PostErrorType.unauthorized:
        backgroundColor = _warningColor;
        break;
      case PostErrorType.permission:
        backgroundColor = Colors.orange;
        break;
      case PostErrorType.quotaExceeded:
        backgroundColor = Colors.deepOrange;
        break;
      default:
        backgroundColor = _errorColor;
    }

    UtilsService().showSnackbar(
      'Error',
      error.message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 3), context: context,
    );
  }

  void _showMenu(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.post.postCreator;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.bookmark, color: _textColor),
                title: Text(
                  _isBookmarked.value ? 'Remove Bookmark' : 'Bookmark',
                  style: TextStyle(color: _textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleBookmark();
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: _textColor),
                title: Text('Share', style: TextStyle(color: _textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _sharePost();
                },
              ),
              if (isOwner) ...[
                Divider(color: _dividerColor),
                ListTile(
                  leading: Icon(Icons.edit, color: _primaryColor),
                  title: Text(
                    'Edit Post',
                    style: TextStyle(color: _primaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _editPost();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: _errorColor),
                  title: Text(
                    'Delete Post',
                    style: TextStyle(color: _errorColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost();
                  },
                ),
              ] else ...[
                Divider(color: _dividerColor),
                ListTile(
                  leading: Icon(Icons.report, color: Colors.orange),
                  title: Text(
                    'Report Post',
                    style: TextStyle(color: Colors.orange),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _reportPost();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.block, color: _errorColor),
                  title: Text(
                    'Block User',
                    style: TextStyle(color: _errorColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _blockUser();
                  },
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.cancel, color: _secondaryTextColor),
                title: Text(
                  'Cancel',
                  style: TextStyle(color: _secondaryTextColor),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editPost() {
    UtilsService().showSnackbar(
      'Edit',
      'Edit feature coming soon',
      backgroundColor: _surfaceColor, context: context,
    );
  }

  void _deletePost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Delete Post', style: TextStyle(color: _textColor)),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete();
            },
            child: Text('Delete', style: TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    _isLoading.value = true;
    try {
      await _service.deletePost(widget.post.id);
      UtilsService().showSnackbar(
        'Success',
        'Post deleted',
        backgroundColor: _successColor,
        colorText: Colors.white, context: context,
      );
      if (controller.posts.contains(widget.post)) {
        controller.posts.remove(widget.post);
      }
    } on PostError catch (e) {
      _showErrorSnackbar(e);
    } finally {
      _isLoading.value = false;
    }
  }

  void _reportPost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Report Post', style: TextStyle(color: _textColor)),
        content: Text(
          'Why are you reporting this post?',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performReport();
            },
            child: Text('Report', style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performReport() async {
    _isLoading.value = true;
    try {
      await _service.reportPost(
        postId: widget.post.id,
        reason: 'Inappropriate content',
      );
      UtilsService().showSnackbar(
        'Reported',
        'Thank you for your report',
        backgroundColor: _successColor,
        colorText: Colors.white, context: context,
      );
    } on PostError catch (e) {
      _showErrorSnackbar(e);
    } finally {
      _isLoading.value = false;
    }
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Block User', style: TextStyle(color: _textColor)),
        content: Text(
          'Are you sure you want to block this user? You will no longer see their posts.',
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _secondaryTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performBlock();
            },
            child: Text('Block', style: TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performBlock() async {
    _isLoading.value = true;
    try {
      await _service.blockUser(widget.post.postCreator);
      UtilsService().showSnackbar(
        'Blocked',
        'User has been blocked',
        backgroundColor: _successColor,
        colorText: Colors.white, context: context,
      );
    } on PostError catch (e) {
      _showErrorSnackbar(e);
    } finally {
      _isLoading.value = false;
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _navigateToProfile(MangoUser? user) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == widget.post.postCreator) {
      Get.to(() => ProfilePage(id: widget.post.postCreator));
    } else {
      Get.to(() => PublicProfilePage(
        userId: widget.post.postCreator,
        username: user?.username,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MangoUser?>(
      stream: controller.getUserInfo(widget.post.postCreator),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PostShimmer();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        final user = snapshot.data;
        final hasMedia =
            widget.post.multiMedia && widget.post.multiImage.isNotEmpty ||
            widget.post.image.isNotEmpty;
        final hasLinkedContent =
            widget.post.isLinked &&
            widget.post.link != null &&
            widget.post.linkType != null;
        final hasText = widget.post.text.isNotEmpty;

        return Obx(
          () => Column(
            children: [
              // Branded Profile Segment Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _profileSegmentColor,
                  borderRadius:  BorderRadius.circular(30),
                ),
                child: _buildUserInfo(user),
              ),

              // Media Section
              if (hasMedia)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: themeController.isDarkMode.value
                        ? Colors.black
                        : Colors.white,
                  ),
                  child: _buildMediaSection(context),
                ),

              // Linked Content Section
              if (hasLinkedContent)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                  ),
                  child: _buildLinkedContentSection(),
                ),

              // Text and Actions Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasText) ...[
                      Text(
                        widget.post.text,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildActionsRow(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(dynamic error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: _errorColor, size: 40),
          const SizedBox(height: 8),
          Text(
            'Failed to load post',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Please try again',
            style: TextStyle(color: _secondaryTextColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(MangoUser? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _navigateToProfile(user),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _profileTextColor.withOpacity(0.2),
                  backgroundImage: user?.profileImage != null
                      ? NetworkImage(user!.profileImage)
                      : null,
                  child: user?.profileImage == null
                      ? Icon(Icons.person, size: 20, color: _profileTextColor)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Unknown User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _profileTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${user?.username ?? 'unknown'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _profileTextColor.withOpacity(0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (FirebaseAuth.instance.currentUser?.uid !=
                widget.post.postCreator) ...[
              Obx(
                () => _followLoading.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: _isFollowing.value
                                ? Colors.transparent
                                : _profileSegmentColor,
                            border: _isFollowing.value
                                ? Border.all(
                                    color: _profileTextColor.withOpacity(0.5),
                                  )
                                : null,
                          ),
                          child: Text(
                            _isFollowing.value ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: _profileTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
            Obx(
              () => _isLoading.value
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _profileTextColor,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _showMenu(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _profileTextColor.withOpacity(0.2),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: _profileTextColor,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    
    if (widget.post.video.isNotEmpty) {
      print('🎬 Video detected: ${widget.post.video}');
      return _buildVideoSection(context);
    }

    if (widget.post.multiMedia && widget.post.multiImage.isNotEmpty) {
      return _buildMultiImageSection(context);
    }

    if (widget.post.image.isNotEmpty) {
      return _buildSingleImageSection(context);
    }

    return const SizedBox();
  }

  Widget _buildVideoSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Obx(() {
      
      if (!_isVideoInitialized.value) {
        return Stack(
          alignment: Alignment.center,
          children: [
            
            if (widget
                .post
                .image
                .isNotEmpty) 
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: CachedNetworkImage(
                  imageUrl: widget.post.image,
                  width: double.infinity,
                  height: screenWidth,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: screenWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: themeController.isDarkMode.value
                      ? Colors.grey[800]
                      : Colors.grey[300],
                ),
              ),
            const CircularProgressIndicator(color: Colors.white),
          ],
        );
      }

      
      if (_videoError.value.isNotEmpty) {
        return Container(
          width: double.infinity,
          height: screenWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: themeController.isDarkMode.value
                ? Colors.grey[800]
                : Colors.grey[300],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 48, color: _errorColor),
              const SizedBox(height: 8),
              Text(_videoError.value, style: TextStyle(color: _errorColor)),
            ],
          ),
        );
      }

      
      final controller = _videoController!;
      return GestureDetector(
        onTap: () {
          controller.value.isPlaying ? controller.pause() : controller.play();
          _isVideoPlaying.value = controller.value.isPlaying;
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.center,
            children: [
              
              SizedBox(
                width: double.infinity,
                height: screenWidth,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$hours:$minutes:$seconds';
}

  
  Widget _buildSingleImageSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _openImageViewer(context, [widget.post.image], 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: CachedNetworkImage(
          imageUrl: widget.post.image,
          width: double.infinity,
          height: MediaQuery.of(context).size.width,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            color: themeController.isDarkMode.value
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.photo,
                size: 40,
                color: themeController.isDarkMode.value
                    ? Colors.grey[600]
                    : Colors.grey[400],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            color: themeController.isDarkMode.value
                ? Colors.grey[800]
                : Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.photo,
                size: 40,
                color: themeController.isDarkMode.value
                    ? Colors.grey
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  
  Widget _buildMultiImageSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.85;

    return SizedBox(
      height: imageWidth,
      child: OptimizedListView(
        scrollDirection: Axis.horizontal,
        itemCount: widget.post.multiImage.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () =>
                _openImageViewer(context, widget.post.multiImage, index),
            child: Container(
              width: imageWidth,
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 2,
                right: index == widget.post.multiImage.length - 1 ? 0 : 2,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: CachedNetworkImage(
                  imageUrl: widget.post.multiImage[index].toString(),
                  width: imageWidth,
                  height: imageWidth,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: imageWidth,
                    height: imageWidth,
                    color: themeController.isDarkMode.value
                        ? Colors.grey[800]
                        : Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.photo_library,
                        size: 40,
                        color: themeController.isDarkMode.value
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: imageWidth,
                    height: imageWidth,
                    color: themeController.isDarkMode.value
                        ? Colors.grey[800]
                        : Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.photo_library,
                        size: 40,
                        color: themeController.isDarkMode.value
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkedContentSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: _service.fetchLinkedContent(
        widget.post.link!,
        widget.post.linkType!,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _surfaceColor,
            ),
            child: Center(
              child: CircularProgressIndicator(color: _primaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _surfaceColor,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: _errorColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unable to load content',
                    style: TextStyle(fontSize: 10, color: _secondaryTextColor),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        return switch (widget.post.linkType!.toLowerCase()) {
          'book' => _buildBookContent(data),
          'playlist' => _buildPlaylistContent(data),
          'product' => _buildProductContent(data),
          'podcast' => _buildPodcastContent(data),
          'movie' => _buildMovieContent(data),
          _ => const SizedBox(),
        };
      },
    );
  }

  Widget _buildActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          timeAgo(widget.post.timeStamp!.toDate()),
          style: TextStyle(fontSize: 10, color: _secondaryTextColor),
        ),
        Obx(
          () => Row(
            children: [
              _buildActionButton(
                icon: FontAwesomeIcons.comment,
                count: widget.post.replyCount,
                onTap: _commentOnPost,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: FontAwesomeIcons.retweet,
                count: widget.post.repostCount,
                onTap: _repost,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: _isLiked.value
                    ? FontAwesomeIcons.solidHeart
                    : FontAwesomeIcons.heart,
                count: _likeCount.value,
                onTap: _toggleLike,
                isActive: _isLiked.value,
                activeColor: Colors.red,
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: FontAwesomeIcons.share,
                onTap: _sharePost,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    int count = 0,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = Colors.blue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? activeColor.withOpacity(0.2) : _surfaceColor,
        ),
        child: Row(
          children: [
            FaIcon(
              icon,
              size: 14,
              color: isActive ? activeColor : _secondaryTextColor,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? activeColor : _secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookContent(Map<String, dynamic> data) {
    try {
      final book = MangoBooks.fromMap(data, data['id'] ?? '');
      return GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _surfaceColor,
            border: Border.all(color: _dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 60,
                child: CachedNetworkImage(
                  imageUrl: book.coverUrl,
                  width: 45,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 45,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: themeController.isDarkMode.value
                          ? Colors.grey[800]
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.book,
                        size: 20,
                        color: themeController.isDarkMode.value
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 45,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: themeController.isDarkMode.value
                          ? Colors.grey[800]
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.book,
                        size: 20,
                        color: themeController.isDarkMode.value
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.book,
                          size: 12,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            book.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: _textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${book.author}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.eye,
                              size: 10,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${book.reads}',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.heart,
                              size: 10,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${book.likes}',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Widget _buildPlaylistContent(Map<String, dynamic> data) {
    try {
      final playlist = MangoPlaylist(
        id: data['id'] ?? '',
        title: data['title'] ?? 'Unknown Title',
        text: data['text'] ?? '',
        link: data['link'] ?? '',
        postCreator: data['postCreator'] ?? '',
        image: data['image'] ?? '',
        timeStamp: data['timeStamp'] ?? Timestamp.now(),
        type: data['type'] ?? '',
        repliedPlaylistID: data['repliedPlaylistID'],
        tags: List.from(data['tags'] ?? []),
        repost: data['repost'] ?? false,
        reply: data['reply'] ?? false,
        originalID: data['originalID'] ?? '',
        repostCount: data['repostCount'] ?? 0,
        replyCount: data['replyCount'] ?? 0,
        likeCount: data['likeCount'] ?? 0,
        plays: data['plays'] ?? 0,
        file: data['file'] ?? '',
        filePreview: data['filePreview'] ?? '',
        about: data['about'] ?? '',
        artiste: data['artiste'] ?? '',
        record: data['record'] ?? '',
        contributingArtistes: data['contributingArtistes'] ?? '',
        writers: data['writers'] ?? '',
        producers: data['producers'] ?? '',
        releaseYear: data['releaseYear'] ?? '',
        genre: data['genre'] ?? '',
        label: data['label'] ?? '',
        sellingPrice: data['sellingPrice'] ?? '',
      );

      return GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _surfaceColor,
            border: Border.all(color: _dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                child: CachedNetworkImage(
                  imageUrl: playlist.image,
                  width: 45,
                  height: 45,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: themeController.isDarkMode.value
                          ? Colors.grey[800]
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.music_note,
                        size: 20,
                        color: themeController.isDarkMode.value
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: themeController.isDarkMode.value
                          ? Colors.grey[800]
                          : Colors.grey[300],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.music_note,
                        size: 20,
                        color: themeController.isDarkMode.value
                            ? Colors.grey
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.music,
                          size: 12,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            playlist.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: _textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${playlist.artiste}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.play,
                              size: 10,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playlist.plays}',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.heart,
                              size: 10,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${playlist.likeCount}',
                              style: TextStyle(
                                fontSize: 9,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox();
    }
  }

  Widget _buildProductContent(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _surfaceColor,
          border: Border.all(color: _dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              child: data['image'] != null
                  ? CachedNetworkImage(
                      imageUrl: data['image'],
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_bag,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_bag,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _primaryColor.withOpacity(0.1),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.shoppingBag,
                          size: 18,
                          color: _primaryColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.tag,
                        size: 12,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['title'] ?? 'Product',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${data['price'] ?? '0'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastContent(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _surfaceColor,
          border: Border.all(color: _dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              child: data['image'] != null
                  ? CachedNetworkImage(
                      imageUrl: data['image'],
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.podcasts,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.podcasts,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _primaryColor.withOpacity(0.1),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.podcast,
                          size: 18,
                          color: _primaryColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.podcast,
                        size: 12,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['title'] ?? 'Podcast',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['host'] ?? 'Unknown Host',
                    style: TextStyle(fontSize: 10, color: _secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieContent(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _surfaceColor,
          border: Border.all(color: _dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 60,
              child: data['image'] != null
                  ? CachedNetworkImage(
                      imageUrl: data['image'],
                      width: 45,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 45,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.movie,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 45,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: themeController.isDarkMode.value
                              ? Colors.grey[800]
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.movie,
                            size: 20,
                            color: themeController.isDarkMode.value
                                ? Colors.grey
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _primaryColor.withOpacity(0.1),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.film,
                          size: 18,
                          color: _primaryColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.film,
                        size: 12,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['title'] ?? 'Movie',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['genre'] ?? 'Unknown Genre',
                    style: TextStyle(fontSize: 10, color: _secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _videoController?.dispose();
  }
}