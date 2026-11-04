import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';

class ProfilePictureSection extends StatelessWidget {
  const ProfilePictureSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UserDetailsController>(tag: UserDetailsController.tag);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Obx(() {
          
          if (controller.profileImage.value != null) {
            if (controller.profileImage.value is File) {
              return Image.file(
                controller.profileImage.value as File,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
              );
            } else if (controller.profileImage.value is Uint8List) {
              return Image.memory(
                controller.profileImage.value as Uint8List,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
              );
            }
          }

          
          if (controller.userData?.profileImage?.isNotEmpty ?? false) {
            return CachedNetworkImage(
              imageUrl: controller.userData!.profileImage!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _buildPlaceholder(isDark),
              errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
            );
          }

          
          return _buildPlaceholder(isDark);
        }),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 40,
        color: isDark ? Colors.grey[400] : Colors.grey,
      ),
    );
  }
}