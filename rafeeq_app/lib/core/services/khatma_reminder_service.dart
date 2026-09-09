import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/timezone.dart' as tz;

/// Daily "read your khatma portion" reminders — one per khatma, at whatever
/// time its owner picked (P2‑11). Same shape as `AzkarReminderService`: a
/// plain notification, no full-screen intent, no custom sound — a nudge to
/// open the app, not an alarm.
class KhatmaReminderService {
  KhatmaReminderService._();
  static final KhatmaReminderService instance = KhatmaReminderService._();

  static const _channelId = 'rafeeq_khatma_reminder';
  static String get _channelName => 'notif.khatma_channel'.tr();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'notif.khatma_channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> schedule(int id, int hour, int minute) async {
    await _ensureChannel();
    await _plugin.zonedSchedule(
      id,
      'notif.khatma_title'.tr(),
      'notif.khatma_body'.tr(),
      _nextInstanceOf(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
