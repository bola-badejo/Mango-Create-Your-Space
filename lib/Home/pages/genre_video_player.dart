import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mango/Core/theme/mango_palette.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

class GenreVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isPlaying;
  final bool shouldLoad;

  const GenreVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isPlaying,
    required this.shouldLoad,
  }) : super(key: key);

  @override
  _GenreVideoPlayerState createState() => _GenreVideoPlayerState();
}

class _GenreVideoPlayerState extends State<GenreVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.shouldLoad) {
      _initializeVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pauseVideo();
        break;
      case AppLifecycleState.resumed:
        if (widget.isPlaying && _isInitialized) {
          _playVideo();
        }
        break;
      case AppLifecycleState.detached:
        _disposeVideo();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<String> _getDownloadUrl(String videoUrl) async {
    try {
      if (videoUrl.startsWith('http')) return videoUrl;
      
      if (videoUrl.startsWith('gs://')) {
        final path = videoUrl.replaceFirst('gs://mango-cloud-34e08.appspot.com/', '');
        final ref = FirebaseStorage.instance.ref().child(path);
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      }
      return '';
    } catch (e) {
      print('❌ Error getting download URL: $e');
      return '';
    }
  }

  void _initializeVideo() async {
    if (!widget.shouldLoad || _isDisposing) return;

    try {
      final effectiveVideoUrl = await _getDownloadUrl(widget.videoUrl);
      if (effectiveVideoUrl.isEmpty) {
        setState(() => _hasError = true);
        return;
      }

      _controller = VideoPlayerController.network(
        effectiveVideoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize().then((_) {
        if (mounted && !_isDisposing) {
          setState(() {
            _isInitialized = true;
            _hasError = false;
          });
          
          _controller!.setLooping(true);
          _controller!.setVolume(_isMuted ? 0.0 : 1.0);
          
          if (widget.isPlaying) {
            _playVideo();
          }
        }
      }).catchError((e) {
        print('Video init error: $e');
        if (mounted && !_isDisposing) setState(() => _hasError = true);
      });

    } catch (e) {
      print('Video creation error: $e');
      if (mounted && !_isDisposing) setState(() => _hasError = true);
    }
  }

  void _playVideo() async {
    if (_isInitialized && _controller != null && !_isDisposing) {
      try {
        await _controller!.play();
      } catch (e) {
        print('Play error: $e');
      }
    }
  }

  void _pauseVideo() async {
    if (_isInitialized && _controller != null && !_isDisposing) {
      try {
        await _controller!.pause();
      } catch (e) {
        print('Pause error: $e');
      }
    }
  }

  void _toggleMute() {
    if (_isInitialized && _controller != null && !_isDisposing) {
      setState(() => _isMuted = !_isMuted);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  void _updatePlayback() {
    if (_isInitialized && _controller != null && !_isDisposing) {
      if (widget.isPlaying && !_controller!.value.isPlaying) {
        _playVideo();
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        _pauseVideo();
      }
    }
  }

  void _disposeVideo() async {
    _isDisposing = true;
    
    if (_controller != null) {
      try {
        await _controller!.pause();
        await Future.delayed(const Duration(milliseconds: 100));
        _controller!.dispose();
        _controller = null;
      } catch (e) {
        print('Dispose error: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
    _isDisposing = false;
  }

  @override
  void didUpdateWidget(GenreVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    
    if (!oldWidget.shouldLoad && widget.shouldLoad && !_isInitialized && !_hasError) {
      _initializeVideo();
    }
    
    else if (oldWidget.shouldLoad && !widget.shouldLoad && _isInitialized) {
      _disposeVideo();
    }
    
    else if (widget.videoUrl != oldWidget.videoUrl && widget.shouldLoad) {
      _disposeVideo();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initializeVideo();
      });
    }
    
    else if (widget.isPlaying != oldWidget.isPlaying) {
      _updatePlayback();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    if (!widget.shouldLoad) {
      return _buildThumbnailUI();
    }

    return Stack(
      children: [
        
        if (_hasError)
          _buildThumbnailUI()
        else if (!_isInitialized || _controller == null)
          _buildLoadingWithThumbnail()
        else
          Container(
            width: double.infinity,
            height: double.infinity,
            child: VideoPlayer(_controller!),
          ),
        
        
        if (_isInitialized && !_hasError && widget.isPlaying)
          Positioned(
            top: 12,
            right: 12,
            child: MangoPressable(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MangoPalette.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingWithThumbnail() {
    return Stack(
      children: [
        _buildThumbnailUI(),
        Container(
          color: MangoPalette.black.withOpacity(0.3),
          child: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading', 
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailUI() {
    
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildPlaceholderUI(),
        errorWidget: (context, url, error) => _buildPlaceholderUI(),
      );
    }
    
    
    return _buildPlaceholderUI();
  }

  Widget _buildPlaceholderUI() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MangoPalette.grey800, MangoPalette.grey900],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_video,
          size: 40,
          color: MangoPalette.grey400,
        ),
      ),
    );
  }
}