// Mango video player: films, series episodes and vines.
//
// Resumes where you stopped (on any device), double-tap to seek with a
// ripple, speed, mute, fullscreen, keyboard shortcuts on web and desktop,
// controls that hide themselves (and stay visible for screen readers and
// while paused), and an "Up next" countdown with recommendations at the end.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/core/play_source.dart';
import 'package:mango/Media/lists/content_list_sheet.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';
import 'package:video_player/video_player.dart';

class MangoVideoPlayerScreen extends StatefulWidget {
  const MangoVideoPlayerScreen({super.key, required this.type, required this.id, this.source});

  /// 'movie' or 'vine'.
  final String type;
  final String id;
  final PlaySource? source;

  @override
  State<MangoVideoPlayerScreen> createState() => _MangoVideoPlayerScreenState();
}

class _MangoVideoPlayerScreenState extends State<MangoVideoPlayerScreen> {
  VideoPlayerController? _video;
  Map<String, dynamic> _doc = const {};
  String? _error;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _ended = false;
  double _speed = 1.0;
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _countdown;
  int _countdownLeft = 0;
  List<Map<String, dynamic>> _next = const [];
  Offset? _ripple;
  String _rippleText = '';
  final FocusNode _focus = FocusNode();
  bool _recordedStart = false;

  String get _collection => widget.type == 'vine' ? 'vines' : 'movies';
  String get _title => '${_doc['title'] ?? _doc['caption'] ?? 'Video'}';
  String get _progressKey => '${widget.type}_${widget.id}';

  @override
  void initState() {
    super.initState();
    // Music and video never play at once.
    final music = Get.isRegistered<GlobalMusicController>() ? Get.find<GlobalMusicController>() : null;
    if (music != null && music.isPlaying.value) unawaited(music.togglePlayPause());
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(_collection).doc(widget.id).get();
      if (!snap.exists) throw Exception('This video is no longer available.');
      _doc = snap.data()!;
      final url = '${_doc['videoUrl'] ?? ''}';
      if (url.isEmpty) throw Exception('This video has no playable file.');
      final video = VideoPlayerController.networkUrl(Uri.parse(url));
      await video.initialize();
      final resume = await _resumePoint(video.value.duration);
      if (resume != null) await video.seekTo(resume);
      video.addListener(_onTick);
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
      await _play();
      _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
      unawaited(_loadNext());
      if (resume != null && mounted) {
        MangoToast.show(context, message: 'Resumed from ${_fmt(resume)}', actionLabel: 'Start over', onAction: () => _video?.seekTo(Duration.zero));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onTick() {
    final v = _video?.value;
    if (v == null || !mounted) return;
    final finished = v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 400) && !v.isPlaying;
    if (finished && !_ended) _onEnded();
    setState(() {});
  }

  Future<void> _play() async {
    final v = _video;
    if (v == null) return;
    _ended = false;
    _countdown?.cancel();
    await v.play();
    if (widget.type == 'movie') MangoActivityTracker.startInBackground(contentType: 'movie', contentId: widget.id);
    if (!_recordedStart) {
      _recordedStart = true;
      _record('start');
      unawaited(FirebaseFirestore.instance.collection(_collection).doc(widget.id).update({'views': FieldValue.increment(1)}).catchError((_) {}));
    }
    _scheduleHide();
  }

  Future<void> _pause() async {
    await _video?.pause();
    MangoActivityTracker.stopInBackground();
    unawaited(_saveProgress());
    _showControls(keep: true);
  }

  Future<void> _togglePlay() async => (_video?.value.isPlaying ?? false) ? _pause() : _play();

  void _onEnded() {
    _ended = true;
    MangoActivityTracker.stopInBackground();
    _record('complete');
    unawaited(_saveProgress(completed: true));
    _showControls(keep: true);
    if (_next.isNotEmpty && !MangoMotion.reduced(context)) {
      _countdownLeft = 8;
      _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _countdownLeft -= 1);
        if (_countdownLeft <= 0) {
          t.cancel();
          _openNext(_next.first);
        }
      });
    }
  }

  Future<void> _seekBy(int seconds, {Offset? at}) async {
    final v = _video;
    if (v == null) return;
    var target = v.value.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.value.duration) target = v.value.duration;
    await v.seekTo(target);
    if (at != null) {
      setState(() {
        _ripple = at;
        _rippleText = seconds > 0 ? '+${seconds}s' : '${seconds}s';
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _ripple = null);
      });
    }
    MangoAnnounce.polite(context, '${seconds > 0 ? 'Forward' : 'Back'} ${seconds.abs()} seconds');
  }

  void _showControls({bool keep = false}) {
    setState(() => _controlsVisible = true);
    if (!keep) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // Screen-reader users keep the controls on screen.
    if (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_video?.value.isPlaying ?? false)) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await _exitFullscreen();
    }
    if (mounted) setState(() {});
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  // ----------------------------------------------------- data and taste
  Future<Duration?> _resumePoint(Duration duration) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final d = (await FirebaseFirestore.instance.collection('media_progress').doc(uid).collection('items').doc(_progressKey).get()).data();
      if (d == null || d['completed'] == true) return null;
      final pos = Duration(milliseconds: (d['positionMs'] ?? 0) as int);
      if (pos < const Duration(seconds: 30) || (duration > Duration.zero && pos > duration * 0.95)) return null;
      return pos - const Duration(seconds: 3);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProgress({bool completed = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final v = _video?.value;
    if (uid == null || v == null || !v.isInitialized) return;
    try {
      await FirebaseFirestore.instance.collection('media_progress').doc(uid).collection('items').doc(_progressKey).set({
        'type': widget.type,
        'id': widget.id,
        'title': _title.length > 120 ? _title.substring(0, 120) : _title,
        if ('${_doc['posterUrl'] ?? _doc['thumbnailUrl'] ?? ''}'.isNotEmpty) 'imageUrl': '${_doc['posterUrl'] ?? _doc['thumbnailUrl']}',
        'positionMs': v.position.inMilliseconds,
        'durationMs': v.duration.inMilliseconds,
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _record(String event) {
    if (widget.type != 'movie' || FirebaseAuth.instance.currentUser == null) return;
    final v = _video?.value;
    unawaited(MangoLedgerClient.instance.call('mediaRecord', {
      'type': 'movie',
      'id': widget.id,
      'event': event,
      'positionSec': v?.position.inSeconds ?? 0,
      'durationSec': v?.duration.inSeconds ?? 0,
    }).catchError((_) => <String, dynamic>{}));
  }

  Future<void> _loadNext() async {
    if (widget.type != 'movie') return;
    try {
      final res = await MangoLedgerClient.instance.call('mediaRecommend', {'type': 'movie', 'seedId': widget.id, 'limit': 6});
      final items = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _next = items);
    } catch (_) {}
  }

  void _openNext(Map<String, dynamic> item) {
    Get.off(() => MangoVideoPlayerScreen(type: 'movie', id: '${item['id']}', source: widget.source ?? const PlaySource(kind: 'recommendation', label: 'Recommended')), preventDuplicates: false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _countdown?.cancel();
    final v = _video?.value;
    if (!_ended && v != null && v.duration > Duration.zero && v.position.inMilliseconds / v.duration.inMilliseconds < 0.7) _record('skip');
    unawaited(_saveProgress());
    MangoActivityTracker.stopInBackground();
    _video?.removeListener(_onTick);
    _video?.dispose();
    _focus.dispose();
    if (_fullscreen) unawaited(_exitFullscreen());
    super.dispose();
  }

  // ----------------------------------------------------------------- UI
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyK) {
      _togglePlay();
    } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyL) {
      _seekBy(10);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyJ) {
      _seekBy(-10);
    } else if (k == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (k == LogicalKeyboardKey.keyM) {
      final v = _video;
      if (v != null) v.setVolume(v.value.volume > 0 ? 0 : 1);
    } else if (k == LogicalKeyboardKey.escape && _fullscreen) {
      _toggleFullscreen();
    } else {
      return KeyEventResult.ignored;
    }
    _showControls();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (v != null)
                  MangoIconButton(
                    icon: Icons.playlist_add_rounded,
                    semanticLabel: 'Add to a list',
                    onPressed: () => showAddToListSheet(context, type: widget.type, id: widget.id, title: _title, imageUrl: '${_doc['posterUrl'] ?? _doc['thumbnailUrl'] ?? ''}'),
                  ),
              ],
            ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: _error != null
            ? MangoStateView(kind: MangoStateKind.error, title: "Can't play this video", message: _error!, actionLabel: 'Try again', onAction: () {
                setState(() => _error = null);
                _load();
              })
            : v == null
                ? const MangoLoadingRegion(label: 'Loading video', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')))
                : Focus(
                    focusNode: _focus,
                    autofocus: true,
                    onKeyEvent: _onKey,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
                        child: _stage(context, v),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _stage(BuildContext context, VideoPlayerController v) {
    final value = v.value;
    return LayoutBuilder(builder: (context, box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _controlsVisible ? setState(() => _controlsVisible = false) : _showControls(),
        onDoubleTapDown: (d) => _ripple = d.localPosition,
        onDoubleTap: () {
          final at = _ripple ?? Offset(box.maxWidth / 2, 0);
          _seekBy(at.dx < box.maxWidth / 2 ? -10 : 10, at: at);
        },
        child: Stack(fit: StackFit.expand, children: [
          Semantics(label: 'Video: $_title', child: VideoPlayer(v)),
          if (value.isBuffering)
            const Center(child: CircularProgressIndicator(semanticsLabel: 'Buffering')),
          if (_ripple != null)
            Positioned(
              left: _ripple!.dx - 48,
              top: _ripple!.dy - 48,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1.2),
                  duration: MangoMotion.duration(context, MangoMotionTokens.moderate),
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                    child: Text(_rippleText, style: context.type.titleMedium?.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: MangoMotion.duration(context, MangoMotionTokens.base),
            child: IgnorePointer(ignoring: !_controlsVisible, child: _controls(context, v)),
          ),
          if (_ended) _endCard(context),
        ]),
      );
    });
  }

  Widget _controls(BuildContext context, VideoPlayerController v) {
    final value = v.value;
    final total = value.duration.inMilliseconds.toDouble();
    final pos = value.position.inMilliseconds.clamp(0, value.duration.inMilliseconds).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
      ),
      child: Column(children: [
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RoundButton(icon: Icons.replay_10_rounded, label: 'Back 10 seconds', onTap: () => _seekBy(-10)),
          const SizedBox(width: MangoSpace.s6),
          _RoundButton(icon: value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, label: value.isPlaying ? 'Pause' : 'Play', onTap: _togglePlay, big: true),
          const SizedBox(width: MangoSpace.s6),
          _RoundButton(icon: Icons.forward_10_rounded, label: 'Forward 10 seconds', onTap: () => _seekBy(10)),
        ]),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s3),
          child: Row(children: [
            Text(_fmt(value.position), style: context.type.labelMedium?.copyWith(color: Colors.white)),
            Expanded(
              child: Semantics(
                label: 'Playback position',
                value: '${_fmt(value.position)} of ${_fmt(value.duration)}',
                child: Slider(
                  value: total <= 0 ? 0 : pos,
                  max: total <= 0 ? 1 : total,
                  onChanged: total <= 0 ? null : (x) => v.seekTo(Duration(milliseconds: x.round())),
                  onChangeStart: (_) => _hideTimer?.cancel(),
                  onChangeEnd: (_) => _scheduleHide(),
                ),
              ),
            ),
            Text(_fmt(value.duration), style: context.type.labelMedium?.copyWith(color: Colors.white)),
            PopupMenuButton<double>(
              tooltip: 'Playback speed, ${_speed}x',
              iconColor: Colors.white,
              initialValue: _speed,
              onSelected: (s) {
                setState(() => _speed = s);
                v.setPlaybackSpeed(s);
              },
              itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => PopupMenuItem(value: s, child: Text('${s}x'))).toList(),
              child: Padding(padding: const EdgeInsets.all(MangoSpace.s3), child: Text('${_speed}x', style: context.type.labelLarge?.copyWith(color: Colors.white))),
            ),
            IconButton(
              tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
              color: Colors.white,
              icon: Icon(value.volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded),
              onPressed: () => v.setVolume(value.volume > 0 ? 0 : 1),
            ),
            IconButton(
              tooltip: _fullscreen ? 'Exit full screen' : 'Full screen',
              color: Colors.white,
              icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
              onPressed: _toggleFullscreen,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _endCard(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MangoSpace.s4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(liveRegion: true, child: Text(_next.isEmpty ? 'Finished' : (_countdownLeft > 0 ? 'Up next in $_countdownLeft' : 'Up next'), style: context.type.titleLarge?.copyWith(color: Colors.white))),
            const SizedBox(height: MangoSpace.s3),
            if (_next.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.separated(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  itemCount: _next.length,
                  separatorBuilder: (_, __) => const SizedBox(width: MangoSpace.s3),
                  itemBuilder: (_, i) {
                    final n = _next[i];
                    return MangoPressable(
                      semanticLabel: 'Play ${n['title']}',
                      onTap: () {
                        _countdown?.cancel();
                        _openNext(n);
                      },
                      child: SizedBox(
                        width: 150,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(MangoRadius.sm),
                            child: SizedBox(
                              width: 150,
                              height: 100,
                              child: (n['imageUrl'] ?? '') == ''
                                  ? const ColoredBox(color: Colors.white12, child: Icon(Icons.movie_rounded, color: Colors.white))
                                  : CachedNetworkImage(imageUrl: '${n['imageUrl']}', fit: BoxFit.cover, memCacheWidth: 450),
                            ),
                          ),
                          const SizedBox(height: MangoSpace.s1),
                          Text('${n['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.labelLarge?.copyWith(color: Colors.white)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: MangoSpace.s3),
            Wrap(spacing: MangoSpace.s3, children: [
              MangoButton(label: 'Replay', icon: Icons.replay_rounded, size: MangoButtonSize.medium, variant: MangoButtonVariant.secondary, onPressed: () async {
                await _video?.seekTo(Duration.zero);
                await _play();
              }),
              if (_countdownLeft > 0)
                MangoButton(label: 'Cancel', size: MangoButtonSize.medium, variant: MangoButtonVariant.text, onPressed: () {
                  _countdown?.cancel();
                  setState(() => _countdownLeft = 0);
                }),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.big = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 72.0 : 56.0;
    return MangoPressable(
      onTap: onTap,
      semanticLabel: label,
      focusRadius: size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: big ? 40 : 30),
      ),
    );
  }
}
