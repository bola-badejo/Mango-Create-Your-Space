
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentUrl;
  double _playbackRate = 1.0;
  PlayerState _playerState = PlayerState.stopped;

  Future<void> playAudio(String url, {double? speed}) async {
    try {
      if (_currentUrl == url && _playerState == PlayerState.playing) {
        await pauseAudio();
        return;
      }

      if (_currentUrl != url) {
        await _audioPlayer.stop();
        await _audioPlayer.setSourceUrl(url);
        _currentUrl = url;
      }

      final rate = speed ?? _playbackRate;
      await _audioPlayer.setPlaybackRate(rate);
      await _audioPlayer.resume();
      _playerState = PlayerState.playing;
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    _playerState = PlayerState.paused;
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _playerState = PlayerState.stopped;
  }

  void setPlaybackRate(double rate) {
    _playbackRate = rate;
    if (_playerState == PlayerState.playing) {
      _audioPlayer.setPlaybackRate(rate);
    }
  }

  Stream<PlayerState> get onPlayerStateChanged => _audioPlayer.onPlayerStateChanged;
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<Duration?> get onDurationChanged => _audioPlayer.onDurationChanged;

  void dispose() {
    _audioPlayer.dispose();
  }
}