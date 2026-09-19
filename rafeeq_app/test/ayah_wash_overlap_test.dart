import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/ayah_wash_painter.dart';

/// «بيبان خط غريب تحت الآية»: where two lines' washes overlapped, the
/// translucent colour was laid down twice. Paint the path and read pixels.
void main() {
  test('the seam between two lines is no darker than a line itself', () async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final path = washPath(const [
      Rect.fromLTWH(10, 10, 100, 20), // line 1, first word
      Rect.fromLTWH(110, 10, 80, 20), // line 1, second word (separate box)
      Rect.fromLTWH(10, 30, 180, 20), // line 2, touching line 1
    ]);
    canvas.drawPath(path, Paint()..color = const Color(0x80FFC000));
    final img = await rec.endRecording().toImage(200, 60);
    final data = (await img.toByteData())!;
    int alpha(int x, int y) => data.getUint8((y * 200 + x) * 4 + 3);

    final inside = alpha(60, 20);
    expect(inside, greaterThan(0));
    expect(alpha(60, 30), inside, reason: 'the seam between lines');
    expect(alpha(110, 20), inside, reason: 'the seam between two word boxes');
  });
}
