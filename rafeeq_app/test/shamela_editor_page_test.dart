import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/shamela/data/shamela_nass.dart';

/// Shamela 30197 («سبيل الرشاد»), fetched 2026-09-27: page 1 holds its
/// whole text («قالوا عن الكتاب», the editor's) in <p class="hamesh">;
/// page 887 is ordinary body text with footnotes.
void main() {
  final nass = (jsonDecode(File(
              'test/fixtures/shamela_30197_nass_p1_p887.json')
          .readAsStringSync()) as Map)
      .cast<String, String>();

  test('a page whose text is all hamesh parses to nothing but is flagged', () {
    expect(parseNass(nass['p1']!), isEmpty);
    expect(hasHamesh(nass['p1']!), isTrue);
  });

  test('an ordinary page keeps its body', () {
    expect(parseNass(nass['p887']!), isNotEmpty);
  });

  test('the reader model carries the flag', () {
    final doc = BookText.fromJson({
      'meta': {'id': 'x', 'title': 't'},
      'pages': [
        {'p': 5, 'paras': [], 'e': 1},
        {'p': 6, 'paras': []},
      ],
    });
    expect(doc.pages[0].editorOnly, isTrue);
    expect(doc.pages[1].editorOnly, isFalse);
  });
}
