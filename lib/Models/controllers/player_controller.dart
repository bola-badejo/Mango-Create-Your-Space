
import 'package:get/get.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/services/audio_handler.dart';

class PlayerController extends GetxController {
  final AppAudioHandler handler = Get.find<AppAudioHandler>();

  RxList<MediaItem> queue = <MediaItem>[].obs;
  Rxn<MediaItem> current = Rxn<MediaItem>();
  RxBool playing = false.obs;
  RxDouble position = 0.0.obs;
  RxDouble duration = 0.0.obs;
  RxBool isBuffering = false.obs;
  RxBool shuffle = false.obs;
  Rx<RepeatMode> repeatMode = Rx<RepeatMode>(RepeatMode.none);

  @override
  void onInit() {
    super.onInit();
    handler.queue.listen((q) => queue.assignAll(q));
    handler.mediaItem.listen((m) => current.value = m);
    handler.playbackState.listen((ps) {
      playing.value = ps.playing;
      
      isBuffering.value = ps.processingState == AudioProcessingState.buffering ||
          ps.processingState == AudioProcessingState.loading;
      position.value = ps.updatePosition.inMilliseconds.toDouble();
      
      
    });
    
  }

  Future<void> playPause() async {
    if (playing.value) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }

  Future<void> seek(Duration pos) => handler.seek(pos);

  Future<void> skipNext() => handler.skipToNext();
  Future<void> skipPrevious() => handler.skipToPrevious();

  Future<void> toggleShuffle() async {
    shuffle.value = !shuffle.value;
    await handler.setShuffleMode(shuffle.value as AudioServiceShuffleMode);
  }

  Future<void> cycleRepeat() async {
    
    if (repeatMode.value == RepeatMode.none) {
      repeatMode.value = RepeatMode.all;
      await handler.setRepeatMode(AudioServiceRepeatMode.all);
    } else if (repeatMode.value == RepeatMode.all) {
      repeatMode.value = RepeatMode.one;
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
    } else {
      repeatMode.value = RepeatMode.none;
      await handler.setRepeatMode(AudioServiceRepeatMode.none);
    }
  }

  
  Future<void> playQueue(List<MediaItem> items, {int startIndex = 0}) =>
      handler.replaceQueue(items, startIndex: startIndex);

  @override
  void onClose() {
    super.onClose();
  }
}

enum RepeatMode { none, all, one }
