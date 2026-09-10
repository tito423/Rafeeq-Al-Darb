import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/number_symbols_data.dart';
import 'package:rafeeq_app/core/utils/digits.dart';

/// Which languages get Arabic-Indic digits, and why — pinned, because the two
/// answers look inconsistent and are not.
///
/// The owner asked whether Urdu should keep Latin digits. CLDR answers it:
/// `ur` defaults to Latin, while Persian and Pashto default to the **extended**
/// Arabic-Indic set (U+06F0 ۰۱۲۳…, which are not the Arabic U+0660 ٠١٢٣…).
/// Modern CLDR defaults Arabic itself to Latin too.
///
/// So the app is doing two different things on purpose:
///
///  * Urdu follows the standard — Latin, because nobody asked otherwise.
///  * Arabic **departs** from the standard, because the owner wants
///    Arabic-Indic in the Arabic UI: the clock, the Hijri line, the prayer
///    notifications.
///
/// Without this test the second looks like a bug and someone eventually
/// "fixes" it.
void main() {
  test('CLDR is what decided Urdu, and it still says Latin', () {
    // Reading the package's own bundled CLDR data rather than asserting from
    // memory — this is the measurement the decision rests on.
    expect(numberFormatSymbols['ur']!.ZERO_DIGIT, '0',
        reason: 'if CLDR ever changes this, the Urdu decision changes with it');
    expect(numberFormatSymbols['fa']!.ZERO_DIGIT, '۰');
    expect(numberFormatSymbols['ps']!.ZERO_DIGIT, '۰');
  });

  test('only Arabic is reshaped, and it is reshaped completely', () {
    expect(localizeDigits('06:13', 'ar'), '٠٦:١٣');
    expect(localizeDigits('1448', 'ar'), '١٤٤٨');
    for (final locale in ['ur', 'en', 'fr', 'es', 'pt', 'ru']) {
      expect(localizeDigits('06:13', locale), '06:13', reason: locale);
    }
  });

  test('non-digits pass through untouched', () {
    expect(localizeDigits('٢٨ ربيع الأول 1448 هـ', 'ar'),
        '٢٨ ربيع الأول ١٤٤٨ هـ');
    expect(localizeDigits('', 'ar'), '');
  });

  test('there is one converter, not three', () {
    // `core/utils/digits.dart` was written to end a duplicate — and then a
    // third copy sat in `digital_clock_faces.dart` for a while anyway, with
    // its own digit table and its own loop. A file that carries the table is
    // a file that has its own implementation.
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('digits.dart')) continue;
      // `azkar_repeat.dart` parses Arabic-Indic digits back to int — the
      // inverse direction, and not a copy of this.
      if (f.path.endsWith('azkar_repeat.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (line.contains('٠١٢٣٤٥٦٧٨٩')) {
          offenders.add(f.path);
          break;
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these carry their own digit table instead of calling '
            'localizeDigits: ${offenders.join(", ")}');
  });
}
