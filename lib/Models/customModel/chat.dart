import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUsers {
  String name;
  String messageText;
  String imageURL;
  String time;
  ChatUsers(
      {required this.name,
      required this.messageText,
      required this.imageURL,
      required this.time});
}

class ChatMessage {
  String messageContent;
  String messageType;
  ChatMessage({required this.messageContent, required this.messageType});
}

enum MessageStatus {
  sent,
  delivered,
  read,
  edited,
  deleted
}

enum MessageType {
  direct,
  space,
  image,
  video,
  audio,
  file,
}

class Reaction {
  final String emoji;
  final String userId;
  final String username;
  final Timestamp timestamp;

  Reaction({
    required this.emoji,
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  factory Reaction.fromMap(Map<String, dynamic> map) {
    return Reaction(
      emoji: map['emoji'] ?? '❤️',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'userId': userId,
      'username': username,
      'timestamp': timestamp,
    };
  }
}


class Message {
  final String id;
  final String receiver;
  final String sender;
  final String text;
  final String? image;
  final String? video;
  final String? audio;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final bool media;
  final String? replyMessage;
  final String? replyImage;
  final String? replyMessageId;
  final Timestamp timeStamp;
  final Timestamp? editedAt;
  final MessageStatus status;
  final bool isDeleted;
  final String? spaceConversationId;
  final MessageType type;
  final double? audioDuration;
  final String? caption;
  final Map<String, Reaction>? reactions;
  final bool isPinned;
  final String? forwardFrom;
  final String? forwardFromName;
  final List<String> mentions; 
  final bool hasLinks;

  Message({
    required this.id,
    required this.receiver,
    required this.sender,
    required this.text,
    this.image,
    this.video,
    this.audio,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.media,
    this.replyMessage,
    this.replyImage,
    this.replyMessageId,
    required this.timeStamp,
    this.editedAt,
    this.status = MessageStatus.sent,
    this.isDeleted = false,
    this.spaceConversationId,
    this.type = MessageType.direct,
    this.audioDuration,
    this.caption,
    this.reactions,
    this.isPinned = false,
    this.forwardFrom,
    this.forwardFromName,
    this.mentions = const [],
    this.hasLinks = false,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      receiver: (data['receiver'] ?? '') as String,
      sender: (data['sender'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      image: data['image'] as String?,
      video: data['video'] as String?,
      audio: data['audio'] as String?,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileType: data['fileType'] as String?,
      media: (data['media'] ?? false) as bool,
      replyMessage: data['replyMessage'] as String?,
      replyImage: data['replyImage'] as String?,
      timeStamp: data['timeStamp'] ?? Timestamp.now(),
      spaceConversationId: data['spaceConversationId'] as String?,
      type: _parseType(data['type'] as String?),
      audioDuration: (data['audioDuration'] as num?)?.toDouble(),
      caption: data['caption'] as String?,
    );
  }

  static MessageType _parseType(String? raw) {
    if (raw == null) return MessageType.direct;
    switch (raw) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'space':
        return MessageType.space;
      case 'direct':
      default:
        return MessageType.direct;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'receiver': receiver,
      'sender': sender,
      'text': text,
      'image': image,
      'video': video,
      'audio': audio,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'media': media,
      'replyMessage': replyMessage,
      'replyImage': replyImage,
      'timeStamp': timeStamp,
      'spaceConversationId': spaceConversationId,
      'type': type.toString().split('.').last,
      'audioDuration': audioDuration,
      'caption': caption,
    };
  }
}
