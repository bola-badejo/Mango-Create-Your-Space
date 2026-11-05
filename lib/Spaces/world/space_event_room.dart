// A live event inside a Space: the stage, who is here, and live chat.
// Chat opens only while the event is live (enforced by Firestore rules);
// the host starts and ends it through the server.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';

import 'space_live_stage.dart';
import 'space_world_service.dart';

class SpaceEventRoom extends StatefulWidget {
  const SpaceEventRoom({super.key, required this.spaceId, required this.eventId});

  final String spaceId;
  final String eventId;

  @override
  State<SpaceEventRoom> createState() => _SpaceEventRoomState();
}

class _SpaceEventRoomState extends State<SpaceEventRoom> {
  late final SpaceWorldService _svc = SpaceWorldService(widget.spaceId);
  final _text = TextEditingController();
  static const _reactions = ['👏', '🔥', '❤️', '😂', '🥭'];

  @override
  void initState() {
    super.initState();
    _svc.attend(widget.eventId).catchError((_) {});
  }

  @override
  void dispose() {
    _svc.leaveEvent(widget.eventId).catchError((_) {});
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _svc.sendEventChat(widget.eventId, text);
    } catch (_) {
      if (mounted) MangoToast.show(context, message: 'Chat opens when the event is live.', kind: MangoToastKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<SpaceEvent?>(
      stream: _svc.event(widget.eventId),
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return Scaffold(appBar: AppBar(), body: const MangoLoadingRegion(label: 'Loading event', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))));
        }
        final isHost = e.hostId == _svc.uid;
        return Scaffold(
          appBar: AppBar(title: Text(e.title, overflow: TextOverflow.ellipsis)),
          body: SafeArea(
            child: Column(children: [
              Container(
                margin: const EdgeInsets.all(MangoSpace.s4),
                padding: const EdgeInsets.all(MangoSpace.s4),
                decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(MangoRadius.lg)),
                child: Row(children: [
                  const ExcludeSemantics(child: Text('🎤', style: TextStyle(fontSize: 40))),
                  const SizedBox(width: MangoSpace.s4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(
                        liveRegion: true,
                        child: Row(children: [
                          Icon(Icons.circle, size: 10, color: e.isLive ? c.error : c.textTertiary),
                          const SizedBox(width: MangoSpace.s1),
                          Text(e.isLive ? 'Live' : (e.status == 'ended' ? 'Ended' : 'Not started yet'), style: context.type.labelLarge),
                        ]),
                      ),
                      if (e.description.isNotEmpty) Text(e.description, style: context.type.bodyMedium),
                      StreamBuilder<int>(
                        stream: _svc.attendeeCount(widget.eventId),
                        builder: (_, n) => Text('${n.data ?? 0} here', style: context.type.bodySmall?.copyWith(color: c.textSecondary)),
                      ),
                    ]),
                  ),
                  if (isHost && e.status == 'scheduled')
                    MangoButton(label: 'Go live', size: MangoButtonSize.medium, onPressed: () => _svc.setEventStatus(e.id, 'live')),
                  if (isHost && e.isLive)
                    MangoButton(label: 'End', size: MangoButtonSize.medium, variant: MangoButtonVariant.destructive, onPressed: () async {
                      await _svc.setEventStatus(e.id, 'ended');
                      Get.back();
                    }),
                ]),
              ),
              // Live audio and video, available while the event is live.
              if (e.isLive) SpaceLiveStage(svc: _svc, eventId: e.id, isHost: isHost),
              Expanded(
                child: StreamBuilder<List<SpaceMessage>>(
                  stream: _svc.eventChat(widget.eventId),
                  builder: (context, chat) {
                    final msgs = chat.data ?? const <SpaceMessage>[];
                    if (msgs.isEmpty) {
                      return MangoStateView(kind: MangoStateKind.empty, title: e.isLive ? 'Say hi' : 'Chat opens when the event goes live', message: e.isLive ? 'Messages appear here for everyone.' : 'Stay here; it starts automatically.');
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final big = _reactions.contains(m.text);
                        return MangoAppear(
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage: (m.authorPhoto ?? '').isNotEmpty ? CachedNetworkImageProvider(m.authorPhoto!) : null,
                              child: (m.authorPhoto ?? '').isEmpty ? Text(m.authorName[0].toUpperCase()) : null,
                            ),
                            title: Text(m.authorName, style: context.type.labelLarge),
                            subtitle: Text(m.text, style: big ? const TextStyle(fontSize: 28) : context.type.bodyMedium),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (e.isLive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s3),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    for (final r in _reactions)
                      MangoPressable(
                        semanticLabel: 'React $r',
                        onTap: () => _send(r),
                        child: Padding(padding: const EdgeInsets.all(MangoSpace.s2), child: Text(r, style: const TextStyle(fontSize: 26))),
                      ),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.all(MangoSpace.s3),
                child: Row(children: [
                  Expanded(
                    child: MangoTextField(
                      label: e.isLive ? 'Chat' : 'Chat opens when live',
                      controller: _text,
                      enabled: e.isLive,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (v) {
                        _text.clear();
                        _send(v);
                      },
                    ),
                  ),
                  const SizedBox(width: MangoSpace.s2),
                  MangoIconButton(
                    icon: Icons.send_rounded,
                    semanticLabel: 'Send',
                    onPressed: e.isLive
                        ? () {
                            final v = _text.text;
                            _text.clear();
                            _send(v);
                          }
                        : null,
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
