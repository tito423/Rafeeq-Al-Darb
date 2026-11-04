import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/models/adhan_mode.dart';

/// The mode chips read `prayer.mode_<name>_short`, a key built at runtime that
/// the literal-key scan cannot see. v3.94.0's first build showed the raw key
/// «prayer.mode_banner_short» on the new banner chip; this catches the next one.
void main() {
  test('every AdhanMode has its label and short label in all 7 locales', () {
    for (final lang in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final prayer = (jsonDecode(
              File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>)['prayer'] as Map<String, dynamic>;
      for (final m in AdhanMode.values) {
        for (final key in ['mode_${m.name}', 'mode_${m.name}_short']) {
          final v = prayer[key];
          expect(v is String && v.trim().isNotEmpty, isTrue,
              reason: '$lang: prayer.$key');
        }
      }
    }
  });
}
