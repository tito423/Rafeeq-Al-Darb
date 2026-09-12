import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quotes/data/quote_palettes.dart';

/// CLAUDE.md trap #15: «a translucent highlight over a dark ground composites
/// dark, however bright the colour looks on its own. Compute the composite
/// and its contrast ratio; do not judge a colour pairing by eye.» Three
/// mushaf themes shipped at 2.3–2.6 : 1 against a 4.5 : 1 floor because
/// somebody looked at the swatches.
///
/// The quote card is exactly that shape: ink over a gradient, with a
/// translucent ornament drawn between them. So every palette is measured
/// here — at BOTH ends of its gradient, because the saying is centred and the
/// gradient is not flat — and the ornament is measured too, against the
/// ground it is drawn on.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

double _ratio(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final hi = max(a, b);
  final lo = min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// [over] composited onto [under] at its own alpha — what a viewer's eye
/// actually receives, which is the whole point of the trap.
Color _composite(Color over, Color under) {
  final a = over.a;
  return Color.fromARGB(
    255,
    ((over.r * a + under.r * (1 - a)) * 255).round(),
    ((over.g * a + under.g * (1 - a)) * 255).round(),
    ((over.b * a + under.b * (1 - a)) * 255).round(),
  );
}

void main() {
  test('every quote palette clears 4.5:1 at both ends of its gradient', () {
    expect(kQuotePalettes, isNotEmpty);
    for (var i = 0; i < kQuotePalettes.length; i++) {
      final p = kQuotePalettes[i];
      for (final ground in [p.top, p.bottom]) {
        // The ornament sits between the ink and the ground, so the ink's
        // real background is the ornament composited onto the gradient —
        // not the gradient alone.
        final withOrnament = _composite(p.ornament, ground);
        for (final bg in [ground, withOrnament]) {
          expect(_ratio(p.ink, bg), greaterThanOrEqualTo(4.5),
              reason: 'palette $i: the saying measures '
                  '${_ratio(p.ink, bg).toStringAsFixed(2)}:1');
          // The book line is secondary text, so it takes the 3:1 floor
          // large text is allowed — it is set at 13–15 px bold on a card
          // whose whole job is to be read.
          expect(_ratio(p.muted, bg), greaterThanOrEqualTo(3.0),
              reason: 'palette $i: the attribution measures '
                  '${_ratio(p.muted, bg).toStringAsFixed(2)}:1');
        }
      }
    }
  });

  test('the gradient is dark enough for a light ink at both ends', () {
    for (var i = 0; i < kQuotePalettes.length; i++) {
      final p = kQuotePalettes[i];
      expect(_luminance(p.ink), greaterThan(_luminance(p.top)),
          reason: 'palette $i inverts at the top of its gradient');
      expect(_luminance(p.ink), greaterThan(_luminance(p.bottom)),
          reason: 'palette $i inverts at the bottom of its gradient');
    }
  });
}
