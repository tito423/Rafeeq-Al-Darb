import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The calm ground for a Home card whose text must stand on nothing
/// (owner, 2026-09-29: «خلفية خفيفة جميلة هادية … متحطش اي حاجة تشوشر على
/// النص»):
///
/// * a soft diagonal wash of the card's accent over the theme's own ground -
///   a colour, no detail;
/// * one large eight-pointed star drawn in hair-thin lines in the card's
///   bottom-end corner, fading out toward the text;
/// * a row of small eight-pointed stars along the top edge, above the title.
///
/// The hadith card had a faint star-panel PHOTOGRAPH under its text first;
/// the contrast measured fine, but on his phone the owner rejected it
/// («سيئة جدا … منغمشة هتغبش على المحتوى»). The sunnah and quote cards keep
/// their ornament scans (`OrnamentBackdrop`) - he approved those. Worst case
/// of wash + star line + a 10 % tinted ground, secondary text: dark 5.51,
/// RGB 6.53, light 5.08 : 1 (computed 2026-09-29).
class CalmCardGround extends StatelessWidget {
  /// The card's accent: the wash, the corner star and the band.
  final Color color;

  /// Space kept free at both ends of the band (a frame's corner ornaments).
  final double inset;
  final Widget child;

  static const bandHeight = 14.0;

  const CalmCardGround({
    super.key,
    required this.color,
    this.inset = 14,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CalmGround(
                color: color,
                wash: dark ? 0.08 : 0.06,
                line: dark ? 0.10 : 0.12,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: bandHeight - 4),
          child: child,
        ),
        Positioned(
          top: 6,
          left: inset,
          right: inset,
          height: bandHeight,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _StarBand(color.withValues(alpha: 0.55)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two squares, one turned 45 degrees: the eight-pointed star.
Path _khatam(Offset c, double r) {
  final p = Path();
  for (final turn in const [0.0, math.pi / 4]) {
    for (var k = 0; k < 4; k++) {
      final a = turn + k * math.pi / 2 + math.pi / 4;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (k == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
  }
  return p;
}

/// The wash and the corner star.
class _CalmGround extends CustomPainter {
  final Color color;
  final double wash;
  final double line;
  final bool rtl;
  _CalmGround({
    required this.color,
    required this.wash,
    required this.line,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The wash: strongest at the top-start corner, gone by the far side.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.topRight : Alignment.topLeft,
          end: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
          colors: [
            color.withValues(alpha: wash),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    // The corner star at the bottom-END corner (where lines of text end
    // short), mostly outside the card, fading to nothing toward its centre.
    final r = math.min(size.height * 0.62, 120.0);
    final c = Offset(
      rtl ? r * 0.35 : size.width - r * 0.35,
      size.height - r * 0.2,
    );
    canvas.saveLayer(rect, Paint());
    final stroke = Paint()
      ..color = color.withValues(alpha: line)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(_khatam(c, r), stroke);
    canvas.drawPath(_khatam(c, r * 0.72), stroke);
    canvas.drawCircle(c, r * 0.42, stroke);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          center: Alignment(
            (c.dx / size.width) * 2 - 1,
            (c.dy / size.height) * 2 - 1,
          ),
          radius: r / size.shortestSide,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CalmGround old) =>
      old.color != color ||
      old.wash != wash ||
      old.line != line ||
      old.rtl != rtl;
}

/// Eight-pointed stars on a fine rule, fading out toward both ends.
class _StarBand extends CustomPainter {
  final Color color;
  _StarBand(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.height * 0.42;
    const gap = 30.0;
    final count = math.max(1, (size.width / gap).floor());
    final start = (size.width - (count - 1) * gap) / 2;
    canvas.saveLayer(Offset.zero & size, Paint());
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < count; i++) {
      final c = Offset(start + i * gap, cy);
      canvas.drawPath(_khatam(c, r), line);
      if (i < count - 1) {
        // The rule between two stars, with a small diamond in the middle.
        final a = c.dx + r + 3;
        final b = c.dx + gap - r - 3;
        final m = (a + b) / 2;
        canvas.drawLine(Offset(a, cy), Offset(m - 3.5, cy), line);
        canvas.drawLine(Offset(m + 3.5, cy), Offset(b, cy), line);
        canvas.drawPath(
          Path()
            ..moveTo(m - 3.5, cy)
            ..lineTo(m, cy - 3)
            ..lineTo(m + 3.5, cy)
            ..lineTo(m, cy + 3)
            ..close(),
          line,
        );
      }
    }
    // Colour and the fade at both ends, in one pass over what was drawn.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color,
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.22, 0.78, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StarBand old) => old.color != color;
}
