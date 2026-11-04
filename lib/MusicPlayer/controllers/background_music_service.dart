// lib/Core/services/simple_background_audio.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class BackgroundAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static String? currentMusicId;
  static bool _isInitialized = false;
  
  static Future<void> init() async {
    if (_isInitialized) return;
    
    if (!kIsWeb) {
      // Enable background audio on mobile
      await _player.setReleaseMode(ReleaseMode.stop);
      
      // Handle audio session for background playback
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _player.setPlayerMode(PlayerMode.mediaPlayer);
      }
    }
    
    _isInitialized = true;
  }
  
  static Future<void> playMusic(String url, String musicId) async {
    currentMusicId = musicId;
    await _player.play(UrlSource(url));
  }
  
  static Future<void> pause() async => await _player.pause();
  static Future<void> resume() async => await _player.resume();
  static Future<void> stop() async => await _player.stop();
  static Future<void> seek(Duration position) async => await _player.seek(position);
  static AudioPlayer get player => _player;
  static bool get isPlaying => _player.state == PlayerState.playing;
  
  static void dispose() => _player.dispose();
}