import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class PodcastsScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();

  PodcastsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Podcasts'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (profileController.isLoading.value) {
          return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'));
        }

        
        
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.podcasts, size: 64, color: MangoPalette.grey500),
              SizedBox(height: 16),
              Text(
                'No podcasts yet',
                style: TextStyle(fontSize: 16, color: MangoPalette.grey500),
              ),
              SizedBox(height: 8),
              Text(
                'Start creating podcasts to see them here',
                style: TextStyle(fontSize: 14, color: MangoPalette.grey500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}