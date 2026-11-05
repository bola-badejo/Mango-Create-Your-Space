// Content lists: playlists that can mix songs, podcasts, films and books.
// A list belongs to you, or to one of your Spaces (where its editors can
// manage it). Firestore rules enforce ownership, size and visibility.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContentListItem {
  const ContentListItem({required this.type, required this.id, required this.title, this.imageUrl});

  final String type; // song, podcast, movie, book, vine
  final String id;
  final String title;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'title': title.length > 120 ? title.substring(0, 120) : title,
        if (imageUrl != null && imageUrl!.isNotEmpty && imageUrl!.length <= 1000) 'imageUrl': imageUrl,
      };

  factory ContentListItem.fromJson(Map<String, dynamic> j) => ContentListItem(
        type: '${j['type'] ?? 'song'}',
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        imageUrl: j['imageUrl'] as String?,
      );
}

class ContentList {
  ContentList(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get title => '${data['title'] ?? 'List'}';
  String get description => '${data['description'] ?? ''}';
  String get ownerId => '${data['ownerId'] ?? ''}';
  String? get spaceId => data['spaceId'] as String?;
  String get visibility => '${data['visibility'] ?? 'public'}';
  List<ContentListItem> get items =>
      ((data['items'] as List?) ?? const []).map((e) => ContentListItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}

class ContentListService {
  static const maxItems = 200;
  final _col = FirebaseFirestore.instance.collection('content_lists');
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<ContentList>> mine() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col.where('ownerId', isEqualTo: uid).snapshots().map((q) => q.docs.where((d) => d.data()['spaceId'] == null).map((d) => ContentList(d.id, d.data())).toList());
  }

  Stream<List<ContentList>> forSpace(String spaceId) => _col
      .where('spaceId', isEqualTo: spaceId)
      .where('visibility', isEqualTo: 'public')
      .snapshots()
      .map((q) => q.docs.map((d) => ContentList(d.id, d.data())).toList());

  Stream<ContentList?> watch(String id) => _col.doc(id).snapshots().map((s) => s.exists ? ContentList(s.id, s.data()!) : null);

  Future<String> create({required String title, String description = '', String visibility = 'public', String? spaceId, List<ContentListItem> items = const []}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Sign in to create a list.');
    final clean = title.trim();
    if (clean.isEmpty) throw Exception('Give your list a name.');
    final ref = await _col.add({
      'ownerId': uid,
      if (spaceId != null) 'spaceId': spaceId,
      'title': clean.length > 80 ? clean.substring(0, 80) : clean,
      if (description.trim().isNotEmpty) 'description': description.trim().length > 500 ? description.trim().substring(0, 500) : description.trim(),
      'visibility': visibility,
      'items': items.take(maxItems).map((i) => i.toJson()).toList(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> _mutate(String id, List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) change) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(id));
      final current = ((snap.data()?['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final next = change(current);
      if (next.length > maxItems) throw Exception('Lists hold up to $maxItems items.');
      tx.update(_col.doc(id), {'items': next, 'updatedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<void> add(String listId, ContentListItem item) => _mutate(listId, (items) {
        if (items.any((i) => i['type'] == item.type && i['id'] == item.id)) return items;
        return [...items, item.toJson()];
      });

  Future<void> remove(String listId, int index) => _mutate(listId, (items) => [...items]..removeAt(index));

  Future<void> move(String listId, int from, int to) => _mutate(listId, (items) {
        final next = [...items];
        final e = next.removeAt(from);
        next.insert(to > next.length ? next.length : to, e);
        return next;
      });

  Future<void> rename(String listId, String title) => _col.doc(listId).update({'title': title.trim(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> delete(String listId) => _col.doc(listId).delete();
}
