// Notification centre.
//
//   Today / This week / Earlier, unread first in each, All or Unread.
//   Tap to open what it's about; swipe to delete; mark all read.
//   Settings: choose what you hear about, turn pushes off, mute for 8 hours,
//   and send yourself a test.
// Notifications are created by the server (functions/notify); older entries
// written by previous versions still display.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mango/Core/design_system/mango_ui.dart';
import 'package:mango/Notifications/notification_router.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _Item {
  _Item(this.id, this.d);

  final String id;
  final Map<String, dynamic> d;

  String get type => '${d['type'] ?? ''}';
  String get title => '${d['title'] ?? d['message'] ?? ''}';
  String get body => '${d['body'] ?? (d['title'] != null ? d['message'] ?? '' : '')}';
  bool get read => d['isRead'] == true;
  String? get image => (d['imageUrl'] ?? '').toString().isEmpty ? null : '${d['imageUrl']}';
  Map<String, dynamic>? get target => d['target'] is Map ? Map<String, dynamic>.from(d['target'] as Map) : null;
  DateTime get at {
    final t = d['timestamp'] ?? d['time'];
    if (t is Timestamp) return t.toDate();
    if (t is int) return DateTime.fromMillisecondsSinceEpoch(t);
    final ms = d['updatedMs'];
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications');
  }

  Future<void> _markAllRead() async {
    final col = _col;
    if (col == null) return;
    final unread = await col.where('isRead', isEqualTo: false).limit(400).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
    if (mounted) MangoAnnounce.polite(context, 'All marked as read');
  }

  Future<void> _open(_Item n) async {
    if (!n.read) await _col?.doc(n.id).update({'isRead': true}).catchError((_) {});
    final t = n.target;
    if (t != null) {
      await NotificationRouter.open('${t['kind'] ?? ''}', '${t['id'] ?? ''}');
    } else {
      // Older notifications.
      await NotificationRouter.openFromPush({...n.d, 'type': n.type, 'id': n.d['pageId'] ?? n.d['${n.type}Id'] ?? ''});
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _col;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          MangoIconButton(icon: Icons.done_all_rounded, semanticLabel: 'Mark all as read', onPressed: _markAllRead),
          MangoIconButton(icon: Icons.tune_rounded, semanticLabel: 'Notification settings', onPressed: () => _settings(context)),
        ],
      ),
      body: col == null
          ? const MangoStateView(kind: MangoStateKind.permissionDenied, title: 'Sign in to see notifications', message: '')
          : Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4, vertical: MangoSpace.s2),
                child: Row(children: [
                  ChoiceChip(label: const Text('All'), selected: !_unreadOnly, onSelected: (_) => setState(() => _unreadOnly = false)),
                  const SizedBox(width: MangoSpace.s2),
                  ChoiceChip(label: const Text('Unread'), selected: _unreadOnly, onSelected: (_) => setState(() => _unreadOnly = true)),
                ]),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: col.orderBy('timestamp', descending: true).limit(200).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return const MangoStateView(kind: MangoStateKind.error, title: "Couldn't load notifications", message: 'Check your connection and try again.');
                    if (!snap.hasData) {
                      return MangoLoadingRegion(label: 'Loading notifications', child: ListView(children: List.generate(6, (_) => const ListTile(leading: MangoSkeleton(width: 44, height: 44, circle: true), title: MangoSkeleton(width: 180, height: 14)))));
                    }
                    var items = snap.data!.docs.map((d) => _Item(d.id, d.data())).toList();
                    if (_unreadOnly) items = items.where((n) => !n.read).toList();
                    if (items.isEmpty) {
                      return MangoStateView(kind: MangoStateKind.empty, title: _unreadOnly ? "You're all caught up" : 'No notifications yet', message: 'Likes, replies, follows and updates on what you share appear here.');
                    }
                    final now = DateTime.now();
                    String section(DateTime t) {
                      final d = now.difference(t);
                      if (d.inHours < 24 && t.day == now.day) return 'Today';
                      if (d.inDays < 7) return 'This week';
                      return 'Earlier';
                    }
                    final rows = <Widget>[];
                    String? current;
                    for (var i = 0; i < items.length; i++) {
                      final s = section(items[i].at);
                      if (s != current) {
                        current = s;
                        rows.add(Padding(
                          padding: const EdgeInsets.fromLTRB(MangoSpace.s4, MangoSpace.s4, MangoSpace.s4, MangoSpace.s1),
                          child: Semantics(header: true, child: Text(s, style: context.type.titleSmall?.copyWith(color: context.colors.textSecondary))),
                        ));
                      }
                      rows.add(_Row(item: items[i], index: i, onOpen: _open, onDelete: (n) => col.doc(n.id).delete()));
                    }
                    return ListView(padding: const EdgeInsets.only(bottom: MangoSpace.s8), children: rows);
                  },
                ),
              ),
            ]),
    );
  }

  Future<void> _settings(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (sheet, snap) {
          final d = snap.data?.data() ?? const <String, dynamic>{};
          final prefs = Map<String, dynamic>.from((d['notificationPrefs'] as Map?) ?? const {});
          final pushOn = d['notificationsEnabled'] != false;
          final muteUntil = d['muteUntil'];
          final muted = muteUntil is Timestamp && muteUntil.toDate().isAfter(DateTime.now());
          Widget toggle(String key, String title, String sub) => SwitchListTile(
                title: Text(title),
                subtitle: Text(sub),
                value: prefs[key] != false,
                onChanged: (v) => ref.set({'notificationPrefs': {key: v}}, SetOptions(merge: true)),
              );
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheet).height * 0.85,
              child: ListView(children: [
                Padding(padding: const EdgeInsets.all(MangoSpace.s4), child: Text('Notification settings', style: sheet.type.titleLarge)),
                SwitchListTile(
                  title: const Text('Push notifications'),
                  subtitle: const Text('Alerts on this device. The notification centre always fills.'),
                  value: pushOn,
                  onChanged: (v) => ref.set({'notificationsEnabled': v}, SetOptions(merge: true)),
                ),
                SwitchListTile(
                  title: const Text('Mute for 8 hours'),
                  subtitle: Text(muted ? 'Muted until ${TimeOfDay.fromDateTime((muteUntil as Timestamp).toDate()).format(sheet)}' : 'Pause pushes for a while'),
                  value: muted,
                  onChanged: (v) => ref.set({'muteUntil': v ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 8))) : null}, SetOptions(merge: true)),
                ),
                const Divider(),
                toggle('likes', 'Likes', 'When people like your posts'),
                toggle('comments', 'Replies and mentions', 'When people reply to or mention you'),
                toggle('follows', 'New followers', 'When someone follows you'),
                toggle('spaces', 'Spaces', 'Messages in your Spaces and live events in Spaces you joined'),
                toggle('content', 'Your content', 'Milestones when people play, watch and read what you share'),
                toggle('reading', 'Pick up where you left off', 'Reminders for books, episodes and films you started'),
                toggle('account', 'Account and tips', 'Welcome, profile and important account updates'),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Send a test notification'),
                  onTap: () async {
                    try {
                      await MangoLedgerClient.instance.call('notifyTest');
                      if (sheet.mounted) MangoToast.show(sheet, message: 'Test sent', kind: MangoToastKind.success);
                    } catch (e) {
                      if (sheet.mounted) MangoToast.show(sheet, message: e.toString(), kind: MangoToastKind.error);
                    }
                  },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.index, required this.onOpen, required this.onDelete});

  final _Item item;
  final int index;
  final Future<void> Function(_Item) onOpen;
  final Future<void> Function(_Item) onDelete;

  static (IconData, Color) _visual(String type, BuildContext context) {
    final c = context.colors;
    return switch (type) {
      'like' => (Icons.favorite_rounded, const Color(0xFFE5484D)),
      'reply' || 'mention' || 'post' => (Icons.chat_bubble_rounded, c.textBrand),
      'follow' || 'profile' => (Icons.person_add_alt_1_rounded, const Color(0xFF0EADFF)),
      'space_message' || 'space_live' => (Icons.meeting_room_rounded, const Color(0xFF9B55A0)),
      'content_milestone' => (Icons.emoji_events_rounded, const Color(0xFFF5A524)),
      'reading_reminder' || 'book' => (Icons.menu_book_rounded, c.textBrand),
      'song' => (Icons.music_note_rounded, c.textBrand),
      'chat' => (Icons.chat_rounded, const Color(0xFF0EADFF)),
      'welcome' => (Icons.waving_hand_rounded, const Color(0xFFF5A524)),
      'complete_profile' => (Icons.badge_rounded, c.actionPrimary),
      _ => (Icons.notifications_rounded, c.textSecondary),
    };
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = _visual(item.type, context);
    return MangoAppear.staggered(
      index: index,
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(color: c.errorContainer, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: MangoSpace.s6), child: Icon(Icons.delete_outline_rounded, color: c.error)),
        onDismissed: (_) => onDelete(item),
        child: Semantics(
          label: '${item.read ? '' : 'Unread. '}${item.title}. ${item.body}. ${_ago(item.at)} ago',
          button: true,
          child: ExcludeSemantics(
            child: Material(
              color: item.read ? Colors.transparent : c.surfaceSelected.withValues(alpha: 0.5),
              child: InkWell(
                onTap: () => onOpen(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s4, vertical: MangoSpace.s3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withValues(alpha: 0.15),
                        backgroundImage: item.image == null ? null : CachedNetworkImageProvider(item.image!),
                        child: item.image == null ? Icon(icon, color: color, size: 22) : null,
                      ),
                      if (item.image != null)
                        Positioned(right: -2, bottom: -2, child: CircleAvatar(radius: 10, backgroundColor: c.bgPrimary, child: Icon(icon, size: 12, color: color))),
                    ]),
                    const SizedBox(width: MangoSpace.s3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.title, style: context.type.bodyLarge?.copyWith(fontWeight: item.read ? FontWeight.w400 : FontWeight.w700)),
                        if (item.body.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.bodyMedium?.copyWith(color: c.textSecondary))),
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(_ago(item.at), style: context.type.labelSmall?.copyWith(color: c.textTertiary))),
                      ]),
                    ),
                    if (!item.read) Padding(padding: const EdgeInsets.only(top: 6, left: MangoSpace.s2), child: Icon(Icons.circle, size: 10, color: c.actionPrimary)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
