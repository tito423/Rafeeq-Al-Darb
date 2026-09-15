import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:rafeeq_app/core/services/prayer_times_service.dart';
import 'package:rafeeq_app/core/utils/digits.dart';
import 'package:rafeeq_app/features/adhan/data/prayer_adjustments_provider.dart';

/// «٨٧٥٩» hours to Fajr, on a real phone in the UAE.
///
/// `DateFormat('HH:mm')` without a locale follows the phone's, and under
/// `ar_EG` it writes «٠٤:٤٤». The parser only read ASCII digits and fell back
/// to a year from now. These pin both halves: what the formatter really emits
/// under that locale, and that the parsers read it.
void main() {
  test('ar_EG really does format HH:mm with Arabic-Indic digits', () async {
    await initializeDateFormatting('ar_EG');
    final t = DateTime(2026, 9, 13, 4, 44);
    expect(DateFormat('HH:mm', 'ar_EG').format(t), '٠٤:٤٤');
    // The fix: an explicit ASCII locale, whatever the phone is set to.
    expect(DateFormat('HH:mm', 'en').format(t), '04:44');
  });

  test('asciiDigits turns both Arabic-Indic digit sets into ASCII', () {
    expect(asciiDigits('٠٤:٤٤'), '04:44');
    expect(asciiDigits('۰۴:۴۴'), '04:44');
    expect(asciiDigits('04:44'), '04:44');
  });

  test('parseHM reads a time written in Arabic-Indic digits', () {
    expect(PrayerTimesService.parseHM('٠٤:٤٤'), (4, 44));
    expect(PrayerTimesService.parseHM('۲۰:۰۴'), (20, 4));
    expect(PrayerTimesService.parseHM('--:--'), isNull);
  });

  test('a minute offset applies to an Arabic-Indic time', () {
    expect(applyMinuteOffset('٠٤:٤٤', 2), '04:46');
  });
}
