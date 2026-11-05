// Voice notes, the way people expect them to work:
//   hold the mic to record (live waveform and timer)
//   slide left to cancel, slide up to lock and keep recording hands-free
//   when locked: stop to preview, then send or delete
// Works on Android, iOS and web (the `record` package).
import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceClip {
  VoiceClip({required this.bytes, required this.duration, required this.waveform, required this.mime, this.source});

  final Uint8List bytes;
  final Duration duration;

  /// 0..1 levels, about 10 per second, for drawing the waveform.
  final List<double> waveform;
  final String mime;

  /// Local path (device) or blob URL (web) for previewing.
  final String? source;
}

/// A mic button for composer bars. Calls [onRecorded] with a finished clip.
class MangoVoiceRecorderButton extends StatefulWidget {
  const MangoVoiceRecorderButton({super.key, required this.onRecorded, this.minDuration = const Duration(milliseconds: 800)});

  final Future<void> Function(VoiceClip clip) onRecorded;
  final Duration minDuration;

  @override
  State<MangoVoiceRecorderButton> createState() => _MangoVoiceRecorderButtonState();
}

class _MangoVoiceRecorderButtonState extends State<MangoVoiceRecorderButton> {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Amplitude>? _amp;
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  final List<double> _levels = [];
  bool _recording = false;
  bool _locked = false;
  bool _cancelArmed = false;
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _amp?.cancel();
    _ticker?.cancel();
    _overlay?.remove();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (mounted) MangoToast.show(context, message: 'Allow microphone access to record voice notes.', kind: MangoToastKind.error);
      return;
    }
    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    // Browsers record Opus; phones record AAC.
    await _rec.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), path: path);
    HapticFeedback.mediumImpact();
    _levels.clear();
    _startedAt = DateTime.now();
    _amp = _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
      // dBFS (-60..0) to 0..1.
      final v = ((a.current + 60) / 60).clamp(0.0, 1.0).toDouble();
      _levels.add(v);
      _overlay?.markNeedsBuild();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed = DateTime.now().difference(_startedAt!);
      _overlay?.markNeedsBuild();
    });
    setState(() {
      _recording = true;
      _locked = false;
      _cancelArmed = false;
    });
    _showOverlay();
    MangoAnnounce.polite(context, 'Recording. Slide left to cancel, up to lock.');
  }

  Future<VoiceClip?> _stop() async {
    _amp?.cancel();
    _ticker?.cancel();
    final source = await _rec.stop();
    final elapsed = _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);
    setState(() => _recording = false);
    if (source == null || elapsed < widget.minDuration) return null;
    final bytes = await XFile(source).readAsBytes();
    return VoiceClip(bytes: bytes, duration: elapsed, waveform: List.of(_levels), mime: kIsWeb ? 'audio/webm' : 'audio/mp4', source: source);
  }

  Future<void> _cancel() async {
    _amp?.cancel();
    _ticker?.cancel();
    await _rec.cancel();
    _hideOverlay();
    setState(() => _recording = false);
    HapticFeedback.lightImpact();
    if (mounted) MangoAnnounce.polite(context, 'Recording cancelled');
  }

  Future<void> _finish({bool preview = false}) async {
    final clip = await _stop();
    _hideOverlay();
    if (clip == null) {
      if (mounted) MangoToast.show(context, message: 'Hold the mic a little longer to record.');
      return;
    }
    if (!mounted) return;
    if (preview) {
      final send = await showModalBottomSheet<bool>(context: context, builder: (_) => _VoicePreview(clip: clip));
      if (send != true) return;
    }
    await widget.onRecorded(clip);
  }

  void _showOverlay() {
    _overlay = OverlayEntry(builder: (_) => _RecordingBar(
          elapsed: _elapsed,
          levels: _levels,
          locked: _locked,
          cancelArmed: _cancelArmed,
          onCancel: _cancel,
          onSend: () => _finish(),
          onPreview: () => _finish(preview: true),
        ));
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _recording ? 'Recording voice note' : 'Hold to record a voice note',
      // Screen readers: double-tap starts, the bar's buttons stop or send.
      onTap: _recording ? null : () async {
        await _start();
        setState(() => _locked = true);
        _overlay?.markNeedsBuild();
      },
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressMoveUpdate: (d) {
          if (!_recording || _locked) return;
          if (d.offsetFromOrigin.dx < -90) {
            _cancel();
          } else if (d.offsetFromOrigin.dy < -70) {
            setState(() => _locked = true);
            HapticFeedback.selectionClick();
          } else {
            _cancelArmed = d.offsetFromOrigin.dx < -40;
          }
          _overlay?.markNeedsBuild();
        },
        onLongPressEnd: (_) {
          if (_recording && !_locked) _finish();
        },
        child: AnimatedScale(
          scale: _recording ? 1.25 : 1,
          duration: MangoMotion.duration(context, MangoMotionTokens.fast),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? context.colors.error : Colors.transparent),
            child: Icon(Icons.mic_rounded, color: _recording ? Colors.white : context.colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.elapsed, required this.levels, required this.locked, required this.cancelArmed, required this.onCancel, required this.onSend, required this.onPreview});

  final Duration elapsed;
  final List<double> levels;
  final bool locked;
  final bool cancelArmed;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mm = elapsed.inMinutes.toString().padLeft(1, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
      child: Material(
        color: c.surfaceRaised,
        elevation: 6,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4, vertical: MangoSpace.s3),
            child: Row(children: [
              Icon(Icons.fiber_manual_record_rounded, color: c.error, size: 14),
              const SizedBox(width: MangoSpace.s2),
              Semantics(liveRegion: true, child: Text('$mm:$ss', style: context.type.titleSmall)),
              const SizedBox(width: MangoSpace.s3),
              Expanded(child: SizedBox(height: 32, child: CustomPaint(painter: WaveformPainter(levels.length > 60 ? levels.sublist(levels.length - 60) : levels, c.actionPrimary)))),
              const SizedBox(width: MangoSpace.s3),
              if (locked) ...[
                MangoIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Delete recording', onPressed: onCancel),
                MangoIconButton(icon: Icons.play_circle_outline_rounded, semanticLabel: 'Stop and preview', onPressed: onPreview),
                MangoIconButton(icon: Icons.send_rounded, semanticLabel: 'Send voice note', onPressed: onSend),
              ] else
                Text(cancelArmed ? 'Release to cancel' : '‹ Slide to cancel · ↑ lock', style: context.type.bodySmall?.copyWith(color: cancelArmed ? c.error : c.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter(this.levels, this.color, {this.progress});

  final List<double> levels;
  final Color color;

  /// 0..1 playback progress; bars before it are drawn solid.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final bars = levels.length;
    final w = size.width / bars;
    for (var i = 0; i < bars; i++) {
      final h = (levels[i] * size.height).clamp(2.0, size.height).toDouble();
      final played = progress == null || i / bars <= progress!;
      final paint = Paint()
        ..color = played ? color : color.withValues(alpha: 0.35)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (w * 0.6).clamp(1.5, 4.0).toDouble();
      final x = i * w + w / 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) => old.levels.length != levels.length || old.progress != progress || old.color != color;
}

class _VoicePreview extends StatefulWidget {
  const _VoicePreview({required this.clip});

  final VoiceClip clip;

  @override
  State<_VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends State<_VoicePreview> {
  final AudioPlayer _p = AudioPlayer();
  double _progress = 0;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _p.onPositionChanged.listen((pos) {
      final total = widget.clip.duration.inMilliseconds;
      if (mounted && total > 0) setState(() => _progress = (pos.inMilliseconds / total).clamp(0.0, 1.0).toDouble());
    });
    _p.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _p.pause();
    } else {
      final src = widget.clip.source;
      if (src == null) return;
      await _p.play(kIsWeb ? UrlSource(src) : DeviceFileSource(src));
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MangoSpace.s4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Voice note · ${widget.clip.duration.inSeconds}s', style: context.type.titleMedium),
          const SizedBox(height: MangoSpace.s3),
          Row(children: [
            MangoIconButton(icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded, semanticLabel: _playing ? 'Pause' : 'Play', onPressed: _toggle),
            Expanded(child: SizedBox(height: 40, child: CustomPaint(painter: WaveformPainter(widget.clip.waveform, context.colors.actionPrimary, progress: _progress)))),
          ]),
          const SizedBox(height: MangoSpace.s4),
          Row(children: [
            Expanded(child: MangoButton(label: 'Delete', variant: MangoButtonVariant.tertiary, onPressed: () => Navigator.pop(context, false))),
            const SizedBox(width: MangoSpace.s3),
            Expanded(child: MangoButton(label: 'Send', icon: Icons.send_rounded, onPressed: () => Navigator.pop(context, true))),
          ]),
        ]),
      ),
    );
  }
}
