import 'package:cloud_firestore/cloud_firestore.dart';

class MyBooks {
  final String bookId;
  final String type;
  String paymentStatus;
  bool isFav;
  final Timestamp timeStamp;

  MyBooks({
    required this.paymentStatus,
    required this.isFav,
    required this.type,
    required this.timeStamp,
    required this.bookId});
}