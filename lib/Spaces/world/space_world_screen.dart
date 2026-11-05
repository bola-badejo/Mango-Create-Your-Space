// The virtual Space: a themed room with the owner's content and objects,
// the people who are here now, a message wall, connections and live events.
//
// Visiting mines MangoCoin for the Space owner (server-timed), and anything
// played here credits the owner too. Editors arrange the room in edit mode,
// by dragging or with the arrow buttons (an accessible alternative).
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Chat/chat_screen.dart';
import 'package:mango/Chat/chat_service.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/core/play_source.dart';
import 'package:mango/Media/lists/content_list_service.dart';
import 'package:mango/Media/lists/content_list_sheet.dart';
import 'package:mango/Wallet/ledger/mango_activity_tracker.dart';

import 'space_catalog.dart';
import 'space_event_room.dart';
import 'space_shop_sheet.dart';
import 'space_world_service.dart';

double _clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Opens the one-to-one chat with [userId] in Mango Chat.
Future<void> openDirectMessage(BuildContext context, String userId) async {
  try {
    final chatId = await ChatService.instance.open(userId);
    await Get.to(() => ChatScreen(chatId: chatId, peerId: userId));
  } catch (e) {
    if (context.mounted) {
      MangoToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), kind: MangoToastKind.error);
    }
  }
}

/// Actions for a person you meet in a Space: message or connect.
void showPersonActions(BuildContext context, SpaceWorldService svc, String userId, String name) {
  if (userId == svc.uid) return;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text(name, style: context.type.titleLarge)),
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline_rounded),
          title: const Text('Message'),
          subtitle: const Text('Opens a private conversation in Chats'),
          onTap: () {
            Navigator.pop(sheet);
            openDirectMessage(context, userId);
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_add_alt_1_rounded),
          title: const Text('Connect'),
          subtitle: const Text('Follow to see their posts and Spaces'),
          onTap: () async {
            Navigator.pop(sheet);
            try {
              await svc.follow(userId);
              if (context.mounted) MangoToast.show(context, message: 'Connected with $name', kind: MangoToastKind.success);
            } catch (_) {
              if (context.mounted) MangoToast.show(context, message: "Couldn't connect. Try again.", kind: MangoToastKind.error);
            }
          },
        ),
        const SizedBox(height: MangoSpace.s2),
      ]),
    ),
  );
}

class SpaceWorldScreen extends StatefulWidget {
  const SpaceWorldScreen({super.key, required this.spaceId, this.showTour = false});

  final String spaceId;

  /// Shows the guided tour (used right after creating a Space).
  final bool showTour;

  @override
  State<SpaceWorldScreen> createState() => _SpaceWorldScreenState();
}

class _SpaceWorldScreenState extends State<SpaceWorldScreen> {
  late final SpaceWorldService _svc = SpaceWorldService(widget.spaceId);
  SpaceCatalog? _catalog;
  Timer? _heartbeat;
  bool _editing = false;
  String? _selected;
  int? _tourStep;
  final Map<String, Offset> _dragging = {};
  String _spaceTitle = 'Space';
  bool _isEditorNow = false;

  PlaySource get _source => PlaySource(kind: 'space', id: widget.spaceId, label: _spaceTitle);

  @override
  void initState() {
    super.initState();
    SpaceCatalog.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
    if (widget.showTour) _tourStep = 0;
    _enter();
  }

  Future<void> _enter() async {
    MangoActivityTracker.activeSpaceId = widget.spaceId;
    MangoActivityTracker.startInBackground(contentType: 'space', contentId: widget.spaceId);
    unawaited(_svc.heartbeat().catchError((_) {}));
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) => _svc.heartbeat().catchError((_) {}));
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    if (MangoActivityTracker.activeSpaceId == widget.spaceId) MangoActivityTracker.activeSpaceId = null;
    MangoActivityTracker.stopInBackground();
    unawaited(_svc.leave().catchError((_) {}));
    super.dispose();
  }

  bool _isEditor(Map<String, dynamic> s) {
    final uid = _svc.uid;
    if (uid == null) return false;
    return s['ownerId'] == uid || s['postCreator'] == uid || ((s['editors'] as List?) ?? const []).contains(uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _svc.space(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: MangoStateView(kind: MangoStateKind.error, title: "Couldn't open this Space", message: 'Check your connection and try again.', actionLabel: 'Back', onAction: () => Get.back()));
        }
        final space = snap.data;
        if (space == null || _catalog == null) {
          return Scaffold(appBar: AppBar(), body: const MangoLoadingRegion(label: 'Opening Space', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))));
        }
        final editor = _isEditor(space);
        return StreamBuilder<bool>(
          stream: _svc.isMember(),
          builder: (context, member) {
            final visibility = (space['visibility'] ?? ((space['isPrivate'] == true) ? 'members' : 'public')) as String;
            final mayEnter = visibility == 'public' || editor || member.data == true;
            if (!mayEnter) return _Gate(space: space, visibility: visibility, onJoin: _svc.join);
            return _world(context, space, editor);
          },
        );
      },
    );
  }

  Widget _world(BuildContext context, Map<String, dynamic> space, bool editor) {
    final cat = _catalog!;
    final theme = Map<String, dynamic>.from((space['theme'] as Map?) ?? const {});
    final skin = cat[theme['skinId'] as String?] ?? cat['skin.meadow'];
    final icon = cat[theme['iconId'] as String?] ?? cat['icon.mango'];
    final dark = skin?.isDark ?? false;
    final onSkin = dark ? Colors.white : const Color(0xFF101310);
    final title = (space['title'] ?? 'Space') as String;
    _spaceTitle = title;
    _isEditorNow = editor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: onSkin,
        title: Row(children: [
          SpaceGlyph(item: icon, size: 24),
          const SizedBox(width: MangoSpace.s2),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: context.type.titleLarge?.copyWith(color: onSkin))),
        ]),
        actions: [
          StreamBuilder<List<SpacePresence>>(
            stream: _svc.presence(),
            builder: (_, p) => MangoIconButton(
              icon: Icons.people_alt_rounded,
              semanticLabel: 'People here: ${p.data?.length ?? 0}',
              onPressed: () => _openPeople(p.data ?? const []),
            ),
          ),
          if (editor)
            MangoIconButton(icon: Icons.storefront_rounded, semanticLabel: 'Shop', onPressed: () => _openShop(space)),
          if (editor)
            MangoIconButton(
              icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
              semanticLabel: _editing ? 'Done editing' : 'Edit Space',
              selected: _editing,
              onPressed: () => setState(() {
                _editing = !_editing;
                _selected = null;
              }),
            ),
          MangoIconButton(icon: Icons.help_outline_rounded, semanticLabel: 'Guide', onPressed: () => setState(() => _tourStep = 0)),
        ],
      ),
      floatingActionButton: _editing
          ? FloatingActionButton.extended(
              onPressed: () => _openAddSheet(space),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : FloatingActionButton.extended(
              onPressed: _openWall,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Leave a message'),
            ),
      body: SpaceSkinBackground(
        skin: skin,
        child: SafeArea(
          child: Stack(children: [
            Positioned.fill(child: _canvas(context, space, editor, onSkin)),
            if (space['liveEventId'] != null)
              Positioned(top: MangoSpace.s2, left: MangoSpace.s4, right: MangoSpace.s4, child: _LiveBanner(svc: _svc, eventId: space['liveEventId'] as String, onJoin: _joinEvent)),
            Positioned(left: 0, right: 0, bottom: 88, child: _HereNow(svc: _svc, onTap: _openPeople, textColor: onSkin)),
            if (_editing && _selected != null) Positioned(left: MangoSpace.s4, right: MangoSpace.s4, bottom: 150, child: _editToolbar()),
            if (_tourStep != null) Positioned.fill(child: _tour(editor)),
          ]),
        ),
      ),
    );
  }

  Widget _canvas(BuildContext context, Map<String, dynamic> space, bool editor, Color onSkin) {
    return StreamBuilder<List<SpaceObject>>(
      stream: _svc.objects(),
      builder: (context, snap) {
        final objects = snap.data ?? const <SpaceObject>[];
        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight - 120; // keep clear of the bottom bar
          final children = <Widget>[];
          for (final o in objects) {
            final pos = _dragging[o.id] ?? Offset(o.x, o.y);
            final size = _objectSize(o);
            children.add(Positioned(
              left: _clampD(pos.dx * w - size / 2, 0, w - size < 0 ? 0 : w - size),
              top: _clampD(pos.dy * h - size / 2, 0, h - size < 0 ? 0 : h - size) + 56,
              child: MangoAppear(
                child: _ObjectView(
                  object: o,
                  item: _catalog![o.itemId],
                  size: size,
                  textColor: onSkin,
                  selected: _editing && _selected == o.id,
                  editing: _editing,
                  onTap: () => _editing ? setState(() => _selected = o.id) : _activate(o),
                  onDrag: _editing
                      ? (delta) => setState(() {
                            final cur = _dragging[o.id] ?? Offset(o.x, o.y);
                            _dragging[o.id] = Offset(_clampD(cur.dx + delta.dx / w, 0, 1), _clampD(cur.dy + delta.dy / h, 0, 1));
                            _selected = o.id;
                          })
                      : null,
                  onDragEnd: _editing
                      ? () {
                          final p = _dragging.remove(o.id);
                          if (p != null) unawaited(_svc.moveObject(o.id, p.dx, p.dy).catchError((Object e) => _toastError(e)));
                        }
                      : null,
                ),
              ),
            ));
          }
          if (objects.isEmpty && snap.connectionState == ConnectionState.active) {
            children.add(Center(
              child: Padding(
                padding: const EdgeInsets.all(MangoSpace.s6),
                child: Text(editor ? 'Your Space is empty. Tap Edit, then Add to bring in content and objects.' : 'Nothing here yet.',
                    textAlign: TextAlign.center, style: context.type.bodyLarge?.copyWith(color: onSkin)),
              ),
            ));
          }
          return Stack(children: children);
        });
      },
    );
  }

  double _objectSize(SpaceObject o) {
    final base = switch (o.kind) { 'content' => 96.0, 'wall' => 84.0, 'events' => 84.0, _ => 56.0 };
    final itemScale = _catalog![o.itemId]?.size ?? 1.0;
    return base * o.scale * (o.kind == 'decor' ? itemScale : 1.0);
  }

  Future<void> _activate(SpaceObject o) async {
    switch (o.kind) {
      case 'wall':
        _openWall();
      case 'events':
        _openEvents();
      case 'content':
        await _openContent(o);
      default:
        final item = _catalog![o.itemId];
        MangoToast.show(context, message: item?.name ?? o.label);
    }
  }

  Future<void> _openContent(SpaceObject o) async {
    final ref = o.contentRef;
    if (ref == null) return;
    final type = '${ref['type']}';
    final id = '${ref['id']}';
    if (type == 'list') {
      await Get.to(() => ContentListScreen(listId: id, spaceLabel: _spaceTitle, canEdit: _isEditorNow));
      return;
    }
    if (type == 'post' || type == 'product') {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(MangoSpace.s6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ref['title'] ?? 'Content'}', style: context.type.headlineSmall),
            const SizedBox(height: MangoSpace.s2),
            Text('Shared by this Space', style: context.type.bodyMedium),
          ]),
        ),
      );
      return;
    }
    try {
      await openContentItem(context, ContentListItem(type: type, id: id, title: '${ref['title'] ?? ''}', imageUrl: ref['imageUrl'] as String?), source: _source);
      if (mounted && (type == 'song' || type == 'podcast')) {
        MangoToast.show(context, message: 'Playing ${ref['title'] ?? ''} in this Space', kind: MangoToastKind.success);
      }
    } catch (e) {
      _toastError(e);
    }
  }

  void _toastError(Object e) {
    if (mounted) MangoToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), kind: MangoToastKind.error);
  }

  // --------------------------------------------------------- edit mode
  Widget _editToolbar() {
    final id = _selected!;
    Future<void> nudge(double dx, double dy) async {
      final snap = await FirebaseFirestore.instance.collection('spaces').doc(widget.spaceId).collection('objects').doc(id).get();
      final d = snap.data();
      if (d == null) return;
      await _svc.moveObject(id, ((d['x'] as num) + dx).toDouble(), ((d['y'] as num) + dy).toDouble());
    }

    Future<void> resize(double f) async {
      final snap = await FirebaseFirestore.instance.collection('spaces').doc(widget.spaceId).collection('objects').doc(id).get();
      final s = ((snap.data()?['scale'] ?? 1) as num).toDouble();
      await _svc.scaleObject(id, s * f);
    }

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(MangoRadius.lg),
      color: context.colors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s2, vertical: MangoSpace.s1),
        child: Wrap(alignment: WrapAlignment.center, children: [
          MangoIconButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Move left', onPressed: () => nudge(-0.04, 0)),
          MangoIconButton(icon: Icons.arrow_upward_rounded, semanticLabel: 'Move up', onPressed: () => nudge(0, -0.04)),
          MangoIconButton(icon: Icons.arrow_downward_rounded, semanticLabel: 'Move down', onPressed: () => nudge(0, 0.04)),
          MangoIconButton(icon: Icons.arrow_forward_rounded, semanticLabel: 'Move right', onPressed: () => nudge(0.04, 0)),
          MangoIconButton(icon: Icons.zoom_out_rounded, semanticLabel: 'Smaller', onPressed: () => resize(0.85)),
          MangoIconButton(icon: Icons.zoom_in_rounded, semanticLabel: 'Bigger', onPressed: () => resize(1.15)),
          MangoIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: 'Remove from Space',
            onPressed: () async {
              await _svc.removeObject(id).catchError((Object e) => _toastError(e));
              if (mounted) setState(() => _selected = null);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _openAddSheet(Map<String, dynamic> space) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddSheet(svc: _svc, catalog: _catalog!),
    );
  }

  Future<void> _openShop(Map<String, dynamic> space) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SpaceShopSheet(svc: _svc, catalog: _catalog!, theme: Map<String, dynamic>.from((space['theme'] as Map?) ?? const {})),
    );
  }

  // ------------------------------------------------------ social sheets
  void _openWall() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WallSheet(svc: _svc),
    );
  }

  void _openPeople([List<SpacePresence> people = const []]) {
    showModalBottomSheet<void>(context: context, builder: (_) => _PeopleSheet(svc: _svc));
  }

  void _openEvents() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StreamBuilder<Map<String, dynamic>?>(
        stream: _svc.space(),
        builder: (_, s) => _EventsSheet(svc: _svc, editor: s.data != null && _isEditor(s.data!), onJoin: _joinEvent),
      ),
    );
  }

  void _joinEvent(String eventId) {
    Get.to(() => SpaceEventRoom(spaceId: widget.spaceId, eventId: eventId));
  }

  // ---------------------------------------------------------- the tour
  Widget _tour(bool editor) {
    final steps = <(IconData, String, String)>[
      (Icons.waving_hand_rounded, 'Welcome to your Space', 'This is a room people can walk into. Everything you place here, visitors can see and tap.'),
      if (editor) (Icons.edit_rounded, 'Arrange your room', 'Tap Edit, then Add to bring in your songs, videos, posts and objects. Drag them, or use the arrow buttons.'),
      (Icons.edit_note_rounded, 'The message wall', 'Visitors leave messages here. You can remove anything that breaks your rules.'),
      (Icons.mic_rounded, 'Go live', editor ? 'Tap the live stage to schedule an event. When it starts, everyone here can join and chat.' : 'Tap the live stage to see events and join when they go live.'),
      if (editor) (Icons.storefront_rounded, 'Make it yours', 'Use the shop to buy skins, icons and objects with MangoCoin. Visitors earn you MangoCoin just by spending time here.'),
    ];
    final raw = _tourStep ?? 0;
    final i = raw < 0 ? 0 : (raw >= steps.length ? steps.length - 1 : raw);
    final s = steps[i];
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MangoSpace.s6),
          child: Material(
            color: context.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(MangoRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(MangoSpace.s6),
              child: Semantics(
                liveRegion: true,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ExcludeSemantics(child: Icon(s.$1, color: context.colors.textBrand)),
                    const SizedBox(width: MangoSpace.s3),
                    Expanded(child: Text(s.$2, style: context.type.titleLarge)),
                  ]),
                  const SizedBox(height: MangoSpace.s3),
                  Text(s.$3, style: context.type.bodyLarge),
                  const SizedBox(height: MangoSpace.s4),
                  Text('Tip ${i + 1} of ${steps.length}', style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary)),
                  const SizedBox(height: MangoSpace.s4),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    MangoButton(label: 'Skip', variant: MangoButtonVariant.text, size: MangoButtonSize.medium, onPressed: () => setState(() => _tourStep = null)),
                    const SizedBox(width: MangoSpace.s2),
                    MangoButton(
                      label: i == steps.length - 1 ? 'Got it' : 'Next',
                      size: MangoButtonSize.medium,
                      onPressed: () => setState(() => _tourStep = i == steps.length - 1 ? null : i + 1),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
class _ObjectView extends StatelessWidget {
  const _ObjectView({
    required this.object,
    required this.item,
    required this.size,
    required this.textColor,
    required this.selected,
    required this.editing,
    required this.onTap,
    this.onDrag,
    this.onDragEnd,
  });

  final SpaceObject object;
  final SpaceItem? item;
  final double size;
  final Color textColor;
  final bool selected;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onDragEnd;

  String get _label {
    switch (object.kind) {
      case 'wall':
        return 'Message wall. Open to read and leave messages';
      case 'events':
        return 'Live stage. Open to see events';
      case 'content':
        return '${object.contentRef?['title'] ?? 'Content'}, ${object.contentRef?['type'] ?? ''}. Open';
      default:
        return item?.name ?? object.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget visual;
    switch (object.kind) {
      case 'content':
        final img = object.contentRef?['imageUrl'] as String?;
        visual = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(MangoRadius.md)),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            if (img != null && img.isNotEmpty)
              CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: (size * 3).round(), errorWidget: (_, __, ___) => const SizedBox())
            else
              Center(child: Icon(_contentIcon(object.contentRef?['type'] as String?), size: size * 0.4, color: c.textBrand)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('${object.contentRef?['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.labelMedium?.copyWith(color: Colors.white)),
              ),
            ),
          ]),
        );
      case 'wall':
        visual = _Builtin(glyph: '🗒️', label: 'Wall', size: size, textColor: textColor);
      case 'events':
        visual = _Builtin(glyph: '🎤', label: 'Live stage', size: size, textColor: textColor);
      default:
        visual = SizedBox(width: size, height: size, child: FittedBox(child: SpaceGlyph(item: item, size: 48)));
    }
    if (selected) {
      visual = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: c.focusRing, width: 3), borderRadius: BorderRadius.circular(MangoRadius.md)),
        child: visual,
      );
    }
    final pressable = MangoPressable(onTap: onTap, semanticLabel: editing ? '$_label. Selected for editing: ${selected ? 'yes' : 'no'}' : _label, child: visual);
    if (onDrag == null) return pressable;
    return GestureDetector(
      onPanUpdate: (d) => onDrag!(d.delta),
      onPanEnd: (_) => onDragEnd?.call(),
      child: pressable,
    );
  }

  static IconData _contentIcon(String? type) => switch (type) {
        'song' => Icons.music_note_rounded,
        'podcast' => Icons.podcasts_rounded,
        'movie' => Icons.movie_rounded,
        'book' => Icons.menu_book_rounded,
        'product' => Icons.shopping_bag_rounded,
        'list' => Icons.queue_music_rounded,
        _ => Icons.article_rounded,
      };
}

class _Builtin extends StatelessWidget {
  const _Builtin({required this.glyph, required this.label, required this.size, required this.textColor});

  final String glyph;
  final String label;
  final double size;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Expanded(child: FittedBox(child: Text(glyph, style: const TextStyle(fontSize: 48)))),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.labelMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HereNow extends StatelessWidget {
  const _HereNow({required this.svc, required this.onTap, required this.textColor});

  final SpaceWorldService svc;
  final void Function(List<SpacePresence>) onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SpacePresence>>(
      stream: svc.presence(),
      builder: (context, snap) {
        final people = snap.data ?? const <SpacePresence>[];
        if (people.isEmpty) return const SizedBox.shrink();
        return MangoPressable(
          onTap: () => onTap(people),
          semanticLabel: '${people.length} ${people.length == 1 ? 'person' : 'people'} here now. Open to connect',
          child: SizedBox(
            height: 48,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final p in people.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: (p.photo ?? '').isNotEmpty ? CachedNetworkImageProvider(p.photo!) : null,
                    child: (p.photo ?? '').isEmpty ? Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()) : null,
                  ),
                ),
              const SizedBox(width: MangoSpace.s2),
              Text('${people.length} here', style: context.type.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      },
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.svc, required this.eventId, required this.onJoin});

  final SpaceWorldService svc;
  final String eventId;
  final void Function(String) onJoin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpaceEvent?>(
      stream: svc.event(eventId),
      builder: (context, snap) {
        final e = snap.data;
        if (e == null || !e.isLive) return const SizedBox.shrink();
        return Material(
          color: context.colors.errorContainer,
          borderRadius: BorderRadius.circular(MangoRadius.pill),
          child: Padding(
            padding: const EdgeInsets.only(left: MangoSpace.s4),
            child: Row(children: [
              Icon(Icons.circle, size: 10, color: context.colors.error),
              const SizedBox(width: MangoSpace.s2),
              Expanded(child: Text('Live now: ${e.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.labelLarge)),
              MangoButton(label: 'Join', size: MangoButtonSize.medium, onPressed: () => onJoin(e.id)),
            ]),
          ),
        );
      },
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.space, required this.visibility, required this.onJoin});

  final Map<String, dynamic> space;
  final String visibility;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context) {
    final private = visibility == 'private';
    return Scaffold(
      appBar: AppBar(title: Text((space['title'] ?? 'Space') as String)),
      body: MangoStateView(
        kind: MangoStateKind.permissionDenied,
        title: private ? 'This Space is private' : 'Members only',
        message: private ? 'Only people the owner adds can enter.' : 'Join this Space to step inside, meet people and leave messages.',
        actionLabel: private ? null : 'Join Space',
        onAction: private ? null : () => onJoin(),
      ),
    );
  }
}

class _WallSheet extends StatefulWidget {
  const _WallSheet({required this.svc});

  final SpaceWorldService svc;

  @override
  State<_WallSheet> createState() => _WallSheetState();
}

class _WallSheetState extends State<_WallSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Message wall', style: context.type.titleLarge)),
          Expanded(
            child: StreamBuilder<List<SpaceMessage>>(
              stream: widget.svc.wall(),
              builder: (context, snap) {
                final msgs = snap.data ?? const <SpaceMessage>[];
                if (snap.connectionState == ConnectionState.waiting) return const MangoLoadingRegion(label: 'Loading messages', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')));
                if (msgs.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No messages yet', message: 'Be the first to say hello.');
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.authorId == widget.svc.uid;
                    return MangoAppear.staggered(
                      index: i,
                      child: ListTile(
                        leading: MangoPressable(
                          semanticLabel: mine ? 'You' : 'Message or connect with ${m.authorName}',
                          onTap: mine ? null : () => showPersonActions(context, widget.svc, m.authorId, m.authorName),
                          child: CircleAvatar(
                            backgroundImage: (m.authorPhoto ?? '').isNotEmpty ? CachedNetworkImageProvider(m.authorPhoto!) : null,
                            child: (m.authorPhoto ?? '').isEmpty ? Text(m.authorName[0].toUpperCase()) : null,
                          ),
                        ),
                        title: Text(m.authorName, style: context.type.labelLarge),
                        subtitle: Text(m.text, style: context.type.bodyMedium),
                        trailing: mine
                            ? MangoIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Delete your message', onPressed: () => widget.svc.deleteMessage(m.id))
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(MangoSpace.s3),
              child: Row(children: [
                Expanded(child: MangoTextField(label: 'Your message', controller: _text, maxLines: 3, textInputAction: TextInputAction.send, onSubmitted: (_) => _send())),
                const SizedBox(width: MangoSpace.s2),
                MangoIconButton(icon: Icons.send_rounded, semanticLabel: 'Send', onPressed: _send),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _send() async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    try {
      await widget.svc.postToWall(t);
      if (mounted) MangoAnnounce.polite(context, 'Message posted');
    } catch (e) {
      if (mounted) MangoToast.show(context, message: "Couldn't post your message. Try again.", kind: MangoToastKind.error);
    }
  }
}

class _PeopleSheet extends StatelessWidget {
  const _PeopleSheet({required this.svc});

  final SpaceWorldService svc;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SpacePresence>>(
        stream: svc.presence(),
        builder: (context, snap) {
          final people = snap.data ?? const <SpacePresence>[];
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Here now', style: context.type.titleLarge)),
            if (people.isEmpty) const Padding(padding: EdgeInsets.all(MangoSpace.s6), child: Text("It's quiet right now.")),
            for (final p in people)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: (p.photo ?? '').isNotEmpty ? CachedNetworkImageProvider(p.photo!) : null,
                  child: (p.photo ?? '').isEmpty ? Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase()) : null,
                ),
                title: Text(p.uid == svc.uid ? '${p.name} (you)' : p.name),
                trailing: p.uid == svc.uid
                    ? null
                    : Wrap(spacing: MangoSpace.s1, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        MangoIconButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          semanticLabel: 'Message ${p.name}',
                          onPressed: () => openDirectMessage(context, p.uid),
                        ),
                        MangoButton(
                        label: 'Connect',
                        size: MangoButtonSize.medium,
                        variant: MangoButtonVariant.secondary,
                        showSuccess: true,
                        successLabel: 'Connected',
                        onPressed: () => svc.follow(p.uid),
                        onError: (_) => MangoToast.show(context, message: "Couldn't connect. Try again.", kind: MangoToastKind.error),
                      ),
                      ]),
              ),
            const SizedBox(height: MangoSpace.s4),
          ]);
        },
      ),
    );
  }
}

class _EventsSheet extends StatelessWidget {
  const _EventsSheet({required this.svc, required this.editor, required this.onJoin});

  final SpaceWorldService svc;
  final bool editor;
  final void Function(String) onJoin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Live stage', style: context.type.titleLarge)),
          if (editor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
              child: MangoButton(label: 'Schedule an event', icon: Icons.event_rounded, expand: true, onPressed: () => _schedule(context)),
            ),
          Expanded(
            child: StreamBuilder<List<SpaceEvent>>(
              stream: svc.events(),
              builder: (context, snap) {
                final events = snap.data ?? const <SpaceEvent>[];
                if (events.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No events yet', message: 'Live events will appear here.');
                return ListView(children: [
                  for (final e in events)
                    ListTile(
                      leading: Icon(e.isLive ? Icons.sensors_rounded : Icons.event_rounded, color: e.isLive ? context.colors.error : null),
                      title: Text(e.title),
                      subtitle: Text(e.isLive ? 'Live now' : _when(e.startsAt)),
                      trailing: Wrap(spacing: MangoSpace.s1, children: [
                        if (e.isLive) MangoButton(label: 'Join', size: MangoButtonSize.medium, onPressed: () => onJoin(e.id)),
                        if (!e.isLive && editor)
                          MangoButton(label: 'Go live', size: MangoButtonSize.medium, variant: MangoButtonVariant.secondary, onPressed: () async {
                            await svc.setEventStatus(e.id, 'live');
                            onJoin(e.id);
                          }),
                      ]),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  static String _when(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.inMinutes < 60) return 'Starts in ${d.inMinutes < 0 ? 0 : d.inMinutes} min';
    if (d.inHours < 24) return 'Starts in ${d.inHours} h';
    return 'Starts ${t.day}/${t.month} at ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _schedule(BuildContext context) async {
    final title = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    int minutes = 60;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Schedule an event'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            MangoTextField(label: 'Title', controller: title, required: true),
            const SizedBox(height: MangoSpace.s3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts'),
              subtitle: Text('${when.day}/${when.month} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: when);
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                if (t == null) return;
                setLocal(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
            DropdownButtonFormField<int>(
              value: minutes,
              decoration: const InputDecoration(labelText: 'Length'),
              items: const [30, 60, 90, 120, 180].map((m) => DropdownMenuItem(value: m, child: Text('$m minutes'))).toList(),
              onChanged: (v) => setLocal(() => minutes = v ?? 60),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            MangoButton(
              label: 'Schedule',
              size: MangoButtonSize.medium,
              onPressed: () async {
                await svc.createEvent(title: title.text.trim(), startsAt: when, durationMinutes: minutes);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              onError: (e) => MangoToast.show(ctx, message: e.toString(), kind: MangoToastKind.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({required this.svc, required this.catalog});

  final SpaceWorldService svc;
  final SpaceCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: 'My content'), Tab(text: 'Lists'), Tab(text: 'Objects')]),
          Expanded(
            child: TabBarView(children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: svc.myContent(),
                builder: (context, snap) {
                  if (!snap.hasData) return const MangoLoadingRegion(label: 'Loading your content', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')));
                  final items = snap.data!;
                  if (items.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No content yet', message: 'Upload music, podcasts, films or posts, then add them here.');
                  return ListView(children: [
                    for (final it in items)
                      ListTile(
                        leading: Icon(_ObjectView._contentIcon(it['type'] as String?)),
                        title: Text('${it['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${it['type']}'),
                        trailing: MangoButton(
                          label: 'Add',
                          size: MangoButtonSize.medium,
                          onPressed: () async {
                            final title = '${it['title']}';
                            await svc.placeObject(
                              kind: 'content',
                              label: title,
                              contentRef: {
                                'type': it['type'],
                                'id': it['id'],
                                'title': title.length > 120 ? title.substring(0, 120) : title,
                                if (it['imageUrl'] != null) 'imageUrl': it['imageUrl'],
                              },
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                  ]);
                },
              ),
              _SpaceListsTab(svc: svc),
              StreamBuilder<Set<String>>(
                stream: svc.inventory(),
                builder: (context, snap) {
                  final owned = (snap.data ?? const <String>{}).map((id) => catalog[id]).whereType<SpaceItem>().where((i) => i.kind == SpaceItemKind.object).toList();
                  if (owned.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No objects yet', message: 'Buy objects in the shop to place them here.');
                  return GridView.count(
                    crossAxisCount: 4,
                    padding: const EdgeInsets.all(MangoSpace.s4),
                    children: [
                      for (final it in owned)
                        MangoPressable(
                          semanticLabel: 'Add ${it.name}',
                          onTap: () async {
                            await svc.placeObject(kind: 'decor', itemId: it.id, label: it.name);
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Column(children: [
                            SpaceGlyph(item: it, size: 36),
                            Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
                          ]),
                        ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


/// Content lists for this Space: create one, then place it in the room.
class _SpaceListsTab extends StatelessWidget {
  const _SpaceListsTab({required this.svc});

  final SpaceWorldService svc;

  @override
  Widget build(BuildContext context) {
    final lists = ContentListService();
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.add_rounded),
        title: const Text('New list for this Space'),
        subtitle: const Text('Mix songs, episodes, films and books'),
        onTap: () async {
          final ctrl = TextEditingController();
          final name = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('New list'),
              content: MangoTextField(label: 'Name', controller: ctrl, required: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Create')),
              ],
            ),
          );
          if (name == null || name.isEmpty) return;
          try {
            final id = await lists.create(title: name, spaceId: svc.spaceId);
            await svc.placeObject(kind: 'content', label: name, contentRef: {'type': 'list', 'id': id, 'title': name.length > 120 ? name.substring(0, 120) : name});
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) MangoToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), kind: MangoToastKind.error);
          }
        },
      ),
      const Divider(),
      Expanded(
        child: StreamBuilder<List<ContentList>>(
          stream: lists.forSpace(svc.spaceId),
          builder: (context, snap) {
            final all = snap.data ?? const <ContentList>[];
            if (all.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No lists yet', message: 'Create a list, then add to it from any player.');
            return ListView(children: [
              for (final l in all)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(l.title),
                  subtitle: Text('${l.items.length} items'),
                  trailing: MangoButton(
                    label: 'Place',
                    size: MangoButtonSize.medium,
                    onPressed: () async {
                      await svc.placeObject(kind: 'content', label: l.title, contentRef: {'type': 'list', 'id': l.id, 'title': l.title});
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
            ]);
          },
        ),
      ),
    ]);
  }
}
