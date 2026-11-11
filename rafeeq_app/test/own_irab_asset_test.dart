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

  // The grammar labels a reader of the other six languages sees under each
  // word (scripts/own_irab/irab_tags.py): every role and case the asset
  // uses must be named in all seven files, or it would show as a raw key.
  test('every i\'rab grammar label is translated in all seven languages', () {
    final own = jsonDecode(File('assets/data/own_irab.json').readAsStringSync())
        as Map<String, dynamic>;
    final roles = <String>{}, cases = <String>{'positional'};
    var tagged = 0, total = 0;
    for (final v in own.values) {
      for (final w in (v as List).cast<List<dynamic>>()) {
        total++;
        expect(w.length, 4, reason: '${w[0]}: no tag list');
        final tags = (w[3] as List).cast<String>();
        if (tags.isNotEmpty) tagged++;
        for (final t in tags) {
          final p = t.split(':');
          roles.add(p[0]);
          if (p.length > 1) cases.add(p[1].replaceAll('~', ''));
        }
      }
    }
    // Measured 2026-11-12: 75,958 of 77,430 words carry a label.
    expect(tagged / total, greaterThan(0.95));
    for (final lang in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final d = jsonDecode(File('assets/translations/$lang.json')
          .readAsStringSync()) as Map<String, dynamic>;
      final tag = d['irab_tag'] as Map<String, dynamic>;
      final cas = d['irab_case'] as Map<String, dynamic>;
      for (final r in roles) {
        expect((tag[r] as String?)?.trim(), isNotEmpty, reason: '$lang $r');
      }
      for (final c in cases) {
        expect((cas[c] as String?)?.trim(), isNotEmpty, reason: '$lang $c');
      }
    }
  });
}
