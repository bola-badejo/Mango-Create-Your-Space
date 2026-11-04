import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';

class PostsScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();

  PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (profileController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = profileController.userPosts;

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return OptimizedListView(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.post_add, color: Colors.blue),
                title: Text(
                  post.text.isNotEmpty 
                    ? post.text 
                    : 'Post ${index + 1}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Posted on ${_formatDate(post.timeStamp!)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  
                  
                },
              ),
            );
          },
        );
      }),
    );
  }

  String _formatDate(Timestamp timestamp) {
    return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
  }
}