import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/notification_ids.dart';

/// Runs before any feature re-arms. Only scheduled legacy IDs are removed;
/// the old range contained multiple kinds, so all affected kinds re-arm
/// from their existing settings after the localized widget tree is ready.
class NotificationIdUpgrade {
  static const preferenceKey = 'notification_ids_v2_cleaned';

  static Future<void> cleanLegacy(
    SharedPreferences prefs, {
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (prefs.getBool(preferenceKey) == true) return;
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    final pending = await notifications.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= NotificationIds.legacyKhatma &&
          request.id <
              NotificationIds.legacyKhatma +
                  NotificationIds.legacyKhatmaCount) {
        await notifications.cancel(id: request.id);
      }
    }
    // A failed cancellation leaves this unset, so next launch retries.
    await prefs.setBool(preferenceKey, true);
  }
}
