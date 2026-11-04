import 'package:cloud_firestore/cloud_firestore.dart';

class MangoEpisodes {
  final String id;
  final String postCreator;
  final String image;
  final Timestamp timeStamp;

  MangoEpisodes({required this.postCreator, required this.image, required this.timeStamp, required this.id});
}