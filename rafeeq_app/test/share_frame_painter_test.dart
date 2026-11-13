import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/ayah_share_card.dart';

/// Every frame in every colour paints on a short card and a tall one
/// (2026-11-13: five frames x eight colours in the share sheet).
void main() {
  test('every share frame paints in every colour', () {
    for (final style in ShareStyle.values) {
      for (final frame in ShareFrame.values) {
        for (final size in const [Size(1080, 640), Size(1080, 4200)]) {
          final rec = ui.PictureRecorder();
          ShareFramePainter(
            SharePalette.of(style),
            frame,
          ).paint(Canvas(rec), size);
          final picture = rec.endRecording();
          expect(picture, isNotNull, reason: '$style $frame $size');
          picture.dispose();
        }
      }
    }
  });

  test('light grounds keep ink and ornament readable', () {
    for (final s in [ShareStyle.ivory, ShareStyle.sand, ShareStyle.parchment]) {
      final c = SharePalette.of(s);
      expect(c.top.computeLuminance(), greaterThan(0.6), reason: '$s');
      expect(c.ink.computeLuminance(), lessThan(0.05), reason: '$s');
    }
  });
}
