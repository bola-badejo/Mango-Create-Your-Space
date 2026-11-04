// lib/MusicPlayer/controllers/global_music_controller.dart
import 'dart:ui';

import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mango/MusicPlayer/music.dart';

class GlobalMusicController extends GetxController {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Observable states
  var isPlaying = false.obs;
  var currentMusic = Rxn<Music>();
  var currentPosition = Duration.zero.obs;
  var totalDuration = Duration.zero.obs;
  var isMiniPlayerVisible = true.obs;
  var showMiniPlayer = false.obs;
  var isLoading = false.obs;
  
  // Playlist management
  var playlist = <Music>[].obs;
  var upcomingTracks = <Music>[].obs;
  var playedTrackIds = <String>[].obs;
  var currentIndex = 0.obs;
  var isShuffled = false.obs;
  var isLooped = false.obs;
  
  // Color for background
  var backgroundColor = Rx<Color?>(null);
  
  // Callbacks for UI updates
  Function(Music)? onMusicChange;
  Function(Color?)? onColorChange;
  
  // Getter for audio player (for Lyrics page)
  AudioPlayer get audioPlayer => _audioPlayer;
  
  @override
  void onInit() {
    super.onInit();
    _initListeners();
  }
  
  void _initListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      currentPosition.value = position;
    });
    
    _audioPlayer.onDurationChanged.listen((duration) {
      totalDuration.value = duration;
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!isLooped.value) {
        playNextTrack(); // Changed from _playNextTrack to public method
      }
    });
  }
  
  Future<void> initializePlayer(String musicId, {List<Music>? initialPlaylist, int initialIndex = 0}) async {
    isLoading.value = true;
    
    try {
      if (initialPlaylist != null) {
        playlist.value = initialPlaylist;
        currentIndex.value = initialIndex;
        currentMusic.value = playlist[initialIndex];
      } else {
        final doc = await _firestore
            .collection('music')
            .doc(musicId)
            .get();
        
        if (doc.exists) {
          final music = Music.fromFirestore(doc);
          currentMusic.value = music;
          playlist.value = [music];
          currentIndex.value = 0;
        } else {
          throw Exception('Music not found');
        }
      }
      
      await _generateUpcomingTracks();
      await _playCurrentTrack();
      
      isPlaying.value = true;
      showMiniPlayer.value = true;
      isLoading.value = false;
      
      // Increment plays
      _incrementPlays(currentMusic.value!);
      
    } catch (e) {
      debugPrint('Error initializing player: $e');
      isLoading.value = false;
    }
  }
  
  Future<void> _playCurrentTrack() async {
    final music = currentMusic.value;
    if (music == null || music.trackUrl.isEmpty) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(music.trackUrl));
      
      if (!playedTrackIds.contains(music.id)) {
        playedTrackIds.add(music.id);
      }
      
      // Notify UI of music change
      onMusicChange?.call(music);
      
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }
  
  Future<void> playNextTrack() async {
    if (currentIndex.value + 1 < playlist.length) {
      currentIndex.value++;
      currentMusic.value = playlist[currentIndex.value];
    } else if (upcomingTracks.isNotEmpty) {
      currentMusic.value = upcomingTracks.removeAt(0);
      playlist.add(currentMusic.value!);
      currentIndex.value = playlist.length - 1;
    } else {
      await _generateUpcomingTracks();
      if (upcomingTracks.isNotEmpty) {
        currentMusic.value = upcomingTracks.removeAt(0);
        playlist.add(currentMusic.value!);
        currentIndex.value = playlist.length - 1;
      } else {
        isPlaying.value = false;
        return;
      }
    }
    
    await _playCurrentTrack();
    _incrementPlays(currentMusic.value!);
  }
  
  Future<void> playPreviousTrack() async {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      currentMusic.value = playlist[currentIndex.value];
      await _playCurrentTrack();
    }
  }
  
  Future<void> _generateUpcomingTracks() async {
    final music = currentMusic.value;
    if (music == null || playlist.isEmpty) return;
    
    upcomingTracks.clear();
    
    if (playlist.length == 1) {
      final artistTracks = await _getTracksByArtist(music.artistId, limit: 2);
      upcomingTracks.addAll(artistTracks);
      
      final genreTracks = await _getTracksByGenre(music.genre, limit: 15);
      upcomingTracks.addAll(genreTracks);
    } else {
      final genreTracks = await _getTracksByGenre(music.genre, limit: 10);
      upcomingTracks.addAll(genreTracks);
    }
    
    upcomingTracks.removeWhere((track) => playedTrackIds.contains(track.id));
    
    if (isShuffled.value) {
      upcomingTracks.shuffle();
    }
  }
  
  Future<List<Music>> _getTracksByArtist(String artistId, {int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('music')
          .where('artistId', isEqualTo: artistId)
          .limit(limit)
          .get();
      
      return query.docs
          .map((doc) => Music.fromFirestore(doc))
          .where((track) => !playedTrackIds.contains(track.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching artist tracks: $e');
      return [];
    }
  }
  
  Future<List<Music>> _getTracksByGenre(String genre, {int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('music')
          .where('genre', isEqualTo: genre)
          .limit(limit)
          .get();
      
      return query.docs
          .map((doc) => Music.fromFirestore(doc))
          .where((track) => !playedTrackIds.contains(track.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching genre tracks: $e');
      return [];
    }
  }
  
  Future<void> _incrementPlays(Music music) async {
    try {
      await _firestore
          .collection('music')
          .doc(music.id)
          .update({'plays': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error incrementing plays: $e');
    }
  }
  
  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await _audioPlayer.pause();
      isPlaying.value = false;
    } else {
      await _audioPlayer.resume();
      isPlaying.value = true;
    }
  }
  
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }
  
  void toggleShuffle() {
    isShuffled.value = !isShuffled.value;
    if (isShuffled.value && upcomingTracks.isNotEmpty) {
      upcomingTracks.shuffle();
    }
  }
  
  void toggleLoop() {
    isLooped.value = !isLooped.value;
    _audioPlayer.setReleaseMode(isLooped.value ? ReleaseMode.loop : ReleaseMode.release);
  }
  
  void toggleMiniPlayer() {
    isMiniPlayerVisible.toggle();
  }
  
  Future<void> stopMusic() async {
    await _audioPlayer.stop();
    isPlaying.value = false;
    currentMusic.value = null;
    showMiniPlayer.value = false;
    playlist.clear();
    upcomingTracks.clear();
    playedTrackIds.clear();
  }
  
  void setBackgroundColor(Color? color) {
    backgroundColor.value = color;
    onColorChange?.call(color);
  }
  
  int get totalTracks => playlist.length + upcomingTracks.length;
  
  Music getMusicAtIndex(int index) {
    if (index < playlist.length) {
      return playlist[index];
    } else {
      return upcomingTracks[index - playlist.length];
    }
  }
  
  void playSpecificTrack(int index) {
    if (index < playlist.length) {
      currentIndex.value = index;
      currentMusic.value = playlist[index];
      _playCurrentTrack();
    }
  }
  
  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }
}