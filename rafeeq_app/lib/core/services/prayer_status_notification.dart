import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';

import '../i18n/hijri_months.dart';
import '../models/prayer_times.dart';
import '../utils/digits.dart';
import '../utils/time_formatter.dart';
import 'notification_router.dart';
import 'prayer_times_service.dart';

/// P2‑6 — a low-priority status-bar card showing the **next prayer** (name +
/// clock time), the **Hijri date**, and a **live countdown**.
///
/// The countdown is Android's notification chronometer, so it keeps counting
/// with the app killed. Since 3.17.1 the card itself is posted natively
/// (`PrayerCard.kt`): «خلّي دايمًا إشعار الصلاة القادمة بعدّاده شغّال حتى لو
/// حذفته بالغلط». Android 14 lets a user swipe away even a foreground
/// service's notification, and flutter_local_notifications cannot hear the
/// dismissal; a native delete intent can, and posts the card straight back.
/// The rollover to the prayer after it, and re-posting after a reboot or an
/// update, are native too. This class only decides what the card says.
///
/// Opt-in: `prayer_status_enabled_provider`. Offline-first: the [PrayerTimes]
/// come from `PrayerTimesService`'s cache when there's no network; if they're
/// empty the card says so rather than inventing times.
class PrayerStatusNotification {
  PrayerStatusNotification._();
  static final PrayerStatusNotification instance = PrayerStatusNotification._();

  static const _channelId = 'rafeeq_prayer_status';
  static const _liveId = 6100;

  /// The scheduled re-post earlier builds kept in the plugin's own storage.
  /// Cancelled on every refresh, or it would post a second card at the next
  /// prayer.
  static const _legacyRolloverId = 6101;

  static const _native = MethodChannel('com.tito.rafeeq_aldarb/prayer_card');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _legacyStopped = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      // Through the router — see `NotificationRouter` (trap #31).
      await NotificationRouter.instance.ensureInitialized();
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // No permission request here: the startup sequence owns the asking.
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

  /// Earlier builds posted the card as the plugin's foreground service, with
  /// a scheduled re-post. Both are stopped once per process so the native card
  /// is the only one.
  Future<void> _stopLegacy() async {
    if (_legacyStopped) return;
    _legacyStopped = true;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    } catch (_) {}
    try {
      await _plugin.cancel(_legacyRolloverId);
    } catch (_) {}
  }

  /// Post / refresh the card from real [times]. When [enabled] is false the
  /// card is removed.
  Future<void> refresh({
    required PrayerTimes times,
    required String localeCode,
    required bool enabled,
  }) async {
    await _ensureReady();
    if (!_ready) return;
    await _stopLegacy();
    if (!enabled) {
      await hide();
      return;
    }

    final now = DateTime.now();

    // THE HOUR AFTER THE ADHAN BELONGS TO THE PRAYER THAT CAME IN.
    // «لما يحين وقت الصلاة يبدأ يعد عدّاد تصاعدي … لحد ساعة، وبعد الساعة يبدأ
    // يغيّر الإشعار: باقي على صلاة الفجر». [elapsedWindow] is that hour, and
    // it is sent to the native side rather than decided here, for the reason
    // written on [_schedule].
    try {
      if (times.isEmpty) {
        // Enabled but no real times yet — be honest, don't invent them.
        await _native.invokeMethod<void>('show', {
          'events': <Map<String, Object>>[],
          'title': _needLocationTitle(localeCode),
          'body': _needLocationBody(localeCode),
          'elapsedMs': elapsedWindow.inMilliseconds,
          ..._buttonLabels(),
        });
        return;
      }
      // THE CARD IS BUILT FROM A WHOLE SCHEDULE, NOT FROM ONE PRAYER.
      // It used to send the current card and the one after it, and the native
      // side swapped them on an alarm. That chain is two links long: once both
      // had been used the card froze until the app was opened again —
      // photographed on the owner's Honor at 06:06, still reading «العشاء ·
      // ١٩:٤١» under «٤ ربيع الآخر», a whole Hijri day out of date. Sending
      // every event of today and tomorrow lets the native side work out what
      // to show from the clock alone, so a missed alarm costs nothing: the
      // next repost is already right.
      await _native.invokeMethod<void>('show', {
        'events': schedule(times, now, localeCode),
        'elapsedMs': elapsedWindow.inMilliseconds,
        ..._buttonLabels(),
      });
    } catch (_) {
      // Notifications are optional; the app is fine without this card.
    }
  }

  /// Every prayer of today and tomorrow, each already written the way the card
  /// shows it: the Hijri date and city on one line, «الفجر، ٤:٤٧ ص» on the
  /// other. That order is the owner's — «انا عايز شكل الاشعار … تيبيكال
  /// صلاتك» — and it is the reverse of what this card used to say.
  ///
  /// SUNRISE IS IN THE LIST. The card skipped it because sunrise is not a
  /// prayer, but it is the event a reader watches between Fajr and Dhuhr, and
  /// the screenshot he sent reads «الشروق، 06:02 ص  +04:15».
  ///
  /// Tomorrow's entries repeat today's clock times a day later. That is the
  /// same approximation `nextPrayer` has always made for tomorrow's Fajr — the
  /// real times move a minute or two — and it only ever covers the gap until
  /// the app next runs and sends the day it actually fetched.
  @visibleForTesting
  List<Map<String, Object>> schedule(
    PrayerTimes times,
    DateTime now,
    String localeCode,
  ) {
    final entries = <(String, DateTime)>[];
    for (final day in [now, now.add(const Duration(days: 1))]) {
      for (final e in [
        ('fajr', times.fajr),
        ('sunrise', times.sunrise),
        ('dhuhr', times.dhuhr),
        ('asr', times.asr),
        ('maghrib', times.maghrib),
        ('isha', times.isha),
      ]) {
        final at = _at(e.$2, day);
        if (at != null) entries.add((e.$1, at));
      }
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));

    // Only AlAdhan's Umm al-Qura date belongs to today; every other day's
    // line is computed by `_hijriLine` from the date it is handed.
    final today = DateTime(now.year, now.month, now.day);
    final out = <Map<String, Object>>[];
    for (final e in entries) {
      if (!e.$2.isAfter(now.subtract(elapsedWindow))) continue;
      final day = DateTime(e.$2.year, e.$2.month, e.$2.day);
      out.add({
        'label': _eventLine(e.$1, e.$2, localeCode),
        'body': _withCity(
          _hijriLine(day == today ? times.hijriDate : '', e.$2, localeCode),
          times.cityName,
        ),
        'when': e.$2.millisecondsSinceEpoch,
      });
    }
    return out;
  }

  /// [hhmm] on [day], or null when the string cannot be read — an unreadable
  /// time is left out of the schedule rather than invented.
  DateTime? _at(String hhmm, DateTime day) {
    final hm = PrayerTimesService.parseHM(hhmm);
    if (hm == null) return null;
    return DateTime(day.year, day.month, day.day, hm.$1, hm.$2);
  }

  Future<void> hide() async {
    try {
      await _native.invokeMethod<void>('hide');
    } catch (_) {}
    try {
      await _plugin.cancel(_liveId);
      await _plugin.cancel(_legacyRolloverId);
    } catch (_) {}
  }

  // ── content helpers ──────────────────────────────────────────────────────

  /// How long the card stays on the event that has just come in, counting up
  /// from it before it moves on to the next one.
  static const elapsedWindow = Duration(hours: 1);

  /// «الفجر، ٤:٤٧ ص» — the event line, in the shape the owner's reference
  /// screenshot uses. The clock is [formatTime12h], which is already wrapped
  /// in a left-to-right isolate: «٦:٠٢ ص» is a bidi-weak numeral beside a
  /// marker and the two swap without one (trap #16).
  String _eventLine(String key, DateTime at, String localeCode) {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final clock =
        localizeDigits(formatTime12h('$hh:$mm', localeCode), localeCode);
    return 'notif.prayer_event'
        .tr(namedArgs: {'prayer': 'prayer.$key'.tr(), 'time': clock});
  }

  /// «٥ ربيع الآخر ١٤٤٨ هـ | دبي» — the city is appended only when there
  /// really is one; the separator is the one «صلاتك» uses.
  String _withCity(String line, String city) {
    final name = city.trim();
    if (name.isEmpty) return line;
    return '$line | $name';
  }

  /// The card's two action buttons, captioned here because nothing native
  /// may invent a user-visible word.
  ///
  /// «عايز شكل الاشعار بتاعي تيبيكال نفس اشعار صلاتك» (2026-09-17): beside
  /// Salatuk's card, which carries «افتح صلاتك» and «تحديث الموقع», ours
  /// carried none at all.
  ///
  /// «الصلاة القادمة» is the more useful of the two, and it exists because of
  /// what he was looking at when he asked. At 19:13 his card read «المغرب،
  /// ٦:٢١» while Salatuk read «العشاء ٠٧:٣٨». That is not a fault: it is
  /// [elapsedWindow] doing exactly what he asked for earlier — «لما يحين وقت
  /// الصلاة يبدأ يعد عدّاد تصاعدي … لحد ساعة». The rule stays; the button is
  /// one tap past it, and the override lasts a single post.
  Map<String, String> _buttonLabels() => {
        'openLabel': 'notif.prayer_open'.tr(),
        'nextLabel': 'notif.prayer_next'.tr(),
      };

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
        return localizeDigits(line, localeCode);
      }
    }
    try {
      HijriCalendar.setLocal(lang);
      final h = HijriCalendar.fromDate(day);
      final line = '${h.hDay} ${hijriMonthName(h.hMonth)} ${h.hYear}$suffix';
      return localizeDigits(line, localeCode);
    } catch (_) {
      return '';
    }
  }
}
