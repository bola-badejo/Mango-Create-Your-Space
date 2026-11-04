import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mango/Models/cloud/content.dart';

class CatalogController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  var trending = <Content>[].obs;
  var newReleases = <Content>[].obs;
  var recommended = <Content>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTrending();
    fetchNewReleases();
    fetchRecommended();
  }

  void fetchTrending() {
    _db
        .collection('content')
        .orderBy('playCount', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      trending.value =
          snapshot.docs.map((d) => Content.fromFirestore(d.data(), d.id)).toList();
    });
  }

  void fetchNewReleases() {
    _db
        .collection('content')
        .orderBy('releaseDate', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      newReleases.value =
          snapshot.docs.map((d) => Content.fromFirestore(d.data(), d.id)).toList();
    });
  }

  void fetchRecommended() {
    
    _db
        .collection('content')
        .where('genres', arrayContains: 'pop')
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      recommended.value =
          snapshot.docs.map((d) => Content.fromFirestore(d.data(), d.id)).toList();
    });
  }
}
