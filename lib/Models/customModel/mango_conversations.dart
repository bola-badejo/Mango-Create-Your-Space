import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationData {
  final String id;
  final String text;
  final String postCreator;
  final String image;
  final Timestamp timeStamp;

  ConversationData({required this.text, required this.postCreator, required this.image, required this.timeStamp, required this.id});
}

