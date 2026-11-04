import 'package:cloud_firestore/cloud_firestore.dart';

class MyVines {
  final String vineId;
  final String type;
  String paymentStatus;
  bool isFav;
  final Timestamp timeStamp;

  MyVines({
    required this.paymentStatus,
    required this.isFav,
    required this.type,
    required this.timeStamp,
    required this.vineId});
}