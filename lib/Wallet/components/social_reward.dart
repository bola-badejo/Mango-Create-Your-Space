


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:mango/Wallet/data/content_mining_services.dart';
import 'package:mango/Wallet/data/decimal.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class SocialFeatures {
  static final ContentMiningService _miningService = Get.find<ContentMiningService>();
  static final WalletService _walletService = Get.find<WalletService>();

  
  static Future<void> playSong({
    required String songId,
    required String artistId,
    int durationSeconds = 0,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      MiningResult result;
      
      if (spaceId != null && spaceOwnerId != null) {
        
        result = await _miningService.mineContentInSpace(
          contentId: songId,
          contentType: ContentType.song,
          creatorId: artistId,
          spaceId: spaceId,
          spaceOwnerId: spaceOwnerId,
          durationSeconds: durationSeconds,
        );
      } else {
        
        result = await _miningService.mineContent(
          contentId: songId,
          contentType: ContentType.song,
          creatorId: artistId,
          durationSeconds: durationSeconds,
        );
      }

      
      await _sendMiningNotification(result, 'song');
      
    } catch (e) {
      print('Error mining song: $e');
      await _sendErrorNotification('song mining', e.toString());
    }
  }

  static Future<void> watchMovie({
    required String movieId,
    required String creatorId,
    int durationSeconds = 0,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      MiningResult result;
      
      if (spaceId != null && spaceOwnerId != null) {
        result = await _miningService.mineContentInSpace(
          contentId: movieId,
          contentType: ContentType.movie,
          creatorId: creatorId,
          spaceId: spaceId,
          spaceOwnerId: spaceOwnerId,
          durationSeconds: durationSeconds,
        );
      } else {
        result = await _miningService.mineContent(
          contentId: movieId,
          contentType: ContentType.movie,
          creatorId: creatorId,
          durationSeconds: durationSeconds,
        );
      }

      await _sendMiningNotification(result, 'movie');
      
    } catch (e) {
      print('Error mining movie: $e');
      await _sendErrorNotification('movie mining', e.toString());
    }
  }

  static Future<void> readBook({
    required String bookId,
    required String authorId,
    int durationSeconds = 0,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      MiningResult result;
      
      if (spaceId != null && spaceOwnerId != null) {
        result = await _miningService.mineContentInSpace(
          contentId: bookId,
          contentType: ContentType.book,
          creatorId: authorId,
          spaceId: spaceId,
          spaceOwnerId: spaceOwnerId,
          durationSeconds: durationSeconds,
        );
      } else {
        result = await _miningService.mineContent(
          contentId: bookId,
          contentType: ContentType.book,
          creatorId: authorId,
          durationSeconds: durationSeconds,
        );
      }

      await _sendMiningNotification(result, 'book');
      
    } catch (e) {
      print('Error mining book: $e');
      await _sendErrorNotification('book mining', e.toString());
    }
  }

  static Future<void> buyProduct({
  required String productId,
  required String sellerId,
  required Decimal purchaseAmount,
  String? spaceId,
  String? spaceOwnerId,
}) async {
    try {
      MiningResult result;
      
      if (spaceId != null && spaceOwnerId != null) {
        result = await _miningService.mineContentInSpace(
          contentId: productId,
          contentType: ContentType.product,
          creatorId: sellerId,
          spaceId: spaceId,
          spaceOwnerId: spaceOwnerId,
        );
      } else {
        result = await _miningService.mineContent(
          contentId: productId,
          contentType: ContentType.product,
          creatorId: sellerId,
        );
      }

      await _sendMiningNotification(result, 'product purchase');
      
    } catch (e) {
      print('Error mining product: $e');
      await _sendErrorNotification('product mining', e.toString());
    }
  }

  static Future<void> listenToPodcast({
    required String podcastId,
    required String creatorId,
    int durationSeconds = 0,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      MiningResult result;
      
      if (spaceId != null && spaceOwnerId != null) {
        result = await _miningService.mineContentInSpace(
          contentId: podcastId,
          contentType: ContentType.podcast,
          creatorId: creatorId,
          spaceId: spaceId,
          spaceOwnerId: spaceOwnerId,
          durationSeconds: durationSeconds,
        );
      } else {
        result = await _miningService.mineContent(
          contentId: podcastId,
          contentType: ContentType.podcast,
          creatorId: creatorId,
          durationSeconds: durationSeconds,
        );
      }

      await _sendMiningNotification(result, 'podcast');
      
    } catch (e) {
      print('Error mining podcast: $e');
      await _sendErrorNotification('podcast mining', e.toString());
    }
  }

  static Future<void> visitSpace({
    required String spaceId,
    required String spaceOwnerId,
    int visitDurationSeconds = 0,
  }) async {
    try {
      final result = await _miningService.mineSpaceVisit(
        spaceId: spaceId,
        spaceOwnerId: spaceOwnerId,
        visitDurationSeconds: visitDurationSeconds,
      );

      await _sendSpaceVisitNotification(result, spaceId);
      
    } catch (e) {
      print('Error mining space visit: $e');
      await _sendErrorNotification('space visit mining', e.toString());
    }
  }

  
  static Future<void> rewardForPostCreation(String postId) async {
    try {
      final result = await _walletService.rewardForActivity(
        ActivityType.createPost,
        contentId: postId,
      );

      
      await _sendActivityNotification(
        'Post Created!',
        '+${result.amount.toFixed(6)} MNG for creating a post',
        'create_post',
        postId,
      );
      
    } catch (e) {
      print('Error rewarding post creation: $e');
    }
  }

  static Future<void> rewardForLike(String contentId) async {
    try {
      final result = await _walletService.rewardForActivity(
        ActivityType.likeContent,
        contentId: contentId,
      );

      await _sendActivityNotification(
        'Content Liked!',
        '+${result.amount.toFixed(6)} MNG for liking content',
        'like_content',
        contentId,
      );
      
    } catch (e) {
      print('Error rewarding like: $e');
    }
  }

  static Future<void> rewardForShare(String contentId) async {
    try {
      final result = await _walletService.rewardForActivity(
        ActivityType.shareContent,
        contentId: contentId,
      );

      await _sendActivityNotification(
        'Content Shared!',
        '+${result.amount.toFixed(6)} MNG for sharing content',
        'share_content',
        contentId,
      );
      
    } catch (e) {
      print('Error rewarding share: $e');
    }
  }

  static Future<void> rewardDailyLogin() async {
    try {
      await _walletService.onDailyLogin();
      
      await _sendActivityNotification(
        'Daily Login Reward!',
        '+${WalletService.dailyLoginReward.toFixed(6)} MNG for daily login',
        'daily_login',
        null,
      );
      
    } catch (e) {
      print('Error rewarding daily login: $e');
    }
  }

  
  static Future<void> _sendMiningNotification(MiningResult result, String contentType) async {
    final message = result.spaceId != null 
        ? '🎉 Space Mining! +${result.minerShare.toFixed(6)} MNG from $contentType'
        : '⛏️ Mining Reward! +${result.minerShare.toFixed(6)} MNG from $contentType';

    await _sendActivityNotification(
      'Mining Complete!',
      message,
      'content_mining',
      result.miningId,
    );
  }

  static Future<void> _sendSpaceVisitNotification(MiningResult result, String spaceId) async {
    await _sendActivityNotification(
      'Space Visit Rewarded!',
      '🏠 Space Mining! +${result.minerShare.toFixed(6)} MNG for visiting space',
      'space_visit',
      spaceId,
    );
  }

  static Future<void> _sendActivityNotification(
    String title,
    String message,
    String type,
    String? contentId,
  ) async {
    try {
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('messages').add({
        'user_id': user.uid,
        'type': type,
        'title': title,
        'message': message,
        'data': {
          'content_id': contentId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'high', 
      });

    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  static Future<void> _sendErrorNotification(String activity, String error) async {
    await _sendActivityNotification(
      'Mining Failed',
      '❌ $activity failed: $error',
      'mining_error',
      null,
    );
  }
}