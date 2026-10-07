import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every bundled adhan names its muezzin in all seven languages
/// (CLAUDE.md §1.7c): a French reader used to pick from Arabic names.
void main() {
  test('every catalogue adhan has a name in the six other languages', () {
    final list = jsonDecode(
            File('assets/data/catalogs/adhans.json').readAsStringSync())
        as List;
    const langs = ['en', 'fr', 'es', 'pt', 'ru', 'ur'];
    for (final a in list.cast<Map<String, dynamic>>()) {
      final names = (a['names'] as Map?) ?? const {};
      for (final l in langs) {
        expect((names[l] as String?)?.trim(), isNotEmpty,
            reason: '${a['id']} $l');
      }
      for (final l in langs.where((l) => l != 'ur')) {
        expect(RegExp('[ء-ي]').hasMatch(names[l] as String), isFalse,
            reason: '${a['id']} $l still has Arabic letters');
      }
    }
  });
}
