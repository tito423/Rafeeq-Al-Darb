import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/fasting/data/sunnah_fasting.dart';
import 'notification_router.dart';

/// Arms the evenings [planFastingReminders] chose, one notification each.
///
/// One-shot alarms rather than a weekly repeat, because the days are not
/// weekly: Ramadan, the Eids and tashriq take Mondays and Thursdays out, and
/// the white days follow the moon. The window is two months, re-armed on every
/// launch and on every settings change — the same rolling-window pattern as
/// the quote reminder. Its text is fixed when ARMED (trap #29), so a language
/// change re-arms it too (`RafeeqApp`).
class FastingReminderService {
  FastingReminderService._();
  static final FastingReminderService instance = FastingReminderService._();

  static const _channelId = 'rafeeq_fasting_reminder';
  static const _firstId = 7300;
  static const _maxCount = 50;

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
        'fasting.channel'.tr(),
        description: 'fasting.channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  Future<void> cancelAll() async {
    for (var i = 0; i < _maxCount; i++) {
      await _plugin.cancel(_firstId + i);
    }
  }

  Future<void> reschedule(List<FastingReminder> plan) async {
    await cancelAll();
    if (plan.isEmpty) return;
    await _ensureChannel();
    for (var i = 0; i < plan.length && i < _maxCount; i++) {
      final r = plan[i];
      final title = switch (r.kind) {
        FastKind.monday => 'fasting.notif_monday'.tr(),
        FastKind.thursday => 'fasting.notif_thursday'.tr(),
        FastKind.whiteDays => 'fasting.notif_white'.tr(),
      };
      final h = r.kind == FastKind.whiteDays
          ? whiteDaysHadith
          : mondayThursdayHadith;
      final body = '«${h.text}»\n${h.citationKey.tr()}';
      await _plugin.zonedSchedule(
        _firstId + i,
        title,
        body,
        tz.TZDateTime.from(r.at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'fasting.channel'.tr(),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(body),
            // Gone by the next morning's fast if it was not dismissed — the
            // 25-notification budget is shared with everything else (trap #33).
            timeoutAfter: const Duration(hours: 14).inMilliseconds,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
