import 'package:cloud_firestore/cloud_firestore.dart';

class MyMusic {
  final String song_id;
  final String type;
  String paymentStatus;
  bool isFav;
  final Timestamp timeStamp;

  MyMusic({
    required this.paymentStatus,
    required this.isFav,
    required this.type,
    required this.timeStamp,
    required this.song_id});
}