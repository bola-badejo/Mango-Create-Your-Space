// Chat list, Snapchat style: each friend shows what happened last as a
// coloured icon (red = Snap, purple = video Snap, blue = chat; filled = new,
// outlined = opened or delivered), how long ago, and the streak.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Media/compose/mango_composer.dart';

import 'chat_screen.dart';
import 'chat_service.dart';

/// Snapchat's status colours.
class ChatColors {
  static const snap = Color(0xFFF23C57);
  static const videoSnap = Color(0xFF9B55A0);
  static const chat = Color(0xFF0EADFF);
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _svc = ChatService.instance;
  String _filter = '';

  Future<void> _openChat(String peerId) async {
    try {
      final chatId = await _svc.open(peerId);
      if (!mounted) return;
      await Get.to(() => ChatScreen(chatId: chatId, peerId: peerId));
    } catch (e) {
      if (mounted) MangoToast.show(context, message: e.toString(), kind: MangoToastKind.error);
    }
  }

  Future<void> _quickSnap(String chatId) async {
    final m = await MangoComposer.pick(context, allow: const {ComposeKind.image, ComposeKind.video}, actionLabel: 'Send Snap');
    if (m == null || !mounted) return;
    try {
      await _svc.sendMedia(chatId, m, asSnap: true);
      if (mounted) MangoToast.show(context, message: 'Snap sent', kind: MangoToastKind.success);
    } catch (e) {
      if (mounted) MangoToast.show(context, message: "Couldn't send your Snap. ${e.toString()}", kind: MangoToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat', style: context.type.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          MangoIconButton(icon: Icons.person_add_alt_1_rounded, semanticLabel: 'New chat', onPressed: () => _startNewChat(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-chat',
        tooltip: 'New chat',
        onPressed: () => _startNewChat(context),
        child: const Icon(Icons.chat_rounded),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(MangoSpace.s4, 0, MangoSpace.s4, MangoSpace.s2),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search', isDense: true),
            onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: _svc.chats(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return MangoLoadingRegion(label: 'Loading chats', child: ListView(children: List.generate(6, (_) => const _RowSkeleton())));
              }
              final chats = snap.data ?? const <ChatSummary>[];
              if (chats.isEmpty) {
                return MangoStateView(kind: MangoStateKind.empty, title: 'No chats yet', message: 'Say hi to someone you follow, or meet people in Spaces.', actionLabel: 'New chat', onAction: () => _startNewChat(context));
              }
              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, i) => _ChatRow(
                  summary: chats[i],
                  filter: _filter,
                  onOpen: () => Get.to(() => ChatScreen(chatId: chats[i].id, peerId: chats[i].peerId)),
                  onSnap: () => _quickSnap(chats[i].id),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _startNewChat(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const _NewChatSheet());
    if (picked != null) await _openChat(picked);
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.summary, required this.filter, required this.onOpen, required this.onSnap});

  final ChatSummary summary;
  final String filter;
  final VoidCallback onOpen;
  final VoidCallback onSnap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatPerson>(
      future: ChatService.instance.person(summary.peerId),
      builder: (context, p) {
        final person = p.data;
        if (person == null) return const _RowSkeleton();
        if (filter.isNotEmpty && !person.name.toLowerCase().contains(filter) && !person.username.toLowerCase().contains(filter)) {
          return const SizedBox.shrink();
        }
        final status = summary.status;
        final (streak, hourglass) = summary.streak;
        final (icon, color, label) = _statusVisual(status, summary);
        final isNew = status == ChatStatus.newChat || status == ChatStatus.newSnap;
        final ago = summary.lastAt == 0 ? '' : _ago(DateTime.fromMillisecondsSinceEpoch(summary.lastAt));
        return MangoAppear(
          child: ListTile(
            onTap: onOpen,
            leading: _Avatar(person: person, size: 48),
            title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.titleMedium?.copyWith(fontWeight: isNew ? FontWeight.w700 : FontWeight.w500)),
            subtitle: Semantics(
              label: '$label${ago.isEmpty ? '' : ', $ago ago'}${streak > 0 ? ', $streak day streak${hourglass ? ', ending soon' : ''}' : ''}',
              child: ExcludeSemantics(
                child: Row(children: [
                  if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodySmall?.copyWith(color: isNew ? color : context.colors.textSecondary, fontWeight: isNew ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                  if (ago.isNotEmpty) Text(' · $ago', style: context.type.bodySmall?.copyWith(color: context.colors.textTertiary)),
                  if (streak > 0) Text(' · $streak🔥${hourglass ? '⏳' : ''}', style: context.type.bodySmall),
                ]),
              ),
            ),
            trailing: MangoIconButton(icon: Icons.photo_camera_outlined, semanticLabel: 'Send ${person.name} a Snap', onPressed: onSnap),
          ),
        );
      },
    );
  }

  static (IconData?, Color, String) _statusVisual(ChatStatus s, ChatSummary c) {
    final video = (c.last?['preview'] ?? '').toString().contains('video');
    final snapColor = video ? ChatColors.videoSnap : ChatColors.snap;
    return switch (s) {
      ChatStatus.newSnap => (Icons.square_rounded, snapColor, video ? 'New video Snap' : 'New Snap'),
      ChatStatus.newChat => (Icons.chat_bubble_rounded, ChatColors.chat, 'New Chat'),
      ChatStatus.snapDelivered => (Icons.near_me_rounded, snapColor, 'Delivered'),
      ChatStatus.chatDelivered => (Icons.near_me_rounded, ChatColors.chat, 'Delivered'),
      ChatStatus.snapOpened => (Icons.near_me_outlined, snapColor, 'Opened'),
      ChatStatus.chatOpened => (Icons.near_me_outlined, ChatColors.chat, 'Opened'),
      ChatStatus.snapReceived => (Icons.crop_square_rounded, snapColor, 'Received'),
      ChatStatus.chatReceived => (Icons.chat_bubble_outline_rounded, ChatColors.chat, 'Received'),
      ChatStatus.none => (null, ChatColors.chat, 'Tap to chat'),
    };
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person, this.size = 40});

  final ChatPerson person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = person.name.isEmpty ? '?' : person.name[0].toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: context.colors.surfaceSelected,
        backgroundImage: person.photo.isEmpty ? null : CachedNetworkImageProvider(person.photo),
        child: person.photo.isEmpty ? Text(initial, style: context.type.titleMedium) : null,
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) => const ListTile(
        leading: MangoSkeleton(width: 48, height: 48, circle: true),
        title: MangoSkeleton(width: 140, height: 14),
        subtitle: Padding(padding: EdgeInsets.only(top: 6), child: MangoSkeleton(width: 90, height: 10)),
      );
}

/// Start a chat: search people by name or username.
class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<ChatPerson> _results = const [];
  bool _loading = false;

  Future<void> _search(String q) async {
    final query = q.trim().toLowerCase();
    if (query.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final col = FirebaseFirestore.instance.collection('users');
      final byUsername = await col.orderBy('username').startAt([query]).endAt(['$query\uf8ff']).limit(15).get();
      final me = ChatService.instance.me;
      setState(() => _results = byUsername.docs.where((d) => d.id != me).map((d) => ChatPerson.fromUser(d.id, d.data())).toList());
    } catch (_) {
      setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(MangoSpace.s4),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Find people by username'),
              onChanged: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(semanticsLabel: 'Searching'),
          Expanded(
            child: ListView(children: [
              for (final p in _results)
                ListTile(
                  leading: _Avatar(person: p),
                  title: Text(p.name),
                  subtitle: p.username.isEmpty ? null : Text('@${p.username}'),
                  onTap: () => Navigator.pop(context, p.uid),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
