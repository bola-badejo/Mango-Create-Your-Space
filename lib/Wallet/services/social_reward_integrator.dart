
import 'package:get/get.dart';
import 'package:mango/Wallet/components/social_reward.dart';
import 'package:mango/Wallet/data/content_mining_services.dart';
import 'package:mango/Wallet/services/wallet_services.dart';

class SocialRewardIntegrator extends GetxService {
  final ContentMiningService _miningService = Get.find<ContentMiningService>();
  final WalletService _walletService = Get.find<WalletService>();
  final SocialFeatures _socialFeatures = SocialFeatures();

  Future<SocialRewardIntegrator> init() async {
    print('✅ Social Reward Integrator Initialized');
    return this;
  }

  Future<void> userVisitsSpace({
    required String spaceId,
    required String spaceOwnerId,
    required int visitDurationSeconds,
  }) async {
    try {
      await SocialFeatures.visitSpace(
        spaceId: spaceId,
        spaceOwnerId: spaceOwnerId,
        visitDurationSeconds: visitDurationSeconds,
      );
      if (visitDurationSeconds >= 60) {
        await _walletService.rewardForActivity(
          ActivityType.joinSpace,
          contentId: spaceId,
        );

        print('🏠 User rewarded for visiting space: $spaceId');
      }
    } catch (e) {
      print('❌ Space visit reward error: $e');
    }
  }

  Future<void> userCreatesSpace({
    required String spaceId,
    required String creatorId,
  }) async {
    try {
      await _walletService.rewardForActivity(
        ActivityType.createPost,
        contentId: spaceId,
      );

      print('🏗️ User rewarded for creating space: $spaceId');
    } catch (e) {
      print('❌ Space creation reward error: $e');
    }
  }

  Future<void> userCommentsOnPost({
    required String postId,
    required String postAuthorId,
    required String commentId,
  }) async {
    try {
      await _walletService.rewardForActivity(
        ActivityType.sendMessage,
        contentId: commentId,
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: postId,
      );

      print('💬 User rewarded for commenting on post: $postId');
    } catch (e) {
      print('❌ Comment reward error: $e');
    }
  }

  Future<void> userSendsMessage({
    required String chatId,
    required String recipientId,
    required String messageId,
  }) async {
    try {
      await _walletService.rewardForActivity(
        ActivityType.sendMessage,
        contentId: messageId,
      );

      print('✉️ User rewarded for sending message: $messageId');
    } catch (e) {
      print('❌ Message reward error: $e');
    }
  }

  Future<void> userLikesContent({
    required String contentId,
    required String contentType,
    required String contentAuthorId,
  }) async {
    try {
      await SocialFeatures.rewardForLike(contentId);
      await _walletService.rewardForActivity(
        ActivityType.likeContent,
        contentId: contentId,
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: contentId,
      );

      print('❤️ User rewarded for liking $contentType: $contentId');
    } catch (e) {
      print('❌ Like reward error: $e');
    }
  }

  Future<void> userSharesContent({
    required String contentId,
    required String contentType,
    required String contentAuthorId,
  }) async {
    try {
      await SocialFeatures.rewardForShare(contentId);
      await _walletService.rewardForActivity(
        ActivityType.shareContent,
        contentId: contentId,
      );

      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: contentId,
      );

      print('🔄 User rewarded for sharing $contentType: $contentId');
    } catch (e) {
      print('❌ Share reward error: $e');
    }
  }

  Future<void> userStreamsMusic({
    required String songId,
    required String artistId,
    required int durationSeconds,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      await SocialFeatures.playSong(
        songId: songId,
        artistId: artistId,
        durationSeconds: durationSeconds,
        spaceId: spaceId,
        spaceOwnerId: spaceOwnerId,
      );

      if (durationSeconds >= 30) {
        await _walletService.rewardForActivity(
          ActivityType.contentEngagement,
          contentId: songId,
        );

        print('🎵 User rewarded for listening to song: $songId');
      }
    } catch (e) {
      print('❌ Music streaming reward error: $e');
    }
  }

  Future<void> userWatchesMovie({
    required String movieId,
    required String creatorId,
    required int durationSeconds,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      await SocialFeatures.watchMovie(
        movieId: movieId,
        creatorId: creatorId,
        durationSeconds: durationSeconds,
        spaceId: spaceId,
        spaceOwnerId: spaceOwnerId,
      );

      if (durationSeconds >= 300) {
        await _walletService.rewardForActivity(
          ActivityType.watchVideo,
          contentId: movieId,
        );

        print('🎬 User rewarded for watching movie: $movieId');
      }
    } catch (e) {
      print('❌ Movie watching reward error: $e');
    }
  }

  Future<void> userReadsBook({
    required String bookId,
    required String authorId,
    required int durationSeconds,
    String? spaceId,
    String? spaceOwnerId,
  }) async {
    try {
      await SocialFeatures.readBook(
        bookId: bookId,
        authorId: authorId,
        durationSeconds: durationSeconds,
        spaceId: spaceId,
        spaceOwnerId: spaceOwnerId,
      );

      if (durationSeconds >= 60) {
        await _walletService.rewardForActivity(
          ActivityType.readArticle,
          contentId: bookId,
        );

        print('📚 User rewarded for reading book: $bookId');
      }
    } catch (e) {
      print('❌ Book reading reward error: $e');
    }
  }

  

  Future<void> userVisitsProfile({
    required String visitedUserId,
    required int visitDurationSeconds,
  }) async {
    try {
      
      if (visitDurationSeconds >= 30) {
        
        await _walletService.rewardForActivity(
          ActivityType.contentEngagement,
          contentId: 'profile_$visitedUserId',
        );
      }

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'profile_visit_$visitedUserId',
      );

      print('👤 User rewarded for profile visit: $visitedUserId');
    } catch (e) {
      print('❌ Profile visit reward error: $e');
    }
  }

  Future<void> userCompletesProfile({
    required String userId,
    required int profileCompletionPercentage,
  }) async {
    try {
      if (profileCompletionPercentage >= 80) {
        
        await _walletService.rewardForActivity(
          ActivityType.completeProfile,
          contentId: 'profile_$userId',
        );

        print('✅ User rewarded for completing profile: $userId');
      }
    } catch (e) {
      print('❌ Profile completion reward error: $e');
    }
  }

  Future<void> userUpdatesProfile({
    required String userId,
    required String updateType, 
  }) async {
    try {
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'profile_update_$updateType',
      );

      print('🔄 User rewarded for profile update: $updateType');
    } catch (e) {
      print('❌ Profile update reward error: $e');
    }
  }

  

  Future<void> userFollowsUser({
    required String followerId,
    required String followedId,
  }) async {
    try {
      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'follow_$followedId',
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'follower_$followerId',
      );

      print('➕ User rewarded for follow action');
    } catch (e) {
      print('❌ Follow reward error: $e');
    }
  }

  Future<void> userCreatesPost({
    required String postId,
    required String postType, 
  }) async {
    try {
      await SocialFeatures.rewardForPostCreation(postId);
      await _walletService.rewardForActivity(
        ActivityType.createPost,
        contentId: postId,
      );

      print('📝 User rewarded for creating $postType post: $postId');
    } catch (e) {
      print('❌ Post creation reward error: $e');
    }
  }

  Future<void> userJoinsCommunity({
    required String communityId,
    required String communityOwnerId,
  }) async {
    try {
      await _walletService.rewardForActivity(
        ActivityType.joinSpace,
        contentId: communityId,
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'community_join_$communityId',
      );

      print('👥 User rewarded for joining community: $communityId');
    } catch (e) {
      print('❌ Community join reward error: $e');
    }
  }

  

  
  Future<void> userUploadsPodcast({
    required String podcastId,
    required String creatorId,
    required int durationSeconds,
    required String title,
  }) async {
    try {
      
      await _walletService.rewardForActivity(
        ActivityType.uploadPodcast,
        contentId: podcastId,
      );

      print('🎙️ Creator rewarded for uploading podcast: $title');
    } catch (e) {
      print('❌ Podcast upload reward error: $e');
    }
  }

  Future<void> userListensToPodcast({
    required String podcastId,
    required String creatorId,
    required int durationSeconds,
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

      
      if (durationSeconds >= 60) {
        
        await _walletService.rewardForActivity(
          ActivityType.contentEngagement,
          contentId: podcastId,
        );

        print('🎧 User rewarded for listening to podcast: $podcastId');
        print('💰 Mining result: ${result.minerShare.toFixed(6)} MNG earned');
      }
    } catch (e) {
      print('❌ Podcast listening reward error: $e');
    }
  }

  Future<void> userCompletesPodcast({
    required String podcastId,
    required String creatorId,
    required int totalDuration,
  }) async {
    try {
      
      await _walletService.rewardForActivity(
        ActivityType.streakBonus, 
        contentId: podcastId,
      );

      print('🏆 User rewarded for completing podcast: $podcastId');
    } catch (e) {
      print('❌ Podcast completion reward error: $e');
    }
  }

  Future<void> userSubscribesToPodcast({
    required String podcastId,
    required String creatorId,
  }) async {
    try {
      
      await _walletService.rewardForActivity(
        ActivityType.followUser, 
        contentId: podcastId,
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'podcast_sub_$podcastId',
      );

      print('📌 User rewarded for subscribing to podcast: $podcastId');
    } catch (e) {
      print('❌ Podcast subscription reward error: $e');
    }
  }

  Future<void> userSharesPodcast({
    required String podcastId,
    required String creatorId,
    required String sharePlatform, 
  }) async {
    try {
      await SocialFeatures.rewardForShare(podcastId);
      await _walletService.rewardForActivity(
        ActivityType.shareContent,
        contentId: podcastId,
      );

      
      await _walletService.rewardForActivity(
        ActivityType.contentEngagement,
        contentId: 'podcast_share_$sharePlatform',
      );

      print(
        '📤 User rewarded for sharing podcast: $podcastId on $sharePlatform',
      );
    } catch (e) {
      print('❌ Podcast share reward error: $e');
    }
  }

  Future<void> userReachesMilestone({
    required String userId,
    required String
    milestoneType, 
    required String milestoneId,
  }) async {
    try {
      
      await _walletService.rewardForActivity(
        ActivityType.streakBonus,
        contentId: milestoneId,
      );

      print('🏆 User rewarded for milestone: $milestoneType');
    } catch (e) {
      print('❌ Milestone reward error: $e');
    }
  }

  Future<void> userMaintainsStreak({
    required String userId,
    required int streakDays,
  }) async {
    try {
      if (streakDays >= 7) {
        
        await _walletService.rewardForActivity(
          ActivityType.streakBonus,
          contentId: 'streak_${streakDays}days',
        );

        print('🔥 User rewarded for $streakDays day streak');
      }
    } catch (e) {
      print('❌ Streak reward error: $e');
    }
  }
}
