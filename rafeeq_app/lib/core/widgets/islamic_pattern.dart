import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A tiling eight-point star (khātim) lattice, painted rather than fetched.
///
/// The obvious alternative was a decorative photo pulled from the web with
/// `CachedNetworkImage`. This is deliberately not that: the app is
/// offline-first, and a screen whose background only appears once the network
/// answers is a screen that looks broken on a plane or in a masjid basement.
/// A painted pattern costs no bytes, renders identically the first time and
/// every time, takes the theme's own gold rather than whatever palette a stock
/// photo happened to have, and scales to any screen without a blurry upscale.
class IslamicPatternPainter extends CustomPainter {
  /// Distance between star centres, in logical pixels.
  final double tile;
  final Color color;
  final double strokeWidth;

  const IslamicPatternPainter({
    this.tile = 64,
    this.color = AppColors.gold,
    this.strokeWidth = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true;

    final radius = tile * 0.42;
    // Start one tile off-canvas on each axis so the lattice bleeds past the
    // edges instead of showing a cut first row.
    for (var y = -tile; y < size.height + tile; y += tile) {
      for (var x = -tile; x < size.width + tile; x += tile) {
        final centre = Offset(x + tile / 2, y + tile / 2);
        canvas.drawPath(_star(centre, radius), paint);
        // A square rotated 45° through the star's inner vertices — the
        // interlace that turns isolated stars into a real lattice.
        canvas.drawPath(_diamond(centre, radius * 0.52), paint);
      }
    }
  }

  Path _star(Offset centre, double radius) {
    const points = 8;
    final inner = radius * 0.52;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : inner;
      final angle = (math.pi / points) * i - math.pi / 2;
      final p = Offset(
        centre.dx + r * math.cos(angle),
        centre.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  Path _diamond(Offset centre, double radius) => Path()
    ..moveTo(centre.dx, centre.dy - radius)
    ..lineTo(centre.dx + radius, centre.dy)
    ..lineTo(centre.dx, centre.dy + radius)
    ..lineTo(centre.dx - radius, centre.dy)
    ..close();

  @override
  bool shouldRepaint(covariant IslamicPatternPainter old) =>
      old.tile != tile || old.color != color || old.strokeWidth != strokeWidth;
}

/// A rounded panel with the lattice above a theme gradient — the header
/// treatment used across the Downloads hub.
class IslamicPatternPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the default navy→teal gradient (used for the "everything is
  /// downloaded" state, which goes gold).
  final List<Color>? colors;

  const IslamicPatternPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16),
    this.radius = 22,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // THEME-AWARE, because it was not. The gradient was a fixed navy->teal
    // and the text on it a fixed light grey, whatever theme the reader had
    // chosen — so on the light themes the Downloads storage card sat there
    // as a dark green slab with nothing around it that colour. That is the
    // owner's «خلي كارت التنزيلات اللي بلون مختلف للون الثيم بلون متناسق مع
    // لون الثيم المختار». The panel now takes its two stops and its border
    // from the live ColorScheme, so it belongs to whichever theme is on.
    final scheme = Theme.of(context).colorScheme;
    final gradient = colors ??
        [
          Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.22),
            scheme.surfaceContainerHighest,
          ),
          scheme.surfaceContainerHigh,
        ];
    final accent = Color.alphaBlend(
      AppColors.gold.withValues(alpha: 0.55),
      scheme.onSurface,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicPatternPainter(
                  tile: 54,
                  color: accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// The progress bar used everywhere in the Downloads hub: rounded, thick
/// enough to read at a glance, with a gold track on a dim rail.
class GoldProgressBar extends StatelessWidget {
  /// Null renders the indeterminate sweep (size not yet known).
  final double? value;
  final double height;
  final Color? color;

  const GoldProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: AppColors.nightBorder.withValues(alpha: 0.55),
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.gold),
      ),
    );
  }
}
