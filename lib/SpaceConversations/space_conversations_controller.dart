import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/SpaceConversations/space_conversations_model.dart';
import '../Models/customModel/user.dart';

class SpaceConversationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> joinSpaceConversation(
    String spaceId,
    String conversationId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('conversations')
          .doc(conversationId)
          .update({
            'participants': FieldValue.arrayUnion([userId]),
            'participantCount': FieldValue.increment(1),
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      print('Error joining space conversation: $e');
      rethrow;
    }
  }

  Stream<List<SpaceConversation>> getUserSpaceConversations(String userId) {
    return _firestore
        .collectionGroup('conversations')
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SpaceConversation.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

Future<void> sendSpaceConversationMessage({
  required String spaceId,
  required String conversationId,
  required String text,
  required String senderId,
  String? imageUrl,
  String? videoUrl,
  String? audioUrl,
  double? audioDuration,
  MessageType messageType = MessageType.space,
}) async {
  try {
    final messageData = {
      'sender': senderId,
      'text': text,
      'media': messageType != MessageType.space,
      'timeStamp': Timestamp.now(),
      'type': _messageTypeToString(messageType),
    };

    if (imageUrl != null) messageData['image'] = imageUrl;
    if (videoUrl != null) messageData['video'] = videoUrl;
    if (audioUrl != null) {
      messageData['audio'] = audioUrl;
      messageData['audioDuration'] = audioDuration!;
    }
    if (text.isNotEmpty && (imageUrl != null || videoUrl != null || audioUrl != null)) {
      messageData['caption'] = text;
    }

    await _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);

    await _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('conversations')
        .doc(conversationId)
        .update({
      'updatedAt': Timestamp.now(),
    });
    
    print('Space conversation message sent successfully');
  } catch (e) {
    print('Error sending space conversation message: $e');
    rethrow;
  }
}

String _messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.direct:
      return 'direct';
    case MessageType.space:
      return 'space';
    case MessageType.image:
      return 'image';
    case MessageType.video:
      return 'video';
    case MessageType.audio:
      return 'audio';
    case MessageType.file:
      return 'file';
    }
}

  Stream<List<SpaceConversation>> getSpaceConversations(String spaceId) {
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('conversations')
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SpaceConversation.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<SpaceConversation?> getSpaceConversation(
    String spaceId,
    String conversationId,
  ) {
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return SpaceConversation.fromMap(
            snapshot.data() as Map<String, dynamic>,
            snapshot.id,
          );
        });
  }

  Stream<List<MangoUser>>? getSpaceConversationMembers(
    String spaceId,
    String conversationId,
  ) {
    return _firestore
        .collection('spaces')
        .doc(spaceId)
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) return <MangoUser>[];

          final data = snapshot.data();
          if (data == null) return <MangoUser>[];

          final participants = List<String>.from(data['participants'] ?? []);
          final users = <MangoUser>[];

          for (final userId in participants) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(userId)
                  .get();
              if (userDoc.exists && userDoc.data() != null) {
                final userData = userDoc.data() as Map<String, dynamic>;
                users.add(
                  MangoUser.fromMap(userData));
              }
            } catch (e) {
              print('Error fetching user $userId: $e');
            }
          }
          return users;
        });
  }
}
