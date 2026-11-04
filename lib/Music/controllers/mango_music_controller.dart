import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/customModel/playlist.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'dart:math';

import 'package:provider/provider.dart';

class MangoMusicController extends GetxController {
  var playlist = [].obs;
  var nowPlaying = {}.obs;
  var queue = [].obs;
  var isLoading = true.obs;
  var isPlayerActive = false.obs;
  var index = 0.obs;
  var isShuffling = false.obs;
  var repeat = "off".obs;
  var playerState = "stopped".obs;

  var isPanelOpen = false.obs;
  var isPanelVisible = false.obs;


  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void onInit() {
    super.onInit();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _handleSongCompletion();
      }
    });
  }

  void togglePanel() {
    isPanelOpen.value = !isPanelOpen.value;
  }

  void removePanel() {
    isPanelVisible.value = false;
  }

  void setPlaylist(List currentPlaylist) {
    playlist.value = currentPlaylist;
    isLoading.value = false;
    index.value = 0;
    if (playlist.isNotEmpty) {
      nowPlaying.value = playlist[index.value];
    }
  }

  playMusic(song) async {
    if (song != null) {
      nowPlaying.value = song;
      await audioPlayer.play(song);
      playerState.value = "playing";
      isPanelVisible.value = true;
    }
  }

  void pauseMusic() async {
    await audioPlayer.pause();
    playerState.value = "paused";
  }

  void skipMusic() {
    if (queue.isNotEmpty) {
      nowPlaying.value = queue.removeAt(0); 
    } else if (isShuffling.value) {
      index.value = Random().nextInt(playlist.length);
    } else {
      index.value = (index.value + 1) % playlist.length;
    }

    if (index.value == 0 && repeat.value != "repeat all") {
      if (repeat.value == "off") {
        audioPlayer.stop();
        playerState.value = "stopped";
        isPlayerActive.value = false;
        return;
      }
    }

    nowPlaying.value = playlist[index.value];
    playMusic(nowPlaying.value);
  }

  void repeatMusic() {
    if (repeat.value == "off") {
      repeat.value = "repeat all";
    } else if (repeat.value == "repeat all") {
      repeat.value = "repeat current index";
    } else if (repeat.value == "repeat current index") {
      repeat.value = "off";
    }
  }

  void shuffleMusic() {
    isShuffling.value = !isShuffling.value;
  }

  void addToQueue(song) {
    queue.add(song);
  }

  void _handleSongCompletion() {
    if (repeat.value == "repeat current index") {
      
      playMusic(nowPlaying.value);
    } else {
      
      skipMusic();
    }
  }
}


class MusicPlayerState extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<MangoPlaylist> _queue = [];
  int _currentIndex = 0;
  bool _shuffleEnabled = false;
  List<MangoPlaylist> _originalQueue = [];

  bool _isPlaying = false;
  bool _isExpanded = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  bool get isExpanded => _isExpanded;
  Duration get position => _position;
  Duration get duration => _duration;
  List<MangoPlaylist> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  MangoPlaylist? get currentTrack => _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  
  void updateQueue(List<MangoPlaylist> newTracks) {
    _queue = newTracks;
    _originalQueue = List.from(_queue);
    notifyListeners();
  }

  void togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (currentTrack == null && _queue.isNotEmpty) {
        await playTrack(_queue[0]);
      }
      await _audioPlayer.resume();
    }
  }

  playTrack(MangoPlaylist track) async {
    print('this is track');
    print(track.file);
    _currentIndex = _queue.indexOf(track);
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(track.record));
    notifyListeners();
  }

  void addToQueue(MangoPlaylist track) {
    _queue.add(track);
    notifyListeners();
  }

  void insertToQueueNext(MangoPlaylist track) {
    _queue.insert(_currentIndex + 1, track);
    notifyListeners();
  }

  void _playNext() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      playTrack(_queue[_currentIndex]);
    }
  }

  void playNext() {
    _playNext();
    notifyListeners();
  }

  void playPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      playTrack(_queue[_currentIndex]);
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    if (_shuffleEnabled) {
      _originalQueue = List.from(_queue);
      _queue.shuffle();
    } else {
      _queue = List.from(_originalQueue);
    }
    notifyListeners();
  }

  void seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void expandPlayer() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapsePlayer() {
    _isExpanded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class TrackListItem extends StatelessWidget {
  final MangoPlaylist track;

  const TrackListItem({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(track.image)),
      title: Text(track.title),
      subtitle: Text(track.artiste),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              context.read<MusicPlayerState>().playTrack(track);
              context.read<MusicPlayerState>().expandPlayer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () => context.read<MusicPlayerState>().addToQueue(track),
          ),
        ],
      ),
    );
  }
}


class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<MusicPlayerState>();

    return DraggableScrollableSheet(
      initialChildSize: playerState.isExpanded ? 1.0 : 0.15,
      minChildSize: 0.15,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.15, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: playerState.isExpanded
              ? ExpandedPlayerView(scrollController: scrollController)
              : const MinimizedPlayerView(),
        );
      },
    );
  }
}

class ExpandedPlayerView extends StatelessWidget {
  final ScrollController scrollController;

  const ExpandedPlayerView({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<MusicPlayerState>();
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: NetworkImage(track.image),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          Text(track.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(track.artiste, style: TextStyle(fontSize: 18, color: Colors.grey[400])),
          const SizedBox(height: 20),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Slider(
                  min: 0,
                  max: playerState.duration.inSeconds.toDouble(),
                  value: playerState.position.inSeconds.toDouble(),
                  onChanged: (value) => playerState.seek(Duration(seconds: value.toInt())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatTime(playerState.position)),
                    Text(formatTime(playerState.duration)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 40,
                onPressed: playerState.playPrevious,
              ),
              IconButton(
                icon: Icon(playerState.isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 60,
                onPressed: playerState.togglePlay,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 40,
                onPressed: playerState.playNext,
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.queue_music),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (context) => QueueListView(),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  color: playerState.shuffleEnabled ? Colors.blue : Colors.white,
                ),
                onPressed: playerState.toggleShuffle,
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(track.image),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('About the Artist', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(track.about, style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class MinimizedPlayerView extends StatelessWidget {
  const MinimizedPlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<MusicPlayerState>();
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        
        playerState.expandPlayer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(track.image)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(track.title, overflow: TextOverflow.ellipsis),
                  Text(track.artiste, style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ),
            IconButton(
              icon: Icon(playerState.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: playerState.togglePlay,
            ),
          ],
        ),
      ),
    );
  }
}

class QueueListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final playerState = context.watch<MusicPlayerState>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Up Next',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: OptimizedListView(
              itemCount: playerState.queue.length,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(playerState.queue[index].image),
                ),
                title: Text(playerState.queue[index].title),
                subtitle: Text(playerState.queue[index].artiste),
                trailing: index == playerState.currentIndex
                    ? const Icon(Icons.equalizer)
                    : null,
                onTap: () => playerState.playTrack(playerState.queue[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}