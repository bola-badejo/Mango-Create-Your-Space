// The queue: what's playing and where from, Up next (drag to reorder,
// swipe to remove), recommendations, and the shuffle, AI shuffle, repeat,
// speed and sleep controls. Shared by music and podcasts.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/core/play_queue.dart';
import 'package:mango/Media/lists/content_list_sheet.dart';
import 'package:mango/MusicPlayer/controllers/global_music_controller.dart';
import 'package:mango/MusicPlayer/music.dart';
import 'package:mango/Spaces/world/space_world_screen.dart';

Future<void> showQueueSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.92, child: MangoQueueSheet()),
    );

class MangoQueueSheet extends StatelessWidget {
  const MangoQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = Get.find<GlobalMusicController>();
    final c = context.colors;
    return Obx(() {
      final current = engine.currentMusic.value;
      // Reading the reactive mirror subscribes this view to queue changes.
      engine.upcomingTracks.length;
      final upcoming = engine.queue.upcoming;
      final src = engine.source.value;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(MangoSpace.s4, 0, MangoSpace.s4, MangoSpace.s2),
          child: Text('Queue', style: context.type.titleLarge),
        ),
        if (current != null)
          ListTile(
            leading: _Art(url: current.artworkUrl),
            title: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: MangoPressable(
              semanticLabel: 'Playing from ${src.label}',
              onTap: src.kind == 'space' && src.id != null ? () => Get.to(() => SpaceWorldScreen(spaceId: src.id!)) : null,
              child: Text('Playing from ${src.label}', style: context.type.bodySmall?.copyWith(color: c.textBrand)),
            ),
            trailing: MangoIconButton(
              icon: Icons.playlist_add_rounded,
              semanticLabel: 'Add to a list',
              onPressed: () => showAddToListSheet(context, type: engine.kindOf(current).name, id: current.id, title: current.title, imageUrl: current.artworkUrl),
            ),
          ),
        _Controls(engine: engine),
        const Divider(),
        Expanded(
          child: CustomScrollView(slivers: [
            if (upcoming.isNotEmpty)
              SliverToBoxAdapter(child: _Header(text: engine.upNext.isNotEmpty ? 'Up next' : 'Coming up', trailing: '${upcoming.length}')),
            SliverReorderableList(
              itemCount: upcoming.length,
              onReorder: (o, n) => engine.moveInQueue(o, n > o ? n - 1 : n),
              itemBuilder: (context, i) {
                final e = upcoming[i];
                return Dismissible(
                  key: ValueKey('q-${e.item.id}-$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(color: c.errorContainer, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: MangoSpace.s6), child: Icon(Icons.delete_outline_rounded, color: c.error)),
                  onDismissed: (_) {
                    engine.removeFromQueue(i);
                    MangoAnnounce.polite(context, 'Removed ${e.item.title}');
                  },
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: _Art(url: e.item.artworkUrl),
                        title: Text(e.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [e.item.artistName, if (e.origin == QueueOrigin.user) 'Queued by you', if (e.origin == QueueOrigin.recommended) 'AI pick', if (e.origin == QueueOrigin.autoplay) 'Autoplay'].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => engine.jumpToQueue(i),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          // Accessible alternatives to dragging and swiping.
                          MangoIconButton(icon: Icons.arrow_upward_rounded, semanticLabel: 'Move ${e.item.title} up', onPressed: i == 0 ? null : () => engine.moveInQueue(i, i - 1)),
                          MangoIconButton(icon: Icons.remove_circle_outline_rounded, semanticLabel: 'Remove ${e.item.title}', onPressed: () => engine.removeFromQueue(i)),
                          ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(MangoSpace.s2), child: Icon(Icons.drag_handle_rounded))),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (engine.recommendations.isNotEmpty) ...[
              SliverToBoxAdapter(child: _Header(text: current == null ? 'Recommended for you' : 'Because you played ${current.title}')),
              SliverList.builder(
                itemCount: engine.recommendations.length,
                itemBuilder: (context, i) {
                  final m = engine.recommendations[i];
                  return MangoAppear.staggered(
                    index: i,
                    child: ListTile(
                      leading: _Art(url: m.artworkUrl),
                      title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(m.artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        MangoIconButton(
                          icon: Icons.queue_play_next_rounded,
                          semanticLabel: 'Play ${m.title} next',
                          onPressed: () {
                            engine.playNext(m);
                            MangoToast.show(context, message: '${m.title} plays next', kind: MangoToastKind.success);
                          },
                        ),
                        MangoIconButton(
                          icon: Icons.add_to_queue_rounded,
                          semanticLabel: 'Add ${m.title} to queue',
                          onPressed: () {
                            engine.addToQueue(m);
                            MangoToast.show(context, message: 'Added to queue', kind: MangoToastKind.success);
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ],
            if (upcoming.isEmpty && engine.recommendations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: MangoStateView(kind: MangoStateKind.empty, title: 'Nothing queued', message: 'Use "Play next" or "Add to queue" on any track.'),
              ),
          ]),
        ),
      ]);
    });
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.engine});

  final GlobalMusicController engine;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shuffle = engine.isShuffled.value;
      final smart = engine.isSmartShuffled.value;
      final repeat = engine.repeatMode.value;
      final speed = engine.playbackSpeed.value;
      final sleep = engine.sleepTimerEndsAt.value;
      return Wrap(alignment: WrapAlignment.center, spacing: MangoSpace.s1, children: [
        MangoIconButton(
          icon: Icons.shuffle_rounded,
          semanticLabel: shuffle && !smart ? 'Shuffle on. Turn off' : 'Shuffle',
          selected: shuffle && !smart,
          onPressed: () => engine.toggleShuffle(),
        ),
        MangoIconButton(
          icon: Icons.auto_awesome_rounded,
          semanticLabel: smart ? 'AI shuffle on. Turn off' : 'AI shuffle: order by your taste',
          selected: smart,
          onPressed: () async {
            if (smart) {
              engine.toggleShuffle();
            } else {
              await engine.smartShuffle();
              if (context.mounted) MangoAnnounce.polite(context, 'AI shuffle on');
            }
          },
        ),
        MangoIconButton(
          icon: repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          semanticLabel: switch (repeat) { RepeatMode.off => 'Repeat off', RepeatMode.all => 'Repeat all', RepeatMode.one => 'Repeat one' },
          selected: repeat != RepeatMode.off,
          onPressed: () {
            final m = engine.cycleRepeat();
            MangoAnnounce.polite(context, switch (m) { RepeatMode.off => 'Repeat off', RepeatMode.all => 'Repeat all', RepeatMode.one => 'Repeat one' });
          },
        ),
        PopupMenuButton<double>(
          tooltip: 'Playback speed, ${speed}x',
          initialValue: speed,
          onSelected: engine.setSpeed,
          itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) => PopupMenuItem(value: s, child: Text('${s}x'))).toList(),
          child: Padding(
            padding: const EdgeInsets.all(MangoSpace.s3),
            child: Text('${speed}x', style: context.type.labelLarge),
          ),
        ),
        PopupMenuButton<int>(
          tooltip: sleep == null ? 'Sleep timer' : 'Sleep timer on',
          onSelected: (m) {
            if (m == 0) {
              engine.setSleepTimer(null);
            } else if (m == -1) {
              engine.setSleepTimer(null, endOfItem: true);
            } else {
              engine.setSleepTimer(Duration(minutes: m));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 15, child: Text('15 minutes')),
            const PopupMenuItem(value: 30, child: Text('30 minutes')),
            const PopupMenuItem(value: 60, child: Text('1 hour')),
            const PopupMenuItem(value: -1, child: Text('End of this track')),
            const PopupMenuItem(value: 0, child: Text('Off')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(MangoSpace.s3),
            child: Icon(sleep == null && !engine.sleepAtEndOfItem.value ? Icons.bedtime_outlined : Icons.bedtime_rounded),
          ),
        ),
      ]);
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.text, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(MangoSpace.s4, MangoSpace.s4, MangoSpace.s4, MangoSpace.s1),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: context.type.titleMedium))),
          if (trailing != null) Text(trailing!, style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary)),
        ]),
      );
}

class _Art extends StatelessWidget {
  const _Art({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(MangoRadius.sm),
        child: SizedBox(
          width: 44,
          height: 44,
          child: url.isEmpty
              ? ColoredBox(color: context.colors.surfaceSelected, child: const Icon(Icons.music_note_rounded))
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 132, errorWidget: (_, __, ___) => const Icon(Icons.music_note_rounded)),
        ),
      );
}

/// Track actions used across the app: play next, add to queue, add to list.
Future<void> showTrackActions(BuildContext context, Music m) {
  final engine = Get.find<GlobalMusicController>();
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.queue_play_next_rounded), title: const Text('Play next'), onTap: () {
          Navigator.pop(sheet);
          engine.playNext(m);
        }),
        ListTile(leading: const Icon(Icons.add_to_queue_rounded), title: const Text('Add to queue'), onTap: () {
          Navigator.pop(sheet);
          engine.addToQueue(m);
        }),
        ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Add to a list'), onTap: () {
          Navigator.pop(sheet);
          showAddToListSheet(context, type: engine.kindOf(m).name, id: m.id, title: m.title, imageUrl: m.artworkUrl);
        }),
      ]),
    ),
  );
}
