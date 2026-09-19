import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/inked_svg.dart';

/// The ink is written into the page's SVG (no colour-filter layer, whose
/// bounds clipped words on the owner's phone). A slice of real page 316.
void main() {
  test('both kinds of glyph take the ink, and nothing is left black', () {
    final svg = File('test/fixtures/mushaf_page_316_slice.svg').readAsStringSync();
    expect(svg, contains('fill="#231f20"'), reason: 'fixture must hold both kinds');
    final out = inkedSvg(svg, const Color(0xFFE8E0CC));
    expect(out, isNot(contains('#231f20')));
    expect(RegExp(r'<svg fill="#e8e0cc"').hasMatch(out), isTrue,
        reason: 'unfilled paths inherit the ink from the root');
    expect('fill="#e8e0cc"'.allMatches(out).length, 2);
  });
}
