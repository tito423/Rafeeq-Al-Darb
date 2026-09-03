import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Daily "read your khatma portion" reminders — one per khatma, at whatever
/// time its owner picked (P2‑11). Same shape as `AzkarReminderService`: a
/// plain notification, no full-screen intent, no custom sound — a nudge to
/// open the app, not an alarm.
class KhatmaReminderService {
  KhatmaReminderService._();
  static final KhatmaReminderService instance = KhatmaReminderService._();

  static const _channelId = 'rafeeq_khatma_reminder';
  static const _channelName = 'تذكير الختمة';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'تذكير يومي بقراءة وردك من الختمة في الوقت الذي تحدده',
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> schedule(int id, int hour, int minute) async {
    await _ensureChannel();
    await _plugin.zonedSchedule(
      id,
      'ورد الختمة',
      'حان وقت وردك من القرآن اليوم',
      _nextInstanceOf(hour, minute),
      const NotificationDetails(
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
