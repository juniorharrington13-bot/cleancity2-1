import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PushNotificationService {
  static const String oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static bool get isConfigured => oneSignalAppId.trim().isNotEmpty && oneSignalAppId != 'YOUR_ONESIGNAL_APP_ID';

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint('PushNotificationService: OneSignal not configured (missing ONESIGNAL_APP_ID).');
      return;
    }

    try {
      OneSignal.initialize(oneSignalAppId);
      // Recommended: only ask for permission in-context (button), but we still
      // set up the SDK early.
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // Show notification while app in foreground.
        event.notification.display();
      });
    } catch (e) {
      debugPrint('PushNotificationService.initialize failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!isConfigured) return false;
    try {
      final accepted = await OneSignal.Notifications.requestPermission(true);
      return accepted;
    } catch (e) {
      debugPrint('PushNotificationService.requestPermission failed: $e');
      return false;
    }
  }

  static Future<void> setExternalUserId(String userId) async {
    if (!isConfigured) return;
    try {
      await OneSignal.login(userId);
    } catch (e) {
      debugPrint('PushNotificationService.setExternalUserId failed: $e');
    }
  }
}
