import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rafeeq_app/core/services/prayer_times_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manual location set to Tanta on emulator-5554 (2026-09-25): the card said
/// «Tanta, Egypt» over Dubai's Fajr 4:50. A same-day cache keyed by the date
/// alone answered before the calculation. A new place - or a new method -
/// must give new times the same day.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a second place the same day gets its own times', () async {
    final s = PrayerTimesService();
    final dubai = await s.fetchPrayerTimes(lat: 25.2048, lon: 55.2708);
    final tanta = await s.fetchPrayerTimes(lat: 30.7885, lon: 31.0019);
    expect(dubai.fajr, isNotEmpty);
    expect(tanta.fajr, isNot(dubai.fajr));
    expect(tanta.maghrib, isNot(dubai.maghrib));
  });

  test('a second calculation method the same day gets its own times',
      () async {
    final s = PrayerTimesService();
    // 4 = Umm al-Qura (Fajr 18.5°), 5 = Egyptian (Fajr 19.5°)
    final a = await s.fetchPrayerTimes(lat: 25.2048, lon: 55.2708, method: 4);
    final b = await s.fetchPrayerTimes(lat: 25.2048, lon: 55.2708, method: 5);
    expect(b.fajr, isNot(a.fajr));
  });
}
