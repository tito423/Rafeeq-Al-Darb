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
/// would answer a question about a font the app never uses. The budget is
/// calibrated against what was actually seen on emulator-5554 — Spanish and
/// Portuguese «Biblioteca» (10) fits, French «Bibliothèque» (12) does not.
///
/// The full word still appears wherever there is room for it: `library.title`
/// is the Library screen's own heading and is deliberately not abbreviated.
void main() {
  const budget = 10;

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
        if (label!.characters > budget) {
          tooLong.add('$code/nav.$key = "$label" (${label.characters})');
        }
      }
    }
    expect(tooLong, isEmpty,
        reason: 'these labels wrap and get clipped in the bottom bar:\n'
            '${tooLong.join('\n')}');
  });
}

extension on String {
  /// Runes, not code units: an Arabic or Cyrillic label must be counted in
  /// characters the way a Latin one is.
  int get characters => runes.length;
}
