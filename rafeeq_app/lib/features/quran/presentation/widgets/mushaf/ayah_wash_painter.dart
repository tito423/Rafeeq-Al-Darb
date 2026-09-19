import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The recited verse's wash, painted behind the paragraph from the verse's
/// OWN glyph boxes.
///
/// «رقم الآية الفائتة متظلل مع الحالية». The wash used to be the verse
/// span's `backgroundColor`. In a justified right-to-left paragraph with the
/// verse markers set as `WidgetSpan`s, that background ran across the
/// stretched gap and under the PREVIOUS verse's marker — ② inside verse 3's
/// wash on Maryam, ٢٣ inside verse 24's on al-Kahf, on the owner's phone.
///
/// Here the wash is exactly `getBoxesForSelection` over the verse's text, its
/// trailing space excluded, so it can only ever cover the verse's own words.
/// It is read at PAINT time from the paragraph laid out in the same frame, so
/// a new verse is washed on its first frame — no one-frame gap to flicker.
class AyahWashPainter extends CustomPainter {
  final GlobalKey textKey;

  /// Character range of the recited verse in the paragraph, or null.
  final (int, int)? range;
  final Color color;

  AyahWashPainter({required this.textKey, required this.range, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = range;
    if (r == null || r.$2 <= r.$1) return;
    final ro = textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    final boxes = ro.getBoxesForSelection(
      TextSelection(baseOffset: r.$1, extentOffset: r.$2),
      boxHeightStyle: BoxHeightStyle.max,
    );
    canvas.drawPath(washPath(boxes.map((b) => b.toRect())), Paint()..color = color);
  }

  @override
  bool shouldRepaint(AyahWashPainter old) => true;
}

/// The wash as ONE shape.
///
/// «لما بيظلل الآية بيبان خط غريب تحت الآية». Each glyph box used to be
/// drawn as its own translucent rounded rectangle. Inflated so the wash
/// breathes, the boxes of two consecutive lines overlap by a few pixels, and
/// a line can come back as several boxes; wherever two overlapped, the
/// translucent colour was laid down twice and showed as a darker band - the
/// line the owner saw under every verse that wraps.
///
/// Now each line's boxes are merged into one rectangle, and all of them go
/// into a single path filled once (non-zero winding: the overlap is inside
/// the shape once, not twice).
@visibleForTesting
Path washPath(Iterable<Rect> boxes) {
  final lines = <Rect>[];
  for (final b in boxes) {
    final i = lines.indexWhere(
        (l) => (l.center.dy - b.center.dy).abs() < b.height / 2);
    if (i < 0) {
      lines.add(b);
    } else {
      lines[i] = lines[i].expandToInclude(b);
    }
  }
  final path = Path()..fillType = PathFillType.nonZero;
  for (final l in lines) {
    path.addRRect(RRect.fromRectAndRadius(l.inflate(1.5), const Radius.circular(6)));
  }
  return path;
}
