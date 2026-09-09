import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bottom bar's labels have to fit one line.
///
/// `AppShell` shows SEVEN destinations. Material's own guidance stops at five,
/// and seven on a 393dp phone leaves roughly 56dp per tile — so a long
/// translated word does not merely look tight, it wraps to a second line that
/// the bar's fixed 68px height then clips. The owner photographed exactly
/// that: French «Bibliothèque» rendered as "Bibliothèqu" over "e".
///
/// A character budget rather than a text measurement on purpose: a widget test
/// lays out with the test font (every glyph one square em), so measuring there
/// would answer a question about a font the app never uses.
///
/// THE BUDGET IS PER SCRIPT, BECAUSE ONE NUMBER WAS NOT ENOUGH.
/// A flat budget of 10 passed Russian «Библиотека» — exactly ten characters —
/// and it wrapped on `emulator-5554` anyway, because Cyrillic letterforms are
/// wider than Latin ones at the same size. It was seen wrapped during the
/// Russian sweep, after the test had said it was fine. Each number below is
/// calibrated against something actually looked at on the device:
///
///   * Latin 10 — Spanish and Portuguese «Biblioteca» (10) fit; French
///     «Bibliothèque» (12) did not, and is «Biblio.» now.
///   * Cyrillic 8 — «Библиотека» (10) wrapped, «Молитва» (7) and «Главная»
///     (7) fit. The library tab is «Книги» (5) now.
///   * Arabic 8 — «الرئيسية» (8) and «کتب خانہ» (8) fit.
void main() {
  const latinBudget = 10;
  const cyrillicBudget = 8;
  const arabicBudget = 8;

  // Exactly the keys `AppShell` puts in the bar, in order.
  const barKeys = [
    'home', 'quran', 'prayer', 'azkar', 'tasbeeh', 'library', 'more',
  ];

  const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];

  test('every bottom-nav label fits one line in every locale', () {
    final tooLong = <String>[];
    for (final code in locales) {
      final doc = jsonDecode(
        File('assets/translations/$code.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final nav = doc['nav'] as Map<String, dynamic>;
      for (final key in barKeys) {
        final label = nav[key] as String?;
        expect(label, isNotNull, reason: '$code: nav.$key is missing');
        final budget = switch (_scriptOf(label!)) {
          _Script.cyrillic => cyrillicBudget,
          _Script.arabic => arabicBudget,
          _Script.latin => latinBudget,
        };
        if (label.characters > budget) {
          tooLong.add('$code/nav.$key = "$label" '
              '(${label.characters} > $budget)');
        }
      }
    }
    expect(tooLong, isEmpty,
        reason: 'these labels wrap and get clipped in the bottom bar:\n'
            '${tooLong.join('\n')}');
  });
}

enum _Script { latin, cyrillic, arabic }

/// The script of the first letter that has one — enough for a nav label,
/// which is a single word in a single script.
_Script _scriptOf(String label) {
  for (final rune in label.runes) {
    if (rune >= 0x0400 && rune <= 0x04FF) return _Script.cyrillic;
    if (rune >= 0x0600 && rune <= 0x06FF) return _Script.arabic;
  }
  return _Script.latin;
}

extension on String {
  /// Runes, not code units: an Arabic or Cyrillic label must be counted in
  /// characters the way a Latin one is.
  int get characters => runes.length;
}
