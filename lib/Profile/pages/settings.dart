import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Media/compose/mango_composer.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/Utils/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../Models/animation.dart';
import '../profile_controller.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';


class AccountSettingsPage extends StatefulWidget {
  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final ProfileController profileController = Get.find<ProfileController>();
  final ThemeController themeController = Get.find<ThemeController>();
  final NotificationController notificationController =
      Get.find<NotificationController>();
  final ImagePicker _imagePicker = ImagePicker();
  final UtilsService _utilsService = UtilsService();

  Uint8List? _webProfileImageBytes;
  Uint8List? _webBannerImageBytes;
  String? _webProfileImageName;
  String? _webBannerImageName;

  // For iOS detection
  bool _isiOS = false;
  bool _isStandalonePWA = false;
  bool _isCheckingPWA = true;

  // Local state for notification toggle
  bool _localNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _detectiOSAndPWA();
    // Sync local state with controller
    _localNotificationsEnabled =
        notificationController.notificationsEnabled.value;
  }

  Future<void> _detectiOSAndPWA() async {
    if (kIsWeb) {
      try {
        final userAgent = html.window.navigator.userAgent;
        final isiOS =
            userAgent.contains('iPhone') || userAgent.contains('iPad');

        bool isStandalone = false;
        try {
          isStandalone = html.window
              .matchMedia('(display-mode: standalone)')
              .matches;
        } catch (e) {
          print('Error detecting standalone mode: $e');
        }

        setState(() {
          _isiOS = isiOS;
          _isStandalonePWA = isStandalone;
          _isCheckingPWA = false;
        });

        print('iOS detected: $_isiOS, PWA mode: $_isStandalonePWA');
      } catch (e) {
        print('Error detecting iOS/PWA: $e');
        setState(() {
          _isCheckingPWA = false;
        });
      }
    } else {
      setState(() {
        _isCheckingPWA = false;
      });
    }
  }

  Future<void> _requestIOSPWAPermission() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? MangoPalette.grey900
                  : Colors.white,
              borderRadius: BorderRadius.circular(MangoRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(semanticsLabel: 'Loading'),
                const SizedBox(height: 16),
                Text(
                  'Enabling notifications...',
                  style: TextStyle(color: _getTextColor(context)),
                ),
              ],
            ),
          ),
        ),
      );

      if (kIsWeb && _isiOS) {
        if (html.Notification.permission == null) {
          Navigator.pop(context);
          _showSnackbar(
            'Notifications not supported on this browser',
            isError: true,
          );
          return;
        }

        final permission = await html.Notification.requestPermission();

        Navigator.pop(context);

        if (permission == 'granted') {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await notificationController.saveToken(token);
            await notificationController.setNotificationsEnabled(true);

            setState(() {
              _localNotificationsEnabled = true;
            });

            _showIOSPWASuccessDialog();
          }
        } else {
          _showIOSPWAInstructionDialog();
        }
      } else {
        Navigator.pop(context);
        await notificationController.requestPermissionIfNeeded();

        // Update local state after permission
        setState(() {
          _localNotificationsEnabled =
              notificationController.notificationsEnabled.value;
        });
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error requesting iOS PWA permission: $e');
      _showSnackbar('Failed to enable notifications: $e', isError: true);
    }
  }

  void _showIOSPWASuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: MangoPalette.green500),
            const SizedBox(width: 8),
            const Text('Notifications Enabled!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You will now receive notifications even when the app is closed.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MangoPalette.green500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: MangoPalette.green500, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Test notifications by having someone message you',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showIOSPWAInstructionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MangoRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('How to Enable Notifications'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For notifications to work on iPhone home screen app:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              '1',
              'Open iPhone Settings',
              'Go to Settings → Notifications → Safari',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '2',
              'Find Mango',
              'Look for Mango in the app list',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '3',
              'Enable Notifications',
              'Turn on "Allow Notifications"',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              '4',
              'Restart App',
              'Close and reopen from home screen',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(
    String number,
    String title,
    String description,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : MangoPalette.black,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIOSPWAButton(
    bool isDarkMode,
    Color primaryColor,
    Color textColor,
  ) {
    if (!kIsWeb || !_isiOS || _isCheckingPWA) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 4,
        shadowColor: primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(MangoRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(MangoRadius.lg),
          ),
          child: InkWell(
            onTap: _requestIOSPWAPermission,
            borderRadius: BorderRadius.circular(MangoRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    child: const Icon(
                      Icons.apple,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'iPhone Home Screen App',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isStandalonePWA
                              ? 'Tap to enable notifications for this app'
                              : 'Add to home screen first for notifications',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(MangoRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isStandalonePWA ? 'Enable' : 'Learn More',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isStandalonePWA
                              ? Icons.notifications_active
                              : Icons.arrow_forward,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSPWAInfoCard(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    if (!kIsWeb || !_isiOS || _isStandalonePWA || _isCheckingPWA) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? MangoPalette.grey900 : Colors.blue[50],
        borderRadius: BorderRadius.circular(MangoRadius.md),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'iPhone Users: Get Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'To receive notifications when the app is closed:',
            style: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
          const SizedBox(height: 8),
          _buildInfoStep(
            '1',
            'Tap the Share button',
            'at the bottom of Safari',
            isDarkMode,
          ),
          _buildInfoStep(
            '2',
            'Select "Add to Home Screen"',
            'then tap "Add"',
            isDarkMode,
          ),
          _buildInfoStep(
            '3',
            'Open the app from your Home Screen',
            'then tap "Enable Notifications" above',
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(
    String number,
    String action,
    String instruction,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: action,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : MangoPalette.black,
                    ),
                  ),
                  TextSpan(
                    text: ' $instruction',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? MangoPalette.grey400 : MangoPalette.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIXED: Proper notification toggle that updates state
  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
            child: Center(child: FaIcon(icon, size: 18, color: textColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<bool>(
            stream: notificationController.notificationsEnabled.stream,
            initialData: notificationController.notificationsEnabled.value,
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              return Switch(
                value: isEnabled,
                onChanged: (newValue) async {
                  if (newValue) {
                    // Show loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Enabling notifications...'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Request permission and save token
                    await notificationController.requestPermissionIfNeeded();

                    // Update local state
                    setState(() {
                      _localNotificationsEnabled =
                          notificationController.notificationsEnabled.value;
                    });

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Notifications enabled!'),
                        backgroundColor: MangoPalette.green500,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Just disable notifications
                    await notificationController.setNotificationsEnabled(false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔕 Notifications disabled'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                activeColor: Theme.of(context).primaryColor,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Profile picture (square) or banner (wide), through the Mango composer.
  Future<void> _pickImage(bool isBanner) async {
    final media = await MangoComposer.pick(
      context,
      crop: isBanner ? CropShape.landscape : CropShape.square,
      allowCaption: false,
      actionLabel: 'Use',
    );
    if (media == null || !mounted) return;
    final data = {'bytes': media.bytes, 'name': media.name};
    if (isBanner) {
      await profileController.updateBannerImage(data, context);
    } else {
      await profileController.updateProfileImage(data, context);
    }
  }

  Widget _buildProfileImage() {
    if (kIsWeb && _webProfileImageBytes != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(_webProfileImageBytes!),
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundImage: profileController.profileImageUrl.isNotEmpty
            ? NetworkImage(profileController.profileImageUrl)
            : const AssetImage('asset/images/mango-13.jpg') as ImageProvider,
      );
    }
  }

  Widget _buildBannerImage(BuildContext context, bool isDarkMode) {
    if (kIsWeb && _webBannerImageBytes != null) {
      return Image.memory(_webBannerImageBytes!, fit: BoxFit.cover);
    } else if (profileController.bannerImageUrl.isNotEmpty) {
      return Image.network(
        profileController.bannerImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Image.asset('asset/images/mango-13.jpg', fit: BoxFit.cover),
      );
    } else {
      return Image.asset('asset/images/mango-13.jpg', fit: BoxFit.cover);
    }
  }

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : MangoPalette.black;
  }

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = _getTextColor(context);
    final secondaryTextColor = _getSecondaryTextColor(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Obx(() {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBannerImage(context, isDarkMode),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isDarkMode
                              ? [
                                  MangoPalette.black.withOpacity(0.8),
                                  MangoPalette.black.withOpacity(0.3),
                                  Colors.transparent,
                                ]
                              : [
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(true),
                          icon: FaIcon(
                            FontAwesomeIcons.image,
                            size: 14,
                            color: textColor,
                          ),
                          label: Text(
                            'Change Banner',
                            style: TextStyle(fontSize: 12, color: textColor),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? MangoPalette.black.withOpacity(0.7)
                                : Colors.white.withOpacity(0.9),
                            foregroundColor: textColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MangoRadius.lg),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 3,
                          ),
                        ),
                        child: _buildProfileImage(),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: IconButton(
        tooltip: 'Camera',
                            icon: FaIcon(
                              FontAwesomeIcons.camera,
                              size: 14,
                              color: Colors.white,
                            ),
                            onPressed: () => _pickImage(false),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _pickImage(false),
                    child: Text(
                      'Change Profile Picture',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (profileController.isUpdating.value)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          CircularProgressIndicator(semanticsLabel: 'Loading', 
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Uploading image...',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'Profile Settings',
                    FontAwesomeIcons.user,
                    textColor,
                  ),
                  _buildEditableCard(
                    'Name',
                    profileController.displayName,
                    'Edit your full name',
                    FontAwesomeIcons.user,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildEditableCard(
                    'Username',
                    '@${profileController.username}',
                    'Change your username',
                    FontAwesomeIcons.at,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildEditableCard(
                    'Display Name',
                    profileController.displayName,
                    'Set your public display name',
                    FontAwesomeIcons.idBadge,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildEditableCard(
                    'Bio',
                    profileController.bio.isNotEmpty
                        ? profileController.bio
                        : 'Add a bio',
                    'Edit your bio',
                    FontAwesomeIcons.pen,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildEditableCard(
                    'Location',
                    profileController.location.isNotEmpty
                        ? profileController.location
                        : 'Add location',
                    'Update your location',
                    FontAwesomeIcons.locationDot,
                    textColor,
                    secondaryTextColor,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'Notifications',
                    FontAwesomeIcons.bell,
                    textColor,
                  ),

                  // iOS PWA Info Card (only for iPhone users not in PWA mode)
                  _buildIOSPWAInfoCard(
                    isDarkMode,
                    textColor,
                    secondaryTextColor,
                  ),

                  // iOS PWA Button (only for iPhone users)
                  _buildIOSPWAButton(isDarkMode, primaryColor, textColor),

                  // Regular notification settings
                  _buildNotificationSettings(
                    isDarkMode,
                    textColor,
                    secondaryTextColor,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'Security',
                    FontAwesomeIcons.shieldHalved,
                    textColor,
                  ),
                  _buildEditableCard(
                    'Email',
                    FirebaseAuth.instance.currentUser?.email ?? 'No email',
                    'Modify your email address',
                    FontAwesomeIcons.envelope,
                    textColor,
                    secondaryTextColor,
                  ),
                  _buildEditableCard(
                    'Password',
                    '********',
                    'Update your password',
                    FontAwesomeIcons.lock,
                    textColor,
                    secondaryTextColor,
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'Preferences',
                    FontAwesomeIcons.sliders,
                    textColor,
                  ),
                  _buildThemeSwitch(textColor, secondaryTextColor),

                  const SizedBox(height: 30),
                  _buildLogoutButton(textColor, secondaryTextColor),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNotificationSettings(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Obx(() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildNotificationToggle(
              'Push Notifications',
              'Receive alerts on your device',
              FontAwesomeIcons.bell,
              notificationController.notificationsEnabled.value,
              (value) => notificationController.setNotificationsEnabled(value),
              isDarkMode,
              textColor,
              secondaryTextColor,
            ),
            _buildNotificationSubMenu(
              'Mute Notifications',
              'Temporarily silence alerts',
              FontAwesomeIcons.volumeMute,
              isDarkMode,
              textColor,
              secondaryTextColor,
              onTap: () => _showMuteOptions(),
            ),
            _buildNotificationSubMenu(
              'Notification Types',
              'Choose what to be notified about',
              FontAwesomeIcons.list,
              isDarkMode,
              textColor,
              secondaryTextColor,
              onTap: () => _showNotificationTypesDialog(),
            ),
            _buildNotificationSubMenu(
              'Quiet Hours',
              'Set schedule to mute notifications',
              FontAwesomeIcons.moon,
              isDarkMode,
              textColor,
              secondaryTextColor,
              onTap: () => _showQuietHoursDialog(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNotificationSubMenu(
    String title,
    String subtitle,
    IconData icon,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MangoRadius.md),
              ),
              child: Center(child: FaIcon(icon, size: 18, color: textColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: secondaryTextColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          FaIcon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCard(
    String title,
    String value,
    String description,
    IconData icon,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(MangoRadius.md),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Center(child: FaIcon(icon, size: 18, color: textColor)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.chevron_right, color: textColor, size: 18),
        ),
        onTap: () => _navigateToEditPage(title, value),
      ),
    );
  }

  Widget _buildThemeSwitch(Color textColor, Color secondaryTextColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(MangoRadius.md),
        boxShadow: [
          BoxShadow(
            color: MangoPalette.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(MangoRadius.md),
          ),
          child: Center(
            child: FaIcon(
              isDarkMode ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
              size: 18,
              color: secondaryTextColor,
            ),
          ),
        ),
        title: Text(
          'Dark Mode',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          isDarkMode ? 'Enabled' : 'Disabled',
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Obx(
          () => Transform.scale(
            scale: 0.8,
            child: Switch(
              value: themeController.isDarkMode.value,
              onChanged: (value) {
                themeController.switchTheme(value);
              },
              activeColor: Colors.white,
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveThumbColor: MangoPalette.grey300,
              inactiveTrackColor: MangoPalette.grey400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(Color textColor, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MangoRadius.md),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.rightFromBracket,
                size: 18,
                color: Colors.red,
              ),
            ),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'Sign out of your account',
            style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 12),
          ),
          trailing: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_right, color: Colors.red, size: 18),
          ),
          onTap: () => _showLogoutConfirmation(textColor, secondaryTextColor),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(
    Color textColor,
    Color secondaryTextColor,
  ) async {
    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MangoRadius.lg),
          ),
          title: Text(
            'Logout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: secondaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                Future.microtask(() {
                  Get.offAllNamed('/welcome');
                });
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEditPage(String field, String currentValue) {
    Get.to(() => EditFieldPage(field: field, currentValue: currentValue));
  }

  void _showMuteOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mute Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildMuteOption('For 1 hour', Duration(hours: 1)),
              _buildMuteOption('For 8 hours', Duration(hours: 8)),
              _buildMuteOption('For 24 hours', Duration(days: 1)),
              _buildMuteOption('Until tomorrow morning', Duration(days: 1)),
              const Divider(),
              TextButton(
                onPressed: () {
                  notificationController.unmute();
                  Navigator.pop(context);
                  _showSnackbar('Notifications unmuted');
                },
                child: const Text(
                  'Unmute',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMuteOption(String label, Duration duration) {
    return ListTile(
      title: Text(label),
      onTap: () {
        notificationController.muteFor(duration);
        Navigator.pop(context);
        _showSnackbar('Notifications muted for $label');
      },
    );
  }

  void _showNotificationTypesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notification Types'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeToggle(
                'Messages',
                'Get notified about new messages',
                true,
              ),
              const Divider(),
              _buildTypeToggle('Posts', 'New posts from friends', true),
              const Divider(),
              _buildTypeToggle(
                'Likes',
                'When someone likes your content',
                true,
              ),
              const Divider(),
              _buildTypeToggle('Comments', 'Replies to your posts', true),
              const Divider(),
              _buildTypeToggle(
                'Song Plays',
                'When someone plays your songs',
                true,
              ),
              const Divider(),
              _buildTypeToggle(
                'Profile Views',
                'When someone views your profile',
                true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeToggle(String title, String subtitle, bool initialValue) {
    return StatefulBuilder(
      builder: (context, setState) {
        var value = initialValue;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (newValue) {
                setState(() {
                  value = newValue;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showQuietHoursDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quiet Hours'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set time range to automatically mute notifications'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimePicker('From', TimeOfDay.now())),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePicker('To', TimeOfDay.now())),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Quiet Hours'),
                value: false,
                onChanged: (value) {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSnackbar('Quiet hours set');
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay initialTime) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: initialTime,
        );
        if (time != null) {
          // Handle time selection
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: MangoPalette.grey300),
          borderRadius: BorderRadius.circular(MangoRadius.md),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              initialTime.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : MangoPalette.green500,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _webProfileImageBytes = null;
    _webBannerImageBytes = null;
    super.dispose();
  }
}

class EditFieldPage extends StatefulWidget {
  final String field;
  final String currentValue;

  const EditFieldPage({required this.field, required this.currentValue});

  @override
  _EditFieldPageState createState() => _EditFieldPageState();
}

class _EditFieldPageState extends State<EditFieldPage> {
  final TextEditingController _controller = TextEditingController();
  final ProfileController profileController = Get.find<ProfileController>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isUpdating = false;

  Color _getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : MangoPalette.black;
  }

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;
  }

  @override
  void initState() {
    super.initState();
    String displayValue = widget.currentValue;
    if (widget.field == 'Username' && displayValue.startsWith('@')) {
      displayValue = displayValue.substring(1);
    }
    _controller.text = displayValue;
  }

  @override
  Widget build(BuildContext context) {
    bool isPassword = widget.field == 'Password';
    bool isBio = widget.field == 'Bio';
    bool isEmail = widget.field == 'Email';
    final textColor = _getTextColor(context);
    final secondaryTextColor = _getSecondaryTextColor(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit ${widget.field}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: textColor,
          ),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeAnimation(
              1.0,
              Text(
                _getFieldDescription(),
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (isPassword) ...[
              _buildPasswordFields(textColor, secondaryTextColor),
            ] else ...[
              _buildTextField(
                isBio: isBio,
                isEmail: isEmail,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            ],
            const Spacer(),
            if (_isUpdating)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            FadeAnimation(
              1.3,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                  ),
                  child: _isUpdating
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    bool isBio = false,
    bool isEmail = false,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return FadeAnimation(
      1.1,
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(MangoRadius.md),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: MangoPalette.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Enter new ${widget.field}',
            labelStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
            border: InputBorder.none,
          ),
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.text,
          maxLines: isBio ? 4 : 1,
          style: TextStyle(color: textColor, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordFields(Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        FadeAnimation(
          1.1,
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.md),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
                border: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              obscureText: true,
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeAnimation(
          1.1,
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(MangoRadius.md),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: MangoPalette.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
                border: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              obscureText: true,
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Password must be at least 6 characters long',
          style: TextStyle(
            fontSize: 12,
            color: secondaryTextColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  String _getFieldDescription() {
    switch (widget.field) {
      case 'Password':
        return 'Update your password to keep your account secure. Enter your current password and a new password below.';
      case 'Name':
        return 'Edit your full name as you want it to appear on your profile.';
      case 'Email':
        return 'Update your email address to receive notifications and account updates.';
      case 'Username':
        return 'Modify your username. This is how others will identify you on the platform.';
      case 'Bio':
        return 'Edit your bio. Let others know a little about you in a few words.';
      case 'Location':
        return 'Update your location to help others find you.';
      case 'Display Name':
        return 'Set your public display name that will be shown to other users.';
      default:
        return 'Make changes to your ${widget.field}.';
    }
  }

  Future<void> _saveChanges() async {
    if (widget.field == 'Password') {
      await _updatePassword();
    } else {
      await _updateProfileField();
    }
  }

  Future<void> _updateProfileField() async {
    if (_controller.text.trim().isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        '${widget.field} cannot be empty',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    String newValue = _controller.text.trim();

    if (widget.field == 'Username') {
      if (newValue.length < 3) {
        UtilsService().showSnackbar(
          'Error',
          'Username must be at least 3 characters',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          context: context,
        );
        return;
      }

      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(newValue)) {
        UtilsService().showSnackbar(
          'Error',
          'Username can only contain letters, numbers, and underscores',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          context: context,
        );
        return;
      }

      newValue = newValue.startsWith('@') ? newValue : newValue;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await profileController.updateProfileField(
        widget.field,
        newValue,
        context,
      );

      Get.back();
      UtilsService().showSnackbar(
        'Success',
        '${widget.field} updated successfully',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to update ${widget.field}: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        'Please fill in both password fields',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      UtilsService().showSnackbar(
        'Error',
        'New password must be at least 6 characters long',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await profileController.updatePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
        context,
      );

      Get.back();
      UtilsService().showSnackbar(
        'Success',
        'Password updated successfully',
        backgroundColor: MangoPalette.green500,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        context: context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        'Failed to update password: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        context: context,
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
