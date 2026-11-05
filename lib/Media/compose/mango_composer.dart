// Mango composer: pick, preview and edit before anything is shared.
//
//   Photos   10 filters; brightness, contrast, saturation and warmth;
//            crop to a shape; rotate and flip; a caption you can move.
//            What you see is exactly what's saved (rendered by Flutter).
//   Videos   preview with sound, caption, and size check
//   Files    name, type and size before sending
//
// Used by chat (snaps and media), posts, profile photos and the creator studio.
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:video_player/video_player.dart';

import 'mango_uploader.dart';

enum ComposeKind { image, video, audio, document, file }

class ComposedMedia {
  ComposedMedia({required this.bytes, required this.mime, required this.name, this.caption, this.width, this.height, this.duration, this.path});

  final Uint8List bytes;
  final String mime;
  final String name;
  final String? caption;
  final int? width;
  final int? height;
  final Duration? duration;

  /// Local file path when picked on a device (null on web).
  final String? path;

  MediaKind get kind => MangoUploader.kindOf(mime);
  int get size => bytes.length;
}

/// Crop shapes offered in the editor.
enum CropShape { original, square, portrait, landscape, story }

extension on CropShape {
  String get label => switch (this) {
        CropShape.original => 'Original',
        CropShape.square => '1:1',
        CropShape.portrait => '4:5',
        CropShape.landscape => '16:9',
        CropShape.story => '9:16',
      };
  double? get ratio => switch (this) {
        CropShape.original => null,
        CropShape.square => 1,
        CropShape.portrait => 4 / 5,
        CropShape.landscape => 16 / 9,
        CropShape.story => 9 / 16,
      };
}

class MangoComposer {
  /// Picks media and lets the person preview and edit it.
  /// Returns null if they cancel at any point.
  static Future<ComposedMedia?> pick(
    BuildContext context, {
    Set<ComposeKind> allow = const {ComposeKind.image},
    String actionLabel = 'Done',
    CropShape? crop,
    bool allowCaption = true,
    bool edit = true,

    /// 'camera' or 'gallery' to skip the source sheet (when a screen asked already).
    String? source,
  }) async {
    final choice = source ?? await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (allow.contains(ComposeKind.image))
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheet, 'camera')),
          if (allow.contains(ComposeKind.video))
            ListTile(leading: const Icon(Icons.videocam_rounded), title: const Text('Record a video'), onTap: () => Navigator.pop(sheet, 'camera_video')),
          if (allow.contains(ComposeKind.image) || allow.contains(ComposeKind.video))
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheet, 'gallery')),
          if (allow.any((k) => k == ComposeKind.audio || k == ComposeKind.document || k == ComposeKind.file))
            ListTile(leading: const Icon(Icons.folder_open_rounded), title: const Text('Choose a file'), onTap: () => Navigator.pop(sheet, 'files')),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return null;

    final picker = ImagePicker();
    XFile? x;
    try {
      switch (choice) {
        case 'camera':
          x = await picker.pickImage(source: ImageSource.camera, maxWidth: 4096);
        case 'camera_video':
          x = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 10));
        case 'gallery':
          x = allow.contains(ComposeKind.video) && allow.contains(ComposeKind.image)
              ? await picker.pickMedia()
              : allow.contains(ComposeKind.video)
                  ? await picker.pickVideo(source: ImageSource.gallery)
                  : await picker.pickImage(source: ImageSource.gallery, maxWidth: 4096);
        case 'files':
          final res = await FilePicker.platform.pickFiles(
            withData: true,
            type: FileType.custom,
            allowedExtensions: [
              if (allow.contains(ComposeKind.audio)) ...['mp3', 'm4a', 'aac', 'wav', 'ogg'],
              if (allow.contains(ComposeKind.document)) ...['pdf', 'epub', 'txt'],
              if (allow.contains(ComposeKind.file)) ...['pdf', 'zip', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'],
            ],
          );
          final f = res?.files.single;
          if (f == null || f.bytes == null) return null;
          final media = ComposedMedia(bytes: f.bytes!, mime: MangoUploader.mimeFor(f.name), name: f.name);
          if (!context.mounted) return null;
          return Navigator.of(context).push<ComposedMedia>(MaterialPageRoute(builder: (_) => _FilePreview(media: media, actionLabel: actionLabel)));
      }
    } catch (e) {
      if (context.mounted) {
        MangoToast.show(context, message: "Mango can't open your camera or photos. Allow access in Settings, then try again.", kind: MangoToastKind.error);
      }
      return null;
    }
    if (x == null || !context.mounted) return null;
    final bytes = await x.readAsBytes();
    final mime = x.mimeType ?? MangoUploader.mimeFor(x.name);
    final media = ComposedMedia(bytes: bytes, mime: mime, name: x.name, path: kIsWeb ? null : x.path);
    if (!context.mounted) return null;
    if (media.kind == MediaKind.video) {
      return Navigator.of(context).push<ComposedMedia>(MaterialPageRoute(builder: (_) => _VideoPreview(media: media, actionLabel: actionLabel, allowCaption: allowCaption)));
    }
    if (!edit) return media;
    return Navigator.of(context).push<ComposedMedia>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MangoImageEditor(media: media, actionLabel: actionLabel, initialCrop: crop, allowCaption: allowCaption),
    ));
  }
}

// ---------------------------------------------------------------- filters
class _Filter {
  const _Filter(this.name, this.matrix);
  final String name;
  final List<double> matrix;
}

const List<double> _identity = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

List<double> _saturationM(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return [
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrastM(double c) {
  final o = 128 * (1 - c);
  return [c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
}

List<double> _brightnessM(double b) {
  final o = b * 255;
  return [1, 0, 0, 0, o, 0, 1, 0, 0, o, 0, 0, 1, 0, o, 0, 0, 0, 1, 0];
}

List<double> _warmthM(double w) => [1 + w * 0.12, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 - w * 0.12, 0, 0, 0, 0, 0, 1, 0];

/// Multiplies two 4x5 colour matrices (a after b).
List<double> _mul(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = col == 4 ? a[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      out[row * 5 + col] = v;
    }
  }
  return out;
}

final List<_Filter> _filters = [
  const _Filter('Original', _identity),
  _Filter('Vivid', _mul(_saturationM(1.35), _contrastM(1.08))),
  _Filter('Mango', _mul(_warmthM(0.8), _saturationM(1.2))),
  _Filter('Warm', _warmthM(1)),
  _Filter('Cool', _warmthM(-1)),
  _Filter('Fade', _mul(_contrastM(0.85), _brightnessM(0.05))),
  _Filter('Mono', _saturationM(0)),
  _Filter('Noir', _mul(_contrastM(1.35), _saturationM(0))),
  const _Filter('Sepia', [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0]),
  _Filter('Lagos', _mul(_mul(_warmthM(0.5), _contrastM(1.15)), _saturationM(1.15))),
];

/// Full-screen photo editor.
class MangoImageEditor extends StatefulWidget {
  const MangoImageEditor({super.key, required this.media, this.actionLabel = 'Done', this.initialCrop, this.allowCaption = true});

  final ComposedMedia media;
  final String actionLabel;
  final CropShape? initialCrop;
  final bool allowCaption;

  @override
  State<MangoImageEditor> createState() => _MangoImageEditorState();
}

class _MangoImageEditorState extends State<MangoImageEditor> {
  final _boundary = GlobalKey();
  final _caption = TextEditingController();
  int _filter = 0;
  double _brightness = 0, _contrastV = 1, _saturationV = 1, _warmthV = 0;
  late CropShape _crop = widget.initialCrop ?? CropShape.original;
  int _turns = 0;
  bool _flip = false;
  double _captionY = 0.7;
  int _tab = 0;
  bool _saving = false;
  double? _naturalRatio;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.media.bytes, (image) {
      if (mounted) setState(() => _naturalRatio = image.width / image.height);
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  List<double> get _matrix => _mul(
        _mul(_mul(_mul(_filters[_filter].matrix, _brightness == 0 ? _identity : _brightnessM(_brightness)), _contrastM(_contrastV)), _saturationM(_saturationV)),
        _warmthM(_warmthV),
      );

  double get _ratio {
    final base = _crop.ratio ?? _naturalRatio ?? 1;
    return _turns.isOdd && _crop == CropShape.original ? 1 / base : base;
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final w = boundary.size.width;
      // Export at up to 2048 px on the long side, whatever the screen size.
      final longSide = w >= boundary.size.height ? w : boundary.size.height;
      final ratio = (2048 / longSide).clamp(1.0, 6.0).toDouble();
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final png = data!.buffer.asUint8List();
      final (jpg, pw, ph) = await MangoUploader.prepareImage(png, quality: 88);
      if (!mounted) return;
      Navigator.pop(
        context,
        ComposedMedia(
          bytes: jpg,
          mime: 'image/jpeg',
          name: '${widget.media.name.split('.').first}.jpg',
          caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
          width: pw,
          height: ph,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        MangoToast.show(context, message: "Couldn't apply your edits. Try again.", kind: MangoToastKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: MangoIconButton(icon: Icons.close_rounded, semanticLabel: 'Discard', onPressed: () => Navigator.pop(context)),
          title: const Text('Edit'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: MangoSpace.s3),
              child: MangoButton(label: widget.actionLabel, size: MangoButtonSize.medium, onPressed: _saving ? null : _done),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(MangoSpace.s3),
                  child: RepaintBoundary(
                    key: _boundary,
                    child: AspectRatio(
                      aspectRatio: _ratio,
                      child: ClipRect(
                        child: Stack(fit: StackFit.expand, children: [
                          ColorFiltered(
                            colorFilter: ColorFilter.matrix(_matrix),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(_flip ? -1 : 1, 1, 1),
                              child: RotatedBox(
                                quarterTurns: _turns,
                                child: Image.memory(widget.media.bytes, fit: BoxFit.cover, gaplessPlayback: true),
                              ),
                            ),
                          ),
                          if (_caption.text.isNotEmpty) _captionBar(),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_saving) const LinearProgressIndicator(semanticsLabel: 'Saving'),
            _tools(context),
            _tabs(),
          ]),
        ),
      ),
    );
  }

  Widget _captionBar() {
    return LayoutBuilder(builder: (context, box) {
      return Positioned(
        left: 0,
        right: 0,
        top: (_captionY * box.maxHeight).clamp(0.0, box.maxHeight - 48).toDouble(),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => setState(() => _captionY = ((_captionY * box.maxHeight + d.delta.dy) / box.maxHeight).clamp(0.0, 0.95).toDouble()),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4, vertical: MangoSpace.s2),
            child: Text(_caption.text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    });
  }

  Widget _tabs() {
    final tabs = [
      (Icons.auto_awesome_rounded, 'Filters'),
      (Icons.tune_rounded, 'Adjust'),
      (Icons.crop_rounded, 'Crop'),
      if (widget.allowCaption) (Icons.text_fields_rounded, 'Text'),
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      for (var i = 0; i < tabs.length; i++)
        Semantics(
          selected: _tab == i,
          button: true,
          label: tabs[i].$2,
          child: InkWell(
            onTap: () => setState(() => _tab = i),
            child: Padding(
              padding: const EdgeInsets.all(MangoSpace.s3),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(tabs[i].$1, color: _tab == i ? context.colors.actionPrimary : Colors.white70),
                Text(tabs[i].$2, style: TextStyle(color: _tab == i ? Colors.white : Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _tools(BuildContext context) {
    switch (_tab) {
      case 0:
        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s3),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: MangoSpace.s2),
            itemBuilder: (_, i) => Semantics(
              selected: _filter == i,
              button: true,
              label: '${_filters[i].name} filter',
              child: GestureDetector(
                onTap: () => setState(() => _filter = i),
                child: Column(children: [
                  AnimatedContainer(
                    duration: MangoMotion.duration(context, MangoMotionTokens.fast),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MangoRadius.sm),
                      border: Border.all(color: _filter == i ? context.colors.actionPrimary : Colors.transparent, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ColorFiltered(colorFilter: ColorFilter.matrix(_filters[i].matrix), child: Image.memory(widget.media.bytes, fit: BoxFit.cover, cacheWidth: 160)),
                  ),
                  const SizedBox(height: 4),
                  Text(_filters[i].name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
        );
      case 1:
        Widget slider(String label, double value, double min, double max, ValueChanged<double> on) => Row(children: [
              SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Colors.white))),
              Expanded(child: Slider(value: value, min: min, max: max, label: label, onChanged: on)),
            ]);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
          child: Column(children: [
            slider('Brightness', _brightness, -0.3, 0.3, (v) => setState(() => _brightness = v)),
            slider('Contrast', _contrastV, 0.6, 1.5, (v) => setState(() => _contrastV = v)),
            slider('Saturation', _saturationV, 0, 2, (v) => setState(() => _saturationV = v)),
            slider('Warmth', _warmthV, -1, 1, (v) => setState(() => _warmthV = v)),
          ]),
        );
      case 2:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s3, vertical: MangoSpace.s2),
          child: Column(children: [
            Wrap(spacing: MangoSpace.s2, children: [
              for (final c in CropShape.values)
                ChoiceChip(label: Text(c.label), selected: _crop == c, onSelected: (_) => setState(() => _crop = c)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              MangoIconButton(icon: Icons.rotate_90_degrees_ccw_rounded, semanticLabel: 'Rotate', onPressed: () => setState(() => _turns = (_turns + 3) % 4)),
              MangoIconButton(icon: Icons.flip_rounded, semanticLabel: 'Flip', selected: _flip, onPressed: () => setState(() => _flip = !_flip)),
            ]),
          ]),
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4, vertical: MangoSpace.s2),
          child: TextField(
            controller: _caption,
            maxLength: 80,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Caption on the photo', helperText: 'Drag the caption to move it', helperStyle: TextStyle(color: Colors.white70)),
            onChanged: (_) => setState(() {}),
          ),
        );
    }
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.media, required this.actionLabel, required this.allowCaption});

  final ComposedMedia media;
  final String actionLabel;
  final bool allowCaption;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _v;
  final _caption = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Devices play the picked file; the web plays from memory.
      final path = widget.media.path;
      final v = (!kIsWeb && path != null)
          ? VideoPlayerController.file(File(path))
          : VideoPlayerController.networkUrl(Uri.dataFromBytes(widget.media.bytes, mimeType: widget.media.mime));
      await v.initialize();
      await v.setLooping(true);
      await v.play();
      if (mounted) setState(() => _v = v);
    } catch (_) {
      if (mounted) setState(() => _error = "Preview isn't available for this video, but you can still share it.");
    }
  }

  @override
  void dispose() {
    _v?.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mb = widget.media.size / (1024 * 1024);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: MangoSpace.s3),
            child: MangoButton(
              label: widget.actionLabel,
              size: MangoButtonSize.medium,
              onPressed: () => Navigator.pop(
                context,
                ComposedMedia(
                  bytes: widget.media.bytes,
                  mime: widget.media.mime,
                  name: widget.media.name,
                  caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
                  duration: _v?.value.duration,
                  path: widget.media.path,
                  width: _v?.value.size.width.round(),
                  height: _v?.value.size.height.round(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: _v == null
                  ? (_error != null ? Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center) : const CircularProgressIndicator(semanticsLabel: 'Loading'))
                  : GestureDetector(
                      onTap: () => setState(() => _v!.value.isPlaying ? _v!.pause() : _v!.play()),
                      child: AspectRatio(aspectRatio: _v!.value.aspectRatio, child: VideoPlayer(_v!)),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(MangoSpace.s4),
            child: Column(children: [
              Text('${mb.toStringAsFixed(1)} MB${_v != null ? ' · ${_v!.value.duration.inSeconds}s' : ''}', style: const TextStyle(color: Colors.white70)),
              if (widget.allowCaption)
                TextField(controller: _caption, maxLength: 200, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Caption')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.media, required this.actionLabel});

  final ComposedMedia media;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final mb = media.size / (1024 * 1024);
    final icon = switch (media.kind) {
      MediaKind.audio => Icons.audio_file_rounded,
      MediaKind.document => Icons.picture_as_pdf_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(MangoSpace.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 72, color: context.colors.textBrand),
            const SizedBox(height: MangoSpace.s3),
            Text(media.name, style: context.type.titleMedium, textAlign: TextAlign.center),
            Text('${mb.toStringAsFixed(2)} MB · ${media.mime}', style: context.type.bodySmall),
            const SizedBox(height: MangoSpace.s6),
            MangoButton(label: actionLabel, expand: true, onPressed: () => Navigator.pop(context, media)),
          ]),
        ),
      ),
    );
  }
}
