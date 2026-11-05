import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'package:mango/Core/theme/mango_palette.dart';

void showImageSourceDialog(BuildContext context, int type) {
  final controller = Get.find<UserDetailsController>(
    tag: UserDetailsController.tag,
  );
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MangoPalette.grey300,
                borderRadius: BorderRadius.circular(MangoRadius.xs),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              type == 0 ? 'Change Profile Picture' : 'Change Banner',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildOption(
              context,
              icon: Icons.photo_library,
              title: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                await controller.pickImage(ImageSource.gallery, type, context);
              },
            ),
            const SizedBox(height: 16),
            _buildOption(
              context,
              icon: Icons.camera_alt,
              title: 'Take a Photo',
              onTap: () async {
                Navigator.pop(context);
                await controller.pickImage(ImageSource.camera, type, context);
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildOption(BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MangoRadius.md),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MangoPalette.green500.withOpacity(0.05),
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(color: MangoPalette.green500.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: MangoPalette.green500),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: MangoPalette.grey500),
          ],
        ),
      ),
    ),
  );
}