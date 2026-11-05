// One-to-one chat, Snapchat style.
//
//   Messages are grouped under a coloured ME / NAME label with a side bar.
//   Tap a message to see its time; press and hold for reactions, Save in
//   chat, Reply, Copy and Delete. Swipe right to reply.
//   Saved messages are highlighted and kept; everything else deletes after
//   viewing (or 24 hours after, or never: the chat's setting).
//   Snaps open once. Leaving the chat marks what you saw as viewed.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';
import 'package:mango/Media/compose/mango_voice_recorder.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_list_screen.dart' show ChatColors;
import 'chat_service.dart';
import 'snap_viewer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.peerId});

  final String chatId;
  final String peerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _svc = ChatService.instance;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  ChatPerson? _peer;
  ChatMessage? _replyTo;
  String? _showTimeFor;
  double? _uploadProgress;
  UploadHandle? _upload;
  Timer? _presence;
  Timer? _typingOff;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.person(widget.peerId).then((p) {
      if (mounted) setState(() => _peer = p);
    });
    _here(true);
    _presence = Timer.periodic(const Duration(seconds: 30), (_) => _here(true));
  }

  void _here(bool here) => _svc.setPresence(widget.chatId, here: here, typing: here && _typing).catchError((_) {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _here(false);
      _svc.markViewed(widget.chatId).catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      _here(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presence?.cancel();
    _typingOff?.cancel();
    _here(false);
    // Leaving the chat: what you saw now counts as viewed.
    _svc.markViewed(widget.chatId).catchError((_) {});
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTyping(String v) {
    final now = v.trim().isNotEmpty;
    if (now != _typing) {
      _typing = now;
      _here(true);
    }
    _typingOff?.cancel();
    _typingOff = Timer(const Duration(seconds: 4), () {
      _typing = false;
      _here(true);
    });
    setState(() {});
  }

  Future<void> _sendText() async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    _onTyping('');
    try {
      await _svc.sendText(widget.chatId, t, replyTo: reply);
    } catch (_) {
      _text.text = t;
      if (mounted) MangoToast.show(context, message: "Couldn't send. Check your connection and try again.", kind: MangoToastKind.error);
    }
  }

  Future<void> _sendMedia({required bool asSnap, Set<ComposeKind> allow = const {ComposeKind.image, ComposeKind.video}}) async {
    final m = await MangoComposer.pick(context, allow: allow, actionLabel: asSnap ? 'Send Snap' : 'Send');
    if (m == null || !mounted) return;
    final handle = UploadHandle();
    setState(() {
      _upload = handle;
      _uploadProgress = 0;
    });
    try {
      await _svc.sendMedia(widget.chatId, m, asSnap: asSnap, handle: handle, onProgress: (p) {
        if (mounted) setState(() => _uploadProgress = p);
      });
      if (mounted) MangoAnnounce.polite(context, asSnap ? 'Snap sent' : 'Sent');
    } on UploadTooLarge catch (e) {
      if (mounted) MangoToast.show(context, message: e.message, kind: MangoToastKind.error);
    } catch (_) {
      if (mounted && !handle.cancelled) {
        MangoToast.show(context, message: "Couldn't send. Try again.", kind: MangoToastKind.error, actionLabel: 'Retry', onAction: () => _sendMedia(asSnap: asSnap, allow: allow));
      }
    } finally {
      if (mounted) {
        setState(() {
          _upload = null;
          _uploadProgress = null;
        });
      }
    }
  }

  void _actions(ChatMessage m) {
    HapticFeedback.mediumImpact();
    final mine = m.senderId == _svc.me;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(MangoSpace.s3),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final e in const ['❤️', '😂', '🔥', '😮', '😢', '👍'])
                MangoPressable(
                  semanticLabel: m.reactions[_svc.me] == e ? 'Remove reaction $e' : 'React $e',
                  onTap: () {
                    Navigator.pop(sheet);
                    _svc.react(widget.chatId, m.id, m.reactions[_svc.me] == e ? null : e).catchError((_) {});
                  },
                  child: Padding(padding: const EdgeInsets.all(MangoSpace.s2), child: Text(e, style: const TextStyle(fontSize: 28))),
                ),
            ]),
          ),
          if (m.kind != 'snap')
            ListTile(
              leading: Icon(m.saved ? Icons.bookmark_remove_rounded : Icons.bookmark_add_rounded),
              title: Text(m.saved ? 'Unsave in chat' : 'Save in chat'),
              subtitle: Text(m.saved ? 'It will delete like other chats' : 'Kept for both of you until unsaved'),
              onTap: () {
                Navigator.pop(sheet);
                _svc.toggleSave(widget.chatId, m.id).catchError((_) {});
                HapticFeedback.selectionClick();
              },
            ),
          ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Reply'), onTap: () {
            Navigator.pop(sheet);
            setState(() => _replyTo = m);
          }),
          if (m.kind == 'text')
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy'), onTap: () {
              Navigator.pop(sheet);
              Clipboard.setData(ClipboardData(text: m.text));
              MangoToast.show(context, message: 'Copied');
            }),
          if (mine)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: context.colors.error),
              title: Text('Delete', style: TextStyle(color: context.colors.error)),
              subtitle: const Text('Deletes it for both of you'),
              onTap: () {
                Navigator.pop(sheet);
                _svc.unsend(widget.chatId, m.id).catchError((_) {});
              },
            ),
        ]),
      ),
    );
  }

  void _settings(ChatSummary chat) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Delete chats…', style: context.type.titleLarge)),
          for (final (mode, title, sub) in const [
            ('after_viewing', 'After viewing', 'Chats delete once you both have seen them and left'),
            ('24h', '24 hours after viewing', 'Chats stay for a day after being seen'),
            ('keep', 'Never', 'Chats are kept until deleted'),
          ])
            RadioListTile<String>(
              value: mode,
              groupValue: chat.retention,
              title: Text(title),
              subtitle: Text(sub),
              onChanged: (v) {
                Navigator.pop(sheet);
                if (v != null) _svc.setRetention(widget.chatId, v).catchError((_) {});
              },
            ),
          const SizedBox(height: MangoSpace.s3),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    return StreamBuilder<ChatSummary?>(
      stream: _svc.chat(widget.chatId),
      builder: (context, chatSnap) {
        final chat = chatSnap.data;
        final (streak, hourglass) = chat?.streak ?? (0, false);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: (peer?.photo ?? '').isEmpty ? null : CachedNetworkImageProvider(peer!.photo),
                child: (peer?.photo ?? '').isEmpty ? Text((peer?.name ?? '?').isEmpty ? '?' : peer!.name[0].toUpperCase()) : null,
              ),
              const SizedBox(width: MangoSpace.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${peer?.name ?? ''}${streak > 0 ? '  $streak🔥${hourglass ? '⏳' : ''}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.titleMedium),
                  StreamBuilder<(bool, bool)>(
                    stream: _svc.peerPresence(widget.chatId, widget.peerId),
                    builder: (_, p) {
                      final (here, typing) = p.data ?? (false, false);
                      if (!here && !typing) return const SizedBox.shrink();
                      return Semantics(
                        liveRegion: true,
                        child: Row(children: [
                          Icon(Icons.circle, size: 8, color: context.colors.success),
                          const SizedBox(width: 4),
                          Text(typing ? 'typing…' : 'in the chat', style: context.type.bodySmall?.copyWith(color: context.colors.textSecondary)),
                        ]),
                      );
                    },
                  ),
                ]),
              ),
            ]),
            actions: [
              if (chat != null) MangoIconButton(icon: Icons.timer_outlined, semanticLabel: 'Chat settings: ${ChatService.retentionLabel(chat.retention)}', onPressed: () => _settings(chat)),
            ],
          ),
          body: Column(children: [
            if (chat != null)
              MangoPressable(
                semanticLabel: '${ChatService.retentionLabel(chat.retention)}. Change',
                onTap: () => _settings(chat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: MangoSpace.s1),
                  child: Text(ChatService.retentionLabel(chat.retention), textAlign: TextAlign.center, style: context.type.bodySmall?.copyWith(color: context.colors.textTertiary)),
                ),
              ),
            Expanded(child: _messages(context, chat)),
            if (_uploadProgress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4),
                child: Row(children: [
                  Expanded(child: LinearProgressIndicator(value: _uploadProgress, semanticsLabel: 'Sending')),
                  TextButton(onPressed: () => _upload?.cancel(), child: const Text('Cancel')),
                ]),
              ),
            if (_replyTo != null) _replyBar(context),
            _composer(context),
          ]),
        );
      },
    );
  }

  Widget _messages(BuildContext context, ChatSummary? chat) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _svc.messages(widget.chatId),
      builder: (context, snap) {
        final msgs = snap.data ?? const <ChatMessage>[];
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const MangoLoadingRegion(label: 'Loading chat', child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')));
        }
        if (msgs.isEmpty) {
          return MangoStateView(kind: MangoStateKind.empty, title: 'Say hi to ${_peer?.name ?? 'your friend'}', message: 'Send a chat, a Snap or a voice note.');
        }
        // Newest at the bottom; the list is reversed so it opens at the latest.
        final rev = msgs.reversed.toList();
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: MangoSpace.s2),
          itemCount: rev.length,
          itemBuilder: (context, i) {
            final m = rev[i];
            final older = i + 1 < rev.length ? rev[i + 1] : null;
            final startsGroup = older == null || older.senderId != m.senderId || older.kind == 'system' || m.at.difference(older.at).inMinutes > 10;
            final newDay = older == null || older.at.day != m.at.day;
            final isLastMine = m.senderId == _svc.me && rev.indexWhere((x) => x.senderId == _svc.me && x.kind != 'system') == i;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (newDay) _DayDivider(date: m.at),
              if (m.kind == 'system')
                _SystemLine(message: m, peerName: _peer?.name ?? '', me: _svc.me)
              else
                _MessageItem(
                  message: m,
                  me: _svc.me,
                  peerName: _peer?.name ?? 'Friend',
                  showHeader: startsGroup || newDay,
                  showTime: _showTimeFor == m.id,
                  receipt: isLastMine ? (m.viewedByOther(_svc.me) || (chat?.peerLastReadAt ?? 0) >= m.at.millisecondsSinceEpoch ? 'Opened' : (m.pending ? 'Sending…' : 'Delivered')) : null,
                  onTap: () => setState(() => _showTimeFor = _showTimeFor == m.id ? null : m.id),
                  onHold: () => _actions(m),
                  onReply: () => setState(() => _replyTo = m),
                  onOpenSnap: () => Get.to(() => SnapViewer(chatId: widget.chatId, message: m), fullscreenDialog: true),
                ),
            ]);
          },
        );
      },
    );
  }

  Widget _replyBar(BuildContext context) {
    final r = _replyTo!;
    final mine = r.senderId == _svc.me;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: MangoSpace.s3),
      padding: const EdgeInsets.all(MangoSpace.s2),
      decoration: BoxDecoration(
        color: context.colors.bgSecondary,
        border: Border(left: BorderSide(color: mine ? ChatColors.snap : ChatColors.chat, width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            'Replying to ${mine ? 'yourself' : _peer?.name ?? ''}: ${r.kind == 'text' ? r.text : r.kind}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.bodySmall,
          ),
        ),
        MangoIconButton(icon: Icons.close_rounded, semanticLabel: 'Cancel reply', onPressed: () => setState(() => _replyTo = null)),
      ]),
    );
  }

  Widget _composer(BuildContext context) {
    final hasText = _text.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(MangoSpace.s2, MangoSpace.s1, MangoSpace.s2, MangoSpace.s2),
        child: Row(children: [
          MangoIconButton(icon: Icons.photo_camera_rounded, semanticLabel: 'Send a Snap', onPressed: () => _sendMedia(asSnap: true)),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onChanged: _onTyping,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(
                hintText: 'Send a chat',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(MangoRadius.pill), borderSide: BorderSide.none),
                filled: true,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: MangoMotion.duration(context, MangoMotionTokens.fast),
            child: hasText
                ? MangoIconButton(key: const ValueKey('send'), icon: Icons.send_rounded, semanticLabel: 'Send', onPressed: _sendText)
                : Row(key: const ValueKey('tools'), mainAxisSize: MainAxisSize.min, children: [
                    MangoVoiceRecorderButton(onRecorded: (clip) async {
                      try {
                        await _svc.sendVoice(widget.chatId, clip);
                      } catch (_) {
                        if (mounted) MangoToast.show(context, message: "Couldn't send your voice note.", kind: MangoToastKind.error);
                      }
                    }),
                    PopupMenuButton<String>(
                      tooltip: 'Share',
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onSelected: (v) {
                        if (v == 'media') _sendMedia(asSnap: false);
                        if (v == 'file') _sendMedia(asSnap: false, allow: const {ComposeKind.file, ComposeKind.document, ComposeKind.audio});
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'media', child: ListTile(leading: Icon(Icons.photo_library_rounded), title: Text('Photo or video'))),
                        PopupMenuItem(value: 'file', child: ListTile(leading: Icon(Icons.attach_file_rounded), title: Text('File'))),
                      ],
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.me,
    required this.peerName,
    required this.showHeader,
    required this.showTime,
    required this.receipt,
    required this.onTap,
    required this.onHold,
    required this.onReply,
    required this.onOpenSnap,
  });

  final ChatMessage message;
  final String me;
  final String peerName;
  final bool showHeader;
  final bool showTime;
  final String? receipt;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback onReply;
  final VoidCallback onOpenSnap;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == me;
    final color = mine ? ChatColors.snap : ChatColors.chat;
    final c = context.colors;
    final time = TimeOfDay.fromDateTime(message.at).format(context);
    final reactions = message.reactions.values.toList();
    return Dismissible(
      key: ValueKey('swipe-${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        HapticFeedback.selectionClick();
        onReply();
        return false;
      },
      background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: MangoSpace.s4), child: Icon(Icons.reply_rounded, color: color)),
      child: Semantics(
        label: '${mine ? 'You' : peerName}, $time${message.saved ? ', saved' : ''}',
        onLongPressHint: 'message options',
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onHold,
          child: AnimatedOpacity(
            opacity: message.pending ? 0.6 : 1,
            duration: MangoMotion.duration(context, MangoMotionTokens.fast),
            child: Container(
              color: message.saved ? c.bgSecondary : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(MangoSpace.s4, 2, MangoSpace.s4, 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(top: MangoSpace.s2, bottom: 2),
                    child: Text(mine ? 'ME' : peerName.toUpperCase(), style: context.type.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ),
                Container(
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 2))),
                  padding: const EdgeInsets.only(left: MangoSpace.s2, top: 2, bottom: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (message.replyTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('↪ ${message.replyTo!['preview'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySmall?.copyWith(color: c.textTertiary)),
                      ),
                    _body(context, color),
                    if (message.saved)
                      Text('Saved in chat', style: context.type.labelSmall?.copyWith(color: c.textTertiary)),
                  ]),
                ),
                if (reactions.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(left: MangoSpace.s3, top: 2), child: Text(reactions.join(' '), style: const TextStyle(fontSize: 16))),
                if (showTime || receipt != null)
                  Padding(
                    padding: const EdgeInsets.only(left: MangoSpace.s3, top: 2),
                    child: Text([if (showTime) time, if (receipt != null) receipt!].join(' · '), style: context.type.labelSmall?.copyWith(color: c.textTertiary)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Color color) {
    final m = message;
    final media = m.media;
    switch (m.kind) {
      case 'snap':
        final mine = m.senderId == me;
        final opened = mine ? m.viewedByOther(me) : m.viewedBy.containsKey(me);
        final video = '${media?['mime'] ?? ''}'.startsWith('video/');
        final snapColor = video ? ChatColors.videoSnap : ChatColors.snap;
        final label = mine ? (opened ? 'Opened' : 'Delivered') : (opened ? 'Opened' : 'Tap to view');
        return MangoPressable(
          semanticLabel: '${video ? 'Video Snap' : 'Snap'}: $label',
          onTap: !mine && !opened ? onOpenSnap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MangoSpace.s1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(opened ? Icons.crop_square_rounded : Icons.square_rounded, color: snapColor, size: 22),
              const SizedBox(width: MangoSpace.s2),
              Text(label, style: context.type.bodyMedium?.copyWith(color: snapColor, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      case 'media':
        final url = '${media?['url'] ?? ''}';
        final video = '${media?['mime'] ?? ''}'.startsWith('video/');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MangoPressable(
            semanticLabel: video ? 'Video. Open' : 'Photo. Open',
            onTap: () => Get.to(() => SnapViewer.media(url: url, isVideo: video), fullscreenDialog: true),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MangoRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
                child: video
                    ? Container(width: 200, height: 140, color: Colors.black, child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48))
                    : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 720, placeholder: (_, __) => const MangoSkeleton(width: 200, height: 160)),
              ),
            ),
          ),
          if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.text)),
        ]);
      case 'voice':
        return _VoiceNote(media: media ?? const {}, color: color);
      case 'file':
        final name = '${media?['name'] ?? 'File'}';
        final size = ((media?['size'] ?? 0) as num) / (1024 * 1024);
        return MangoPressable(
          semanticLabel: 'File $name. Open',
          onTap: () => launchUrl(Uri.parse('${media?['url'] ?? ''}'), mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file_rounded, color: color),
            const SizedBox(width: MangoSpace.s2),
            Flexible(child: Text('$name · ${size.toStringAsFixed(1)} MB', overflow: TextOverflow.ellipsis)),
          ]),
        );
      default:
        return SelectableText(m.text, style: context.type.bodyLarge, onTap: onTap);
    }
  }
}

class _VoiceNote extends StatefulWidget {
  const _VoiceNote({required this.media, required this.color});

  final Map<String, dynamic> media;
  final Color color;

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  final AudioPlayer _p = AudioPlayer();
  bool _playing = false;
  double _progress = 0;
  double _speed = 1;

  int get _durationMs => ((widget.media['durationMs'] ?? 1) as num).toInt();
  List<double> get _wave => ((widget.media['waveform'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();

  @override
  void initState() {
    super.initState();
    _p.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _progress = (pos.inMilliseconds / _durationMs).clamp(0.0, 1.0).toDouble());
    });
    _p.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _playing = false;
        _progress = 0;
      });
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
      await _p.play(UrlSource('${widget.media['url']}'));
      await _p.setPlaybackRate(_speed);
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final secs = (_durationMs / 1000).round();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MangoIconButton(icon: _playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, semanticLabel: _playing ? 'Pause voice note' : 'Play voice note, $secs seconds', onPressed: _toggle),
      SizedBox(width: 150, height: 28, child: CustomPaint(painter: WaveformPainter(_wave.isEmpty ? List.filled(32, 0.3) : _wave, widget.color, progress: _progress))),
      const SizedBox(width: MangoSpace.s2),
      Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', style: context.type.labelMedium),
      TextButton(
        onPressed: () {
          setState(() => _speed = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2 : 1));
          _p.setPlaybackRate(_speed);
        },
        child: Text('${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x'),
      ),
    ]);
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final label = d == today ? 'TODAY' : (today.difference(d).inDays == 1 ? 'YESTERDAY' : '${date.day}/${date.month}/${date.year}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MangoSpace.s2),
      child: Semantics(header: true, child: Text(label, textAlign: TextAlign.center, style: context.type.labelSmall?.copyWith(color: context.colors.textTertiary, letterSpacing: 1))),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.message, required this.peerName, required this.me});

  final ChatMessage message;
  final String peerName;
  final String me;

  @override
  Widget build(BuildContext context) {
    final who = message.senderId == me ? 'You' : peerName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MangoSpace.s1, horizontal: MangoSpace.s6),
      child: Text('$who ${message.text}', textAlign: TextAlign.center, style: context.type.bodySmall?.copyWith(color: context.colors.textTertiary, fontStyle: FontStyle.italic)),
    );
  }
}
