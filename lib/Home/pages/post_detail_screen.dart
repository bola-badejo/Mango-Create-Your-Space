import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Home/components/post_card.dart';
import 'package:mango/Home/controllers/dashboard_controller.dart';
import 'package:mango/Home/home.dart';
import 'package:mango/Models/customModel/post.dart';
import 'package:mango/Home/home.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  final MangoDashboardController controller = Get.find<MangoDashboardController>();

  PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
        tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: StreamBuilder<MangoPost>(
          stream: controller.getPost(postId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator(semanticsLabel: 'Loading');
            }
          
          final post = snapshot.data!;
          return PostCard(post: post);
        },
      ),
    );
  }
}