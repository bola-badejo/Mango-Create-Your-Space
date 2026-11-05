// Live audio and video for a Space event, on LiveKit.
//
// Joining asks the server for a token, which it issues only while the event
// is live and only to people allowed into the Space. What you can do is
// built into that signed token:
//   host:     camera, microphone, screen share, and managing speakers
//   speaker:  camera and microphone (invited by the host)
//   listener: watch and listen; raise your hand to ask to speak
// Cameras and microphones stay off until you turn them on.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

import 'space_world_service.dart';

class SpaceLiveStage extends StatefulWidget {
  const SpaceLiveStage({super.key, required this.svc, required this.eventId, required this.isHost});

  final SpaceWorldService svc;
  final String eventId;
  final bool isHost;

  @override
  State<SpaceLiveStage> createState() => _SpaceLiveStageState();
}

class _SpaceLiveStageState extends State<SpaceLiveStage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String _role = 'listener';
  bool _connecting = false;
  String? _error;
  bool _handRaised = false;
  bool _screenSharing = false;
  StreamSubscription<SpaceEvent?>? _eventSub;

  bool get _canPublish => _room?.localParticipant?.permissions.canPublish ?? false;

  @override
  void initState() {
    super.initState();
    // If the host invites us up while we are connected, the server updates
    // our permissions live. If we joined before that could apply, reconnect.
    _eventSub = widget.svc.event(widget.eventId).listen((e) {
      final me = widget.svc.uid;
      if (e == null || me == null || _room == null) return;
      final invited = e.speakers.contains(me);
      if (invited && _role == 'listener' && !_canPublish) _reconnect();
      if (!invited && _role == 'speaker') _reconnect();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    unawaited(_disconnect());
    super.dispose();
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _join() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final t = await widget.svc.liveToken(widget.eventId);
      final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      final listener = room.createListener();
      listener
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) setState(() => _room = null);
        })
        ..on<ParticipantPermissionsUpdatedEvent>((e) {
          if (e.participant is LocalParticipant) {
            final can = e.participant.permissions.canPublish;
            if (mounted) {
              setState(() => _role = can ? (_role == 'host' ? 'host' : 'speaker') : 'listener');
              MangoAnnounce.polite(context, can ? 'You can speak now' : 'You are back in the audience');
              if (can) MangoToast.show(context, message: "You're invited to speak. Turn on your mic when ready.", kind: MangoToastKind.success);
            }
            if (!can) {
              unawaited(room.localParticipant?.setMicrophoneEnabled(false));
              unawaited(room.localParticipant?.setCameraEnabled(false));
            }
          }
        });
      room.addListener(_onRoomChanged);
      await room.connect(t['url'] as String, t['token'] as String);
      // Browsers only play audio after a user action; this runs from the tap.
      await room.startAudio();
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _listener = listener;
        _role = (t['role'] ?? 'listener') as String;
      });
      MangoAnnounce.polite(context, 'Connected to live audio');
    } on LedgerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't connect to live audio. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    }
    await listener?.dispose();
  }

  Future<void> _reconnect() async {
    await _disconnect();
    if (mounted) await _join();
  }

  Future<void> _toggleMic() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setMicrophoneEnabled(!lp.isMicrophoneEnabled());
    } catch (_) {
      _permissionHelp('microphone');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setCameraEnabled(!lp.isCameraEnabled());
    } catch (_) {
      _permissionHelp('camera');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleScreen() async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.setScreenShareEnabled(!_screenSharing);
      if (mounted) setState(() => _screenSharing = !_screenSharing);
    } catch (_) {
      if (mounted) MangoToast.show(context, message: "Screen sharing isn't available on this device.", kind: MangoToastKind.error);
    }
  }

  void _permissionHelp(String what) {
    if (!mounted) return;
    MangoToast.show(
      context,
      message: "Mango can't use your $what. Allow access in your ${kIsWeb ? 'browser' : 'device'} settings, then try again.",
      kind: MangoToastKind.error,
    );
  }

  Future<void> _toggleHand() async {
    final next = !_handRaised;
    setState(() => _handRaised = next);
    try {
      await widget.svc.setHandRaised(widget.eventId, next);
      if (mounted) MangoAnnounce.polite(context, next ? 'Hand raised' : 'Hand lowered');
    } catch (_) {
      if (mounted) setState(() => _handRaised = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final room = _room;
    if (room == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
        padding: const EdgeInsets.all(MangoSpace.s4),
        decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(MangoRadius.lg), border: Border.all(color: c.borderSubtle)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ExcludeSemantics(child: Icon(Icons.videocam_rounded, color: c.textBrand)),
            const SizedBox(width: MangoSpace.s2),
            Expanded(child: Text('Live audio and video', style: context.type.titleMedium)),
          ]),
          const SizedBox(height: MangoSpace.s2),
          Text(
            widget.isHost
                ? "You're the host. Join to go on camera or mic; you choose who else speaks."
                : 'Watch and listen. Your camera and mic stay off; raise your hand to ask to speak.',
            style: context.type.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: MangoSpace.s2),
            Semantics(liveRegion: true, child: Text(_error!, style: context.type.bodyMedium?.copyWith(color: c.error))),
          ],
          const SizedBox(height: MangoSpace.s3),
          MangoButton(label: _connecting ? 'Connecting…' : 'Join live', icon: Icons.headphones_rounded, expand: true, onPressed: _connecting ? null : _join),
        ]),
      );
    }

    final lp = room.localParticipant;
    final people = <Participant>[if (lp != null) lp, ...room.remoteParticipants.values];
    // Speakers (anyone publishing) on stage; everyone else is the audience.
    final onStage = people.where((p) => p.permissions.canPublish || p.isSpeaking).toList();
    final audience = people.length - onStage.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
        child: Text('On stage · $audience listening', style: context.type.labelLarge?.copyWith(color: c.textSecondary)),
      ),
      const SizedBox(height: MangoSpace.s2),
      SizedBox(
        height: 170,
        child: onStage.isEmpty
            ? Center(child: Text('Waiting for the host to start…', style: context.type.bodyMedium))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
                scrollDirection: Axis.horizontal,
                itemCount: onStage.length,
                separatorBuilder: (_, __) => const SizedBox(width: MangoSpace.s3),
                itemBuilder: (_, i) => _ParticipantTile(participant: onStage[i], isLocal: onStage[i] == lp),
              ),
      ),
      const SizedBox(height: MangoSpace.s3),
      Wrap(alignment: WrapAlignment.center, spacing: MangoSpace.s2, children: [
        if (_canPublish) ...[
          MangoIconButton(
            icon: (lp?.isMicrophoneEnabled() ?? false) ? Icons.mic_rounded : Icons.mic_off_rounded,
            semanticLabel: (lp?.isMicrophoneEnabled() ?? false) ? 'Mute microphone' : 'Unmute microphone',
            selected: lp?.isMicrophoneEnabled() ?? false,
            onPressed: _toggleMic,
          ),
          MangoIconButton(
            icon: (lp?.isCameraEnabled() ?? false) ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            semanticLabel: (lp?.isCameraEnabled() ?? false) ? 'Turn camera off' : 'Turn camera on',
            selected: lp?.isCameraEnabled() ?? false,
            onPressed: _toggleCamera,
          ),
          if (_role == 'host')
            MangoIconButton(
              icon: Icons.screen_share_rounded,
              semanticLabel: _screenSharing ? 'Stop sharing screen' : 'Share screen',
              selected: _screenSharing,
              onPressed: _toggleScreen,
            ),
        ] else
          MangoIconButton(
            icon: Icons.back_hand_rounded,
            semanticLabel: _handRaised ? 'Lower hand' : 'Raise hand to speak',
            selected: _handRaised,
            onPressed: _toggleHand,
          ),
        MangoIconButton(icon: Icons.call_end_rounded, semanticLabel: 'Leave live audio', onPressed: () async {
          await _disconnect();
          if (mounted) setState(() {});
        }),
      ]),
      if (widget.isHost) _HostPanel(svc: widget.svc, eventId: widget.eventId),
    ]);
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.isLocal});

  final Participant participant;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    VideoTrack? video;
    for (final pub in participant.videoTrackPublications) {
      final track = pub.track;
      if (track is VideoTrack && !pub.muted && pub.source == TrackSource.camera) video = track;
    }
    for (final pub in participant.videoTrackPublications) {
      final track = pub.track;
      if (track is VideoTrack && !pub.muted && pub.source == TrackSource.screenShareVideo) video = track;
    }
    final name = participant.name.isNotEmpty ? participant.name : 'Guest';
    final micOn = participant.isMicrophoneEnabled();
    return Semantics(
      label: '${isLocal ? 'You' : name}${participant.isSpeaking ? ', speaking' : ''}${micOn ? '' : ', muted'}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: MangoMotion.duration(context, MangoMotionTokens.fast),
          width: 130,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(MangoRadius.md),
            border: Border.all(color: participant.isSpeaking ? c.actionPrimary : c.borderSubtle, width: participant.isSpeaking ? 3 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            if (video != null)
              VideoTrackRenderer(video, fit: VideoViewFit.cover)
            else
              Center(
                child: CircleAvatar(radius: 30, child: Text(name[0].toUpperCase(), style: context.type.headlineSmall)),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  Icon(micOn ? Icons.mic_rounded : Icons.mic_off_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Expanded(child: Text(isLocal ? 'You' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.labelMedium?.copyWith(color: Colors.white))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Host controls: raised hands and current speakers.
class _HostPanel extends StatelessWidget {
  const _HostPanel({required this.svc, required this.eventId});

  final SpaceWorldService svc;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpaceEvent?>(
      stream: svc.event(eventId),
      builder: (context, ev) {
        final speakers = ev.data?.speakers ?? const <String>[];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: svc.attendees(eventId),
          builder: (context, snap) {
            final all = snap.data ?? const <Map<String, dynamic>>[];
            final hands = all.where((a) => a['handRaised'] == true && !speakers.contains(a['uid'])).toList();
            final onStage = all.where((a) => speakers.contains(a['uid'])).toList();
            if (hands.isEmpty && onStage.isEmpty) return const SizedBox.shrink();
            void err(Object e) => MangoToast.show(context, message: e.toString(), kind: MangoToastKind.error);
            return Padding(
              padding: const EdgeInsets.fromLTRB(MangoSpace.s4, MangoSpace.s3, MangoSpace.s4, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (hands.isNotEmpty) Text('Raised hands', style: context.type.titleSmall),
                for (final a in hands)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.back_hand_rounded),
                    title: Text('${a['name'] ?? 'Guest'}'),
                    trailing: MangoButton(label: 'Invite to speak', size: MangoButtonSize.medium, onPressed: () => svc.setSpeaker(eventId, '${a['uid']}', true), onError: err),
                  ),
                if (onStage.isNotEmpty) Text('Speakers', style: context.type.titleSmall),
                for (final a in onStage)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.record_voice_over_rounded),
                    title: Text('${a['name'] ?? 'Guest'}'),
                    trailing: MangoButton(
                      label: 'Move to audience',
                      size: MangoButtonSize.medium,
                      variant: MangoButtonVariant.tertiary,
                      onPressed: () => svc.setSpeaker(eventId, '${a['uid']}', false),
                      onError: err,
                    ),
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}
