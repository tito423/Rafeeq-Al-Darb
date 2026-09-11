import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hijri/hijri_calendar.dart';

import '../i18n/hijri_months.dart';
import '../models/prayer_times.dart';
import '../utils/digits.dart';
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

    final svc = PrayerTimesService();
    final now = DateTime.now();
    final next = times.isEmpty ? null : _nextPrayer(svc, times, now);

    try {
      if (next == null) {
        // Enabled but no real times yet — be honest, don't invent them.
        await _show(_needLocationTitle(localeCode), _needLocationBody(localeCode));
        return;
      }

      // AlAdhan's Umm al-Qura date first (matches Home, works offline).
      // «الإشعار زوّد فيه اسم المدينة اللي احنا فيها» — the card said
      // «الفجر · ٤:٤٤ / ٢٩ ربيع الأول ١٤٤٨ هـ» and nothing about where that
      // time was computed for, which is the one fact that makes it checkable
      // when the phone has travelled or the location fix is stale. The name
      // is whatever `LocationService` reverse-geocoded — when there is none
      // (permission refused, offline on a cold start) the line stays exactly
      // as it was rather than claiming a city.
      final hijriToday = _withCity(
        _hijriLine(times.hijriDate, now, localeCode),
        times.cityName,
      );
      final after =
          _nextPrayer(svc, times, next.$2.add(const Duration(minutes: 1)));
      final crossesMidnight = after != null && after.$2.day != next.$2.day;
      await _show(
        _titleFor(next.$1, next.$2, localeCode),
        hijriToday,
        at: next.$2,
        nextTitle: after == null ? null : _titleFor(after.$1, after.$2, localeCode),
        nextBody: after == null
            ? null
            : crossesMidnight
                ? _withCity(
                    _hijriLine('', after.$2, localeCode), times.cityName)
                : hijriToday,
        nextAt: after?.$2,
      );
    } catch (_) {
      // Notifications are optional; the app is fine without this card.
    }
  }

  Future<void> _show(
    String title,
    String body, {
    DateTime? at,
    String? nextTitle,
    String? nextBody,
    DateTime? nextAt,
  }) async {
    await _native.invokeMethod<void>('show', {
      'title': title,
      'body': body,
      'when': at?.millisecondsSinceEpoch ?? 0,
      'nextTitle': nextTitle,
      'nextBody': nextBody,
      'nextWhen': nextAt?.millisecondsSinceEpoch ?? 0,
    });
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

  /// Next of the five prayers after [from] (never `sunrise`); rolls to
  /// tomorrow's Fajr after Isha. Returns `(key, dateTime)`.
  (String, DateTime)? _nextPrayer(
      PrayerTimesService svc, PrayerTimes t, DateTime from) {
    final raw = svc.nextPrayer(t, from);
    if (raw == null) return null;
    if (raw.$1 != 'sunrise') return raw;
    return svc.nextPrayer(t, raw.$2.add(const Duration(minutes: 1)));
  }

  String _titleFor(String key, DateTime at, String localeCode) {
    final name = 'prayer.$key'.tr();
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final clock = localizeDigits('$hh:$mm', localeCode);
    return '$name · $clock';
  }

  /// «الجزء الثاني · المدينة» — appended only when there really is a city.
  String _withCity(String line, String city) {
    final name = city.trim();
    if (name.isEmpty) return line;
    return '$line · $name';
  }

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
