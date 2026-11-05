// Content list screens: add to a list, view and play a list, and a single
// opener that sends each kind of content to the right player.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/core/play_source.dart';
import 'package:mango/Media/reader/mango_reader.dart';
import 'package:mango/Media/video/mango_video_player.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/MusicPlayer/music.dart';

import 'content_list_service.dart';

final _lists = ContentListService();

/// Opens any piece of content in the right place: songs and podcasts in the
/// audio engine, films in the video player, books in Mango Reader.
Future<void> openContentItem(BuildContext context, ContentListItem item, {PlaySource? source, List<ContentListItem> siblings = const []}) async {
  final engine = Get.find<GlobalMusicController>();
  switch (item.type) {
    case 'song':
    case 'podcast':
      final audio = siblings.where((s) => s.type == 'song' || s.type == 'podcast').toList();
      if (audio.length > 1) {
        await playAudioItems(context, audio, startId: item.id, source: source);
      } else {
        await engine.initializePlayer(item.id, source: source, kind: item.type == 'podcast' ? AudioKind.podcast : AudioKind.song);
      }
    case 'movie':
    case 'vine':
      await Get.to(() => MangoVideoPlayerScreen(type: item.type, id: item.id, source: source));
    case 'book':
      await Get.to(() => MangoReaderScreen(bookId: item.id));
    default:
      MangoToast.show(context, message: "This item can't be opened here yet.");
  }
}

/// Loads and plays the audio items of a list, in order, from [startId].
Future<void> playAudioItems(BuildContext context, List<ContentListItem> items, {String? startId, PlaySource? source, bool shuffle = false}) async {
  final db = FirebaseFirestore.instance;
  final loaded = <Music>[];
  for (final it in items) {
    try {
      if (it.type == 'song') {
        final d = await db.collection('music').doc(it.id).get();
        if (d.exists) loaded.add(Music.fromFirestore(d));
      } else if (it.type == 'podcast') {
        final d = await db.collection('podcasts').doc(it.id).get();
        if (d.exists) loaded.add(GlobalMusicController.podcastToMusic(d));
      }
    } catch (_) {}
  }
  if (loaded.isEmpty) {
    if (context.mounted) MangoToast.show(context, message: 'Nothing in this list can be played right now.', kind: MangoToastKind.error);
    return;
  }
  final start = startId == null ? 0 : loaded.indexWhere((m) => m.id == startId);
  await Get.find<GlobalMusicController>().playItems(loaded, startIndex: start < 0 ? 0 : start, source: source, shuffle: shuffle);
}

/// "Add to a list": pick one of your lists or make a new one.
Future<void> showAddToListSheet(BuildContext context, {required String type, required String id, required String title, String? imageUrl}) {
  final item = ContentListItem(type: type, id: id, title: title, imageUrl: imageUrl);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * 0.6,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Add to a list', style: sheet.type.titleLarge)),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('New list'),
            onTap: () async {
              final name = await _askName(sheet);
              if (name == null) return;
              try {
                await _lists.create(title: name, items: [item]);
                if (sheet.mounted) Navigator.pop(sheet);
                if (context.mounted) MangoToast.show(context, message: 'Added to $name', kind: MangoToastKind.success);
              } catch (e) {
                if (context.mounted) MangoToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), kind: MangoToastKind.error);
              }
            },
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<ContentList>>(
              stream: _lists.mine(),
              builder: (_, snap) {
                final lists = snap.data ?? const <ContentList>[];
                if (lists.isEmpty) return const MangoStateView(kind: MangoStateKind.empty, title: 'No lists yet', message: 'Create one to collect songs, episodes, films and books.');
                return ListView(children: [
                  for (final l in lists)
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(l.title),
                      subtitle: Text('${l.items.length} items'),
                      onTap: () async {
                        try {
                          await _lists.add(l.id, item);
                          if (sheet.mounted) Navigator.pop(sheet);
                          if (context.mounted) MangoToast.show(context, message: 'Added to ${l.title}', kind: MangoToastKind.success);
                        } catch (e) {
                          if (context.mounted) MangoToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), kind: MangoToastKind.error);
                        }
                      },
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<String?> _askName(BuildContext context) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('New list'),
      content: MangoTextField(label: 'Name', controller: ctrl, required: true, textInputAction: TextInputAction.done, onSubmitted: (v) => Navigator.pop(d, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('Create')),
      ],
    ),
  );
  final t = name?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// A list's page: play all, shuffle, open items, and (for editors) reorder and remove.
class ContentListScreen extends StatelessWidget {
  const ContentListScreen({super.key, required this.listId, this.spaceLabel, this.canEdit = false});

  final String listId;
  final String? spaceLabel;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ContentList?>(
      stream: _lists.watch(listId),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState == ConnectionState.waiting
                ? const MangoLoadingRegion(label: 'Loading list', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')))
                : const MangoStateView(kind: MangoStateKind.error, title: "This list isn't available", message: 'It may be private or deleted.'),
          );
        }
        final items = list.items;
        final source = PlaySource(
          kind: list.spaceId != null ? 'space' : 'list',
          id: list.spaceId ?? list.id,
          label: list.spaceId != null ? '${spaceLabel ?? 'Space'} · ${list.title}' : list.title,
        );
        final audio = items.where((i) => i.type == 'song' || i.type == 'podcast').toList();
        return Scaffold(
          appBar: AppBar(title: Text(list.title)),
          body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            Padding(
              padding: const EdgeInsets.all(MangoSpace.s4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (list.description.isNotEmpty) Text(list.description, style: context.type.bodyMedium),
                Text('${items.length} items', style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary)),
                const SizedBox(height: MangoSpace.s3),
                Row(children: [
                  Expanded(child: MangoButton(label: 'Play all', icon: Icons.play_arrow_rounded, onPressed: audio.isEmpty ? null : () => playAudioItems(context, audio, source: source))),
                  const SizedBox(width: MangoSpace.s3),
                  Expanded(child: MangoButton(label: 'Shuffle', icon: Icons.shuffle_rounded, variant: MangoButtonVariant.secondary, onPressed: audio.isEmpty ? null : () => playAudioItems(context, audio, source: source, shuffle: true))),
                ]),
              ]),
            ),
            if (items.isEmpty) const MangoStateView(kind: MangoStateKind.empty, title: 'Empty list', message: 'Add songs, episodes, films or books from any player.'),
            for (var i = 0; i < items.length; i++)
              MangoAppear.staggered(
                index: i,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(MangoRadius.sm),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: (items[i].imageUrl ?? '').isEmpty
                          ? ColoredBox(color: context.colors.surfaceSelected, child: Icon(_icon(items[i].type)))
                          : CachedNetworkImage(imageUrl: items[i].imageUrl!, fit: BoxFit.cover, memCacheWidth: 144, errorWidget: (_, __, ___) => Icon(_icon(items[i].type))),
                    ),
                  ),
                  title: Text(items[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_label(items[i].type)),
                  onTap: () => openContentItem(context, items[i], source: source, siblings: items),
                  trailing: canEdit
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          MangoIconButton(icon: Icons.arrow_upward_rounded, semanticLabel: 'Move ${items[i].title} up', onPressed: i == 0 ? null : () => _lists.move(list.id, i, i - 1)),
                          MangoIconButton(icon: Icons.remove_circle_outline_rounded, semanticLabel: 'Remove ${items[i].title}', onPressed: () => _lists.remove(list.id, i)),
                        ])
                      : null,
                ),
              ),
          ]),
        );
      },
    );
  }

  static IconData _icon(String t) => switch (t) {
        'song' => Icons.music_note_rounded,
        'podcast' => Icons.podcasts_rounded,
        'movie' => Icons.movie_rounded,
        'book' => Icons.menu_book_rounded,
        _ => Icons.play_circle_outline_rounded,
      };

  static String _label(String t) => switch (t) {
        'song' => 'Song',
        'podcast' => 'Podcast episode',
        'movie' => 'Film',
        'book' => 'Book',
        'vine' => 'Video',
        _ => t,
      };
}
