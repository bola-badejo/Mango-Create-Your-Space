import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/utils.dart';
import 'package:mango/Utils/optimized_lists.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class FollowingScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();
  final String userId;

  FollowingScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('following')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: MangoPalette.grey500),
                  SizedBox(height: 16),
                  Text(
                    'Not following anyone yet',
                    style: TextStyle(fontSize: 16, color: MangoPalette.grey500),
                  ),
                ],
              ),
            );
          }

          final following = snapshot.data!.docs;

          return OptimizedListView(
            padding: const EdgeInsets.all(16),
            itemCount: following.length,
            itemBuilder: (context, index) {
              final follow = following[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(follow.id)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading...'),
                    );
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  final username = userData?['username'] ?? 'Unknown User';
                  final displayName = userData?['displayName'] ?? 'Unknown User';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(displayName),
                      subtitle: Text('@$username'),
                      trailing: _buildUnfollowButton(follow.id, context),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUnfollowButton(String followingId, context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    if (followingId == currentUserId) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () {
        _unfollowUser(followingId, context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: MangoPalette.grey500,
        foregroundColor: Colors.white,
      ),
      child: const Text('Unfollow'),
    );
  }

  void _unfollowUser(String userId, context) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

    await currentUserRef.collection('following').doc(userId).delete();
    await userRef.collection('followers').doc(currentUserId).delete();

    UtilsService().showSnackbar(
      'Success',
      'Unfollowed user',
      backgroundColor: MangoPalette.green500,
      colorText: Colors.white, context: context,
    );
  }
}