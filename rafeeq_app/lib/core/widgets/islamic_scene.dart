import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A calm Islamic scene painted behind a card: a sky gradient, a crescent or
/// a scatter of stars, and the silhouette of domes and minarets or a row of
/// arches. Painted, not photographed, so it is sharp at every size and turn of
/// the screen, costs no bytes, and has a pale form for the light theme and a
/// deep one for the dark themes (owner, 2026-09-29: «خلفيات إسلامية هادية
/// جميلة … تتغير كل ما أفتح التطبيق»).
///
/// [variant] picks one of [IslamicScene.count] scenes; the Home header draws
/// one number per launch of the app.
class IslamicScene extends CustomPainter {
  static const count = 5;

  final int variant;
  final bool dark;
  const IslamicScene({required this.variant, required this.dark});

  /// The palette of a scene: sky stops, and the tint of the silhouettes.
  ({List<Color> sky, Color shape, Color glow, Color star}) _palette() {
    switch (variant % count) {
      case 0: // dusk over a mosque
        return dark
            ? (
                sky: const [Color(0xFF0C1A38), Color(0xFF17395B), Color(0xFF6A5236)],
                shape: const Color(0xFF050B18),
                glow: const Color(0xFFE9B86A),
                star: const Color(0xFFFFF3D6),
              )
            : (
                sky: const [Color(0xFFF7EEDD), Color(0xFFF7E3C8), Color(0xFFF3D3AE)],
                shape: const Color(0xFF9A7B52),
                glow: const Color(0xFFFFE2A8),
                star: const Color(0xFFFFFFFF),
              );
      case 1: // dawn with minarets
        return dark
            ? (
                sky: const [Color(0xFF1B2247), Color(0xFF3B3566), Color(0xFF8A5F6E)],
                shape: const Color(0xFF0B0E22),
                glow: const Color(0xFFFFC9A0),
                star: const Color(0xFFE9E6FF),
              )
            : (
                sky: const [Color(0xFFEDEAF7), Color(0xFFF6E4EA), Color(0xFFFBE3D2)],
                shape: const Color(0xFF8E7A9A),
                glow: const Color(0xFFFFD9BE),
                star: const Color(0xFFFFFFFF),
              );
      case 2: // starry night, a large crescent
        return dark
            ? (
                sky: const [Color(0xFF060C1E), Color(0xFF0E1E3F), Color(0xFF16345A)],
                shape: const Color(0xFF040812),
                glow: const Color(0xFFDDE7FF),
                star: const Color(0xFFFFFFFF),
              )
            : (
                sky: const [Color(0xFFE6EEF7), Color(0xFFDCE8F3), Color(0xFFD3E3EF)],
                shape: const Color(0xFF6F8AA6),
                glow: const Color(0xFFFFFFFF),
                star: const Color(0xFFFFFFFF),
              );
      case 3: // green arches
        return dark
            ? (
                sky: const [Color(0xFF07231D), Color(0xFF0C3B31), Color(0xFF14574A)],
                shape: const Color(0xFF041611),
                glow: const Color(0xFF7BE0C4),
                star: const Color(0xFFE3FFF6),
              )
            : (
                sky: const [Color(0xFFEAF6F1), Color(0xFFDDF0E8), Color(0xFFCFE8DD)],
                shape: const Color(0xFF5E9483),
                glow: const Color(0xFFFFFFFF),
                star: const Color(0xFFFFFFFF),
              );
      default: // golden lattice
        return dark
            ? (
                sky: const [Color(0xFF2A1F0E), Color(0xFF3F2E14), Color(0xFF5A4220)],
                shape: const Color(0xFF130D04),
                glow: const Color(0xFFF0C56A),
                star: const Color(0xFFFFE9B0),
              )
            : (
                sky: const [Color(0xFFFBF3DF), Color(0xFFF6E8C6), Color(0xFFF0DCAE)],
                shape: const Color(0xFFB08A3E),
                glow: const Color(0xFFFFF1C2),
                star: const Color(0xFFFFFFFF),
              );
    }
  }

  /// The darkest sky stop - what ink drawn on the card is measured against.
  Color get ground => _palette().sky.last;

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _palette();
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pal.sky,
        ).createShader(rect),
    );

    final v = variant % count;
    final rnd = math.Random(variant * 7919 + 13);

    // Stars: many on the night scene, a few elsewhere, faint in the light theme.
    final stars = v == 2 ? 46 : (v == 1 || v == 0 ? 16 : 8);
    final starPaint = Paint();
    for (var i = 0; i < stars; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.62;
      final r = 0.5 + rnd.nextDouble() * 1.2;
      starPaint.color = pal.star.withValues(alpha: dark ? 0.35 + rnd.nextDouble() * 0.5 : 0.7);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // A soft glow: on the horizon at dusk/dawn, around the moon at night.
    final glowCentre = switch (v) {
      0 => Offset(size.width * 0.5, size.height * 1.02),
      1 => Offset(size.width * 0.22, size.height * 1.0),
      2 => Offset(size.width * 0.8, size.height * 0.3),
      3 => Offset(size.width * 0.5, size.height * 0.15),
      _ => Offset(size.width * 0.5, size.height * 0.4),
    };
    final glowR = size.width * (v == 2 ? 0.34 : 0.5);
    canvas.drawCircle(
      glowCentre,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          pal.glow.withValues(alpha: dark ? 0.3 : 0.55),
          pal.glow.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: glowCentre, radius: glowR)),
    );

    // The crescent.
    if (v == 0 || v == 1 || v == 2) {
      // Top centre: the header's two dates sit at the sides and the weekday
      // just below, so the crescent has this corner to itself.
      final r = size.height * (v == 2 ? 0.1 : 0.085);
      final c = Offset(size.width * 0.5, size.height * 0.15);
      _crescent(canvas, c, r,
          dark ? const Color(0xFFFFF3D6) : const Color(0xFFFFFFFF),
          dark ? 0.9 : 0.85);
    }

    // The silhouettes.
    final shape = Paint()..color = pal.shape.withValues(alpha: dark ? 0.85 : 0.2);
    switch (v) {
      case 0:
        _skyline(canvas, size, shape, minarets: false);
      case 1:
        _skyline(canvas, size, shape, minarets: true);
      case 3:
        _arches(canvas, size, shape);
      case 4:
        _lattice(canvas, size,
            (dark ? pal.glow : pal.shape).withValues(alpha: dark ? 0.09 : 0.12));
      default:
        break;
    }
  }

  void _crescent(Canvas c, Offset centre, double r, Color color, double alpha) {
    final outer = Path()..addOval(Rect.fromCircle(center: centre, radius: r));
    final cut = Path()
      ..addOval(Rect.fromCircle(
          center: centre.translate(r * 0.42, -r * 0.18), radius: r * 0.86));
    c.drawPath(
      Path.combine(PathOperation.difference, outer, cut),
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  /// Domes and minarets along the bottom edge.
  void _skyline(Canvas c, Size s, Paint p, {required bool minarets}) {
    final base = s.height;
    final w = s.width;
    final h = s.height;
    final path = Path()..addRect(Rect.fromLTWH(0, base - h * 0.1, w, h * 0.1));
    void dome(double cx, double r) {
      final y = base - h * 0.1;
      path
        ..moveTo(cx - r, y)
        ..cubicTo(cx - r, y - r * 1.5, cx + r, y - r * 1.5, cx + r, y)
        ..close()
        ..addRect(Rect.fromLTWH(cx - r * 0.06, y - r * 1.25 - r * 0.35, r * 0.12, r * 0.4));
    }

    void minaret(double cx, double mw, double mh) {
      final y = base - h * 0.1;
      path
        ..addRect(Rect.fromLTWH(cx - mw / 2, y - mh, mw, mh))
        ..addRect(Rect.fromLTWH(cx - mw * 0.8, y - mh * 0.78, mw * 1.6, mw * 0.32))
        ..moveTo(cx - mw * 0.75, y - mh)
        ..lineTo(cx, y - mh - mw * 2.6)
        ..lineTo(cx + mw * 0.75, y - mh)
        ..close();
    }

    if (minarets) {
      dome(w * 0.5, h * 0.2);
      dome(w * 0.34, h * 0.11);
      dome(w * 0.66, h * 0.11);
      minaret(w * 0.14, h * 0.05, h * 0.5);
      minaret(w * 0.86, h * 0.05, h * 0.5);
      minaret(w * 0.24, h * 0.035, h * 0.32);
      minaret(w * 0.76, h * 0.035, h * 0.32);
    } else {
      dome(w * 0.5, h * 0.24);
      dome(w * 0.3, h * 0.13);
      dome(w * 0.7, h * 0.13);
      dome(w * 0.12, h * 0.08);
      dome(w * 0.88, h * 0.08);
      minaret(w * 0.4, h * 0.03, h * 0.36);
      minaret(w * 0.6, h * 0.03, h * 0.36);
      minaret(w * 0.05, h * 0.028, h * 0.28);
      minaret(w * 0.95, h * 0.028, h * 0.28);
    }
    c.drawPath(path, p);
  }

  /// A row of pointed arches, the way a cloister is drawn.
  void _arches(Canvas c, Size s, Paint p) {
    final n = math.max(4, (s.width / (s.height * 0.62)).round());
    final aw = s.width / n;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = i * aw;
      final top = s.height * 0.36;
      path
        ..moveTo(x + aw * 0.06, s.height)
        ..lineTo(x + aw * 0.06, top + aw * 0.4)
        ..quadraticBezierTo(x + aw * 0.06, top + aw * 0.1, x + aw * 0.5, top - aw * 0.1)
        ..quadraticBezierTo(x + aw * 0.94, top + aw * 0.1, x + aw * 0.94, top + aw * 0.4)
        ..lineTo(x + aw * 0.94, s.height)
        ..close();
    }
    // Only the piers are drawn: the arches are the gaps between them.
    final apex = s.height * 0.36 - aw * 0.11;
    final full = Path()..addRect(Rect.fromLTWH(0, apex, s.width, s.height - apex));
    c.drawPath(Path.combine(PathOperation.difference, full, path), p);
  }

  /// The eight-pointed khatim star, tiled.
  void _lattice(Canvas c, Size s, Color color) {
    final t = s.height * 0.36;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var y = -t / 2; y < s.height + t; y += t) {
      for (var x = -t / 2; x < s.width + t; x += t) {
        final o = Offset(x + t / 2, y + t / 2);
        final path = Path();
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8;
          final r = i.isEven ? t * 0.46 : t * 0.26;
          final pt = o + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        c.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(IslamicScene old) =>
      old.variant != variant || old.dark != dark;
}
