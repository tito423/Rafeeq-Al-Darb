import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen may still name a book the app no longer ships.
///
/// THE DEFECT THIS EXISTS FOR, three times over. «من كتاب الشيخ ابن باز»
/// survived three commits after his manual was removed from the Hajj guide. On
/// 2026-09-17 the azkar corpus moved off «حصن المسلم» and three strings still
/// named it — the Adhkar hub subtitle and two lines on the ruqyah screen —
/// which a reader would take as a statement about what he is reading.
///
/// And the Russian one nearly escaped: it had the book's name **translated**,
/// «Крепости мусульманина», so a search for the Arabic or the transliteration
/// found nothing. A removed book has to be searched for in every form a
/// locale might write it.
void main() {
  const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];

  /// Books removed from the app, in every spelling the locale files use.
  const removed = <String, List<String>>{
    'Hisn al-Muslim': [
      'حصن المسلم',
      'Hisn al-Muslim',
      'Hisn al-Muslim',
      'Крепости мусульманина',
      'Крепость мусульманина',
      'Fortaleza del musulmán',
      'Forteresse du musulman',
      'Fortaleza do muçulmano',
      'حصن المسلم',
    ],
    'Ibn Baz\'s Hajj manual': ['ابن باز', 'Ibn Baz'],
  };

  String flatten(Object? node) {
    if (node is String) return node;
    if (node is Map) return node.values.map(flatten).join(' \u0000 ');
    if (node is List) return node.map(flatten).join(' \u0000 ');
    return '';
  }

  for (final locale in locales) {
    test('$locale names no removed book', () {
      final text = flatten(jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync()));
      for (final entry in removed.entries) {
        for (final spelling in entry.value) {
          expect(text.contains(spelling), isFalse,
              reason: '$locale still says «$spelling» — ${entry.key} is not in '
                  'the app any more, so a reader is being told something '
                  'untrue about what he is looking at');
        }
      }
    });
  }
}
