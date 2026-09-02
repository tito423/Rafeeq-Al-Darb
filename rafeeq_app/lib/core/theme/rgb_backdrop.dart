import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

/// Wraps the whole navigator when the RGB theme is active: a full-screen
/// animated Islamic-geometry backdrop behind every (transparent-scaffold)
/// screen. For the other three themes `RafeeqApp` does not insert this at all,
/// so it costs nothing there.
class RgbScaffoldBackground extends ConsumerWidget {
  const RgbScaffoldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motionOn = ref.watch(motionEffectsProvider);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _RgbBackdrop(animate: motionOn && !reduceMotion),
          ),
        ),
        child,
      ],
    );
  }
}

class _RgbBackdrop extends StatefulWidget {
  const _RgbBackdrop({required this.animate});
  final bool animate;

  @override
  State<_RgbBackdrop> createState() => _RgbBackdropState();
}

class _RgbBackdropState extends State<_RgbBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _RgbBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _RgbPainter(widget.animate ? _c.value : 0.32),
      ),
    );
  }
}

class _RgbPainter extends CustomPainter {
  _RgbPainter(this.t);

  /// 0..1 phase of the loop.
  final double t;

  static const _base = Color(0xFF05060B);
  static const _blobs = <Color>[
    Color(0xFF15C7B0), // electric teal
    Color(0xFF7C4DFF), // violet
    Color(0xFFD4AF37), // gold
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _base);

    final w = size.width, h = size.height;
    final tau = 2 * math.pi;

    // Three colour fields drifting on slow Lissajous paths.
    for (var i = 0; i < _blobs.length; i++) {
      final p = t * tau + i * (tau / 3);
      final cx = w * (0.5 + 0.32 * math.sin(p * (1 + i * 0.15)));
      final cy = h * (0.42 + 0.30 * math.cos(p * (0.8 + i * 0.2)));
      final radius = math.max(w, h) * 0.62;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _blobs[i].withValues(alpha: 0.28),
              _blobs[i].withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
      );
    }

    // A faint rub-el-hizb (8-point star) lattice, slowly counter-rotating.
    final star = _starPath(26);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.05);
    const step = 132.0;
    final angle = math.sin(t * tau) * 0.06;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(angle);
    canvas.translate(-w / 2, -h / 2);
    for (var y = -step; y < h + step; y += step) {
      for (var x = -step; x < w + step; x += step) {
        canvas.save();
        canvas.translate(x + step / 2, y + step / 2);
        canvas.drawPath(star, stroke);
        canvas.restore();
      }
    }
    canvas.restore();

    // Gentle top-down vignette so status-bar / app-bar text stays legible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000), Color(0x4D000000)],
          stops: [0.0, 0.35, 1.0],
        ).createShader(rect),
    );
  }

  /// One 8-point star = two overlapped squares, centred on the origin.
  static Path _starPath(double r) {
    final a = Path()
      ..addRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2));
    final b = Path()
      ..addRect(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2));
    final m = Matrix4.rotationZ(math.pi / 4).storage;
    return Path.combine(
      PathOperation.union,
      a,
      b.transform(m),
    );
  }

  @override
  bool shouldRepaint(covariant _RgbPainter old) => old.t != t;
}
