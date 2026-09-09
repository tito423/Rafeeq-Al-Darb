import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/timezone.dart' as tz;

/// Daily "time for your adhkar" reminders, at whatever time the user picked
/// — WORK_QUEUE Stage 3 is explicit that this must not be a hardcoded
/// 05:00/16:30, so there is no default time here at all; a reminder simply
/// doesn't exist until the user sets one.
///
/// Deliberately much simpler than `AdhanAlarmService`: a plain notification,
/// no full-screen intent, no custom native sound — this is a reminder to
/// open the app, not an alarm that must wake a locked screen.
class AzkarReminderService {
  AzkarReminderService._();
  static final AzkarReminderService instance = AzkarReminderService._();

  static const _channelId = 'rafeeq_azkar_reminder';
  static String get _channelName => 'notif.azkar_channel'.tr();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  static const _morningId = 6001;
  static const _eveningId = 6002;

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'notif.azkar_channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> scheduleMorning(int hour, int minute) =>
      _schedule(_morningId, hour, minute, 'notif.azkar_morning_title'.tr(),
          'notif.azkar_morning_body'.tr());

  Future<void> scheduleEvening(int hour, int minute) =>
      _schedule(_eveningId, hour, minute, 'notif.azkar_evening_title'.tr(),
          'notif.azkar_evening_body'.tr());

  Future<void> cancelMorning() => _plugin.cancel(_morningId);
  Future<void> cancelEvening() => _plugin.cancel(_eveningId);

  Future<void> _schedule(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    await _ensureChannel();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
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
