// Creating, editing and deleting posts, on the shared Mango uploader.
// Writes the same document shape the feed and post cards already read
// (MangoPost.toMap), plus ownerId and storagePaths so the server can clean
// up files when a post is deleted.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Media/compose/mango_uploader.dart';

class PostException implements Exception {
  PostException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MangoPostService {
  MangoPostService._();
  static final MangoPostService instance = MangoPostService._();

  static const maxChars = 280;
  static const maxImages = 10;

  final _db = FirebaseFirestore.instance;

  Future<String> create({
    String text = '',
    List<ComposedMedia> media = const [],
    String? link,
    String? linkType,
    String? replyTo,
    String? repliedPostID,
    void Function(double)? onProgress,
    UploadHandle? handle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw PostException('Sign in to post.');
    final clean = text.trim();
    if (clean.isEmpty && media.isEmpty && link == null) throw PostException('Write something or add a photo or video.');
    if (clean.length > maxChars) throw PostException('Posts can be up to $maxChars characters.');
    final videos = media.where((m) => m.kind == MediaKind.video).toList();
    final images = media.where((m) => m.kind == MediaKind.image).toList();
    if (videos.length > 1 || (videos.isNotEmpty && images.isNotEmpty)) throw PostException('Add one video, or up to $maxImages photos.');
    if (images.length > maxImages) throw PostException('Up to $maxImages photos per post.');

    final uploaded = <UploadedFile>[];
    try {
      for (var i = 0; i < media.length; i++) {
        final m = media[i];
        final up = await MangoUploader.uploadWithRetry(
          bytes: m.bytes,
          contentType: m.mime,
          path: MangoUploader.userPath('posts', MangoUploader.extensionFor(m.mime, m.name)),
          handle: handle,
          onProgress: (p) => onProgress?.call((i + p) / media.length),
        );
        uploaded.add(up);
      }
    } catch (e) {
      for (final u in uploaded) {
        await MangoUploader.delete(u.path);
      }
      rethrow;
    }

    final imageUrls = uploaded.where((u) => u.contentType.startsWith('image/')).map((u) => u.url).toList();
    final videoUrls = uploaded.where((u) => u.contentType.startsWith('video/')).map((u) => u.url).toList();
    final videoUrl = videoUrls.isEmpty ? '' : videoUrls.first;
    final multi = imageUrls.length > 1;
    final ref = _db.collection('posts').doc();
    final now = Timestamp.now();
    final batch = _db.batch();
    batch.set(ref, {
      'id': ref.id,
      'text': clean,
      'postCreator': user.uid,
      'ownerId': user.uid,
      'image': imageUrls.isNotEmpty && !multi ? imageUrls.first : '',
      'video': videoUrl,
      if (repliedPostID != null) 'repliedPostID': repliedPostID,
      if (link != null) 'link': link,
      if (replyTo != null) 'replyTo': replyTo,
      if (linkType != null) 'linkType': linkType,
      'timeStamp': now,
      'repost': false,
      'multiMedia': multi,
      'reply': replyTo != null,
      'isLinked': link != null,
      'likeCount': 0,
      'replyCount': 0,
      'repostCount': 0,
      'multiImage': multi ? imageUrls : [],
      'mediaMeta': [for (final u in uploaded) {'mime': u.contentType, if (u.width != null) 'width': u.width, if (u.height != null) 'height': u.height}],
      'storagePaths': uploaded.map((u) => u.path).toList(),
    });
    batch.update(_db.collection('users').doc(user.uid), {'postCount': FieldValue.increment(1)});
    if (repliedPostID != null) batch.update(_db.collection('posts').doc(repliedPostID), {'replyCount': FieldValue.increment(1)});
    await batch.commit();
    onProgress?.call(1);
    return ref.id;
  }

  /// Edits a post's text (media stays). Marks it as edited.
  Future<void> editText(String postId, String text) async {
    final clean = text.trim();
    if (clean.length > maxChars) throw PostException('Posts can be up to $maxChars characters.');
    await _db.collection('posts').doc(postId).update({'text': clean, 'editedAt': FieldValue.serverTimestamp()});
  }

  /// Deletes your post. Its files are removed by the server.
  Future<void> delete(String postId) async {
    final ref = _db.collection('posts').doc(postId);
    final d = (await ref.get()).data();
    if (d == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch()..delete(ref);
    if (uid != null) batch.update(_db.collection('users').doc(uid), {'postCount': FieldValue.increment(-1)});
    final parent = d['repliedPostID'];
    if (parent is String && parent.isNotEmpty && (await _db.collection('posts').doc(parent).get()).exists) {
      batch.update(_db.collection('posts').doc(parent), {'replyCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }
}
