import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoController extends GetxController {
  late YoutubePlayerController youtubeController;

  @override
  void onInit() {
    youtubeController = YoutubePlayerController(
      initialVideoId: 'ztVV54sPOns',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        controlsVisibleAtStart: false,
      ),
    );
    youtubeController.mute();
    super.onInit();
  }

  @override
  void onClose() {
    youtubeController.dispose();
    super.onClose();
  }
}
