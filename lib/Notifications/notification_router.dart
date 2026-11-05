// Opens whatever a notification is about. Used for taps in the
// notification centre and for taps on push notifications.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mango/Chat/chat_list_screen.dart';
import 'package:mango/Chat/chat_screen.dart';
import 'package:mango/Home/pages/post_detail_screen.dart';
import 'package:mango/Media/reader/mango_reader.dart';
import 'package:mango/Media/video/mango_video_player.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/Onboarding/mango_explainer.dart';
import 'package:mango/Profile/pages/notifications.dart';
import 'package:mango/Profile/pages/settings.dart';
import 'package:mango/Profile/public_profile.dart';
import 'package:mango/Spaces/world/space_world_screen.dart';

class NotificationRouter {
  /// [kind] and [id] come from a notification's target (or push data).
  static Future<void> open(String? kind, String? id, {Map<String, dynamic> extra = const {}}) async {
    final target = id ?? '';
    switch (kind) {
      case 'post':
        if (target.isNotEmpty) await Get.to(() => PostDetailScreen(postId: target));
      case 'profile':
        if (target.isNotEmpty) await Get.to(() => PublicProfilePage(userId: target));
      case 'chat':
        final chatId = target.isNotEmpty ? target : '${extra['chatId'] ?? ''}';
        final me = FirebaseAuth.instance.currentUser?.uid ?? '';
        final peer = chatId.split('_').firstWhere((p) => p != me, orElse: () => '');
        if (chatId.isNotEmpty && peer.isNotEmpty) {
          await Get.to(() => ChatScreen(chatId: chatId, peerId: peer));
        } else {
          await Get.to(() => const ChatListScreen());
        }
      case 'song':
      case 'podcast':
        if (target.isNotEmpty) {
          await Get.find<GlobalMusicController>().initializePlayer(target, kind: kind == 'podcast' ? AudioKind.podcast : AudioKind.song);
        }
      case 'movie':
      case 'vine':
        if (target.isNotEmpty) await Get.to(() => MangoVideoPlayerScreen(type: kind!, id: target));
      case 'book':
        if (target.isNotEmpty) await Get.to(() => MangoReaderScreen(bookId: target));
      case 'space':
        if (target.isNotEmpty) await Get.to(() => SpaceWorldScreen(spaceId: target));
      case 'settings':
        await Get.to(() => AccountSettingsPage());
      case 'explainer':
        await Get.to(() => const MangoExplainer());
      default:
        await Get.to(() => const NotificationsPage());
    }
  }

  /// Push payloads: new ones carry targetKind/targetId; older ones carry
  /// type plus postId, songId, chatId and so on.
  static Future<void> openFromPush(Map<String, dynamic> data) {
    final kind = (data['targetKind'] ?? '').toString();
    if (kind.isNotEmpty) return open(kind, '${data['targetId'] ?? ''}', extra: data);
    final type = '${data['type'] ?? ''}';
    final legacyId = '${data['${type}Id'] ?? data['postId'] ?? data['chatId'] ?? data['id'] ?? ''}';
    return open(type, legacyId, extra: data);
  }
}
