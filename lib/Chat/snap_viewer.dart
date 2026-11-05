// Full-screen viewer. For Snaps: opened through the server (once only),
// with a countdown bar; photos show for 10 seconds, videos for their length.
// Tap or swipe down to close. Also used for photos and videos sent in chat.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:video_player/video_player.dart';

import 'chat_service.dart';

class SnapViewer extends StatefulWidget {
  const SnapViewer({super.key, required this.chatId, required ChatMessage this.message})
      : url = null,
        isVideo = false;

  const SnapViewer.media({super.key, required String this.url, required this.isVideo})
      : chatId = null,
        message = null;

  final String? chatId;
  final ChatMessage? message;
  final String? url;
  final bool isVideo;

  @override
  State<SnapViewer> createState() => _SnapViewerState();
}

class _SnapViewerState extends State<SnapViewer> with SingleTickerProviderStateMixin {
  String? _url;
  bool _video = false;
  String? _error;
  VideoPlayerController? _v;
  late final AnimationController _timer = AnimationController(vsync: this);

  bool get _isSnap => widget.message != null;

  @override
  void initState() {
    super.initState();
    _timer.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) Navigator.pop(context);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      if (_isSnap) {
        final r = await ChatService.instance.openSnap(widget.chatId!, widget.message!.id);
        final media = Map<String, dynamic>.from(r['media'] as Map);
        _url = '${media['url']}';
        _video = '${media['mime'] ?? ''}'.startsWith('video/');
      } else {
        _url = widget.url;
        _video = widget.isVideo;
      }
      if (_video) {
        final v = VideoPlayerController.networkUrl(Uri.parse(_url!));
        await v.initialize();
        await v.play();
        _v = v;
        if (_isSnap) {
          _timer.duration = v.value.duration;
          _timer.forward();
        }
      } else if (_isSnap) {
        _timer.duration = const Duration(seconds: 10);
        _timer.forward();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: Stack(fit: StackFit.expand, children: [
          if (_error != null)
            Center(child: Padding(padding: const EdgeInsets.all(MangoSpace.s6), child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))
          else if (_url == null)
            const Center(child: CircularProgressIndicator(semanticsLabel: 'Opening'))
          else if (_video && _v != null)
            Center(child: AspectRatio(aspectRatio: _v!.value.aspectRatio, child: VideoPlayer(_v!)))
          else
            InteractiveViewer(child: Center(child: Semantics(label: _isSnap ? 'Snap' : 'Photo', child: CachedNetworkImage(imageUrl: _url!, fit: BoxFit.contain)))),
          if (_isSnap)
            Positioned(
              top: MediaQuery.paddingOf(context).top + MangoSpace.s2,
              left: MangoSpace.s3,
              right: MangoSpace.s3,
              child: AnimatedBuilder(
                animation: _timer,
                builder: (_, __) => LinearProgressIndicator(value: 1 - _timer.value, minHeight: 3, color: Colors.white, backgroundColor: Colors.white24, semanticsLabel: 'Time left'),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + MangoSpace.s4,
            right: MangoSpace.s2,
            child: MangoIconButton(icon: Icons.close_rounded, semanticLabel: 'Close', onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }
}
