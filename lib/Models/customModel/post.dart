import 'package:cloud_firestore/cloud_firestore.dart';

class MangoPost {
  final String id;
  final String text;
  List<dynamic> multiImage = [];
  final String postCreator;
  final String image;
  final String video;
  final String? videoQuality; 
  final List<dynamic>? imageEdits; 
  final String? originalID;
  final String? repliedPostID;
  final String? link;
  final String? replyTo;
  final String? linkType;
  final Timestamp? timeStamp;
  final bool repost;
  bool multiMedia = false;
  final bool reply;
  final bool isLinked;
  int likeCount;
  int replyCount;
  int repostCount;

  MangoPost({
    required this.id,
    required this.text,
    required this.postCreator,
    required this.image,
    required this.video,
    this.videoQuality, 
    this.imageEdits, 
    this.originalID,
    this.repliedPostID,
    this.link,
    this.replyTo,
    this.linkType,
    this.timeStamp,
    required this.repost,
    required this.multiMedia,
    required this.reply,
    required this.isLinked,
    required this.likeCount,
    required this.replyCount,
    required this.repostCount,
    required this.multiImage,
  });

  factory MangoPost.fromMap(Map<String, dynamic> data, [String? id]) {
    return MangoPost(
      id: id ?? data['id'] ?? '',
      text: data['text'] ?? '',
      postCreator: data['postCreator'] ?? '',
      image: data['image'] ?? '',
      video: data['video'] ?? '',
      videoQuality: data['videoQuality'], 
      imageEdits: data['imageEdits'] as List<dynamic>?, 
      originalID: data['originalID'],
      repliedPostID: data['repliedPostID'],
      link: data['link'],
      replyTo: data['replyTo'],
      linkType: data['linkType'],
      timeStamp: data['timeStamp'] ?? Timestamp.now(),
      repost: data['repost'] ?? false,
      multiMedia: data['multiMedia'] ?? false,
      reply: data['reply'] ?? false,
      isLinked: data['isLinked'] ?? false,
      likeCount: data['likeCount'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
      multiImage: List<dynamic>.from(data['multiImage'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'postCreator': postCreator,
      'image': image,
      'video': video,
      if (videoQuality != null) 'videoQuality': videoQuality, 
      if (imageEdits != null) 'imageEdits': imageEdits, 
      if (originalID != null) 'originalID': originalID,
      if (repliedPostID != null) 'repliedPostID': repliedPostID,
      if (link != null) 'link': link,
      if (replyTo != null) 'replyTo': replyTo,
      if (linkType != null) 'linkType': linkType,
      'timeStamp': timeStamp ?? Timestamp.now(),
      'repost': repost,
      'multiMedia': multiMedia,
      'reply': reply,
      'isLinked': isLinked,
      'likeCount': likeCount,
      'replyCount': replyCount,
      'repostCount': repostCount,
      'multiImage': multiImage,
    };
  }

  factory MangoPost.fromDocument(DocumentSnapshot doc) {
    return MangoPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory MangoPost.fromQueryDocumentSnapshot(QueryDocumentSnapshot doc) {
    return MangoPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory MangoPost.fromJson(Map<String, dynamic> json) =>
      MangoPost.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  MangoPost copyWith({
    String? id,
    String? text,
    List<dynamic>? multiImage,
    String? postCreator,
    String? image,
    String? video,
    String? originalID,
    String? repliedPostID,
    String? link,
    String? replyTo,
    String? linkType,
    Timestamp? timeStamp,
    bool? repost,
    bool? multiMedia,
    bool? reply,
    bool? isLinked,
    int? likeCount,
    int? replyCount,
    int? repostCount,
  }) {
    return MangoPost(
      id: id ?? this.id,
      text: text ?? this.text,
      multiImage: multiImage ?? this.multiImage,
      postCreator: postCreator ?? this.postCreator,
      image: image ?? this.image,
      video: video ?? this.video,
      originalID: originalID ?? this.originalID,
      repliedPostID: repliedPostID ?? this.repliedPostID,
      link: link ?? this.link,
      replyTo: replyTo ?? this.replyTo,
      linkType: linkType ?? this.linkType,
      timeStamp: timeStamp ?? this.timeStamp,
      repost: repost ?? this.repost,
      multiMedia: multiMedia ?? this.multiMedia,
      reply: reply ?? this.reply,
      isLinked: isLinked ?? this.isLinked,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      repostCount: repostCount ?? this.repostCount,
    );
  }
}
