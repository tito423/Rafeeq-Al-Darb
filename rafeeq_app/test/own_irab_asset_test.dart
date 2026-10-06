import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// assets/data/own_irab.json (scripts/own_irab/export_app.py): every word
/// has its i'rab, and every book named under a word has its label in
/// ar.json - a missing key would show raw (TRAPS #8).
void main() {
  test('own i\'rab asset is complete and its books are labelled', () {
    final own = jsonDecode(File('assets/data/own_irab.json').readAsStringSync())
        as Map<String, dynamic>;
    final quran = (jsonDecode(File('assets/translations/ar.json')
            .readAsStringSync()) as Map<String, dynamic>)['quran']
        as Map<String, dynamic>;
    expect(own, isNotEmpty);
    var words = 0;
    for (final e in own.entries) {
      expect(RegExp(r'^\d+:\d+$').hasMatch(e.key), isTrue, reason: e.key);
      for (final w in (e.value as List).cast<List<dynamic>>()) {
        words++;
        expect((w[0] as String).trim(), isNotEmpty, reason: e.key);
        expect((w[1] as String).trim(), isNotEmpty, reason: '${e.key} ${w[0]}');
        for (final a in (w[2] as List).cast<List<dynamic>>()) {
          expect(quran['irab_alt_${a[0]}'], isA<String>(), reason: '${a[0]}');
        }
      }
    }
    expect(words, greaterThanOrEqualTo(993));
  });
}
