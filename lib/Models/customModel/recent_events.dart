import 'package:cloud_firestore/cloud_firestore.dart';

class RecentEvent{
  var recentId;
  final String type;
  final Timestamp timeStamp;

  RecentEvent({
    required this.recentId,
    required this.type,
    required this.timeStamp
});

}