import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_paper_provider.dart';

/// Night and warm paper for the paper mushaf, COMPUTED — trap #15: a colour
/// pairing is judged by its contrast ratio, not by eye.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

double _hue(Color c) => HSVColor.fromColor(c).hue;

void main() {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  test('a scan at night: white page becomes the night ground, ink stays legible', () {
    final page = applyMatrix(nightScanMatrix, white);
    final ink = applyMatrix(nightScanMatrix, black);
    expect((page.r * 255).round(), closeTo(0x0F, 2));
    expect((page.b * 255).round(), closeTo(0x22, 2));
    expect(_contrast(page, ink), greaterThanOrEqualTo(7.0),
        reason: 'contrast ${_contrast(page, ink).toStringAsFixed(1)}');
  });

  test('warm paper: white becomes the warm ground, black ink stays black', () {
    final page = applyMatrix(warmScanMatrix, white);
    expect(page, warmPaper);
    expect(applyMatrix(warmScanMatrix, black), black);
    expect(_contrast(warmPaper, black), greaterThanOrEqualTo(7.0));
  });

  test('vector pages: both inks read on their grounds', () {
    expect(_contrast(warmPaper, warmInk), greaterThanOrEqualTo(7.0));
    expect(_contrast(nightPaper, nightInk), greaterThanOrEqualTo(7.0));
  });

  test('tajweed colours keep their hue at night (within 40°)', () {
    // The rule colours of a coloured-tajweed printing: a red, a green, a
    // blue. Inverting alone would give their complements; the half-turn hue
    // rotation brings each back near its own hue.
    for (final c in const [Color(0xFFD32F2F), Color(0xFF2E7D32), Color(0xFF1565C0)]) {
      final out = applyMatrix(nightScanMatrix, c);
      final d = (_hue(out) - _hue(c)).abs() % 360;
      expect(math.min(d, 360 - d), lessThan(40),
          reason: '$c -> $out (hue ${_hue(c).round()} -> ${_hue(out).round()})');
    }
  });

  test('a dark-page printing is never filtered', () {
    for (final p in MushafPaper.values) {
      expect(scanFilter(p, darkPage: true), isNull);
    }
    expect(scanFilter(MushafPaper.normal, darkPage: false), isNull);
  });
}
