import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:mango/Notifications/notification_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/App/router/app_routes.dart';
import '../main.dart';

// Browser notifications on web; a no-op stub on Android and iOS.
import 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications.dart';

class NotificationController extends GetxController {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin? _local =
      kIsWeb ? null : localNotificationsPlugin;
  final _db = FirebaseFirestore.instance;
  final notificationsEnabled = true.obs;
  
  // Add logger
  final logger = Get.log;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
  try {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
      
      // Get and save token IMMEDIATELY
      final token = await _fcm.getToken();
      print('📱 Got FCM token: $token');
      
      if (token != null) {
        await _saveToken(token);
        print('✅ Token saved to Firestore');
      }
      
      _setupTokenRefresh();
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpened(initialMessage);
      }
    } else {
      print('❌ Notification permission denied');
    }
    _listenUserSettings();
  } catch (e) {
    print('Error initializing notifications: $e');
  }
}

  Future<void> initializeOfflineSync() async {
    try {
      // Wait a bit for connectivity
      await Future.delayed(const Duration(seconds: 3));
      
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Sync offline messages
        await syncOfflineMessages();
      }
      
      // Enable Firestore persistence for offline support
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      logger('Offline sync initialized');
    } catch (e) {
      logger('Error initializing offline sync: $e');
    }
  }
  
  // Add this method to sync offline messages
  Future<void> syncOfflineMessages() async {
    try {
      // You'll need to implement this based on your offline storage
      // This is a placeholder - implement your actual offline sync logic
      logger('Syncing offline messages...');
      // Example: await conversationController.syncOfflineMessages();
    } catch (e) {
      logger('Error syncing offline messages: $e');
    }
  }

  Future<void> debugCheckTokenStorage() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No user logged in');
    return;
  }
  
  print('=== TOKEN DEBUG FOR USER: ${user.uid} ===');
  
  // Get current device token
  final currentToken = await _fcm.getToken();
  print('📱 Current device token: $currentToken');
  
  // Check Firestore
  final userDoc = await _db.collection('users').doc(user.uid).get();
  if (userDoc.exists) {
    final data = userDoc.data();
    print('📦 Stored fcmToken: ${data?['fcmToken']}');
    print('📦 Stored fcmTokens array: ${data?['fcmTokens']}');
    print('🔔 notificationsEnabled: ${data?['notificationsEnabled']}');
    
    // Check if token matches
    final tokens = data?['fcmTokens'] ?? [];
    final singleToken = data?['fcmToken'];
    
    if (tokens.contains(currentToken) || singleToken == currentToken) {
      print('✅ Token is properly stored!');
    } else {
      print('❌ Token NOT found in Firestore!');
      print('Attempting to save token now...');
      await _saveToken(currentToken!);
    }
  } else {
    print('❌ User document does not exist!');
    print('Creating user document...');
    await _saveToken(currentToken!);
  }
}

  void _setupTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      await _saveToken(newToken);
    }).onError((error) {
      logger('Token refresh error: $error');
    });
  }

  Future<void> _saveCurrentToken() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ Cannot save token: No user logged in');
    return;
  }
  
  print('💾 Saving token for user: ${user.uid}');
  print('Token: $token');
  
  try {
    // Update the user document with the new token
    await _db.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp()
    });
    print('✅ Token saved successfully using arrayUnion');
  } catch (error) {
    print('⚠️ Update failed (document may not exist), creating document...');
    // Document doesn't exist, create it
    await _db.collection('users').doc(user.uid).set({
      'fcmTokens': [token],
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    print('✅ Token saved successfully in new document');
  }
}

Future<void> setNotificationsEnabled(bool enabled) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  await _db.collection('users').doc(user.uid).set({
    'notificationsEnabled': enabled
  }, SetOptions(merge: true));
  notificationsEnabled.value = enabled;  // This updates the UI
}


Future<void> saveToken(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ Cannot save token: No user logged in');
    return;
  }
  
  print('💾 Saving token for user: ${user.uid}');
  print('Token: $token');
  
  try {
    // Update the user document with the new token
    await _db.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp()
    });
    print('✅ Token saved successfully using arrayUnion');
  } catch (error) {
    print('⚠️ Update failed (document may not exist), creating document...');
    // Document doesn't exist, create it
    await _db.collection('users').doc(user.uid).set({
      'fcmTokens': [token],
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    print('✅ Token saved successfully in new document');
  }
}

  void _listenUserSettings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _db.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final enabled = data['notificationsEnabled'] ?? true;
      notificationsEnabled.value = enabled;
    });
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    if (!await _shouldShowNotification()) return;

    if (kIsWeb) {
      _showWebNotification(message);
    } else {
      _showMobileNotification(message);
    }
  }

  Future<bool> _shouldShowNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return true;
    final enabled = userDoc.data()?['notificationsEnabled'] ?? true;
    if (!enabled) return false;
    final muteUntil = userDoc.data()?['muteUntil'] as Timestamp?;
    if (muteUntil != null && muteUntil.toDate().isAfter(DateTime.now())) {
      return false;
    }
    return true;
  }

  void _showMobileNotification(RemoteMessage message) async {
    if (_local == null) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mango_channel',
      'Mango Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await _local!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      platformDetails,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  // ====================== WEB NOTIFICATIONS ======================
  void _showWebNotification(RemoteMessage message) {
    final permission = webNotificationPermission();
    if (permission == 'unsupported') {
      logger('Browser does not support notifications');
      return;
    }
    if (permission == 'granted') {
      _createWebNotification(message);
    } else if (permission != 'denied') {
      requestWebNotificationPermission().then((result) {
        if (result == 'granted') _createWebNotification(message);
      }).catchError((Object e) {
        logger('Permission request failed: $e');
      });
    }
  }

  Future<void> requestPermissionIfNeeded() async {
    if (kIsWeb) {
      // For web, use the browser permission API
      if (webNotificationPermission() == 'default') {
        // Request permission
        final permission = await requestWebNotificationPermission();
        if (permission == 'granted') {
          await _saveCurrentToken();
        }
      }
    } else {
      // For mobile, check if already granted
      final settings = await _fcm.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        final newSettings = await _fcm.requestPermission();
        if (newSettings.authorizationStatus == AuthorizationStatus.authorized) {
          await _saveCurrentToken();
        }
      }
    }
  }

  void _createWebNotification(RemoteMessage message) {
    showWebNotification(
      message.notification?.title ?? 'Mango',
      body: message.notification?.body ?? '',
      icon: message.notification?.android?.imageUrl ?? 'icons/Icon-192.png',
    );
  }
  // ================================================================

  /// A push was tapped: open what it is about.
  void _handleMessageOpened(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    // A short delay lets the app finish starting when opened from a push.
    Future.delayed(const Duration(milliseconds: 500), () => NotificationRouter.openFromPush(data));
  }

  // Add this to handle deep links
  void handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      _handleMessageOpened(message);
    }
  }

  Future<void> muteFor(Duration duration) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final until = DateTime.now().add(duration);
    await _db.collection('users').doc(user.uid).set({
      'muteUntil': Timestamp.fromDate(until)
    }, SetOptions(merge: true));
  }

  Future<void> unmute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'muteUntil': null
    }, SetOptions(merge: true));
  }
}