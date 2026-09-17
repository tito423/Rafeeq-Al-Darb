import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rafeeq_app/core/i18n/supported_locales.dart';
import 'package:rafeeq_app/core/utils/time_formatter.dart';

/// The 12-hour marker is written in the reader's language, not in English.
///
/// THE DEFECT THIS EXISTS FOR. `formatTime12h` called
/// `DateFormat('h:mm a')` **with no locale**, and `Intl.defaultLocale` is set
/// nowhere in this app — so `intl` fell back to `en_US` and wrote AM/PM for
/// all seven languages. The owner found it on his own phone: the prayer card
/// read «المغرب، ٦:٢١ PM» — Arabic-Indic digits, an Arabic prayer name, and a
/// Latin marker welded to the end.
///
/// `main.dart` was half the cause: it called `initializeDateFormatting('ar')`
/// and nothing else, so even a correct locale argument would have thrown for
/// the other six. It loads all of them now, and this test walks the same list
/// so a language added to the app cannot quietly skip the clock.
void main() {
  setUpAll(() async {
    for (final l in kSupportedLocales) {
      await initializeDateFormatting(l.languageCode);
    }
  });

  test('Arabic writes ص and م, not AM and PM', () {
    // U+2066/U+2069 are the isolate characters `ltr()` adds (trap #16); the
    // marker is what is being asserted, not the wrapping.
    final morning = formatTime12h('04:47', 'ar');
    final evening = formatTime12h('18:21', 'ar');
    expect(morning, contains('ص'), reason: 'got «$morning»');
    expect(evening, contains('م'), reason: 'got «$evening»');
    expect(morning, isNot(contains('AM')));
    expect(evening, isNot(contains('PM')));
  });

  test('English still writes AM and PM', () {
    expect(formatTime12h('04:47', 'en'), contains('AM'));
    expect(formatTime12h('18:21', 'en'), contains('PM'));
  });

  test('every supported language gets its own marker, none falls back to en',
      () {
    // The point is not what each marker IS — that is the locale's business —
    // but that a language which shares English's marker does so because its
    // own data says so, and that nothing throws. A throw here would be the
    // real regression: it means `main.dart` stopped loading that locale.
    for (final l in kSupportedLocales) {
      final code = l.languageCode;
      final out = formatTime12h('18:21', code);
      expect(out, isNotEmpty, reason: code);
      expect(out, isNot(contains('18')),
          reason: '$code did not convert to 12-hour: «$out»');
    }
  });

  test('a locale nobody loaded falls back instead of throwing', () {
    // A clock on the screen beats a crashed tile. The raw «18:21» would be
    // worse than an English marker, so the fallback still formats.
    final out = formatTime12h('18:21', 'zz');
    expect(out, isNotEmpty);
    expect(out, isNot(contains('18:21')));
  });

  test('a malformed input is returned untouched, not guessed at', () {
    expect(formatTime12h('--:--', 'ar'), '--:--');
    expect(formatTime12h('', 'ar'), '');
    expect(formatTime12h('not a time', 'ar'), 'not a time');
  });
}
