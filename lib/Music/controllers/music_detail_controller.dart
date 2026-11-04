import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MusicDetailController extends GetxController {
  var music = {}.obs;
  var isLoading = true.obs;

  void fetchMusic(String id) async {
    var doc = await FirebaseFirestore.instance.collection('playlists').doc(id).get();
    music.value = doc.data() ?? {};
    isLoading.value = false;
  }
}