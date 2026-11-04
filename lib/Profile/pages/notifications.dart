import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/Utils/theme.dart';
import 'package:mango/Utils/optimized_lists.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final NotificationController _notificationController =
      Get.find<NotificationController>();
  final ThemeController _themeController = Get.find<ThemeController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _themeController.isDarkMode.value;
    final primaryColor = _themeController.primaryColorValue;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      appBar: _buildAppBar(isDarkMode, primaryColor),
      body: Column(
        children: [
          _buildTabBar(isDarkMode, primaryColor),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsList(isDarkMode, primaryColor),
                _buildSettingsSection(isDarkMode, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, Color primaryColor) {
    return AppBar(
      title: Text(
        'Notifications',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.done_all_rounded,
            color: primaryColor,
          ),
          onPressed: () => _markAllAsRead(),
          tooltip: 'Mark all as read',
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onSelected: (value) {
            if (value == 'clear_all') {
              _clearAllNotifications();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear_all',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Text('Clear all notifications'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDarkMode, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: primaryColor,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isDarkMode, Color primaryColor) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildEmptyState(isDarkMode);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDarkMode);
        }

        if (snapshot.hasError) {
          return _buildErrorState(isDarkMode);
        }

        final notifications = snapshot.data?.docs ?? [];
        if (notifications.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        return OptimizedListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final doc = notifications[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNotificationCard(
              data,
              doc.id,
              isDarkMode,
              primaryColor,
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> data,
    String docId,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'general';
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final imageUrl = data['imageUrl'];

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(docId);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(data),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isRead
                  ? (isDarkMode ? Colors.grey[900] : Colors.white)
                  : (isDarkMode ? Colors.grey[850] : primaryColor.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRead
                    ? (isDarkMode ? Colors.grey[800]! : Colors.grey[200]!)
                    : primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(type, isDarkMode, primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
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

  Widget _buildIcon(String type, bool isDarkMode, Color primaryColor) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'chat':
        iconData = Icons.chat_bubble_outline;
        iconColor = Colors.blue;
        break;
      case 'post':
        iconData = Icons.article_outlined;
        iconColor = Colors.green;
        break;
      case 'song':
        iconData = Icons.music_note;
        iconColor = Colors.orange;
        break;
      case 'profile':
        iconData = Icons.person_outline;
        iconColor = Colors.purple;
        break;
      case 'book':
        iconData = Icons.book_outlined;
        iconColor = Colors.brown;
        break;
      default:
        iconData = Icons.notifications_outlined;
        iconColor = primaryColor;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildSettingsSection(bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsCard(
            'Notification Preferences',
            Icons.notifications_active_outlined,
            isDarkMode,
            [
              _buildSwitchTile(
                'Push Notifications',
                'Receive notifications on your device',
                _notificationController.notificationsEnabled.value,
                (value) => _notificationController.setNotificationsEnabled(value),
                isDarkMode,
                primaryColor,
              ),
              const SizedBox(height: 16),
              _buildMuteSection(isDarkMode, primaryColor),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsCard(
            'Notification Types',
            Icons.category_outlined,
            isDarkMode,
            [
              _buildNotificationTypeTile(
                'Messages',
                'Get notified when you receive a message',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildNotificationTypeTile(
                'Posts',
                'Get notified about new posts from friends',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildNotificationTypeTile(
                'Likes & Reactions',
                'Get notified when someone likes your content',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildNotificationTypeTile(
                'Song Plays',
                'Get notified when someone plays your songs',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildNotificationTypeTile(
                'Profile Views',
                'Get notified when someone views your profile',
                true,
                isDarkMode,
                primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsCard(
            'Delivery Options',
            Icons.delivery_dining_outlined,
            isDarkMode,
            [
              _buildRadioTile(
                'Sound',
                'Play sound for notifications',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildRadioTile(
                'Vibration',
                'Vibrate device for notifications',
                true,
                isDarkMode,
                primaryColor,
              ),
              _buildRadioTile(
                'Preview',
                'Show message preview in notifications',
                true,
                isDarkMode,
                primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingsCard(
            'Quiet Hours',
            Icons.nightlight_round_outlined,
            isDarkMode,
            [
              _buildQuietHoursTile(isDarkMode, primaryColor),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    String title,
    IconData icon,
    bool isDarkMode,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: isDarkMode ? Colors.white : Colors.black),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
          activeTrackColor: primaryColor.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildMuteSection(bool isDarkMode, Color primaryColor) {
    return Column(
      children: [
        _buildSwitchTile(
          'Mute All',
          'Temporarily silence all notifications',
          false,
          (value) {
            if (value) {
              _showMuteOptions();
            }
          },
          isDarkMode,
          primaryColor,
        ),
      ],
    );
  }

  Widget _buildNotificationTypeTile(
    String title,
    String subtitle,
    bool enabled,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) {},
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(
    String title,
    String subtitle,
    bool selected,
    bool isDarkMode,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Radio<bool>(
            value: true,
            groupValue: selected,
            onChanged: (value) {},
            activeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursTile(bool isDarkMode, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiet Hours',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Set schedule to mute notifications',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showQuietHoursDialog(),
          child: Text(
            'Set Schedule',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get notifications, they\'ll appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    _markAsRead(data['id'] as String);
    final type = data['type'];
    final id = data['id'] ?? data['${type}Id'];

    switch (type) {
      case 'chat':
        Get.toNamed('/chat/$id');
        break;
      case 'post':
        Get.toNamed('/post/$id');
        break;
      case 'song':
        Get.toNamed('/song/$id');
        break;
      case 'profile':
        Get.toNamed('/profile/$id');
        break;
      case 'book':
        Get.toNamed('/book/$id');
        break;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    }
  }

  Future<void> _clearAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
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
                  _notificationController.unmute();
                  Navigator.pop(context);
                },
                child: const Text('Unmute', style: TextStyle(color: Colors.red)),
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
        _notificationController.muteFor(duration);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifications muted for $label'),
            duration: const Duration(seconds: 2),
          ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quiet hours set'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
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
}