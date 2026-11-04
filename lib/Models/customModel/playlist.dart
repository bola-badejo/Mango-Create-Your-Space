import 'package:cloud_firestore/cloud_firestore.dart';

class MangoPlaylist {
  final String id;
  final String title;
  final String text;
  final String type;
  final String link;
  final String postCreator;
  final String image;
  final Timestamp timeStamp;
  final String? repliedPlaylistID;
  final String originalID;
  final List<dynamic> tags;
  final bool repost;
  final bool reply;
  final String file;
  final String filePreview;
  final String about;
  final String artiste;
  final String record;
  final String contributingArtistes;
  final String writers;
  final String producers;
  final String releaseYear;
  final String genre;
  final String label;
  final String sellingPrice;

  int replyCount;
  int likeCount;
  int plays;
  int repostCount;

  MangoPlaylist({
    required this.id,
    required this.title,
    required this.text,
    required this.type,
    required this.link,
    required this.postCreator,
    required this.image,
    required this.timeStamp,
    this.repliedPlaylistID,
    required this.originalID,
    required this.tags,
    required this.repost,
    required this.reply,
    required this.file,
    required this.filePreview,
    required this.about,
    required this.artiste,
    required this.record,
    required this.contributingArtistes,
    required this.writers,
    required this.producers,
    required this.releaseYear,
    required this.genre,
    required this.label,
    required this.sellingPrice,
    required this.replyCount,
    required this.likeCount,
    required this.plays,
    required this.repostCount,
  });

  
  factory MangoPlaylist.fromMap(Map<String, dynamic> data, [String? id]) {
    return MangoPlaylist(
      id: id ?? data['id'] ?? '',
      title: data['title'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'music',
      link: data['link'] ?? '',
      postCreator: data['postCreator'] ?? '',
      image: data['image'] ?? '',
      timeStamp: data['timeStamp'] ?? Timestamp.now(),
      repliedPlaylistID: data['repliedPlaylistID'],
      originalID: data['originalID'] ?? '',
      tags: List<dynamic>.from(data['tags'] ?? []),
      repost: data['repost'] ?? false,
      reply: data['reply'] ?? false,
      file: data['file'] ?? '',
      filePreview: data['filePreview'] ?? '',
      about: data['about'] ?? '',
      artiste: data['artiste'] ?? '',
      record: data['record'] ?? '',
      contributingArtistes: data['contributingArtistes'] ?? '',
      writers: data['writers'] ?? '',
      producers: data['producers'] ?? '',
      releaseYear: data['releaseYear'] ?? '',
      genre: data['genre'] ?? '',
      label: data['label'] ?? '',
      sellingPrice: data['sellingPrice'] ?? '',
      replyCount: data['replyCount'] ?? 0,
      likeCount: data['likeCount'] ?? 0,
      plays: data['plays'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
    );
  }

  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'type': type,
      'link': link,
      'postCreator': postCreator,
      'image': image,
      'timeStamp': timeStamp,
      if (repliedPlaylistID != null) 'repliedPlaylistID': repliedPlaylistID,
      'originalID': originalID,
      'tags': tags,
      'repost': repost,
      'reply': reply,
      'file': file,
      'filePreview': filePreview,
      'about': about,
      'artiste': artiste,
      'record': record,
      'contributingArtistes': contributingArtistes,
      'writers': writers,
      'producers': producers,
      'releaseYear': releaseYear,
      'genre': genre,
      'label': label,
      'sellingPrice': sellingPrice,
      'replyCount': replyCount,
      'likeCount': likeCount,
      'plays': plays,
      'repostCount': repostCount,
    };
  }

  
  factory MangoPlaylist.fromDocument(DocumentSnapshot doc) {
    return MangoPlaylist.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  
  factory MangoPlaylist.fromQueryDocumentSnapshot(QueryDocumentSnapshot doc) {
    return MangoPlaylist.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  
  factory MangoPlaylist.fromJson(Map<String, dynamic> json) => MangoPlaylist.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  
  MangoPlaylist copyWith({
    String? id,
    String? title,
    String? text,
    String? type,
    String? link,
    String? postCreator,
    String? image,
    Timestamp? timeStamp,
    String? repliedPlaylistID,
    String? originalID,
    List<dynamic>? tags,
    bool? repost,
    bool? reply,
    String? file,
    String? filePreview,
    String? about,
    String? artiste,
    String? record,
    String? contributingArtistes,
    String? writers,
    String? producers,
    String? releaseYear,
    String? genre,
    String? label,
    String? sellingPrice,
    int? replyCount,
    int? likeCount,
    int? plays,
    int? repostCount,
  }) {
    return MangoPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      type: type ?? this.type,
      link: link ?? this.link,
      postCreator: postCreator ?? this.postCreator,
      image: image ?? this.image,
      timeStamp: timeStamp ?? this.timeStamp,
      repliedPlaylistID: repliedPlaylistID ?? this.repliedPlaylistID,
      originalID: originalID ?? this.originalID,
      tags: tags ?? this.tags,
      repost: repost ?? this.repost,
      reply: reply ?? this.reply,
      file: file ?? this.file,
      filePreview: filePreview ?? this.filePreview,
      about: about ?? this.about,
      artiste: artiste ?? this.artiste,
      record: record ?? this.record,
      contributingArtistes: contributingArtistes ?? this.contributingArtistes,
      writers: writers ?? this.writers,
      producers: producers ?? this.producers,
      releaseYear: releaseYear ?? this.releaseYear,
      genre: genre ?? this.genre,
      label: label ?? this.label,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      plays: plays ?? this.plays,
      repostCount: repostCount ?? this.repostCount,
    );
  }
}