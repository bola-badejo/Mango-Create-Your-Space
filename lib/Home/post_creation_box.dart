// Create a post or a reply. Photos (up to 10) and videos go through the
// Mango composer for preview, filters and crop before posting; tap a photo
// to edit it again, drag to reorder, or remove it. Progress and cancel are
// shown while uploading.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Home/compose/mango_post_service.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';

class PostCreationBox extends StatefulWidget {
  final String? replyTo;
  final String? repliedPostID;
  final VoidCallback? onPostCreated;
  final VoidCallback? onCancel;

  const PostCreationBox({
    super.key,
    this.replyTo,
    this.repliedPostID,
    this.onPostCreated,
    this.onCancel,
  });

  @override
  State<PostCreationBox> createState() => _PostCreationBoxState();
}

class _PostCreationBoxState extends State<PostCreationBox> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<ComposedMedia> _media = [];
  String? _link;
  double? _progress;
  UploadHandle? _handle;
  String? _error;

  bool get _hasVideo => _media.any((m) => m.kind == MediaKind.video);
  bool get _canPost => _progress == null && (_text.text.trim().isNotEmpty || _media.isNotEmpty || _link != null) && _text.text.length <= MangoPostService.maxChars;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _addMedia() async {
    if (_hasVideo) return _say('A post can have one video, or up to ${MangoPostService.maxImages} photos.');
    if (_media.length >= MangoPostService.maxImages) return _say('Up to ${MangoPostService.maxImages} photos per post.');
    final m = await MangoComposer.pick(
      context,
      allow: _media.isEmpty ? const {ComposeKind.image, ComposeKind.video} : const {ComposeKind.image},
      actionLabel: 'Add',
      allowCaption: false,
    );
    if (m == null) return;
    if (m.kind == MediaKind.video && _media.isNotEmpty) return _say('Remove the photos to add a video.');
    setState(() {
      _media.add(m);
      _error = null;
    });
  }

  Future<void> _edit(int i) async {
    final m = _media[i];
    if (m.kind != MediaKind.image) return;
    final edited = await Navigator.of(context).push<ComposedMedia>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MangoImageEditor(media: m, actionLabel: 'Done', allowCaption: false),
    ));
    if (edited != null) setState(() => _media[i] = edited);
  }

  Future<void> _addLink() async {
    final ctrl = TextEditingController(text: _link ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add a link'),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://')),
        actions: [
          if (_link != null) TextButton(onPressed: () => Navigator.pop(d, ''), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (url == null) return;
    if (url.isEmpty) return setState(() => _link = null);
    final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (u == null || u.host.isEmpty) return _say("That doesn't look like a link.");
    setState(() => _link = u.toString());
  }

  void _say(String msg) => MangoToast.show(context, message: msg, kind: MangoToastKind.error);

  Future<void> _post() async {
    if (!_canPost) return;
    final handle = UploadHandle();
    setState(() {
      _progress = 0;
      _handle = handle;
      _error = null;
    });
    try {
      await MangoPostService.instance.create(
        text: _text.text,
        media: List.of(_media),
        link: _link,
        linkType: _link == null ? null : 'web',
        replyTo: widget.replyTo,
        repliedPostID: widget.repliedPostID,
        handle: handle,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      _text.clear();
      setState(() {
        _media.clear();
        _link = null;
      });
      _focus.unfocus();
      MangoToast.show(context, message: widget.replyTo != null ? 'Reply posted' : 'Posted', kind: MangoToastKind.success);
      widget.onPostCreated?.call();
    } on PostException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on UploadTooLarge catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted && !handle.cancelled) setState(() => _error = "Couldn't post. Check your connection and try again.");
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _handle = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = FirebaseAuth.instance.currentUser;
    final count = _text.text.length;
    final left = MangoPostService.maxChars - count;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MangoSpace.s3, vertical: MangoSpace.s2),
      padding: const EdgeInsets.all(MangoSpace.s3),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        border: Border.all(color: _focus.hasFocus ? c.actionPrimary : c.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: c.surfaceSelected,
            backgroundImage: (user?.photoURL ?? '').isEmpty ? null : CachedNetworkImageProvider(user!.photoURL!),
            child: (user?.photoURL ?? '').isEmpty ? Icon(Icons.person_rounded, color: c.textBrand) : null,
          ),
          const SizedBox(width: MangoSpace.s3),
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              minLines: 1,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              style: context.type.bodyLarge,
              decoration: InputDecoration(
                hintText: widget.replyTo != null ? 'Post your reply' : "What's happening?",
                border: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: MangoSpace.s2),
              ),
            ),
          ),
        ]),
        if (_media.isNotEmpty) ...[
          const SizedBox(height: MangoSpace.s2),
          SizedBox(
            height: 112,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _media.length,
              onReorder: (o, n) => setState(() => _media.insert(n > o ? n - 1 : n, _media.removeAt(o))),
              itemBuilder: (context, i) {
                final m = _media[i];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(m),
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(right: MangoSpace.s2),
                    child: Stack(children: [
                      MangoPressable(
                        semanticLabel: m.kind == MediaKind.image ? 'Photo ${i + 1}. Edit' : 'Video',
                        onTap: () => _edit(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(MangoRadius.md),
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: m.kind == MediaKind.image
                                ? Image.memory(m.bytes, fit: BoxFit.cover, cacheWidth: 336)
                                : ColoredBox(color: Colors.black, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withValues(alpha: 0.9), size: 40)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Remove',
                            iconSize: 16,
                            color: Colors.white,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _media.removeAt(i)),
                          ),
                        ),
                      ),
                      if (m.kind == MediaKind.image)
                        const Positioned(left: 6, bottom: 6, child: Icon(Icons.tune_rounded, color: Colors.white, size: 18, shadows: [Shadow(blurRadius: 4)])),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        if (_link != null)
          Padding(
            padding: const EdgeInsets.only(top: MangoSpace.s2),
            child: InputChip(avatar: const Icon(Icons.link_rounded, size: 18), label: Text(Uri.parse(_link!).host), onDeleted: () => setState(() => _link = null), deleteButtonTooltipMessage: 'Remove link'),
          ),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: MangoSpace.s2), child: Semantics(liveRegion: true, child: Text(_error!, style: context.type.bodySmall?.copyWith(color: c.error)))),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.only(top: MangoSpace.s2),
            child: Row(children: [
              Expanded(child: LinearProgressIndicator(value: _progress, semanticsLabel: 'Posting')),
              TextButton(onPressed: () => _handle?.cancel(), child: const Text('Cancel')),
            ]),
          ),
        const Divider(height: MangoSpace.s4),
        Row(children: [
          MangoIconButton(icon: Icons.image_outlined, semanticLabel: 'Add photos or a video', onPressed: _progress == null ? _addMedia : null),
          MangoIconButton(icon: Icons.link_rounded, semanticLabel: _link == null ? 'Add a link' : 'Change link', selected: _link != null, onPressed: _progress == null ? _addLink : null),
          const Spacer(),
          if (count > 0)
            Semantics(
              label: '$left characters left',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: (count / MangoPostService.maxChars).clamp(0.0, 1.0).toDouble(),
                    strokeWidth: 3,
                    color: left < 0 ? c.error : (left <= 20 ? c.warning : c.actionPrimary),
                    backgroundColor: c.borderSubtle,
                  ),
                  if (left <= 20) Text('$left', style: context.type.labelSmall?.copyWith(color: left < 0 ? c.error : c.textSecondary)),
                ]),
              ),
            ),
          const SizedBox(width: MangoSpace.s3),
          if (widget.onCancel != null) TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
          MangoButton(label: widget.replyTo != null ? 'Reply' : 'Post', size: MangoButtonSize.medium, onPressed: _canPost ? _post : null),
        ]),
      ]),
    );
  }
}
