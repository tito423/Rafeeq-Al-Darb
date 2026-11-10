import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../../../data/mushaf_theme.dart';
import '../../../data/rub_el_hizb.dart';

/// The left gutter a text page keeps when it carries a quarter mark, so the
/// margin plate has paper of its own and never sits on a word.
const double rubGutterWidth = 46;

/// The quarter plate of the printed mushaf, in the page's margin beside the
/// line that carries «۞» (owner, 2026-11-10: «علامة الربع المفروض تبقى زي
/// المصحف الورقي بالظبط»).
///
/// The shape and the wording are read off the Madinah printing of 1428 AH
/// (pages 5, 7, 9 and 22): a plate with a pointed head and foot, a pale
/// ground and a dark outline, the words stacked - «ربع / الحزب / ١».
class RubMarginPainter extends CustomPainter {
  /// The paragraph the marks are in.
  final GlobalKey textKey;

  /// Text offset of each «۞» in that paragraph, and the quarter it opens.
  final List<(int, RubInfo)> marks;

  /// How far left of the paragraph the page's edge is.
  final double gutter;
  final MushafTheme mt;
  final TextStyle baseStyle;

  RubMarginPainter({
    required this.textKey,
    required this.marks,
    required this.gutter,
    required this.mt,
    required this.baseStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty || gutter < 30) return;
    final ro = textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    final width = (gutter - 8).clamp(30.0, 40.0);
    for (final (offset, info) in marks) {
      final boxes = ro.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      if (boxes.isEmpty) continue;
      final line = boxes.first.toRect();
      paintRubPlate(
        canvas,
        centre: Offset(-gutter / 2, line.center.dy),
        width: width,
        lines: info.marginLines,
        mt: mt,
        baseStyle: baseStyle,
      );
    }
  }

  @override
  bool shouldRepaint(RubMarginPainter old) =>
      old.gutter != gutter ||
      old.mt != mt ||
      old.marks.length != marks.length ||
      old.textKey != textKey;
}

/// The plate itself, [width] wide and as tall as its lines need.
void paintRubPlate(
  Canvas canvas, {
  required Offset centre,
  required double width,
  required List<String> lines,
  required MushafTheme mt,
  required TextStyle baseStyle,
}) {
  final inner = width - 8;
  final painters = <TextPainter>[];
  for (var i = 0; i < lines.length; i++) {
    final last = i == lines.length - 1;
    // The hizb's name is the large line, as printed; the fraction above it
    // and the number under it are smaller.
    final big = lines.length == 2 || i == lines.length - 2;
    final tp = TextPainter(
      text: TextSpan(
        text: lines[i],
        style: baseStyle.copyWith(
          fontFamily: 'AmiriQuran',
          letterSpacing: 0,
          fontSize: big ? 13.5 : (last ? 12 : 10.5),
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: mt.ink,
        ),
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    painters.add(tp);
  }
  double scaleOf(TextPainter tp) => tp.width > inner ? inner / tp.width : 1;
  final textHeight = painters.fold<double>(
    0,
    (sum, tp) => sum + tp.height * scaleOf(tp),
  );
  final tip = width * 0.34;
  final half = Size(width / 2, textHeight / 2 + tip + 6);

  final w = half.width;
  final h = half.height;
  final r = width * 0.2;
  final plate = Path()
    ..moveTo(0, -h)
    ..quadraticBezierTo(w * 0.25, -h + tip * 0.9, w * 0.7, -h + tip)
    ..quadraticBezierTo(w, -h + tip, w, -h + tip + r)
    ..lineTo(w, h - tip - r)
    ..quadraticBezierTo(w, h - tip, w * 0.7, h - tip)
    ..quadraticBezierTo(w * 0.25, h - tip * 0.9, 0, h)
    ..quadraticBezierTo(-w * 0.25, h - tip * 0.9, -w * 0.7, h - tip)
    ..quadraticBezierTo(-w, h - tip, -w, h - tip - r)
    ..lineTo(-w, -h + tip + r)
    ..quadraticBezierTo(-w, -h + tip, -w * 0.7, -h + tip)
    ..quadraticBezierTo(-w * 0.25, -h + tip * 0.9, 0, -h)
    ..close();

  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.drawPath(
    plate,
    Paint()
      ..color = Color.alphaBlend(mt.gold.withValues(alpha: 0.16), mt.paper),
  );
  canvas.drawPath(
    plate,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = mt.gold,
  );
  var y = -textHeight / 2;
  for (final tp in painters) {
    final s = scaleOf(tp);
    canvas.save();
    canvas.translate(-tp.width * s / 2, y);
    canvas.scale(s);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    y += tp.height * s;
    tp.dispose();
  }
  canvas.restore();
}
