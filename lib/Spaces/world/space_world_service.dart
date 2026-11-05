// Data access for virtual Spaces. Reads and the actions Firestore rules
// allow (placing objects, presence, wall posts, RSVPs, live chat) go to
// Firestore directly; anything involving ownership, handles, money or event
// state goes through the Space Cloud Functions.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Wallet/ledger/mango_ledger_client.dart';

class SpaceObject {
  SpaceObject(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get kind => (data['kind'] ?? 'decor') as String;
  String? get itemId => data['itemId'] as String?;
  double get x => ((data['x'] ?? 0.5) as num).toDouble();
  double get y => ((data['y'] ?? 0.5) as num).toDouble();
  double get scale => ((data['scale'] ?? 1) as num).toDouble();
  String get label => (data['label'] ?? '') as String;
  Map<String, dynamic>? get contentRef =>
      data['contentRef'] == null ? null : Map<String, dynamic>.from(data['contentRef'] as Map);
}

class SpacePresence {
  SpacePresence(this.uid, this.data);

  final String uid;
  final Map<String, dynamic> data;

  String get name => (data['name'] ?? 'Guest') as String;
  String? get photo => data['photo'] as String?;
  DateTime? get lastSeen => (data['lastSeen'] as Timestamp?)?.toDate();
  bool get isActive => lastSeen != null && DateTime.now().difference(lastSeen!) < const Duration(minutes: 2);
}

class SpaceMessage {
  SpaceMessage(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get authorId => (data['authorId'] ?? '') as String;
  String get authorName => (data['authorName'] ?? 'Someone') as String;
  String? get authorPhoto => data['authorPhoto'] as String?;
  String get text => (data['text'] ?? '') as String;
  DateTime? get createdAt => (data['createdAt'] as Timestamp?)?.toDate();
}

class SpaceEvent {
  SpaceEvent(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get title => (data['title'] ?? '') as String;
  String get description => (data['description'] ?? '') as String;
  String get status => (data['status'] ?? 'scheduled') as String;
  String get hostId => (data['hostId'] ?? '') as String;
  DateTime get startsAt => DateTime.fromMillisecondsSinceEpoch((data['startsAt'] ?? 0) as int);
  DateTime get endsAt => DateTime.fromMillisecondsSinceEpoch((data['endsAt'] ?? 0) as int);
  bool get isLive => status == 'live';
  List<String> get speakers => ((data['speakers'] as List?) ?? const []).map((e) => '$e').toList();
}

String _cut(String s, int max) => s.length <= max ? s : s.substring(0, max);

class SpaceWorldService {
  SpaceWorldService(this.spaceId);

  final String spaceId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MangoLedgerClient _fn = MangoLedgerClient.instance;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  DocumentReference<Map<String, dynamic>> get _space => _db.collection('spaces').doc(spaceId);

  // ------------------------------------------------------------ streams
  Stream<Map<String, dynamic>?> space() => _space.snapshots().map((s) => s.data());

  Stream<List<SpaceObject>> objects() => _space
      .collection('objects')
      .snapshots()
      .map((q) => q.docs.map((d) => SpaceObject(d.id, d.data())).toList());

  Stream<Set<String>> inventory() =>
      _space.collection('inventory').snapshots().map((q) => q.docs.map((d) => d.id).toSet());

  Stream<List<SpacePresence>> presence() => _space
      .collection('presence')
      .snapshots()
      .map((q) => q.docs.map((d) => SpacePresence(d.id, d.data())).where((p) => p.isActive).toList());

  Stream<List<SpaceMessage>> wall({int limit = 50}) => _space
      .collection('wall')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map((d) => SpaceMessage(d.id, d.data())).toList());

  Stream<List<SpaceEvent>> events() => _space
      .collection('events')
      .where('status', whereIn: ['scheduled', 'live'])
      .snapshots()
      .map((q) => q.docs.map((d) => SpaceEvent(d.id, d.data())).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt)));

  Stream<SpaceEvent?> event(String eventId) =>
      _space.collection('events').doc(eventId).snapshots().map((s) => s.exists ? SpaceEvent(s.id, s.data()!) : null);

  Stream<List<SpaceMessage>> eventChat(String eventId) => _space
      .collection('events')
      .doc(eventId)
      .collection('chat')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map((d) => SpaceMessage(d.id, d.data())).toList());

  Stream<int> attendeeCount(String eventId) =>
      _space.collection('events').doc(eventId).collection('attendees').snapshots().map((q) => q.size);

  Stream<bool> isMember() {
    final id = uid;
    if (id == null) return Stream.value(false);
    return _space.collection('subscribers').doc(id).snapshots().map((s) => s.exists);
  }

  // ----------------------------------------------------- direct actions
  Map<String, dynamic> _me() {
    final u = FirebaseAuth.instance.currentUser;
    return {
      if ((u?.displayName ?? '').isNotEmpty) 'authorName': _cut(u!.displayName!, 60),
      if ((u?.photoURL ?? '').isNotEmpty && u!.photoURL!.length <= 500) 'authorPhoto': u.photoURL,
    };
  }

  Future<void> heartbeat({double x = 0.5, double y = 0.85}) async {
    final id = uid;
    if (id == null) return;
    final u = FirebaseAuth.instance.currentUser;
    await _space.collection('presence').doc(id).set({
      'name': (u?.displayName?.isNotEmpty ?? false) ? _cut(u!.displayName!, 60) : 'Guest',
      if ((u?.photoURL ?? '').isNotEmpty && u!.photoURL!.length <= 500) 'photo': u.photoURL,
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'status': 'here',
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leave() async {
    final id = uid;
    if (id == null) return;
    await _space.collection('presence').doc(id).delete();
  }

  Future<void> join() async {
    final id = uid;
    if (id == null) return;
    await _space.collection('subscribers').doc(id).set({'userId': id, 'role': 'member', 'joinedAt': DateTime.now().millisecondsSinceEpoch});
    await _space.update({'members': FieldValue.increment(1)});
  }

  Future<void> postToWall(String text) async {
    final id = uid;
    final clean = text.trim();
    if (id == null || clean.isEmpty) return;
    await _space.collection('wall').add({
      'authorId': id,
      ..._me(),
      'text': clean.length > 500 ? clean.substring(0, 500) : clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) => _space.collection('wall').doc(messageId).delete();

  Future<void> sendEventChat(String eventId, String text) async {
    final id = uid;
    final clean = text.trim();
    if (id == null || clean.isEmpty) return;
    await _space.collection('events').doc(eventId).collection('chat').add({
      'authorId': id,
      ..._me(),
      'text': clean.length > 500 ? clean.substring(0, 500) : clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> attend(String eventId) async {
    final id = uid;
    if (id == null) return;
    final u = FirebaseAuth.instance.currentUser;
    await _space.collection('events').doc(eventId).collection('attendees').doc(id).set({
      'name': (u?.displayName?.isNotEmpty ?? false) ? _cut(u!.displayName!, 60) : 'Guest',
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Attendees of an event, with whether their hand is raised.
  Stream<List<Map<String, dynamic>>> attendees(String eventId) => _space
      .collection('events')
      .doc(eventId)
      .collection('attendees')
      .snapshots()
      .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList());

  /// Raise or lower your hand to ask the host to let you speak.
  Future<void> setHandRaised(String eventId, bool raised) async {
    final id = uid;
    if (id == null) return;
    final u = FirebaseAuth.instance.currentUser;
    await _space.collection('events').doc(eventId).collection('attendees').doc(id).set({
      'name': (u?.displayName?.isNotEmpty ?? false) ? _cut(u!.displayName!, 60) : 'Guest',
      'joinedAt': FieldValue.serverTimestamp(),
      'handRaised': raised,
    });
  }

  /// A LiveKit token for this live event, issued only while it is live.
  Future<Map<String, dynamic>> liveToken(String eventId) =>
      _fn.call('spaceLiveToken', {'spaceId': spaceId, 'eventId': eventId});

  /// Host: invite someone to speak, or move them back to the audience.
  Future<Map<String, dynamic>> setSpeaker(String eventId, String userId, bool speaker) =>
      _fn.call('spaceSetSpeaker', {'spaceId': spaceId, 'eventId': eventId, 'userId': userId, 'speaker': speaker});

  Future<void> leaveEvent(String eventId) async {
    final id = uid;
    if (id == null) return;
    await _space.collection('events').doc(eventId).collection('attendees').doc(id).delete();
  }

  Future<void> follow(String userId) async {
    final id = uid;
    if (id == null || id == userId) return;
    // Same structure the profile screens use; the ledger credits real follows.
    await _db.collection('users').doc(id).collection('following').doc(userId).set({});
    await _db.collection('users').doc(userId).collection('followers').doc(id).set({});
  }

  Future<String> placeObject({
    required String kind,
    String? itemId,
    Map<String, dynamic>? contentRef,
    required String label,
    double x = 0.5,
    double y = 0.5,
  }) async {
    final ref = await _space.collection('objects').add({
      'kind': kind,
      if (itemId != null) 'itemId': itemId,
      if (contentRef != null) 'contentRef': contentRef,
      'label': label.length > 60 ? label.substring(0, 60) : label,
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'scale': 1.0,
      'z': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'createdBy': uid,
    });
    return ref.id;
  }

  Future<void> moveObject(String objectId, double x, double y) => _space.collection('objects').doc(objectId).update({
        'x': x.clamp(0.0, 1.0),
        'y': y.clamp(0.0, 1.0),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> scaleObject(String objectId, double scale) => _space.collection('objects').doc(objectId).update({
        'scale': scale.clamp(0.5, 2.5),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> removeObject(String objectId) => _space.collection('objects').doc(objectId).delete();

  /// The signed-in creator's own content, to place in the Space.
  Future<List<Map<String, dynamic>>> myContent() async {
    final id = uid;
    if (id == null) return [];
    Future<List<Map<String, dynamic>>> from(String col, String field, String type, String titleField, String imageField) async {
      try {
        final q = await _db.collection(col).where(field, isEqualTo: id).limit(30).get();
        return q.docs
            .map((d) => {
                  'type': type,
                  'id': d.id,
                  'title': '${d.data()[titleField] ?? type}',
                  if (d.data()[imageField] is String) 'imageUrl': d.data()[imageField],
                })
            .toList();
      } catch (_) {
        return [];
      }
    }

    final parts = await Future.wait([
      from('music', 'artistId', 'song', 'title', 'artworkUrl'),
      from('podcasts', 'userId', 'podcast', 'title', 'coverUrl'),
      from('movies', 'userId', 'movie', 'title', 'thumbnailUrl'),
      from('posts', 'postCreator', 'post', 'text', 'image'),
    ]);
    return parts.expand((e) => e).toList();
  }

  // ------------------------------------------------- server actions
  static Future<Map<String, dynamic>> checkHandle(String handle) =>
      MangoLedgerClient.instance.call('spaceCheckHandle', {'handle': handle});

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) =>
      MangoLedgerClient.instance.call('spaceCreate', data);

  Future<Map<String, dynamic>> buy(String itemId) => _fn.call('spaceBuyItem', {'spaceId': spaceId, 'itemId': itemId});

  Future<Map<String, dynamic>> applyTheme({String? skinId, String? iconId}) => _fn.call('spaceApplyTheme', {
        'spaceId': spaceId,
        if (skinId != null) 'skinId': skinId,
        if (iconId != null) 'iconId': iconId,
      });

  Future<Map<String, dynamic>> createEvent({
    required String title,
    String description = '',
    required DateTime startsAt,
    int durationMinutes = 60,
  }) =>
      _fn.call('spaceCreateEvent', {
        'spaceId': spaceId,
        'title': title,
        'description': description,
        'startsAt': startsAt.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
      });

  Future<Map<String, dynamic>> setEventStatus(String eventId, String status) =>
      _fn.call('spaceSetEventStatus', {'spaceId': spaceId, 'eventId': eventId, 'status': status});
}
