/// Weekly «وقت القراءة» reminders for a shelf in «مكتبتي».
///
/// One notification per chosen weekday, repeating every week at the chosen
/// time (`DateTimeComponents.dayOfWeekAndTime`, the same mechanism as the
/// sunan-surah reminders). IDs belong to the central shelf range. The tap opens
/// that shelf through `NotificationRouter`'s `open:shelf:<id>`.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/config/notification_ids.dart';
import '../../../core/services/notification_router.dart';
import 'my_shelves.dart';

class ShelfReminderService {
  ShelfReminderService._();
  static final ShelfReminderService instance = ShelfReminderService._();

  static const _channelId = 'rafeeq_reading_reminder';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  static int notificationId(int shelfId, int weekday) =>
      NotificationIds.shelfId(shelfId, weekday);

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    await NotificationRouter.instance.ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        'shelves.channel'.tr(),
        description: 'shelves.channel_desc'.tr(),
      ),
    );
    _channelReady = true;
  }

  /// Makes the scheduled notifications match [shelf]'s reminder exactly:
  /// days no longer chosen are cancelled, chosen ones (re)scheduled.
  Future<void> apply(Shelf shelf) async {
    await cancelAll(shelf.id);
    final r = shelf.reminder;
    if (r == null || r.weekdays.isEmpty) return;
    await _ensureChannel();
    for (final day in r.weekdays) {
      await _plugin.zonedSchedule(
        id: notificationId(shelf.id, day),
        title: 'shelves.notif_title'.tr(args: [shelf.name]),
        body: 'shelves.notif_body'.tr(),
        scheduledDate: _next(day, r.hour, r.minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'shelves.channel'.tr(),
            // Gone before the next one, so a week of unanswered reminders
            // never piles up toward Android's 25-per-app cap (trap #33).
            timeoutAfter: const Duration(hours: 20).inMilliseconds,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '${NotificationRouter.openPrefix}shelf:${shelf.id}',
      );
    }
  }

  Future<void> cancelAll(int shelfId) async {
    for (var d = 1; d <= 7; d++) {
      await _plugin.cancel(id: notificationId(shelfId, d));
    }
  }

  tz.TZDateTime _next(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.weekday != weekday || !t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}
