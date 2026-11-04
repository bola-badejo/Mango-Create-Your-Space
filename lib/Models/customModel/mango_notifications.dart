import 'package:cloud_firestore/cloud_firestore.dart';

class MangoNotifications {
  final String id;
  final String message;
  final String sender;
  final String title;
  final String receiver;
  final String page;
  final dynamic pageId;
  final Timestamp timeStamp;

  MangoNotifications({
    required this.message,
    required this.sender,
    required this.title,
    required this.receiver,
    required this.page,
    required this.pageId,
    required this.timeStamp,
    required this.id});
}
