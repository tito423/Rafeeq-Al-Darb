import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/shamela/data/shamela_nass.dart';

/// The Dart `parseNass` against the pipeline's Python `parse_nass`, on 321
/// real Shamela pages from five books (52 ayah paragraphs, 37 with a reference) (fixture made by
/// `scripts/make_shamela_parse_fixture.py`). Same paragraphs, same kinds,
/// same ayah references - or the imported book reads differently from the
/// library's own.
void main() {
  test('every page parses exactly as the pipeline parses it', () {
    final cases = jsonDecode(utf8.decode(gzip.decode(
            File('test/fixtures/shamela_parse_nass.json.gz').readAsBytesSync())))
        as List;
    expect(cases.length, 321);
    var paras = 0;
    for (final c in cases) {
      final m = c as Map<String, dynamic>;
      final expected = [
        for (final p in m['paras'] as List)
          {for (final e in (p as Map).entries) '${e.key}': '${e.value}'},
      ];
      final got = parseNass(m['nass'] as String);
      expect(got, expected, reason: '${m['book']} page ${m['pageId']}');
      paras += got.length;
    }
    // Not a vacuous pass: the pages hold real text.
    expect(paras, greaterThan(500));
  });
}
