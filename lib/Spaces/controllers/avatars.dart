import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class AvatarController extends GetxController {
  
  var planetaryAvatars = <Map>[].obs;
  var spaceObjectAvatars = <Map>[].obs;
  var mangoCustomAvatars = <Map>[].obs;
  var searchQuery = ''.obs;
  var selectedAvatar = ''.obs;
  var isLoading = true.obs;

  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();

  @override
  void onInit() {
    super.onInit();
    fetchAvatars();
  }

  void fetchAvatars() async {
    try {
      isLoading.value = true;
      print('🔄 Fetching avatars from database...');
      
      DataSnapshot snapshot = await _databaseReference.child('avatars').get();
      
      if (snapshot.exists) {
        Map<dynamic, dynamic> avatars = snapshot.value as Map;
        print('✅ Avatars data found: ${avatars.keys}');
        
        if (avatars['planetary'] != null) {
          planetaryAvatars.assignAll(List<Map>.from(avatars['planetary']));
          print('🌍 Planetary avatars: ${planetaryAvatars.length}');
        }
        
        if (avatars['space_objects'] != null) {
          spaceObjectAvatars.assignAll(List<Map>.from(avatars['space_objects']));
          print('🚀 Space objects: ${spaceObjectAvatars.length}');
        }
        
        if (avatars['mango_custom'] != null) {
          mangoCustomAvatars.assignAll(List<Map>.from(avatars['mango_custom']));
          print('🥭 Mango custom: ${mangoCustomAvatars.length}');
        }
        
      } else {
        print('❌ No avatars found in database');
      }
    } catch (e) {
      print('❌ Error fetching avatars: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }

  void selectAvatar(String link) {
    selectedAvatar.value = link;
    print('✅ Selected avatar: $link');
  }
}