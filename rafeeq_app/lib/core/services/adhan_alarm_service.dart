import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Native alarm/notification pipeline for the Adhan.
///
/// - Exact alarms (USE_EXACT_ALARM / SCHEDULE_EXACT_ALARM in the manifest)
///   scheduled with zonedSchedule + matchDateTimeComponents daily.
/// - Full-screen intent notifications so the Adhan UI wakes the device.
/// - Real notification actions: "Stop" and "Mute" handled by the app.
class AdhanAlarmService {
  AdhanAlarmService._();
  static final AdhanAlarmService instance = AdhanAlarmService._();

  static const adhanChannelId = 'rafeeq_adhan';
  static const adhanChannelName = 'أذان الصلاة';
  static const adhanChannelDesc = 'تنبيهات مواقيت الصلاة بالأذان';

  static const actionStop = 'rafeeq.action.STOP_ADHAN';
  static const actionMute = 'rafeeq.action.MUTE_ADHAN';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Callbacks wired by the Adhan player so notification buttons control it.
  static void Function()? onMuteRequested;
  static void Function()? onStopRequested;

  static Future<void> _backgroundNotificationTap(
    NotificationResponse response,
  ) async {
    switch (response.actionId) {
      case actionStop:
        onStopRequested?.call();
        break;
      case actionMute:
        onMuteRequested?.call();
        break;
      default:
        break;
    }
  }

  Future<void> initialize() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _backgroundNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationTap,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        adhanChannelId,
        adhanChannelName,
        description: adhanChannelDesc,
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ),
    );
    await _requestPermissions();
    _ready = true;
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await Permission.scheduleExactAlarm.request();
  }

  AndroidNotificationDetails _adhanDetails() => const AndroidNotificationDetails(
        adhanChannelId,
        adhanChannelName,
        channelDescription: adhanChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(actionStop, 'إيقاف'),
          AndroidNotificationAction(actionMute, 'كتم'),
        ],
      );

  /// Fire the Adhan notification now (used when a scheduled timer lands
  /// while the app is running, and by tests of the UI flow).
  Future<void> showAdhanNotification(String prayerName) async {
    await _plugin.show(
      9901,
      'الصلاة — $prayerName',
      'الله أكبر، حان وقت الصلاة',
      NotificationDetails(android: _adhanDetails()),
      payload: 'adhan:$prayerName',
    );
  }

  /// Schedules a daily exact alarm at [time] for [prayerName].
  Future<void> scheduleDaily({
    required String prayerName,
    required int hour,
    required int minute,
  }) async {
    final id = _idFor(prayerName);
    await _plugin.zonedSchedule(
      id,
      'الصلاة — $prayerName',
      'الله أكبر، حان وقت الصلاة',
      _nextInstanceOf(hour, minute),
      NotificationDetails(android: _adhanDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'adhan:$prayerName',
    );
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('adhan_alarms') ?? <String>[];
    final updated = existing.where((e) => !e.startsWith('$prayerName:')).toList()
      ..add('$prayerName:$hour:$minute');
    await prefs.setStringList('adhan_alarms', updated);
  }

  Future<void> cancelPrayer(String prayerName) async {
    await _plugin.cancel(_idFor(prayerName));
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList('adhan_alarms') ?? [])
        .where((e) => !e.startsWith('$prayerName:'))
        .toList();
    await prefs.setStringList('adhan_alarms', list);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('adhan_alarms', []);
  }

  int _idFor(String prayerName) {
    const ids = {
      'fajr': 5001,
      'sunrise': 5002,
      'dhuhr': 5003,
      'asr': 5004,
      'maghrib': 5005,
      'isha': 5006,
    };
    return ids[prayerName] ?? 5099;
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
