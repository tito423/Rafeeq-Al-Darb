import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The cuts that show one ayah's part of a multi-ayah i'rab run
/// (scripts/build_irab_daas_splits.py) must rise inside each run.
void main() {
  test('irab splits are rising positive offsets', () {
    final m = jsonDecode(
            File('assets/data/irab_daas_splits.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(m.length, greaterThan(1000));
    m.forEach((k, v) {
      expect(RegExp(r'^\d+:\d+$').hasMatch(k), isTrue, reason: k);
      final cuts = [for (final o in v as List) o as int];
      expect(cuts, isNotEmpty, reason: k);
      for (var i = 0; i < cuts.length; i++) {
        expect(cuts[i], greaterThan(i == 0 ? 0 : cuts[i - 1]), reason: k);
      }
    });
  });
}
