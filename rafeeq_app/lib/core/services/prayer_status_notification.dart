import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../i18n/hijri_months.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_times.dart';
import 'prayer_times_service.dart';

/// P2‑6 — an ongoing, low-priority status-bar card showing the **next prayer**
/// (name + clock time), the **Hijri date**, and a **live countdown**.
///
/// The countdown ticks natively via Android's notification **chronometer**
/// (`usesChronometer` + `chronometerCountDown` + a future `when`), so it keeps
/// counting even while the app is killed — no background Dart, no foreground
/// service. Rollover to the *next* prayer while the app is closed is handled
/// by one `zonedSchedule` re-post at the current prayer's time; anything
/// longer is corrected the moment the app is next opened (`main.dart` /
/// `PrayerController` call [refresh] again).
///
/// Opt-in: `prayer_status_enabled_provider` (default off). Offline-first: the
/// [PrayerTimes] passed in already come from `PrayerTimesService`'s cache when
/// there's no network; if they're empty the card is hidden, not faked.
class PrayerStatusNotification {
  PrayerStatusNotification._();
  static final PrayerStatusNotification instance = PrayerStatusNotification._();

  static const _channelId = 'rafeeq_prayer_status';
  static const _liveId = 6100; // the visible card
  static const _rolloverId = 6101; // the scheduled "next prayer" re-post

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (_) {},
      );
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          'notif.prayer_channel'.tr(),
          description: 'notif.prayer_channel_desc'.tr(),
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      _ready = true;
    } catch (_) {
      // Notifications are optional; the app is fine without this card.
    }
  }

  /// Post / refresh the card from real [times]. When [enabled] is false or the
  /// times are empty, the card is removed.
  Future<void> refresh({
    required PrayerTimes times,
    required String localeCode,
    required bool enabled,
  }) async {
    await _ensureReady();
    if (!_ready) return;
    if (!enabled) {
      await hide();
      return;
    }

    final svc = PrayerTimesService();
    final now = DateTime.now();
    final next = times.isEmpty ? null : _nextPrayer(svc, times, now);

    // P3‑45: real-device testing found `flutter_local_notifications`
    // throwing ("Missing type parameter") from its own persisted
    // scheduled-notification storage on some devices/emulators carrying
    // notification history from earlier plugin versions — this whole
    // method was previously unguarded and this class's own header already
    // documents the card as optional ("the app is fine without this
    // card"); the try/catch here just actually enforces that promise
    // instead of leaving these calls to throw as unhandled exceptions.
    try {
      if (next == null) {
        // Enabled but no real times yet — be honest, don't invent them.
        await _plugin.cancel(_rolloverId);
        await _startLiveCard(
          _needLocationTitle(localeCode),
          _needLocationBody(localeCode),
          AndroidNotificationDetails(
            _channelId,
            'notif.prayer_channel'.tr(),
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            category: AndroidNotificationCategory.status,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
        return;
      }

      // Prefer the AlAdhan Hijri date already in [times] (Umm al-Qura,
      // matches the Home card and works from cache offline); fall back to
      // the `hijri` package only if that string is missing/old-format.
      final hijriToday = _hijriLine(times.hijriDate, now, localeCode);

      await _startLiveCard(
        _titleFor(next.$1, next.$2, localeCode),
        hijriToday,
        _details(next.$2),
      );

      // One rollover while the app is closed: at `next` time, re-post the
      // card for the prayer after it. Same id as any previous schedule →
      // replaces.
      final after =
          _nextPrayer(svc, times, next.$2.add(const Duration(minutes: 1)));
      await _plugin.cancel(_rolloverId);
      if (after != null) {
        // If the rollover crosses midnight the printed Hijri day advances
        // by one.
        final crossesMidnight = after.$2.day != next.$2.day;
        final hijriRollover = crossesMidnight
            ? _hijriLine('', after.$2, localeCode)
            : hijriToday;
        await _plugin.zonedSchedule(
          _rolloverId,
          _titleFor(after.$1, after.$2, localeCode),
          hijriRollover,
          tz.TZDateTime.from(next.$2, tz.local),
          NotificationDetails(android: _details(after.$2)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Notifications are optional; the app is fine without this card.
    }
  }

  /// P3‑47: post the live card as a real **foreground service** so Android
  /// treats it as non-dismissible and keeps it (and the process) alive while
  /// the app is closed — the owner asked for it to stay put like Salatuk's,
  /// rather than a plain `ongoing` notification that Android 14 now lets the
  /// user swipe away. `specialUse` is the honest FGS type for a standing
  /// countdown card; the manifest declares the matching service + subtype.
  /// Falls back to a plain `show` if the platform impl isn't available.
  Future<void> _startLiveCard(
    String title,
    String body,
    AndroidNotificationDetails details,
  ) async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) {
      await _plugin.show(
          _liveId, title, body, NotificationDetails(android: details));
      return;
    }
    await androidImpl.startForegroundService(
      _liveId,
      title,
      body,
      notificationDetails: details,
      foregroundServiceTypes: {
        AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
      },
    );
  }

  Future<void> hide() async {
    if (!_ready) return;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.stopForegroundService();
      await _plugin.cancel(_liveId);
      await _plugin.cancel(_rolloverId);
    } catch (_) {
      // Notifications are optional; the app is fine without this card.
    }
  }

  // ── content helpers ──────────────────────────────────────────────────────

  /// Next of the five prayers after [from] (never `sunrise`); rolls to
  /// tomorrow's Fajr after Isha. Returns `(key, dateTime)`.
  (String, DateTime)? _nextPrayer(
      PrayerTimesService svc, PrayerTimes t, DateTime from) {
    final raw = svc.nextPrayer(t, from);
    if (raw == null) return null;
    if (raw.$1 != 'sunrise') return raw;
    // Skip sunrise → look again from just after it.
    return svc.nextPrayer(t, raw.$2.add(const Duration(minutes: 1)));
  }

  AndroidNotificationDetails _details(DateTime target) {
    return AndroidNotificationDetails(
      _channelId,
      'notif.prayer_channel'.tr(),
      channelDescription:
          'notif.prayer_channel_desc'.tr(),
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.status,
      // Native live countdown — keeps ticking even with the app killed.
      when: target.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );
  }

  String _titleFor(String key, DateTime at, String localeCode) {
    final name = _prayerName(key, localeCode);
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final clock = localeCode == 'ar' ? _toArabicDigits('$hh:$mm') : '$hh:$mm';
    return '$name · $clock';
  }

  /// Prayer names come from the same keys the rest of the app uses, rather
  /// than a table kept here. The table this replaced covered ar/en/es/ru/pt
  /// and silently fell back to English for French and Urdu.


  String _prayerName(String key, String localeCode) => 'prayer.$key'.tr();

  String _needLocationTitle(String l) => 'app.name'.tr();

  String _needLocationBody(String l) => 'notif.prayer_enable_location'.tr();


  /// Formats the Hijri line. [aladhanHijri] is AlAdhan's "DD-MM-YYYY" string
  /// (Umm al-Qura — authoritative, offline via cache); when it's empty/bad we
  /// fall back to the `hijri` package computed from [day].
  String _hijriLine(String aladhanHijri, DateTime day, String localeCode) {
    final lang = localeCode == 'ar' ? 'ar' : 'en';
    final suffix = 'hijri.suffix'.tr();

    final m = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{3,4})').firstMatch(aladhanHijri);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      if (mo >= 1 && mo <= 12) {
        final line = '$d ${hijriMonthName(mo)} $y$suffix';
        return localeCode == 'ar' ? _toArabicDigits(line) : line;
      }
    }
    try {
      HijriCalendar.setLocal(lang);
      final h = HijriCalendar.fromDate(day);
      final line = '${h.hDay} ${hijriMonthName(h.hMonth)} ${h.hYear}$suffix';
      return localeCode == 'ar' ? _toArabicDigits(line) : line;
    } catch (_) {
      return '';
    }
  }

  String _toArabicDigits(String s) {
    const west = '0123456789';
    const east = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = west.indexOf(ch);
      b.write(i >= 0 ? east[i] : ch);
    }
    return b.toString();
  }
}
