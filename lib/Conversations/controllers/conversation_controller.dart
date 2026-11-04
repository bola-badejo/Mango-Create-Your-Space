import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mango/Models/customModel/chat.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class OfflineMessageBox {
  static const String name = 'offline_messages';
  static const String pendingKey = 'pending_messages';
}

class ConversationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth authentication = FirebaseAuth.instance;
  var messages = <Message>[].obs;

  final Map<String, Timer> _typingTimers = {};
  final AudioPlayer _player = AudioPlayer();

  String _messageTypeToString(MessageType type) {
    return type.toString().split('.').last;
  }

  MessageType _stringToMessageType(String type) {
    switch (type) {
      case 'direct':
        return MessageType.direct;
      case 'space':
        return MessageType.space;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'forwarded':
        return MessageType.direct;
      default:
        return MessageType.direct;
    }
  }

  Stream<MangoUser?>? getUserInfo(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return MangoUser.fromFirestoreData(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        });
  }

  Future<void> sendMessage({
    required String receiverId,
    required String senderId,
    String? text,
    String? image,
    String? video,
    String? audio,
    String? fileUrl,
    String? fileName,
    String? fileType,
    double? audioDuration,
    String? caption,
    String? replyMessageId,
    String? replyMessage,
    String? replyImage,
    MessageType messageType = MessageType.direct,
  }) async {
    try {
      final timestamp = Timestamp.now();
      final conversationId = _generateConversationId(senderId, receiverId);

      final messageData = {
        'sender': senderId,
        'receiver': receiverId,
        'text': text ?? '',
        'image': image,
        'video': video,
        'audio': audio,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'audioDuration': audioDuration,
        'caption': caption,
        'replyMessageId': replyMessageId,
        'replyMessage': replyMessage,
        'replyImage': replyImage,
        'media':
            (image != null ||
            video != null ||
            audio != null ||
            fileUrl != null),
        'timeStamp': timestamp,
        'participants': [senderId, receiverId],
        'type': _messageTypeToString(messageType),
        'status': 'sent',
        'isDeleted': false,
        'isPinned': false,
        'conversationId': conversationId,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('messages')
          .add(messageData);

      final messageId = docRef.id;

      final completeMessageData = {...messageData, 'id': messageId};

      await Future.wait([
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('chats')
            .doc(receiverId)
            .collection('messages')
            .doc(messageId)
            .set(completeMessageData, SetOptions(merge: true)),

        _firestore
            .collection('users')
            .doc(receiverId)
            .collection('chats')
            .doc(senderId)
            .collection('messages')
            .doc(messageId)
            .set(completeMessageData, SetOptions(merge: true)),
      ]);

      await _updateConversationMetadata(
        senderId,
        receiverId,
        text ?? '',
        timestamp,
      );

      await markAsRead(
        messageId: messageId,
        conversationId: conversationId,
        userId: senderId,
      );

      // Send notification data
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      final senderName = senderDoc.data()?['displayName'] ?? 'Someone';

      String notificationBody = text ?? '';
      if (image != null) {
        notificationBody = '📸 Sent a photo';
      } else if (video != null) {
        notificationBody = '🎥 Sent a video';
      } else if (audio != null) {
        notificationBody = '🎧 Sent a voice message';
      } else if (fileUrl != null) {
        notificationBody = '📎 Sent a file';
      } else if (text == null || text.isEmpty) {
        notificationBody = '📩 Sent a message';
      }

      await _sendNotificationData(
        receiverId: receiverId,
        senderId: senderId,
        senderName: senderName,
        messageText: notificationBody,
        messageType: _messageTypeToString(messageType),
      );
    } catch (e) {
      print('Error sending message: $e');

      // Save offline
      await _saveOfflineMessage({
        'receiverId': receiverId,
        'senderId': senderId,
        'text': text,
        'image': image,
        'video': video,
        'audio': audio,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'audioDuration': audioDuration,
        'caption': caption,
        'replyMessageId': replyMessageId,
        'replyMessage': replyMessage,
        'replyImage': replyImage,
        'messageType': _messageTypeToString(messageType),
      });

      rethrow;
    }
  }

  Future<void> initializeOfflineSync() async {
  // Wait for connectivity
  await Future.delayed(Duration(seconds: 3));
  
  // Check if online and sync
  final user = authentication.currentUser;
  if (user != null) {
    await syncOfflineMessages();
  }
  
  // Listen to connectivity changes
  // You can use connectivity_plus package for better handling
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  }

  Future<void> _updateConversationMetadata(
    String user1,
    String user2,
    String lastMessage,
    Timestamp timestamp,
  ) async {
    final conversationId = _generateConversationId(user1, user2);
    final conversationData = {
      'participants': [user1, user2],
      'lastMessage': lastMessage,
      'lastMessageTime': timestamp,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount_$user2': FieldValue.increment(1),
    };

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData, SetOptions(merge: true));

      final user1Data = {
        'userId': user2,
        'lastMessage': lastMessage,
        'lastMessageTime': timestamp,
        'unreadCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final user2Data = {
        'userId': user1,
        'lastMessage': lastMessage,
        'lastMessageTime': timestamp,
        'unreadCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(user1)
            .collection('conversations')
            .doc(user2)
            .set(user1Data, SetOptions(merge: true)),

        FirebaseFirestore.instance
            .collection('users')
            .doc(user2)
            .collection('conversations')
            .doc(user1)
            .set(user2Data, SetOptions(merge: true)),
      ]);
    } catch (e) {
      print('Error updating conversation metadata: $e');
    }
  }

  String _generateConversationId(String user1, String user2) {
    final ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _saveOfflineMessage(Map<String, dynamic> messageData) async {
    try {
      final box = await Hive.openBox(OfflineMessageBox.name);

      final offlineMessage = {
        ...messageData,
        'localId': DateTime.now().millisecondsSinceEpoch.toString(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };

      // Store in list
      List<dynamic> pendingMessages = box.get(
        OfflineMessageBox.pendingKey,
        defaultValue: [],
      );
      pendingMessages.add(offlineMessage);
      await box.put(OfflineMessageBox.pendingKey, pendingMessages);

      print('✅ Offline message saved: ${offlineMessage['localId']}');
    } catch (e) {
      print('❌ Error saving offline message: $e');
    }
  }

  Future<void> syncOfflineMessages() async {
    try {
      final box = await Hive.openBox(OfflineMessageBox.name);
      List<dynamic> pendingMessages = box.get(
        OfflineMessageBox.pendingKey,
        defaultValue: [],
      );

      if (pendingMessages.isEmpty) return;

      print('🔄 Syncing ${pendingMessages.length} offline messages...');

      final List<dynamic> successfulMessages = [];
      final List<dynamic> failedMessages = [];

      for (final message in pendingMessages) {
        try {
          final messageMap = Map<String, dynamic>.from(message);

          // Try to send the message
          await sendMessage(
            receiverId: messageMap['receiverId'] as String,
            senderId: messageMap['senderId'] as String,
            text: messageMap['text'] as String?,
            image: messageMap['image'] as String?,
            video: messageMap['video'] as String?,
            audio: messageMap['audio'] as String?,
            fileUrl: messageMap['fileUrl'] as String?,
            fileName: messageMap['fileName'] as String?,
            fileType: messageMap['fileType'] as String?,
            caption: messageMap['caption'] as String?,
            replyMessageId: messageMap['replyMessageId'] as String?,
            replyMessage: messageMap['replyMessage'] as String?,
            replyImage: messageMap['replyImage'] as String?,
            messageType: _stringToMessageType(
              messageMap['messageType'] as String? ?? 'direct',
            ),
          );

          successfulMessages.add(message);
          print('✅ Offline message synced: ${messageMap['localId']}');
        } catch (e) {
          print('❌ Failed to sync message: ${message['localId']}, error: $e');
          final retryCount = (message['retryCount'] ?? 0) + 1;

          if (retryCount < 5) {
            // Keep for retry
            message['retryCount'] = retryCount;
            message['lastRetry'] = DateTime.now().toIso8601String();
            failedMessages.add(message);
          } else {
            print(
              '⚠️ Max retries reached, discarding message: ${message['localId']}',
            );
          }
        }
      }

      // Update the box with remaining messages
      if (failedMessages.isNotEmpty) {
        await box.put(OfflineMessageBox.pendingKey, failedMessages);
      } else {
        await box.delete(OfflineMessageBox.pendingKey);
      }

      print(
        '✅ Sync complete: ${successfulMessages.length} sent, ${failedMessages.length} pending',
      );
    } catch (e) {
      print('❌ Error syncing offline messages: $e');
    }
  }

  Stream<List<Message>> getConversationMessagesSimple(
    String currentUserId,
    String friendId,
  ) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('chats')
        .doc(friendId)
        .collection('messages')
        .orderBy('timeStamp', descending: false)
        .snapshots()
        .map((snapshot) {
          List<Message> messages = [];
          for (var doc in snapshot.docs) {
            try {
              final message = Message.fromDoc(doc);
              if (!message.isDeleted || message.sender == currentUserId) {
                messages.add(message);
              }
            } catch (e) {
              print('Error parsing message: $e');
            }
          }
          return messages;
        })
        .handleError((error) {
          print('Error getting messages: $error');
          return <Message>[];
        });
  }

  Stream<List<Message>> getUserConversations(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Message> conversations = [];

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final friendId = data['userId'] ?? doc.id;

              final lastMessageSnapshot = await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('chats')
                  .doc(friendId)
                  .collection('messages')
                  .orderBy('timeStamp', descending: true)
                  .limit(1)
                  .get();

              if (lastMessageSnapshot.docs.isNotEmpty) {
                final lastMessage = Message.fromDoc(
                  lastMessageSnapshot.docs.first,
                );
                conversations.add(lastMessage);
              }
            } catch (e) {
              print('Error loading conversation: $e');
            }
          }

          return conversations;
        })
        .handleError((error) {
          print('Error getting user conversations: $error');
          return <Message>[];
        });
  }

  Stream<Map<String, dynamic>> getTypingStatus(String conversationId) {
    return FirebaseFirestore.instance
        .collection('typingIndicators')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return {};
          final data = snapshot.data() ?? {};

          final now = Timestamp.now().seconds;
          final cleanedData = Map<String, dynamic>.from(data);

          data.forEach((userId, userData) {
            if (userData is Map && userData['timestamp'] != null) {
              final timestamp = (userData['timestamp'] as Timestamp).seconds;
              if (now - timestamp > 10) {
                cleanedData.remove(userId);
              }
            }
          });

          return cleanedData;
        });
  }

  void setTypingStatus(String conversationId, String userId, bool isTyping) {
    try {
      _typingTimers[conversationId]?.cancel();

      if (isTyping) {
        _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
          _clearTypingStatus(conversationId, userId);
        });
      }

      final updateData = {
        userId: {
          'isTyping': isTyping,
          'timestamp': FieldValue.serverTimestamp(),
          'userName': _getCurrentUserName() ?? 'User',
        },
      };

      FirebaseFirestore.instance
          .collection('typingIndicators')
          .doc(conversationId)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('Error setting typing status: $e');
    }
  }

  Future<void> _sendNotificationData({
  required String receiverId,
  required String senderId,
  required String senderName,
  required String messageText,
  required String messageType,
}) async {
  try {
    // Create a notification document that triggers the cloud function
    final notificationRef = await _firestore.collection('notifications').add({
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'title': 'New message from $senderName',
      'body': messageText,
      'type': 'chat',
      'data': {
        'senderId': senderId,
        'receiverId': receiverId,
        'messageText': messageText,
        'messageType': messageType,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    
    print('✅ Notification document created: ${notificationRef.id}');
  } catch (e) {
    print('❌ Error sending notification data: $e');
  }
}

  void _clearTypingStatus(String conversationId, String userId) {
    try {
      FirebaseFirestore.instance
          .collection('typingIndicators')
          .doc(conversationId)
          .set({
            userId: {
              'isTyping': false,
              'timestamp': FieldValue.serverTimestamp(),
              'userName': _getCurrentUserName() ?? 'User',
            },
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error clearing typing status: $e');
    }
  }

  String? _getCurrentUserName() {
    final currentUser = authentication.currentUser;
    if (currentUser == null) return null;
    return currentUser.displayName ?? currentUser.email?.split('@').first;
  }

  Stream<DocumentSnapshot> getTypingStatusStream(String conversationId) {
    return FirebaseFirestore.instance
        .collection('typingIndicators')
        .doc(conversationId)
        .snapshots();
  }

  Future<void> addReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
    required String userId,
    required String username,
  }) async {
    try {
      final reaction = {
        'emoji': emoji,
        'userId': userId,
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final updateData = {
        'reactions.$userId': reaction,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').doc(messageId).update(updateData);

      await _updateMessageInAllChats(messageId, updateData);
    } catch (e) {
      print('Error adding reaction: $e');
      rethrow;
    }
  }

  Future<void> removeReaction({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final updateData = {
        'reactions.$userId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').doc(messageId).update(updateData);

      await _updateMessageInAllChats(messageId, updateData);
    } catch (e) {
      print('Error removing reaction: $e');
      rethrow;
    }
  }

  Future<void> editMessage({
    required String messageId,
    required String conversationId,
    required String newText,
    required String userId,
  }) async {
    try {
      if (newText.trim().isEmpty) {
        throw Exception('Message cannot be empty');
      }

      final updates = {
        'text': newText.trim(),
        'editedAt': FieldValue.serverTimestamp(),
        'status': 'edited',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').doc(messageId).update(updates);

      await _updateMessageInAllChats(messageId, updates);
    } catch (e) {
      print('Error editing message: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    required String userId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final messageDoc = await _firestore
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final messageData = messageDoc.data()!;
      final senderId = messageData['sender'] as String;

      if (senderId != userId && !deleteForEveryone) {
        throw Exception('You can only delete your own messages');
      }

      final updates = deleteForEveryone
          ? {
              'isDeleted': true,
              'deletedAt': FieldValue.serverTimestamp(),
              'deletedBy': userId,
              'text': 'This message was deleted',
              'status': 'deleted',
              'updatedAt': FieldValue.serverTimestamp(),
            }
          : {
              'deletedFor_$userId': true,
              'updatedAt': FieldValue.serverTimestamp(),
            };

      if (deleteForEveryone || senderId == userId) {
        await _firestore.collection('messages').doc(messageId).update(updates);
      }

      await _updateMessageInAllChats(messageId, updates);
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> markAsRead({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final readData = {
        'readBy.$userId': FieldValue.serverTimestamp(),
        'status': 'read',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').doc(messageId).update(readData);

      await _updateMessageInAllChats(messageId, readData);

      final parts = conversationId.split('_');
      if (parts.length == 2) {
        final otherUserId = parts[0] == userId ? parts[1] : parts[0];

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .doc(otherUserId)
            .update({
              'unreadCount': 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  Future<void> togglePinMessage({
    required String messageId,
    required String conversationId,
    required bool pin,
  }) async {
    try {
      final currentUserId = authentication.currentUser!.uid;
      final updates = {
        'isPinned': pin,
        'pinnedAt': pin ? FieldValue.serverTimestamp() : null,
        'pinnedBy': pin ? currentUserId : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').doc(messageId).update(updates);

      await _updateMessageInAllChats(messageId, updates);
    } catch (e) {
      print('Error pinning message: $e');
      rethrow;
    }
  }

  Future<void> forwardMessage({
    required Message originalMessage,
    required List<String> receiverIds,
    required String senderId,
    required String senderName,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final receiverId in receiverIds) {
        if (receiverId == senderId) continue;

        final messageId = _firestore.collection('messages').doc().id;
        final conversationId = _generateConversationId(senderId, receiverId);
        final timestamp = FieldValue.serverTimestamp();

        final forwardedMessage = {
          'id': messageId,
          'sender': senderId,
          'receiver': receiverId,
          'text': originalMessage.text,
          'image': originalMessage.image,
          'video': originalMessage.video,
          'audio': originalMessage.audio,
          'fileUrl': originalMessage.fileUrl,
          'fileName': originalMessage.fileName,
          'fileType': originalMessage.fileType,
          'caption': originalMessage.caption,
          'forwardFrom': originalMessage.sender,
          'forwardFromName': originalMessage.sender == senderId
              ? 'You'
              : senderName,
          'originalMessageId': originalMessage.id,
          'timeStamp': timestamp,
          'type': 'forwarded',
          'media': originalMessage.media,
          'status': 'sent',
          'isDeleted': false,
          'isPinned': false,
          'conversationId': conversationId,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        };

        final mainRef = _firestore.collection('messages').doc(messageId);
        batch.set(mainRef, forwardedMessage);

        final senderChatRef = _firestore
            .collection('users')
            .doc(senderId)
            .collection('chats')
            .doc(receiverId)
            .collection('messages')
            .doc(messageId);
        batch.set(senderChatRef, forwardedMessage);

        final receiverChatRef = _firestore
            .collection('users')
            .doc(receiverId)
            .collection('chats')
            .doc(senderId)
            .collection('messages')
            .doc(messageId);
        batch.set(receiverChatRef, forwardedMessage);

        final convId = _generateConversationId(senderId, receiverId);
        final convRef = _firestore.collection('conversations').doc(convId);
        batch.set(convRef, {
          'participants': [senderId, receiverId],
          'lastMessage': 'Forwarded: ${originalMessage.text}',
          'lastMessageTime': timestamp,
          'updatedAt': timestamp,
          'unreadCount_$receiverId': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error forwarding message: $e');
      rethrow;
    }
  }

  Future<List<Message>> searchInConversation({
    required String conversationId,
    required String query,
    required String currentUserId,
    required String friendId,
  }) async {
    try {
      final searchQuery = query.trim().toLowerCase();
      if (searchQuery.isEmpty) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('chats')
          .doc(friendId)
          .collection('messages')
          .where('text', isGreaterThanOrEqualTo: searchQuery)
          .where('text', isLessThan: searchQuery + '\uf8ff')
          .orderBy('text')
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        try {
          return Message.fromDoc(doc);
        } catch (e) {
          print('Error parsing search result: $e');
          return Message(
            id: doc.id,
            sender: '',
            receiver: '',
            text: 'Error loading message',
            media: false,
            timeStamp: Timestamp.now(),
            type: MessageType.direct,
          );
        }
      }).toList();
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  Stream<List<Message>> getPinnedMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('isPinned', isEqualTo: true)
        .orderBy('pinnedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            try {
              return Message.fromDoc(doc);
            } catch (e) {
              print('Error parsing pinned message: $e');
              return Message(
                id: doc.id,
                sender: '',
                receiver: '',
                text: 'Error loading message',
                media: false,
                timeStamp: Timestamp.now(),
                type: MessageType.direct,
              );
            }
          }).toList();
        });
  }

  Future<void> _updateMessageInAllChats(
    String messageId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final messageDoc = await _firestore
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;
      final senderId = messageData['sender'] as String;
      final receiverId = messageData['receiver'] as String;

      await Future.wait([
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('chats')
            .doc(receiverId)
            .collection('messages')
            .doc(messageId)
            .update(updates),

        _firestore
            .collection('users')
            .doc(receiverId)
            .collection('chats')
            .doc(senderId)
            .collection('messages')
            .doc(messageId)
            .update(updates),
      ]);
    } catch (e) {
      print('Error updating message in chats: $e');
    }
  }

  Future<void> playVoice(String url) async {
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print("Error playing audio: $e");
      rethrow;
    }
  }

  Future<void> stopVoice() async {
    try {
      await _player.stop();
    } catch (e) {
      print("Error stopping audio: $e");
    }
  }

  Future<void> pauseVoice() async {
    try {
      await _player.pause();
    } catch (e) {
      print("Error pausing audio: $e");
    }
  }

  Future<Duration?> getVoiceDuration(String url) async {
    try {
      await _player.setUrl(url);
      return _player.duration;
    } catch (e) {
      print("Error getting audio duration: $e");
      return null;
    }
  }

  @override
  void onClose() {
    _typingTimers.forEach((key, timer) {
      timer.cancel();
    });
    _typingTimers.clear();

    _player.dispose();

    super.onClose();
  }

  Future<void> uploadMessage(
    String uid,
    String message, {
    String? replyMessage,
    String? replyImage,
  }) async {
    await sendMessage(
      receiverId: uid,
      senderId: authentication.currentUser!.uid,
      text: message,
      replyMessage: replyMessage,
      replyImage: replyImage,
    );
  }

  Future<void> registerConversation(String uid, String message) async {}

  Future<void> refreshChats() async {
    messages.clear();
  }

  Stream<List<Message>>? getSpaceConversationMessages(
    String spaceId,
    String id,
  ) {}
}
