import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Profile/profile_controller.dart';
import 'package:mango/Utils/optimized_lists.dart';

class SpacesScreen extends StatelessWidget {
  final ProfileController profileController = Get.find<ProfileController>();

  SpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Spaces'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (profileController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final spaces = profileController.userSpaces;

        if (spaces.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.space_dashboard, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No spaces created yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return OptimizedListView(
          padding: const EdgeInsets.all(16),
          itemCount: spaces.length,
          itemBuilder: (context, index) {
            final space = spaces[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, color: Colors.blue),
                ),
                title: Text(
                  space.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(space.description),
                    const SizedBox(height: 4),
                    Text(
                      '${space.members} members • ${space.category}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
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
}