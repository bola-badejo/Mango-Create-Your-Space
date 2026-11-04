import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/user_detail/user_detail_controller.dart';
import 'profile_picture_section.dart';
import 'image_source_dialog.dart';

class Step1Profile extends StatelessWidget {
  Step1Profile({super.key});
  final UserDetailsController controller = Get.find<UserDetailsController>(tag: UserDetailsController.tag);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onBackground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BannerSection(),
        Transform.translate(
          offset: const Offset(0, -60),
          child: const ProfilePictureSection(),
        ),
        const SizedBox(height: 10),
        _ChangePhotoButton(),
        const SizedBox(height: 40),
        _UserInfoForm(
          controller: controller,
          textColor: textColor,
        ),
      ],
    );
  }
}


class _BannerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UserDetailsController>(tag: UserDetailsController.tag);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          
          Obx(() {
            
            if (controller.bannerImage.value != null) {
              if (controller.bannerImage.value is File) {
                return Image.file(
                  controller.bannerImage.value as File,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                );
              } else if (controller.bannerImage.value is Uint8List) {
                return Image.memory(
                  controller.bannerImage.value as Uint8List,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                );
              }
            }

            
            if (controller.userData?.bannerImageUrl?.isNotEmpty ?? false) {
              return CachedNetworkImage(
                imageUrl: controller.userData!.bannerImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildPlaceholder(isDark),
                errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
              );
            }

            
            return _buildPlaceholder(isDark);
          }),

          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.4), Colors.transparent],
              ),
            ),
          ),

          
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => showImageSourceDialog(context, 1),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.grey.shade700,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey.shade200,
      child: Icon(
        Icons.photo_library,
        color: isDark ? Colors.grey[400] : Colors.grey,
        size: 50,
      ),
    );
  }
}


class _ChangePhotoButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UserDetailsController>(tag: UserDetailsController.tag);

    return Obx(() {
      final isSelected = controller.isProfileImageSelected.value;
      return ElevatedButton.icon(
        onPressed: () => showImageSourceDialog(context, 0),
        icon: Icon(
          Icons.camera_alt,
          size: 16,
          color: isSelected ? Colors.green : Colors.orange,
        ),
        label: Text(
          isSelected ? "Photo Updated!" : "Change Profile Picture",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.green : Colors.orange,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          foregroundColor: isSelected ? Colors.green : Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          elevation: 0,
        ),
      );
    });
  }
}


class _UserInfoForm extends StatelessWidget {
  final UserDetailsController controller;
  final Color textColor;

  const _UserInfoForm({required this.controller, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEditableField(
            controller: controller.displayNameController,
            label: 'Display Name',
            onChanged: controller.onDisplayNameChanged,
            isDark: isDark,
            textColor: textColor,
          ),
          const SizedBox(height: 16),
          _buildUsernameField(
            controller: controller.usernameController,
            label: 'Username',
            onChanged: controller.onUsernameChanged,
            userController: controller,   
            isDark: isDark,
            textColor: textColor,
          ),
          const SizedBox(height: 20),
          _buildEditableField(
            controller: controller.bioController,
            label: 'Bio',
            isBio: true,
            onChanged: controller.onBioChanged,
            userController: controller,   
            isDark: isDark,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  
  Widget _buildUsernameField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    required UserDetailsController userController,
    required bool isDark,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'e.g., john_doe or johndoe',
            hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange, width: 2),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            prefix: Text('@', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11)),
          ),
          maxLength: ValidationPatterns.maxUsernameLength,
          onChanged: (value) {
            final filtered = value.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
            final cleaned = filtered.startsWith('.') || filtered.startsWith('_')
                ? filtered.substring(1)
                : filtered;
            if (value != cleaned) {
              controller.text = cleaned;
              controller.selection = TextSelection.collapsed(offset: cleaned.length);
            }
            onChanged(cleaned);
          },
        ),
        
        Obx(() {
          final error = userController.usernameError.value;
          if (error.isEmpty) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
          );
        }),
      ],
    );
  }

  
  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    bool isBio = false,
    required ValueChanged<String> onChanged,
    UserDetailsController? userController,  
    required bool isDark,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,            
          style: TextStyle(color: textColor, fontSize: 11),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange, width: 2),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isBio ? 16 : 12,
            ),
          ),
          maxLines: isBio ? 3 : 1,
          minLines: isBio ? 2 : 1,
          onChanged: onChanged,
        ),
        if (isBio) ...[
          const SizedBox(height: 4),
          
          Obx(() {
            final length = userController!.bioLength.value;
            return Text(
              '$length/500 characters',
              style: TextStyle(
                fontSize: 10,
                color: length > 500 ? Colors.red : textColor.withOpacity(0.6),
              ),
            );
          }),
        ],
      ],
    );
  }
}