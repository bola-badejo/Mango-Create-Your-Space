import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mango/Models/customModel/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class FriendsController extends GetxController {
  var friends = <MangoUser>[].obs;
  var collaborators = <String>[].obs;
  var selectedFriends = <MangoUser>[].obs;
  var searchQuery = ''.obs;
  var filteredFriends = <MangoUser>[].obs;
  final RxBool isPodcast = false.obs;
  final RxBool isPrivate = false.obs;
  final RxBool isMovies = false.obs;
  final RxBool isMusic = false.obs;
  final RxBool isBooks = false.obs;
  final RxBool isLounge = false.obs;
  final RxBool isLoading = false.obs; 

  @override
  void onInit() {
    super.onInit();
    _fetchFriendIds();
    debounce(searchQuery, (_) => filterFriends(),
        time: const Duration(milliseconds: 300));
  }

  void _fetchFriendIds() async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      var friendIds = snapshot.docs.map((doc) => doc.id).toList();
      _fetchFriends(friendIds);
    });
  }

  void _fetchFriends(List<String> friendIds) {
    if (friendIds.isEmpty) {
      friends.clear();
      filteredFriends.clear();
      return;
    }
    
    FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      friends.value =
          snapshot.docs.map((doc) => MangoUser.fromDocument(doc)).toList();
      filteredFriends.value = friends;
    });
  }

  void toggleSelectedFriend(MangoUser friend) {
    if (selectedFriends.contains(friend)) {
      selectedFriends.remove(friend);
      collaborators.remove(friend.id);
    } else {
      selectedFriends.add(friend);
      collaborators.add(friend.id);
    }
  }
  
  // NEW: Remove specific friend from selected list
  void removeSelectedFriend(MangoUser friend) {
    if (selectedFriends.contains(friend)) {
      selectedFriends.remove(friend);
      collaborators.remove(friend.id);
      
      // Show success feedback
      Get.snackbar(
        'Contributor Removed',
        '@${friend.username} has been removed',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  // NEW: Check if a friend is selected
  bool isSelected(MangoUser friend) {
    return selectedFriends.contains(friend);
  }
  
  // NEW: Clear all selected friends
  void clearSelectedFriends() {
    if (selectedFriends.isNotEmpty) {
      selectedFriends.clear();
      collaborators.clear();
      
      Get.snackbar(
        'All Removed',
        'All collaborators have been removed',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }
  
  // NEW: Get selected count
  int get selectedCount => selectedFriends.length;
  
  // NEW: Get available friends (not selected)
  List<MangoUser> get availableFriends {
    return friends.where((friend) => !selectedFriends.contains(friend)).toList();
  }

  Future<void> createSpace(
      String title, String description, String price, String category, context) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      await FirebaseFirestore.instance.collection('spaces').add({
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'hasPodcast': isPodcast.value,
        'isPrivate': isPrivate.value,
        'hasMovies': isMovies.value,
        'hasMusic': isMusic.value,
        'hasBooks': isBooks.value,
        'hasLounge': isLounge.value,
        'collaborators': collaborators,
        'postCreator': FirebaseAuth.instance.currentUser!.uid,
        'members': collaborators.length == 0 ? 1 : collaborators.length + 1,
        'timeStamp': FieldValue.serverTimestamp()
      });
      print('✅ Space created successfully');
      
      // Show success message
      UtilsService().showSnackbar(
        'Success',
        'Space created successfully!',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white, 
        context: context,
      );
      
    } catch (e) {
      print('❌ Error creating space: $e');
      UtilsService().showSnackbar(
        'Error',
        'Failed to create space: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white, 
        context: context,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterFriends() {
    var query = searchQuery.value.toLowerCase();
    if (query.isEmpty) {
      filteredFriends.value = friends;
    } else {
      filteredFriends.value = friends.where((friend) {
        return friend.username.toLowerCase().contains(query) ||
            friend.displayName.toLowerCase().contains(query);
      }).toList();
    }
    filteredFriends.sort((a, b) => a.username.compareTo(b.username));
  }
}