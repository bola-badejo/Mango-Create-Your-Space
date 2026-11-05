// Non-web stand-in for web_notifications.dart. Android and iOS use
// firebase_messaging and flutter_local_notifications instead.
String webNotificationPermission() => 'unsupported';

Future<String> requestWebNotificationPermission() async => 'unsupported';

void showWebNotification(String title, {required String body, required String icon}) {}
