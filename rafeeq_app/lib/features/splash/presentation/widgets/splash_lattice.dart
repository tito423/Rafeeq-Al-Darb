import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The splash backdrop — inspired by, not copied from, the reference video's
/// own splash frame (`design_refs/old_app_frames/frame_01.png`): a girih-
/// style radial lattice, low-alpha gold/white lines slowly rotating. Same
/// *technique* `RgbScaffoldBackground`'s `_RgbPainter` uses for its own
/// lattice (a tiled low-alpha `CustomPainter` stroke pattern, slowly
/// counter-rotating), applied here as a single radial rosette instead of a
/// tiled grid.
///
/// Taken further than the reference on purpose — the video's own frame is
/// one flat static rosette; this adds three things of its own so the result
/// reads as *this app's* splash rather than a re-skin: a second, smaller
/// rosette layer counter-rotating against the first (a girih mandala is
/// traditionally built from overlapping polygons, not a single ring), a
/// large, very soft echo of **our own icon's crescent silhouette** in the
/// backdrop (the same two-arc construction `icon_full.svg` uses, just
/// enormous and blurred into the night-sky field), and a handful of
/// twinkling stars.
class SplashLattice extends StatelessWidget {
  const SplashLattice({super.key, required this.animation});

  /// 0..1, looping. Pass a fixed value (e.g. 0) for reduced-motion.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _LatticePainter(animation.value),
      ),
    );
  }
}

class _LatticePainter extends CustomPainter {
  _LatticePainter(this.t);

  /// 0..1 phase of the loop.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tau = 2 * math.pi;
    final center = Offset(w / 2, h * 0.38);
    final maxRadius = size.shortestSide * 0.62;

    _paintCrescentEcho(canvas, size);
    _paintStars(canvas, size);
    _paintRosette(canvas, center, maxRadius,
        angle: t * tau * 0.05, points: 16, step: 5, alpha: 0.16);
    _paintRosette(canvas, center, maxRadius * 0.68,
        angle: -t * tau * 0.08, points: 12, step: 5, alpha: 0.11);
  }

  /// A huge, soft echo of the app icon's own crescent silhouette (the exact
  /// two-arc construction `icon_full.svg` uses — an outer disc with an
  /// inner disc offset toward the opening, painted with the inner disc as
  /// `BlendMode.dstOut` rather than combined paths, since this only needs a
  /// one-off soft-edged cutout, not a crisp vector outline), tucked into a
  /// back corner at very low opacity so it reads as ambient night-sky glow
  /// rather than a second logo competing with the real badge.
  void _paintCrescentEcho(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.62;
    final c = Offset(size.width * 0.82, size.height * 0.16);
    canvas.saveLayer(Rect.largest, Paint());
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.gold.withValues(alpha: 0.16),
          AppColors.gold.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(c, r, glow);
    final cutout = Paint()
      ..blendMode = BlendMode.dstOut
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(c.translate(-r * 0.55, r * 0.12), r * 0.92, cutout);
    canvas.restore();
  }

  void _paintStars(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final tau = 2 * math.pi;
    for (var i = 0; i < 22; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height * 0.75;
      final twinkle = (0.4 + 0.4 * math.sin(t * tau * 2 + i)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(dx, dy),
        1.3,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * twinkle),
      );
    }
  }

  void _paintRosette(
    Canvas canvas,
    Offset center,
    double radius, {
    required double angle,
    required int points,
    required int step,
    required double alpha,
  }) {
    final tau = 2 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: alpha);

    // Concentric rings.
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset.zero, radius * i / 3, line);
    }

    // Radiating chords: a classic girih rosette is straight lines joining
    // points evenly spaced on a circle, several steps apart (not just
    // spokes to the centre) — this is what gives the reference image its
    // criss-crossing star pattern instead of a plain sunburst.
    final pts = <Offset>[
      for (var i = 0; i < points; i++)
        Offset.fromDirection(i * tau / points, radius),
    ];
    for (var i = 0; i < points; i++) {
      canvas.drawLine(pts[i], pts[(i + step) % points], line);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LatticePainter old) => old.t != t;
}
