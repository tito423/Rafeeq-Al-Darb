import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_times.dart';

class PrayerTimesService {
  static const _cacheKey = 'prayer_times_cache';
  static const _cacheDateKey = 'prayer_times_cache_date';

  /// Fetch prayer times from api.aladhan.com using lat/lon.
  /// Falls back to cached data if network fails.
  Future<PrayerTimes> fetchPrayerTimes({
    required double lat,
    required double lon,
    required String cityName,
    int method = 4, // 4 = Umm Al-Qura (Mecca), 2 = ISNA
    Map<String, int>? offsets,
  }) async {
    final today = _todayString();

    // Check cache first
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_cacheDateKey);
    if (cachedDate == today) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          return PrayerTimes.fromAlAdhanJson(
            map['timings'] as Map<String, dynamic>,
            map['date'] as Map<String, dynamic>,
            cityName.isNotEmpty ? cityName : (map['city'] as String? ?? ''),
            offsets: offsets,
          );
        } catch (_) {}
      }
    }

    // Fetch from API
    final url = Uri.parse(
      'https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lon'
      '&method=$method',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 200) {
          final data = body['data'] as Map<String, dynamic>;
          final timings = data['timings'] as Map<String, dynamic>;
          final dateInfo = data['date'] as Map<String, dynamic>;

          // Cache it
          await prefs.setString(
            _cacheKey,
            jsonEncode({
              'timings': timings,
              'date': dateInfo,
              'city': cityName,
            }),
          );
          await prefs.setString(_cacheDateKey, today);

          return PrayerTimes.fromAlAdhanJson(timings, dateInfo, cityName, offsets: offsets);
        }
      }
    } catch (e) {
      // Fall through to cache/fallback
    }

    // Try stale cache
    final staleCache = prefs.getString(_cacheKey);
    if (staleCache != null) {
      try {
        final map = jsonDecode(staleCache) as Map<String, dynamic>;
        return PrayerTimes.fromAlAdhanJson(
          map['timings'] as Map<String, dynamic>,
          map['date'] as Map<String, dynamic>,
          cityName.isNotEmpty ? cityName : (map['city'] as String? ?? ''),
          offsets: offsets,
        );
      } catch (_) {}
    }

    return PrayerTimes.empty();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Determine which prayer is next based on current time.
  String getNextPrayer(PrayerTimes pt) {
    final now = DateTime.now();
    final prayers = {
      'الفجر': _parseTime(pt.fajr),
      'الشروق': _parseTime(pt.sunrise),
      'الظهر': _parseTime(pt.dhuhr),
      'العصر': _parseTime(pt.asr),
      'المغرب': _parseTime(pt.maghrib),
      'العشاء': _parseTime(pt.isha),
    };

    for (final entry in prayers.entries) {
      final prayerTime = entry.value;
      if (prayerTime != null && prayerTime.isAfter(now)) {
        return entry.key;
      }
    }
    return 'الفجر'; // after Isha, next is Fajr tomorrow
  }

  Duration? getTimeUntilNextPrayer(PrayerTimes pt) {
    final now = DateTime.now();
    final prayers = [
      _parseTime(pt.fajr),
      _parseTime(pt.sunrise),
      _parseTime(pt.dhuhr),
      _parseTime(pt.asr),
      _parseTime(pt.maghrib),
      _parseTime(pt.isha),
    ];

    for (final prayerTime in prayers) {
      if (prayerTime != null && prayerTime.isAfter(now)) {
        return prayerTime.difference(now);
      }
    }
    
    // If all prayers today have passed, calculate time until tomorrow's Fajr
    final tomorrowFajr = _parseTime(pt.fajr)?.add(const Duration(days: 1));
    if (tomorrowFajr != null) {
      return tomorrowFajr.difference(now);
    }
    
    return null;
  }

  DateTime? _parseTime(String timeStr) {
    if (timeStr == '--:--') return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }
}
