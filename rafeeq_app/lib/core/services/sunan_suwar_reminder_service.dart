import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Weekly "read your sunnah surah" reminders (P2‑12) — one per surah, fired
/// on the picked weekday+time every week via
/// `DateTimeComponents.dayOfWeekAndTime`. Tapping the notification opens
/// that surah's locked reader (`onOpenSurah`, wired in `main.dart` the same
/// way `AdhanAlarmService.onOpenAdhan` already is).
class SunanSuwarReminderService {
  SunanSuwarReminderService._();
  static final SunanSuwarReminderService instance = SunanSuwarReminderService._();

  static const _channelId = 'rafeeq_sunan_suwar_reminder';
  static const _channelName = 'تذكير سنن السور';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _channelReady = false;
  bool _ready = false;

  static void Function(String payload)? onOpenSurah;

  Future<void> initialize() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onResponse,
    );
    _ready = true;
  }

  @pragma('vm:entry-point')
  static void _onResponse(NotificationResponse response) {
    if (response.payload != null) onOpenSurah?.call(response.payload!);
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'تذكير أسبوعي بقراءة سنن السور في وقتها',
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  /// [weekday] is Dart's `DateTime.weekday` (1=Monday..7=Sunday).
  Future<void> schedule({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String payload,
  }) async {
    await _ensureChannel();
    await _plugin.zonedSchedule(
      id,
      title,
      'حان وقت وردك من سنن السور',
      _nextInstanceOfWeekday(weekday, hour, minute),
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = tz.TZDateTime.now(tz.local);
    scheduled = tz.TZDateTime(
        tz.local, scheduled.year, scheduled.month, scheduled.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
