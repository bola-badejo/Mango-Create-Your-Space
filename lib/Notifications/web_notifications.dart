// Browser notifications (web only). Selected by a conditional import in
// notifications_controller.dart, so Android and iOS builds never import
// dart:js_interop or package:web.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 'granted', 'denied', 'default', or 'unsupported' when the browser has no
/// Notification API (for example iOS Safari outside an installed PWA).
String webNotificationPermission() {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

/// Asks the browser for permission and returns the result as a Dart string.
Future<String> requestWebNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  } catch (_) {
    return 'unsupported';
  }
}

void showWebNotification(String title, {required String body, required String icon}) {
  web.Notification(title, web.NotificationOptions(body: body, icon: icon));
}
