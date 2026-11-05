
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mango/Conversations/utils/audio_player_service.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String audioUrl;
  final double duration;

  const VoiceNotePlayer({
    Key? key,
    required this.audioUrl,
    required this.duration,
  }) : super(key: key);

  @override
  _VoiceNotePlayerState createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayerService _audioService = AudioPlayerService();
  double _playbackRate = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.duration.toInt());
    
    _audioService.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });
    
    _audioService.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_playerState == PlayerState.playing) {
      _audioService.pauseAudio();
    } else {
      _audioService.playAudio(widget.audioUrl, speed: _playbackRate);
    }
  }

  void _changePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    _audioService.setPlaybackRate(_playbackRate);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MangoPalette.grey100,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
      ),
      child: Row(
        children: [
          IconButton(
        tooltip: 'Pause',
            icon: Icon(
              _playerState == PlayerState.playing
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.blue[700],
              size: 24,
            ),
            onPressed: _togglePlayback,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0,
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(fontSize: 12, color: MangoPalette.grey500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<double>(
            icon: Icon(Icons.speed, color: Colors.blue[700]),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1.0,
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 20),
                    SizedBox(width: 8),
                    Text('1.0x'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1.5,
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 20),
                    SizedBox(width: 8),
                    Text('1.5x'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2.0,
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 20),
                    SizedBox(width: 8),
                    Text('2.0x'),
                  ],
                ),
              ),
            ],
            onSelected: (rate) {
              setState(() => _playbackRate = rate);
              _audioService.setPlaybackRate(rate);
            },
          ),
        ],
      ),
    );
  }
}