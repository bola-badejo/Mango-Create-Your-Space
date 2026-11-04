import 'package:cloud_firestore/cloud_firestore.dart';

class MangoShopItem {
  final String id;
  final String title;
  final String text;
  final String postCreator;
  final String quantity;
  final String image;
  final String packageWeight;
  final String packageWidth;
  final String packageHeight;
  final String manufacturer;
  final String releaseYear;
  final List<dynamic> tags;
  final Timestamp timeStamp;
  final String price;

  final String? repliedProductID;
  final bool repost;
  final bool reply;

  int repostCount;
  int replyCount;
  int likeCount;
  int purchaseCount;

  MangoShopItem(
      {required this.repostCount,
      required this.price,
      required this.quantity,
      required this.packageWeight,
      required this.packageWidth,
      required this.packageHeight,
      required this.manufacturer,
      required this.releaseYear,
      required this.purchaseCount,
      required this.tags,
      required this.replyCount,
      required this.likeCount,
      this.repliedProductID,
      required this.repost,
      required this.reply,
      required this.title,
      required this.text,
      required this.postCreator,
      required this.image,
      required this.timeStamp,
      required this.id});
}
