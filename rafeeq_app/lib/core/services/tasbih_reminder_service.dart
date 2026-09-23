import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/tasbih_reminder/data/tasbih_items.dart';
import 'notification_router.dart';

/// The waking hours the tasbih reminders fall in. Nobody is woken at 3 a.m.
/// to be told to say «سبحان الله».
const tasbihDayStartHour = 8;
const tasbihDayEndHour = 21;

/// The times of day a reminder comes, every [everyMinutes] from 08:00 up to
/// and including 21:00.
List<(int, int)> tasbihSlots(int everyMinutes) {
  if (everyMinutes <= 0) return const [];
  final out = <(int, int)>[];
  for (var m = tasbihDayStartHour * 60;
      m <= tasbihDayEndHour * 60;
      m += everyMinutes) {
    out.add((m ~/ 60, m % 60));
  }
  return out;
}

/// Which item slot [slot] shows when the rotation is shifted by [shift]:
/// neighbouring slots differ, and the shift moves the whole day along so
/// tomorrow's 08:00 is not today's.
TasbihItem tasbihItemFor(int slot, int shift) =>
    tasbihItems[(slot + shift) % tasbihItems.length];

/// Daily repeating notifications, one per slot — so the reminders keep coming
/// whether or not the app is opened, with nothing to top up. The rotation is
/// re-shifted on every launch, which is what keeps the day varied.
class TasbihReminderService {
  TasbihReminderService._();
  static final TasbihReminderService instance = TasbihReminderService._();

  static const _channelId = 'rafeeq_tasbih_reminder';
  static const _firstId = 7400;
  static const _maxSlots = 20;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    await NotificationRouter.instance.ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        'tasbih.channel'.tr(),
        description: 'tasbih.channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> cancelAll() async {
    for (var i = 0; i < _maxSlots; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }

  Future<void> reschedule({required int everyMinutes, required int shift}) async {
    await cancelAll();
    final slots = tasbihSlots(everyMinutes);
    if (slots.isEmpty) return;
    await _ensureChannel();
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < slots.length && i < _maxSlots; i++) {
      final (h, m) = slots[i];
      final item = tasbihItemFor(i, shift);
      final body = '«${item.text}»\n${item.citationKey.tr()}';
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: item.titleKey.tr(),
        body: body,
        scheduledDate: at,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'tasbih.channel'.tr(),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(body),
            // Cleared before the next one arrives: a day of undismissed
            // reminders would spend the 25-notification budget (trap #33).
            timeoutAfter: Duration(minutes: everyMinutes).inMilliseconds,
          ),
        ),
        // Exact, as the quote reminder had to be: an inexact alarm is not an
        // interval (trap #32). At most 14 a day, repeating — not a window of
        // one-shots.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
