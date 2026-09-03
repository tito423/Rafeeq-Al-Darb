import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';

/// Real prayer times from the AlAdhan API with offline stale-cache support.
class PrayerTimesService {
  static const _cacheKey = 'prayer_times_cache_v1';
  static const _cacheDateKey = 'prayer_times_cache_date_v1';

  /// [method]: 4 = Umm Al-Qura, 2 = ISNA, 3 = MWL, 5 = Egypt.
  Future<PrayerTimes> fetchPrayerTimes({
    required double lat,
    required double lon,
    String cityName = '',
    String countryName = '',
    int method = 4,
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
      final uri = Uri.parse(
        'https://api.aladhan.com/v1/timings'
        '?latitude=$lat&longitude=$lon&method=$method',
      );
      final resp = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['code'] == 200) {
          final data = body['data'] as Map<String, dynamic>;
          final timings = data['timings'] as Map<String, dynamic>;
          final date = data['date'] as Map<String, dynamic>;
          final hijri =
              (date['hijri'] as Map<String, dynamic>)['date'] as String? ?? '';
          final gregorian =
              (date['gregorian'] as Map<String, dynamic>)['date'] as String? ??
                  '';
          final pt = PrayerTimes(
            fajr: _clean(timings['Fajr']),
            sunrise: _clean(timings['Sunrise']),
            dhuhr: _clean(timings['Dhuhr']),
            asr: _clean(timings['Asr']),
            maghrib: _clean(timings['Maghrib']),
            isha: _clean(timings['Isha']),
            cityName: cityName,
            countryName: countryName,
            hijriDate: hijri,
            gregorianDate: gregorian,
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
              'hijri': hijri,
              'gregorian': gregorian,
            }),
          );
          await prefs.setString(_cacheDateKey, today);
          return pt;
        }
      }
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

  String _clean(Object? t) {
    final s = t?.toString() ?? '--:--';
    // "05:12 (EET)" -> "05:12"
    final m = RegExp(r'^(\d{1,2}:\d{2})').firstMatch(s);
    return m?.group(1) ?? s;
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
