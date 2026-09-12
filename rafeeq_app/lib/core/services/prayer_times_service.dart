import 'dart:convert';

import 'package:adhan/adhan.dart' as adhan;
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/adhan/data/prayer_calculation_methods.dart';
import '../models/prayer_times.dart';

/// Real prayer times calculated offline using the 'adhan' package.
class PrayerTimesService {
  static const _cacheKey = 'prayer_times_cache_v2';
  static const _cacheDateKey = 'prayer_times_cache_date_v2';

  /// [method] is an AlAdhan method id — see `kPrayerCalculationMethods`,
  /// which carries every id the picker offers and the angles behind it.
  /// [madhab] decides when Asr starts and [highLatitudeRule] what happens
  /// where Fajr and Isha have no real time; both are the reader's settings,
  /// not the method's.
  Future<PrayerTimes> fetchPrayerTimes({
    required double lat,
    required double lon,
    String cityName = '',
    String countryName = '',
    int method = 4,
    adhan.Madhab madhab = adhan.Madhab.shafi,
    adhan.HighLatitudeRule highLatitudeRule =
        adhan.HighLatitudeRule.twilight_angle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Fresh cache?
    if (prefs.getString(_cacheDateKey) == today) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final pt = _decode(cached, cityName, countryName);
        if (pt != null) return pt;
      }
    }

    try {
      final coordinates = adhan.Coordinates(lat, lon);
      final params = _getParams(method, madhab, highLatitudeRule);
      final date = adhan.DateComponents.from(DateTime.now());
      
      final ptAdhan = adhan.PrayerTimes(coordinates, date, params);
      
      final hDate = HijriCalendar.now();
      final hijriStr = '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear}';
      final gregorianStr = DateFormat('dd MMM yyyy', 'ar').format(DateTime.now());
      
      final pt = PrayerTimes(
        fajr: _formatTime(ptAdhan.fajr),
        sunrise: _formatTime(ptAdhan.sunrise),
        dhuhr: _formatTime(ptAdhan.dhuhr),
        asr: _formatTime(ptAdhan.asr),
        maghrib: _formatTime(ptAdhan.maghrib),
        isha: _formatTime(ptAdhan.isha),
        cityName: cityName,
        countryName: countryName,
        hijriDate: hijriStr,
        gregorianDate: gregorianStr,
      );

      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'fajr': pt.fajr,
          'sunrise': pt.sunrise,
          'dhuhr': pt.dhuhr,
          'asr': pt.asr,
          'maghrib': pt.maghrib,
          'isha': pt.isha,
          'hijri': pt.hijriDate,
          'gregorian': pt.gregorianDate,
        }),
      );
      await prefs.setString(_cacheDateKey, today);
      return pt;
    } catch (_) {
      // fall through to stale cache
    }

    // Stale cache is still real measured data — better than nothing offline.
    final stale = prefs.getString(_cacheKey);
    if (stale != null) {
      final pt = _decode(stale, cityName, countryName);
      if (pt != null) return pt;
    }
    return PrayerTimes.empty();
  }

  adhan.CalculationParameters _getParams(
    int method,
    adhan.Madhab madhab,
    adhan.HighLatitudeRule highLatitudeRule,
  ) =>
      prayerCalculationMethodById(method).parameters(
        date: DateTime.now(),
        madhab: madhab,
        highLatitudeRule: highLatitudeRule,
      );

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  PrayerTimes? _decode(String raw, String cityName, String countryName) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PrayerTimes(
        fajr: m['fajr'] as String? ?? '--:--',
        sunrise: m['sunrise'] as String? ?? '--:--',
        dhuhr: m['dhuhr'] as String? ?? '--:--',
        asr: m['asr'] as String? ?? '--:--',
        maghrib: m['maghrib'] as String? ?? '--:--',
        isha: m['isha'] as String? ?? '--:--',
        cityName: cityName,
        countryName: countryName,
        hijriDate: m['hijri'] as String? ?? '',
        gregorianDate: m['gregorian'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// (name, time) of the next prayer after [now].
  (String, DateTime)? nextPrayer(PrayerTimes pt, DateTime now) {
    final entries = <(String, DateTime)>[
      ('fajr', _todayAt(pt.fajr, now)),
      ('sunrise', _todayAt(pt.sunrise, now)),
      ('dhuhr', _todayAt(pt.dhuhr, now)),
      ('asr', _todayAt(pt.asr, now)),
      ('maghrib', _todayAt(pt.maghrib, now)),
      ('isha', _todayAt(pt.isha, now)),
    ];
    for (final e in entries) {
      if (e.$2.isAfter(now)) return e;
    }
    final fajr = _todayAt(pt.fajr, now).add(const Duration(days: 1));
    return ('fajr', fajr);
  }

  /// (name, time) of the prayer that has most recently **passed** at [now] —
  /// the mirror of [nextPrayer], and the other half of «عايز لما أضغط على
  /// عدّاد الصلاة القادمة التنازلي يغيّر ويعرض إيه على الصلاة السابقة».
  ///
  /// Before today's fajr the answer is yesterday's isha, which is why this
  /// cannot just be "the entry before the one nextPrayer returned": at
  /// 03:00 that entry does not exist in today's list at all.
  (String, DateTime)? previousPrayer(PrayerTimes pt, DateTime now) {
    final entries = <(String, DateTime)>[
      ('fajr', _todayAt(pt.fajr, now)),
      ('sunrise', _todayAt(pt.sunrise, now)),
      ('dhuhr', _todayAt(pt.dhuhr, now)),
      ('asr', _todayAt(pt.asr, now)),
      ('maghrib', _todayAt(pt.maghrib, now)),
      ('isha', _todayAt(pt.isha, now)),
    ];
    (String, DateTime)? last;
    for (final e in entries) {
      if (!e.$2.isAfter(now)) last = e;
    }
    if (last != null) return last;
    final isha = _todayAt(pt.isha, now).subtract(const Duration(days: 1));
    return ('isha', isha);
  }

  DateTime _todayAt(String hhmm, DateTime now) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
    if (m == null) return now.add(const Duration(days: 365));
    return DateTime(now.year, now.month, now.day, int.parse(m.group(1)!),
        int.parse(m.group(2)!));
  }

  /// Parses "HH:mm" (as returned in [PrayerTimes]) into (hour, minute), or
  /// null if the string isn't a valid time — e.g. the "--:--" placeholder
  /// used when no real reading is available yet.
  static (int, int)? parseHM(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
}

