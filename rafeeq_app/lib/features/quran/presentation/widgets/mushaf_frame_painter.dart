import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/mushaf_frame.dart';

/// Draws one of the [MushafFrameStyle] borders around the mushaf page.
///
/// All ten are geometry, not images. Each is built from the same three
/// primitives — a rule along the four edges, a motif repeated at a fixed step
/// along the band, and something at each corner — so they read as one family
/// rather than ten unrelated decorations, which is the «تناسق» the owner asked
/// for.
///
/// The band is inset from the page edge and the page content is inset from the
/// band (see [MushafFrame.inset]), so no ornament ever sits under the text.
class MushafFramePainter extends CustomPainter {
  final MushafFrameStyle style;
  final Color color;

  /// Thickness of the decorated band.
  final double band;

  const MushafFramePainter({
    required this.style,
    required this.color,
    this.band = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == MushafFrameStyle.none) return;
    if (size.width < 40 || size.height < 40) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color
      ..isAntiAlias = true;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    // The rectangle the band is drawn on, inset so the outer rule is not
    // clipped by the page edge.
    final outer = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final inner = outer.deflate(band);

    switch (style) {
      case MushafFrameStyle.none:
        return;

      case MushafFrameStyle.doubleRule:
        _rrect(canvas, outer, stroke..strokeWidth = 1.6, 10);
        _rrect(canvas, outer.deflate(5), stroke..strokeWidth = 0.9, 8);
        for (final c in _cornerPoints(outer.deflate(2.5))) {
          _rosette(canvas, c, 7, fill, stroke);
        }

      case MushafFrameStyle.khatim:
        _rrect(canvas, outer, stroke..strokeWidth = 1.1, 8);
        _rrect(canvas, inner, stroke, 6);
        _alongBand(outer, inner, 26, (centre) {
          canvas.drawPath(_star(centre, band * 0.34, 8), stroke);
        });

      case MushafFrameStyle.arabesque:
        _rrect(canvas, outer, stroke..strokeWidth = 1.3, 10);
        _rrect(canvas, inner, stroke..strokeWidth = 0.9, 8);
        _wave(canvas, outer, inner, stroke..strokeWidth = 1.1);

      case MushafFrameStyle.geometric:
        _rrect(canvas, outer, stroke..strokeWidth = 1.2, 4);
        _rrect(canvas, inner, stroke, 3);
        _alongBand(outer, inner, 24, (centre) {
          canvas.drawPath(_polygon(centre, band * 0.36, 6), stroke);
        });

      case MushafFrameStyle.zellij:
        _rrect(canvas, outer, stroke..strokeWidth = 1.2, 4);
        _rrect(canvas, inner, stroke, 3);
        var alternate = false;
        _alongBand(outer, inner, 20, (centre) {
          alternate = !alternate;
          final p = _polygon(centre, band * 0.32, 4, rotation: math.pi / 4);
          canvas.drawPath(p, alternate ? fill : stroke);
        });

      case MushafFrameStyle.chain:
        _rrect(canvas, outer, stroke..strokeWidth = 1.1, 10);
        _rrect(canvas, inner, stroke..strokeWidth = 0.8, 8);
        var lift = false;
        _alongBand(outer, inner, 18, (centre) {
          lift = !lift;
          final r = band * 0.30;
          canvas.drawOval(
            Rect.fromCenter(
              center: centre.translate(0, lift ? -1.5 : 1.5),
              width: r * 2.4,
              height: r * 1.6,
            ),
            stroke,
          );
        });

      case MushafFrameStyle.muqarnas:
        _rrect(canvas, outer, stroke..strokeWidth = 1.2, 6);
        for (final (c, sx, sy) in _cornerSigns(outer.deflate(3))) {
          _steps(canvas, c, sx, sy, band, stroke);
        }

      case MushafFrameStyle.cornerFloret:
        // No band at all — the lightest framing, for readers who want the
        // page to breathe.
        for (final (c, sx, sy) in _cornerSigns(outer.deflate(4))) {
          _floret(canvas, c, sx, sy, band * 1.25, stroke, fill);
        }

      case MushafFrameStyle.mihrab:
        _rrect(canvas, outer, stroke..strokeWidth = 1.3, 8);
        _rrect(canvas, outer.deflate(4), stroke..strokeWidth = 0.8, 7);
        _arch(canvas, outer, band, stroke..strokeWidth = 1.4);
    }
  }

  // ── primitives ─────────────────────────────────────────────────────────

  void _rrect(Canvas c, Rect r, Paint p, double radius) {
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
  }

  /// Calls [draw] at points stepped evenly around the band between [outer] and
  /// [inner], with the step adjusted per edge so the motifs land symmetrically
  /// instead of leaving a ragged gap at one corner.
  void _alongBand(
    Rect outer,
    Rect inner,
    double step,
    void Function(Offset centre) draw,
  ) {
    final midBand = (outer.left + inner.left) / 2 - outer.left;
    final top = outer.top + midBand;
    final bottom = outer.bottom - midBand;
    final left = outer.left + midBand;
    final right = outer.right - midBand;

    void run(double from, double to, Offset Function(double) at) {
      final span = to - from;
      if (span <= 0) return;
      final n = math.max(1, (span / step).round());
      final s = span / n;
      for (var i = 0; i <= n; i++) {
        draw(at(from + s * i));
      }
    }

    run(left, right, (x) => Offset(x, top));
    run(left, right, (x) => Offset(x, bottom));
    run(top, bottom, (y) => Offset(left, y));
    run(top, bottom, (y) => Offset(right, y));
  }

  Path _star(Offset centre, double radius, int points) {
    final inner = radius * 0.5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final a = (math.pi / points) * i - math.pi / 2;
      final p = Offset(centre.dx + r * math.cos(a), centre.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _polygon(Offset centre, double radius, int sides,
      {double rotation = 0}) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = (2 * math.pi / sides) * i - math.pi / 2 + rotation;
      final p = Offset(
        centre.dx + radius * math.cos(a),
        centre.dy + radius * math.sin(a),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _rosette(Canvas c, Offset centre, double r, Paint fill, Paint stroke) {
    c.drawPath(_star(centre, r, 8), stroke);
    c.drawCircle(centre, r * 0.28, fill);
  }

  List<Offset> _cornerPoints(Rect r) =>
      [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];

  /// Corner points paired with the direction that points *into* the page, so
  /// one drawing routine serves all four corners.
  List<(Offset, double, double)> _cornerSigns(Rect r) => [
        (r.topLeft, 1, 1),
        (r.topRight, -1, 1),
        (r.bottomLeft, 1, -1),
        (r.bottomRight, -1, -1),
      ];

  void _steps(Canvas c, Offset o, double sx, double sy, double band, Paint p) {
    final unit = band * 0.42;
    final path = Path()..moveTo(o.dx, o.dy + sy * unit * 3);
    for (var i = 0; i < 3; i++) {
      path
        ..lineTo(o.dx + sx * unit * i, o.dy + sy * unit * (3 - i))
        ..lineTo(o.dx + sx * unit * (i + 1), o.dy + sy * unit * (3 - i));
    }
    path.lineTo(o.dx + sx * unit * 3, o.dy);
    c.drawPath(path, p);
  }

  void _floret(
    Canvas c,
    Offset o,
    double sx,
    double sy,
    double size,
    Paint stroke,
    Paint fill,
  ) {
    // A quarter-rosette tucked into the corner, plus two short rules running
    // away from it along each edge.
    final centre = Offset(o.dx + sx * size * 0.5, o.dy + sy * size * 0.5);
    c.drawPath(_star(centre, size * 0.46, 8), stroke);
    c.drawCircle(centre, size * 0.13, fill);
    c.drawLine(
      Offset(o.dx + sx * size * 1.05, o.dy),
      Offset(o.dx + sx * size * 2.6, o.dy),
      stroke,
    );
    c.drawLine(
      Offset(o.dx, o.dy + sy * size * 1.05),
      Offset(o.dx, o.dy + sy * size * 2.6),
      stroke,
    );
  }

  /// A sine running around the band — the arabesque's woven line.
  void _wave(Canvas c, Rect outer, Rect inner, Paint p) {
    final midBand = (inner.left - outer.left) / 2;
    final amp = midBand * 0.62;
    final path = Path();

    void edge(double from, double to, Offset Function(double t, double o) at) {
      final span = to - from;
      if (span <= 0) return;
      final steps = math.max(8, (span / 4).round());
      for (var i = 0; i <= steps; i++) {
        final t = from + span * i / steps;
        final off = math.sin(i / steps * span / 11) * amp;
        final pt = at(t, off);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
    }

    final top = outer.top + midBand;
    final bottom = outer.bottom - midBand;
    final left = outer.left + midBand;
    final right = outer.right - midBand;

    edge(left, right, (x, o) => Offset(x, top + o));
    edge(left, right, (x, o) => Offset(x, bottom + o));
    edge(top, bottom, (y, o) => Offset(left + o, y));
    edge(top, bottom, (y, o) => Offset(right + o, y));
    c.drawPath(path, p);
  }

  /// A pointed arch across the head of the page.
  void _arch(Canvas c, Rect outer, double band, Paint p) {
    final w = outer.width;
    final top = outer.top + band * 0.5;
    final springing = top + band * 1.4;
    final apex = top;
    final path = Path()
      ..moveTo(outer.left + band, springing)
      ..quadraticBezierTo(
        outer.left + w * 0.28,
        apex,
        outer.left + w * 0.5,
        apex - band * 0.35,
      )
      ..quadraticBezierTo(
        outer.left + w * 0.72,
        apex,
        outer.right - band,
        springing,
      );
    c.drawPath(path, p);
    c.drawCircle(
      Offset(outer.left + w * 0.5, apex - band * 0.75),
      band * 0.22,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant MushafFramePainter old) =>
      old.style != style || old.color != color || old.band != band;
}

/// Wraps the mushaf page in its border and insets the content clear of it.
class MushafFrame extends StatelessWidget {
  final MushafFrameStyle style;
  final Color color;
  final Widget child;

  const MushafFrame({
    super.key,
    required this.style,
    required this.color,
    required this.child,
  });

  /// How far the page's own content is pushed in, so no ornament sits under
  /// the text. Zero when there is no frame, so nothing changes for a reader
  /// who never turns one on.
  double get inset => switch (style) {
        MushafFrameStyle.none => 0,
        MushafFrameStyle.cornerFloret => 10,
        MushafFrameStyle.doubleRule => 12,
        MushafFrameStyle.mihrab => 16,
        _ => 22,
      };

  @override
  Widget build(BuildContext context) {
    if (style == MushafFrameStyle.none) return child;
    return Stack(
      children: [
        Padding(padding: EdgeInsets.all(inset), child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: MushafFramePainter(style: style, color: color),
            ),
          ),
        ),
      ],
    );
  }
}
