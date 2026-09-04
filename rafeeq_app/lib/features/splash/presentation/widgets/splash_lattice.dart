import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The radial girih-style star lattice behind the splash badge — thin,
/// low-alpha gold/white lines radiating from and circling the centre,
/// slowly rotating. Same *technique* `RgbScaffoldBackground`'s
/// `_RgbPainter` already uses for its own lattice (a tiled low-alpha
/// `CustomPainter` stroke pattern, slowly counter-rotating) rather than a
/// second, unrelated implementation — the shape here is a single radial
/// rosette (concentric rings + straight radiating chords) instead of a
/// tiled grid of stars, matching the reference video's splash frame
/// (`design_refs/old_app_frames/frame_01.png`) rather than the RGB theme's
/// own backdrop.
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
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxRadius = size.shortestSide * 0.62;
    final tau = 2 * math.pi;
    final angle = t * tau * 0.05; // one very slow full turn per ~20 loops

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: 0.16);

    // Concentric rings.
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset.zero, maxRadius * i / 3, line);
    }

    // Radiating chords: a classic girih rosette is straight lines joining
    // points evenly spaced on a circle, several steps apart (not just
    // spokes to the centre) — this is what gives the reference image its
    // criss-crossing star pattern instead of a plain sunburst.
    const points = 16;
    const step = 5; // connect every 5th point around the circle
    final pts = <Offset>[
      for (var i = 0; i < points; i++)
        Offset.fromDirection(i * tau / points, maxRadius),
    ];
    for (var i = 0; i < points; i++) {
      canvas.drawLine(pts[i], pts[(i + step) % points], line);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LatticePainter old) => old.t != t;
}
