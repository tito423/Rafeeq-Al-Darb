import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_times.dart';
import 'prayer_times_service.dart';

/// The three reminders around a prayer, asked for as one card:
/// «تنبيهات قبل الصلاة وبعد الصلاة … وكذلك للإقامة بعد الأذان».
///
///   * **before** — «باقٍ ١٠ دقائق على الفجر»
///   * **after**  — «مضى ١٠ دقائق على أذان العصر»
///   * **iqama**  — «حان وقت إقامة صلاة المغرب»
///
/// DELIBERATELY NOT THE ADHAN'S PATH.
/// The adhan is armed natively (`AdhanScheduler.kt`, `setAlarmClock`) because
/// it has to take over a locked screen and survive Doze. These three are
/// reminders, not alarms: an ordinary notification through
/// `flutter_local_notifications`, exactly like the adhkar and khatma
/// reminders already in this folder. Nothing here asks for the exemptions the
/// adhan needs, and nothing here breaks if they are refused.
///
/// WHAT "DAILY" MEANS HERE, HONESTLY.
/// Prayer times move a minute or two a day, and these are scheduled with
/// `matchDateTimeComponents: DateTimeComponents.time` — they repeat at the
/// clock time they were armed with. Every successful times fetch re-arms them
/// against the new times, so on a phone the app is opened on they are exact;
/// on a phone left closed for a week the last one drifts by a few minutes.
/// The alternative — an exact alarm per reminder per day — is the machinery
/// the adhan uses and is not worth spending on a nudge.
class PrayerReminderService {
  PrayerReminderService._();
  static final PrayerReminderService instance = PrayerReminderService._();

  static const _channelId = 'rafeeq_prayer_reminder';
  static String get _channelName => 'notif.prayer_reminder_channel'.tr();

  /// The five prayers that get reminders. Sunrise is a timing, not a prayer;
  /// it has no adhan (see `prayer.sunrise_no_adhan`) and gets no iqama.
  static const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  /// One id block per kind, five apart — 7100s before, 7200s after, 7300s
  /// iqama. Fixed so a re-arm replaces yesterday's rather than stacking.
  static const _preBase = 7100;
  static const _postBase = 7200;
  static const _iqamaBase = 7300;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _channelReady = false;

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'notif.prayer_reminder_channel_desc'.tr(),
        importance: Importance.defaultImportance,
      ),
    );
    _channelReady = true;
  }

  /// Re-arms all fifteen slots from [times]. A kind whose minutes are 0 is
  /// cancelled rather than scheduled, so turning one off in settings takes
  /// effect on the next fetch without a separate path.
  Future<void> reschedule(
    PrayerTimes times, {
    required int beforeMinutes,
    required int afterMinutes,
    required int iqamaMinutes,
  }) async {
    if (times.isEmpty) {
      await cancelAll();
      return;
    }
    await _ensureChannel();

    for (var i = 0; i < prayerKeys.length; i++) {
      final key = prayerKeys[i];
      final parsed = PrayerTimesService.parseHM(times.byName(key));
      if (parsed == null) continue;
      final (hour, minute) = parsed;
      final at = Duration(hours: hour, minutes: minute);
      final label = 'prayer.$key'.tr();

      await _arm(
        id: _preBase + i,
        minutes: beforeMinutes,
        // Before the adhan, so back off the clock.
        at: at - Duration(minutes: beforeMinutes),
        title: 'notif.pre_title'.tr(namedArgs: {'prayer': label}),
        body: 'notif.pre_body'.tr(namedArgs: {
          'prayer': label,
          'minutes': _minutes(beforeMinutes),
        }),
      );

      await _arm(
        id: _postBase + i,
        minutes: afterMinutes,
        at: at + Duration(minutes: afterMinutes),
        title: 'notif.post_title'.tr(namedArgs: {'prayer': label}),
        body: 'notif.post_body'.tr(namedArgs: {
          'prayer': label,
          'minutes': _minutes(afterMinutes),
        }),
      );

      await _arm(
        id: _iqamaBase + i,
        minutes: iqamaMinutes,
        at: at + Duration(minutes: iqamaMinutes),
        title: 'notif.iqama_title'.tr(namedArgs: {'prayer': label}),
        body: 'notif.iqama_body'.tr(namedArgs: {'prayer': label}),
      );
    }
  }

  Future<void> cancelAll() async {
    for (var i = 0; i < prayerKeys.length; i++) {
      await _plugin.cancel(_preBase + i);
      await _plugin.cancel(_postBase + i);
      await _plugin.cancel(_iqamaBase + i);
    }
  }

  /// «١٠ دقيقة» / "10 minutes" — the count and its unit, in the app's
  /// language, so the body reads as a sentence and not as a bare number.
  String _minutes(int n) => '$n ${'prayer.minutes_unit'.tr()}';

  Future<void> _arm({
    required int id,
    required int minutes,
    required Duration at,
    required String title,
    required String body,
  }) async {
    if (minutes <= 0) {
      await _plugin.cancel(id);
      return;
    }
    final (hour, minute) = wrapToDay(at);
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

  /// The clock time [at] lands on, wrapped into a single day.
  ///
  /// A reminder can cross midnight in either direction — Isha at 23:45 plus a
  /// 30-minute iqama is 00:15 the next day, Fajr at 00:10 minus a 30-minute
  /// warning is 23:40 the previous one. Both are ordinary clock times;
  /// [_nextInstanceOf] then puts them on the right side of now. Without the
  /// wrap the negative case produced a Duration of -20 minutes, whose
  /// `inHours` is 0 and whose `inMinutes % 60` is -20 — an hour and a minute
  /// Android rejects.
  static (int, int) wrapToDay(Duration at) {
    final minutes = ((at.inMinutes % 1440) + 1440) % 1440;
    return (minutes ~/ 60, minutes % 60);
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
