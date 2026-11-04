import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookDetailController extends GetxController {
  var book = {}.obs;
  var isLoading = true.obs;

  void fetchBook(String id) async {
    var doc = await FirebaseFirestore.instance.collection('library').doc(id).get();
    book.value = doc.data() ?? {};
    isLoading.value = false;
  }
}