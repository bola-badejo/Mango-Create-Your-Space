import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';

class FollowersScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();
  final String userId;

  FollowersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No followers yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final followers = snapshot.data!.docs;

          return OptimizedListView(
            padding: const EdgeInsets.all(16),
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(follower.id)
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
                      trailing: _buildFollowButton(follower.id),
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

  Widget _buildFollowButton(String followerId) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    if (followerId == currentUserId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(followerId)
          .snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.hasData && snapshot.data!.exists;
        
        return ElevatedButton(
          onPressed: () {
            _toggleFollow(followerId, isFollowing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey : Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(isFollowing ? 'Following' : 'Follow Back'),
        );
      },
    );
  }

  void _toggleFollow(String userId, bool isFollowing) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

    if (isFollowing) {
      
      await currentUserRef.collection('following').doc(userId).delete();
      await userRef.collection('followers').doc(currentUserId).delete();
    } else {
      
      await currentUserRef.collection('following').doc(userId).set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      await userRef.collection('followers').doc(currentUserId).set({
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}