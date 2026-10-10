import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_router.dart';

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
  Future<void> _pendingReplacement = Future<void>.value();

  /// Serialize replacement so two quick edits cannot leave a deleted plan
  /// armed. Only khatma payloads are cancelled, including old hashed IDs.
  Future<void> replaceAll(List<(int, int, int)> reminders) {
    final replacement = _pendingReplacement
        .then<void>((_) {}, onError: (Object error, StackTrace stack) {})
        .then((_) async {
          final pending = await _plugin.pendingNotificationRequests();
          for (final notification in pending) {
            if (notification.payload == '${NotificationRouter.openPrefix}khatma') {
              await cancel(notification.id);
            }
          }
          for (final (id, hour, minute) in reminders) {
            await schedule(id, hour, minute);
          }
        });
    _pendingReplacement = replacement;
    return replacement;
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'notif.khatma_channel_desc'.tr(),
      ),
    );
    _channelReady = true;
  }

  Future<void> schedule(int id, int hour, int minute) async {
    await _ensureChannel();
    await _plugin.zonedSchedule(
      id: id,
      title: 'notif.khatma_title'.tr(),
      body: 'notif.khatma_body'.tr(),
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '${NotificationRouter.openPrefix}khatma',
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

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
