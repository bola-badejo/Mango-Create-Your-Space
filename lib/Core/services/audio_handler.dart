
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AppAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final ConcatenatingAudioSource _concatenatingAudioSource;

  AppAudioHandler._(this._player, this._concatenatingAudioSource) {
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForSequenceStateChanges();
    _listenForPlayerProcessingState();
    _listenForPosition();
  }

  static Future<AppAudioHandler> init() async {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.mango_media.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );

    final player = AudioPlayer();
    final concatenating = ConcatenatingAudioSource(children: []);

    
    return AppAudioHandler._(player, concatenating);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    final currentQueue = queue.value;
    final newQueue = List<MediaItem>.from(currentQueue)..addAll(items);
    queue.add(newQueue);

    final sources = items.map((m) {
      return AudioSource.uri(
        Uri.parse(m.extras?['url'] ?? m.id),
        tag: m,
      );
    }).toList();

    await _concatenatingAudioSource.addAll(sources);

    
    if (_player.audioSource == null) {
      await _player.setAudioSource(_concatenatingAudioSource, preload: false);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem item) async {
    final idx = queue.value.indexWhere((q) => q.id == item.id);
    if (idx < 0) return;
    await _concatenatingAudioSource.removeAt(idx);
    final newQueue = List<MediaItem>.from(queue.value)
      ..removeWhere((q) => q.id == item.id);
    queue.add(newQueue);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position, index: _player.currentIndex);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(
      shuffleMode == AudioServiceShuffleMode.all,
    );
    playbackState.add(playbackState.value.copyWith(
      shuffleMode: shuffleMode,
    ));
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    LoopMode loopMode = LoopMode.off;
    if (mode == AudioServiceRepeatMode.one) loopMode = LoopMode.one;
    if (mode == AudioServiceRepeatMode.all) loopMode = LoopMode.all;
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: mode));
  }

  Future<void> replaceQueue(List<MediaItem> items, {int? startIndex}) async {
    await _concatenatingAudioSource.clear();
    queue.add(items);
    final sources = items.map((m) => AudioSource.uri(
      Uri.parse(m.extras?['url'] ?? m.id),
      tag: m,
    )).toList();
    await _concatenatingAudioSource.addAll(sources);

    if (_player.audioSource == null) {
      await _player.setAudioSource(_concatenatingAudioSource, preload: false);
    }

    if (startIndex != null && startIndex < sources.length) {
      await _player.seek(Duration.zero, index: startIndex);
    } else {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _translateProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ));
    });
  }

  void _listenForSequenceStateChanges() {
    _player.sequenceStateStream.listen((sequenceState) {
      final seq = sequenceState;
      if (seq == null) return;
      final currentSource = seq.currentSource;
      final tag = currentSource?.tag;
      if (tag is MediaItem) {
        mediaItem.add(tag);
      }
    });
  }

  void _listenForPlayerProcessingState() {
    _player.processingStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        processingState: _translateProcessingState(state),
      ));
    });
  }

  StreamSubscription<Duration>? _positionSub;
  void _listenForPosition() {
    _positionSub?.cancel();
    _positionSub = _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
  }

  AudioProcessingState _translateProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> disposeHandler() async {
    await _player.dispose();
  }
}
