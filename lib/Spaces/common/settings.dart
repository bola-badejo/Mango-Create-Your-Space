import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mango/Models/animation.dart';
import 'package:mango/Spaces/controllers/space_controller.dart';
import 'package:mango/Spaces/controllers/space_model.dart';
import 'package:mango/Utils/text_field.dart';
import 'package:mango/utils.dart';

class SpaceSettingsScreen extends StatefulWidget {
  final SpaceModel space;

  const SpaceSettingsScreen({Key? key, required this.space}) : super(key: key);

  @override
  State<SpaceSettingsScreen> createState() => _SpaceSettingsScreenState();
}

class _SpaceSettingsScreenState extends State<SpaceSettingsScreen> {
  final SpaceController _spaceController = Get.find<SpaceController>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _categoryController;

  // Settings state
  final RxBool _isPrivate = false.obs;
  final RxBool _allowInvites = true.obs;
  final RxBool _moderateContent = false.obs;
  final RxBool _notificationsEnabled = true.obs;

  String? _backgroundImageUrl;
  bool _isUploadingBg = false;
  final ImagePicker _picker = ImagePicker();

  // Feature state
  final RxBool _hasMusic = false.obs;
  final RxBool _hasBooks = false.obs;
  final RxBool _hasPodcast = false.obs;
  final RxBool _hasVines = false.obs;
  final RxBool _hasShop = false.obs;
  final RxBool _hasLounge = false.obs;

  final GlobalKey<ExpansionTileCardState> basicInfoCard = GlobalKey();
  final GlobalKey<ExpansionTileCardState> privacyCard = GlobalKey();
  final GlobalKey<ExpansionTileCardState> featuresCard = GlobalKey();
  final GlobalKey<ExpansionTileCardState> dangerCard = GlobalKey();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentSettings();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.space.title);
    _descriptionController = TextEditingController(text: widget.space.description);
    _priceController = TextEditingController(text: widget.space.price);
    _categoryController = TextEditingController(text: widget.space.category);
  }

  void _loadCurrentSettings() {
    _isPrivate.value = widget.space.isPrivate;
    _hasMusic.value = widget.space.hasMusic;
    _hasBooks.value = widget.space.hasBooks;
    _hasPodcast.value = widget.space.hasPodcast;
    _hasVines.value = widget.space.hasVines;
    _hasShop.value = widget.space.hasShop;
    _hasLounge.value = widget.space.hasLounge;
    _backgroundImageUrl = widget.space.spaceBackground;

    // Default additional settings
    _allowInvites.value = true;
    _moderateContent.value = false;
    _notificationsEnabled.value = true;
  }

  Future<void> _pickBackgroundImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingBg = true);

    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('spaces/${widget.space.id}/background.jpg');

      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();

      setState(() => _backgroundImageUrl = downloadUrl);

      UtilsService().showSnackbar(
        'Success',
        'Background image updated',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to upload image: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      setState(() => _isUploadingBg = false);
    }
  }

  Future<void> _removeBackgroundImage() async {
    setState(() => _isUploadingBg = true);
    try {
      // Delete from storage if exists
      if (_backgroundImageUrl != null && _backgroundImageUrl!.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(_backgroundImageUrl!);
          await ref.delete();
        } catch (_) {
          // Ignore deletion errors (file might not exist)
        }
      }
      setState(() => _backgroundImageUrl = null);
      UtilsService().showSnackbar(
        'Removed',
        'Background image removed',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to remove image: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      setState(() => _isUploadingBg = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final updates = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'category': _categoryController.text.trim(),
        'spaceBackground': _backgroundImageUrl,
        'isPrivate': _isPrivate.value,
        'hasMusic': _hasMusic.value,
        'hasBooks': _hasBooks.value,
        'hasPodcast': _hasPodcast.value,
        'hasVines': _hasVines.value,
        'hasShop': _hasShop.value,
        'hasLounge': _hasLounge.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Remove null background (optional)
      if (_backgroundImageUrl == null) {
        updates['spaceBackground'] = FieldValue.delete();
      }

      await _spaceController.updateSpaceSettings(widget.space.id, updates);

      // Update local model (optional, but good for consistency)
      final updatedSpace = widget.space.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: _priceController.text.trim(),
        category: _categoryController.text.trim(),
        isPrivate: _isPrivate.value,
        hasMusic: _hasMusic.value,
        hasBooks: _hasBooks.value,
        hasPodcast: _hasPodcast.value,
        hasVines: _hasVines.value,
        hasShop: _hasShop.value,
        hasLounge: _hasLounge.value,
      );

      UtilsService().showSnackbar(
        'Success',
        'Space settings updated',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        context: context,
      );
      Navigator.pop(context, updatedSpace);
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to update: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.primaryColorLight;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: cardColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          "Space Settings",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(
            () => IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Icon(Icons.save, color: textColor),
              onPressed: _isLoading ? null : _saveSettings,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Background image section – enhanced UI
            _buildBackgroundSection(),
            const SizedBox(height: 20),

            // Basic Information Card
            ExpansionTileCard(
              elevation: 0,
              key: basicInfoCard,
              leading: CircleAvatar(
                backgroundColor: theme.primaryColor,
                child: Icon(
                  Icons.info,
                  size: 18,
                  color: textColor,
                ),
              ),
              title: Text(
                "Basic Information",
                style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                "Space details and configuration",
                style: TextStyle(fontSize: 9, color: textColor, fontWeight: FontWeight.w500),
              ),
              children: <Widget>[
                const Divider(thickness: 0.10, height: 0.10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    children: [
                      FadeAnimation(
                        1.1,
                        CustomTextField(
                          controller: _titleController,
                          placeholder: 'Space Title',
                          leading: Icon(Icons.title, color: textColor, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeAnimation(
                        1.2,
                        CustomMultilineTextField(
                          controller: _descriptionController,
                          placeholder: 'Space Description',
                          leading: Icon(Icons.description, color: textColor, size: 20),
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FadeAnimation(
                              1.3,
                              CustomTextField(
                                controller: _categoryController,
                                placeholder: 'Category',
                                leading: Icon(Icons.category, color: textColor, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FadeAnimation(
                              1.4,
                              CustomTextField(
                                controller: _priceController,
                                placeholder: 'Price',
                                keyboardType: TextInputType.number,
                                leading: Icon(Icons.attach_money, color: textColor, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Privacy & Access Card
            ExpansionTileCard(
              elevation: 0,
              key: privacyCard,
              leading: CircleAvatar(
                backgroundColor: theme.primaryColor,
                child: Icon(Icons.security, size: 18, color: textColor),
              ),
              title: Text(
                "Privacy & Access",
                style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                "Control who can access your space",
                style: TextStyle(fontSize: 9, color: textColor, fontWeight: FontWeight.w500),
              ),
              children: <Widget>[
                const Divider(thickness: 0.10, height: 0.10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    children: [
                      _buildSettingSwitch(
                        'Private Space',
                        'Only invited members can join',
                        _isPrivate,
                        Icons.lock,
                      ),
                      _buildSettingSwitch(
                        'Allow Invites',
                        'Members can invite others',
                        _allowInvites,
                        Icons.person_add,
                      ),
                      _buildSettingSwitch(
                        'Content Moderation',
                        'Approve posts before they appear',
                        _moderateContent,
                        Icons.verified,
                      ),
                      _buildSettingSwitch(
                        'Notifications',
                        'Receive space activity updates',
                        _notificationsEnabled,
                        Icons.notifications,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Space Features Card
            ExpansionTileCard(
              elevation: 0,
              key: featuresCard,
              leading: CircleAvatar(
                backgroundColor: theme.primaryColor,
                child: Icon(Icons.featured_play_list, size: 18, color: textColor),
              ),
              title: Text(
                "Space Features",
                style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                "Enable or disable space functionalities",
                style: TextStyle(fontSize: 9, color: textColor, fontWeight: FontWeight.w500),
              ),
              children: <Widget>[
                const Divider(thickness: 0.10, height: 0.10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: _buildFeatureGrid(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Danger Zone Card
            ExpansionTileCard(
              elevation: 0,
              key: dangerCard,
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.warning, size: 18, color: Colors.white),
              ),
              title: Text(
                "Danger Zone",
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                "Irreversible actions - proceed with caution",
                style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.w500),
              ),
              children: <Widget>[
                const Divider(thickness: 0.10, height: 0.10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    children: [
                      _buildDangerButton(
                        'Transfer Ownership',
                        Icons.swap_horiz,
                        Colors.orange,
                        () => _showTransferDialog(),
                      ),
                      _buildDangerButton(
                        'Archive Space',
                        Icons.archive,
                        Colors.amber,
                        () => _archiveSpace(),
                      ),
                      _buildDangerButton(
                        'Delete Space',
                        Icons.delete_forever,
                        Colors.red,
                        () => _deleteSpace(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ------------------- UI Components -------------------

  Widget _buildBackgroundSection() {
    final theme = Theme.of(context);
    final textColor = theme.primaryColorLight;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image or placeholder
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _backgroundImageUrl != null
                  ? Image.network(
                      _backgroundImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                    )
                  : _buildPlaceholder(theme),
            ),
            // Overlay with gradient for better text visibility
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            // Centered actions
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploadingBg)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.photo_camera, color: Colors.white, size: 32),
                        onPressed: _pickBackgroundImage,
                        tooltip: 'Change background',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _backgroundImageUrl == null ? 'Tap to add background' : 'Tap to change',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      if (_backgroundImageUrl != null)
                        TextButton(
                          onPressed: _removeBackgroundImage,
                          child: const Text('Remove', style: TextStyle(color: Colors.white70)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: theme.primaryColorLight.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              'No background set',
              style: TextStyle(color: theme.primaryColorLight.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    RxBool value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.primaryColorLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColorLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          Obx(
            () => Switch(
              value: value.value,
              onChanged: (newValue) => value.value = newValue,
              activeColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildFeatureCard('Music', Icons.music_note, _hasMusic, 'Stream music with members'),
        _buildFeatureCard('Books', Icons.book, _hasBooks, 'Read and share books'),
        _buildFeatureCard('Podcasts', Icons.podcasts, _hasPodcast, 'Create and listen to podcasts'),
        _buildFeatureCard('Videos', Icons.video_library, _hasVines, 'Share short videos'),
        _buildFeatureCard('Shop', Icons.shopping_cart, _hasShop, 'Buy and sell items'),
        _buildFeatureCard('Lounge', Icons.chat, _hasLounge, 'Chat with members'),
      ],
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, RxBool isEnabled, String description) {
    final theme = Theme.of(context);
    return Obx(
      () => GestureDetector(
        onTap: () => isEnabled.value = !isEnabled.value,
        child: Container(
          decoration: BoxDecoration(
            color: isEnabled.value
                ? Colors.orange.withOpacity(0.15)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled.value ? Colors.orange : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isEnabled.value ? Colors.orange : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: isEnabled.value ? Colors.orange : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isEnabled.value)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle, size: 12, color: Colors.orange),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDangerButton(String text, IconData icon, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: MaterialButton(
        onPressed: onTap,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  // ------------------- Dialogs -------------------

  void _showTransferDialog() {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: "Transfer Ownership",
      titleStyle: TextStyle(color: theme.primaryColorLight),
      content: Column(
        children: [
          Text(
            "This feature will allow you to transfer space ownership to another member.",
            style: TextStyle(color: theme.primaryColorLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Coming soon!",
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      backgroundColor: theme.cardColor,
      confirm: TextButton(
        onPressed: () => Get.back(),
        child: Text("Close", style: TextStyle(color: theme.primaryColorLight)),
      ),
    );
  }

  void _archiveSpace() {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: "Archive Space",
      titleStyle: TextStyle(color: theme.primaryColorLight),
      content: Text(
        "Archiving will hide this space from public view. You can restore it later.",
        style: TextStyle(color: theme.primaryColorLight),
        textAlign: TextAlign.center,
      ),
      backgroundColor: theme.cardColor,
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
        onPressed: () {
          Get.back();
          UtilsService().showSnackbar(
            'Coming Soon',
            'Archive space feature will be available soon',
            backgroundColor: Colors.blue,
            colorText: Colors.white,
            context: context,
          );
        },
        child: const Text('Archive', style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Text('Cancel', style: TextStyle(color: theme.primaryColorLight)),
      ),
    );
  }

  void _deleteSpace() async {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: "Delete Space",
      titleStyle: TextStyle(color: Colors.red),
      content: Text(
        "Are you sure you want to delete '${widget.space.title}'? This action cannot be undone and all space data will be permanently lost.",
        style: TextStyle(color: theme.primaryColorLight),
        textAlign: TextAlign.center,
      ),
      backgroundColor: theme.cardColor,
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: () async {
          Get.back(); // close dialog
          UtilsService().showSnackbar(
            'Deleting Space',
            'Please wait...',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            context: context,
          );
          try {
            await _spaceController.deleteSpace(widget.space.id);
            UtilsService().showSnackbar(
              'Space Deleted',
              '${widget.space.title} has been deleted',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              context: context,
            );
            Navigator.pop(context); // back from settings
            Navigator.pop(context); // back from detail screen
          } catch (e) {
            UtilsService().showSnackbar(
              'Error',
              'Failed to delete: ${e.toString()}',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              context: context,
            );
          }
        },
        child: const Text('Delete Forever', style: TextStyle(color: Colors.white)),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Text('Cancel', style: TextStyle(color: theme.primaryColorLight)),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}