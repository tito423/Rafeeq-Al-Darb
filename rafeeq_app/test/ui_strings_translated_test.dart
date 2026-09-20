import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic must not reach a non-Arabic reader through a string literal.
///
/// «لازم كل قسم وكل اوبشن وكل خاصية وكل محتوى مترجم للغه المختارة لان غير
/// العرب مش هيفهموا العربي». The app has 1,417 keys in each of seven locale
/// files and a parity test over them — and none of that helps when a screen
/// writes the Arabic itself. Three places were doing exactly that when this
/// test was written:
///
///   * the sync line on the More tab — «لم تتم المزامنة», «جارٍ المزامنة…» —
///     which is the one line reporting on the reader's own account
///   * the anatomical drawing's credit under مخارج الحروف
///   * as-Safa and al-Marwah in the sa'i counter, where an English
///     transliteration stood in for Spanish, French, Portuguese, Russian
///     AND Urdu
///
/// So: no Arabic string literals under `presentation/` or in `core/services/`,
/// except the files listed below, each of which holds Arabic because the
/// Arabic IS the content — a Qur'anic sample, the app's own name, or a key
/// matched against Arabic data.
void main() {
  /// Files where an Arabic literal is content or a data key, not UI text.
  const allowed = <String, String>{
    'lib/features/azkar/presentation/screens/azkar_screen.dart':
        'keys matched against the azkar database\'s own Arabic section names, '
            'to pick an icon',
    'lib/features/home/presentation/widgets/analog_clock_faces.dart':
        'the Arabic-Indic numeral faces, drawn only when the reader picks them',
    'lib/features/quran/presentation/widgets/mushaf_theme_picker.dart':
        'the ayah drawn in the theme preview',
    'lib/features/quran/presentation/widgets/mushaf/quran_display_sheet.dart':
        'the ayah drawn in the text-size preview — the control sizes Qur\'anic '
            'script, so the sample has to BE that script whatever language '
            'the interface is in',
    'lib/features/settings/presentation/widgets/non_arabic_reading_card.dart':
        'the ayah shown in the transliteration preview',
    'lib/features/tajweed/presentation/screens/jazariyyah_level_screen.dart':
        'the two bare section anchors Shamela sets, «مدخل» and «تمهيد», '
            'matched against the book text so a lesson does not '
            'open on one of them',
    'lib/features/tajweed/presentation/screens/tamhid_level_screen.dart':
        'the same two anchors, for the same reason',
    'lib/features/home/presentation/screens/home_screen.dart':
        'the Arabic comma used as a separator',
    'lib/features/settings/presentation/screens/about_screen.dart':
        'the Arabic comma used as a separator',
    'lib/features/sunan_suwar/presentation/sunan_suwar_reminders_section.dart':
        'the Arabic comma used as a separator',
  };

  final arabic = RegExp('[؀-ۿ]');
  // Dart string literals, single or double quoted, no line breaks.
  final literal = RegExp(r"'((?:[^'\\\n]|\\.)*)'" r'|"((?:[^"\\\n]|\\.)*)"');

  test('no screen or service writes Arabic that a key should carry', () {
    final offenders = <String>[];
    final unusedAllowances = allowed.keys.toSet();

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/presentation/') &&
          !path.contains('/core/services/')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      var found = 0;
      String? first;
      for (final line in lines) {
        final trimmed = line.trim();
        // Comments are where this project explains itself, in both languages.
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        for (final m in literal.allMatches(line)) {
          final value = m.group(1) ?? m.group(2) ?? '';
          if (value.length > 1 && arabic.hasMatch(value)) {
            found++;
            first ??= value;
          }
        }
      }
      if (found == 0) continue;
      if (allowed.containsKey(path)) {
        unusedAllowances.remove(path);
        continue;
      }
      offenders.add('$path — $found literal(s), e.g. "$first"');
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these render Arabic in every language; move them into the '
          'locale files (or add them to `allowed` with the reason the Arabic '
          'is content):\n${offenders.join('\n')}',
    );

    // An allowance that no longer matches anything is a stale claim about the
    // code, and the next person reads it as if it were true.
    expect(unusedAllowances, isEmpty,
        reason: 'these files no longer hold Arabic literals; drop them from '
            '`allowed`: $unusedAllowances');
  });
}
