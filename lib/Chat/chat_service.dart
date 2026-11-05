// Mango Chat data layer. Messages are written straight to Firestore (rules
// check who you are and what you send); viewing, saving, unsending, snaps,
// retention and cleanup go through the chat Cloud Functions.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';
import 'package:mango/Media/compose/mango_voice_recorder.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

const _day = Duration(days: 1);

class ChatPerson {
  const ChatPerson({required this.uid, required this.name, this.username = '', this.photo = ''});

  final String uid;
  final String name;
  final String username;
  final String photo;

  factory ChatPerson.fromUser(String uid, Map<String, dynamic>? d) => ChatPerson(
        uid: uid,
        name: '${d?['displayName'] ?? d?['name'] ?? d?['username'] ?? 'Mango user'}',
        username: '${d?['username'] ?? d?['userName'] ?? ''}',
        photo: '${d?['profileImage'] ?? d?['profileImageUrl'] ?? d?['photoURL'] ?? ''}',
      );
}

class ChatSummary {
  ChatSummary(this.id, this.data, this.me);

  final String id;
  final Map<String, dynamic> data;
  final String me;

  List<String> get members => ((data['members'] as List?) ?? const []).map((e) => '$e').toList();
  String get peerId => members.firstWhere((m) => m != me, orElse: () => me);
  Map<String, dynamic>? get last => data['last'] == null ? null : Map<String, dynamic>.from(data['last'] as Map);
  Map<String, dynamic> _state(String uid) => Map<String, dynamic>.from(((data['state'] as Map?) ?? const {})[uid] as Map? ?? const {});
  int get unread => (_state(me)['unread'] ?? 0) as int;
  int get peerLastReadAt => (_state(peerId)['lastReadAt'] ?? 0) as int;
  String get retention => '${data['retention'] ?? 'after_viewing'}';
  int get lastAt => ((last?['at']) ?? 0) as int;
  bool get lastIsMine => last?['senderId'] == me;
  bool get lastIsSnap => last?['kind'] == 'snap';

  /// Snapchat-style status shown under the name.
  ChatStatus get status {
    if (last == null) return ChatStatus.none;
    if (lastIsMine) return peerLastReadAt >= lastAt ? (lastIsSnap ? ChatStatus.snapOpened : ChatStatus.chatOpened) : (lastIsSnap ? ChatStatus.snapDelivered : ChatStatus.chatDelivered);
    if (unread > 0) return lastIsSnap ? ChatStatus.newSnap : ChatStatus.newChat;
    return lastIsSnap ? ChatStatus.snapReceived : ChatStatus.chatReceived;
  }

  /// Streak count and whether it's about to end (hourglass).
  (int, bool) get streak {
    final s = Map<String, dynamic>.from((data['streak'] as Map?) ?? const {});
    final count = (s['count'] ?? 0) as int;
    final expires = s['expiresAt'] as int?;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (count == 0 || (expires != null && now > expires)) return (0, false);
    return (count, expires != null && expires - now < const Duration(hours: 4).inMilliseconds);
  }
}

enum ChatStatus { none, newSnap, newChat, snapDelivered, chatDelivered, snapOpened, chatOpened, snapReceived, chatReceived }

class ChatMessage {
  ChatMessage(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get senderId => '${data['senderId'] ?? ''}';
  String get kind => '${data['kind'] ?? 'text'}';
  String get text => '${data['text'] ?? ''}';
  Map<String, dynamic>? get media => data['media'] == null ? null : Map<String, dynamic>.from(data['media'] as Map);
  Map<String, dynamic>? get replyTo => data['replyTo'] == null ? null : Map<String, dynamic>.from(data['replyTo'] as Map);
  DateTime get at {
    final c = data['createdAt'];
    if (c is Timestamp) return c.toDate();
    final s = data['serverAt'];
    return s is int ? DateTime.fromMillisecondsSinceEpoch(s) : DateTime.now();
  }

  Map<String, dynamic> get viewedBy => Map<String, dynamic>.from((data['viewedBy'] as Map?) ?? const {});
  List<String> get savedBy => ((data['savedBy'] as List?) ?? const []).map((e) => '$e').toList();
  bool get saved => savedBy.isNotEmpty;
  Map<String, String> get reactions => ((data['reactions'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'));
  bool viewedByOther(String me) => viewedBy.keys.any((k) => k != me);
  bool get pending => data['serverAt'] == null && kind != 'system';
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _db = FirebaseFirestore.instance;
  final _fn = MangoLedgerClient.instance;
  final Map<String, ChatPerson> _people = {};

  String get me => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _messages(String chatId) => _db.collection('dm_chats').doc(chatId).collection('messages');

  Future<String> open(String peerId) async {
    final r = await _fn.call('chatOpen', {'peerId': peerId});
    return '${r['chatId']}';
  }

  Future<ChatPerson> person(String uid) async {
    final cached = _people[uid];
    if (cached != null) return cached;
    final d = (await _db.collection('users').doc(uid).get()).data();
    return _people[uid] = ChatPerson.fromUser(uid, d);
  }

  Stream<List<ChatSummary>> chats() {
    final uid = me;
    if (uid.isEmpty) return Stream.value(const []);
    return _db.collection('dm_chats').where('members', arrayContains: uid).snapshots().map((q) {
      final list = q.docs.map((d) => ChatSummary(d.id, d.data(), uid)).toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
      return list;
    });
  }

  Stream<ChatSummary?> chat(String chatId) => _db.collection('dm_chats').doc(chatId).snapshots().map((s) => s.exists ? ChatSummary(s.id, s.data()!, me) : null);

  Stream<List<ChatMessage>> messages(String chatId) => _messages(chatId)
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((q) => q.docs.map((d) => ChatMessage(d.id, d.data())).toList().reversed.toList());

  Map<String, dynamic>? _reply(ChatMessage? r) => r == null
      ? null
      : {'id': r.id, 'senderId': r.senderId, 'preview': r.kind == 'text' ? (r.text.length > 80 ? r.text.substring(0, 80) : r.text) : r.kind};

  Future<void> sendText(String chatId, String text, {ChatMessage? replyTo}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _messages(chatId).add({
      'senderId': me,
      'kind': 'text',
      'text': t.length > 2000 ? t.substring(0, 2000) : t,
      if (replyTo != null) 'replyTo': _reply(replyTo),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a photo or video as a Snap (view once) or as chat media.
  Future<void> sendMedia(String chatId, ComposedMedia m, {required bool asSnap, void Function(double)? onProgress, UploadHandle? handle}) async {
    final ext = MangoUploader.extensionFor(m.mime, m.name);
    final up = await MangoUploader.uploadWithRetry(bytes: m.bytes, contentType: m.mime, path: MangoUploader.chatPath(chatId, ext), onProgress: onProgress, handle: handle);
    await _messages(chatId).add({
      'senderId': me,
      'kind': asSnap ? 'snap' : (m.kind == MediaKind.image || m.kind == MediaKind.video ? 'media' : 'file'),
      if ((m.caption ?? '').isNotEmpty) 'text': m.caption,
      'media': {
        ...up.toJson(),
        'name': m.name.length > 120 ? m.name.substring(0, 120) : m.name,
        if (m.duration != null) 'durationMs': m.duration!.inMilliseconds,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendVoice(String chatId, VoiceClip clip) async {
    final ext = clip.mime == 'audio/webm' ? 'webm' : 'm4a';
    final up = await MangoUploader.uploadWithRetry(bytes: clip.bytes, contentType: clip.mime, path: MangoUploader.chatPath(chatId, ext));
    await _messages(chatId).add({
      'senderId': me,
      'kind': 'voice',
      'media': {
        ...up.toJson(),
        'durationMs': clip.duration.inMilliseconds,
        // Downsample to 48 bars for drawing.
        'waveform': _downsample(clip.waveform, 48),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static List<double> _downsample(List<double> v, int n) {
    if (v.isEmpty) return List.filled(n, 0.2);
    return List.generate(n, (i) {
      final start = (i * v.length / n).floor();
      final end = ((i + 1) * v.length / n).ceil().clamp(start + 1, v.length).toInt();
      final slice = v.sublist(start, end);
      return double.parse((slice.reduce((a, b) => a > b ? a : b)).toStringAsFixed(2));
    });
  }

  Future<void> react(String chatId, String messageId, String? emoji) => _messages(chatId).doc(messageId).update({
        'reactions.$me': emoji ?? FieldValue.delete(),
      });

  Future<void> markViewed(String chatId) => _fn.call('chatMarkViewed', {'chatId': chatId}).then((_) {});
  Future<Map<String, dynamic>> openSnap(String chatId, String messageId) => _fn.call('chatOpenSnap', {'chatId': chatId, 'messageId': messageId});
  Future<void> toggleSave(String chatId, String messageId) => _fn.call('chatToggleSave', {'chatId': chatId, 'messageId': messageId}).then((_) {});
  Future<void> unsend(String chatId, String messageId) => _fn.call('chatUnsend', {'chatId': chatId, 'messageId': messageId}).then((_) {});
  Future<void> setRetention(String chatId, String mode) => _fn.call('chatSetRetention', {'chatId': chatId, 'mode': mode}).then((_) {});

  // ---------------------------------------------------- presence & typing
  Future<void> setPresence(String chatId, {required bool here, bool typing = false}) => _db
      .collection('dm_chats')
      .doc(chatId)
      .collection('presence')
      .doc(me)
      .set({'here': here, 'typing': typing, 'lastSeen': FieldValue.serverTimestamp()});

  Stream<(bool here, bool typing)> peerPresence(String chatId, String peerId) => _db
      .collection('dm_chats')
      .doc(chatId)
      .collection('presence')
      .doc(peerId)
      .snapshots()
      .map((s) {
        final d = s.data();
        final seen = (d?['lastSeen'] as Timestamp?)?.toDate();
        final fresh = seen != null && DateTime.now().difference(seen) < const Duration(seconds: 45);
        return (fresh && d?['here'] == true, fresh && d?['typing'] == true);
      });

  static String retentionLabel(String mode) => switch (mode) {
        '24h' => 'Chats delete 24 hours after viewing',
        'keep' => 'Chats are kept',
        _ => 'Chats delete after viewing',
      };

  static const retentionDay = _day;
}
