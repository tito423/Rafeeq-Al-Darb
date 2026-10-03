import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The quiz's ground: a deep night gradient with a lattice of eight-pointed
/// stars that drifts and twinkles, slow enough never to pull the eye from a
/// question.
class QuizStarfield extends StatefulWidget {
  final Widget child;
  const QuizStarfield({super.key, required this.child});

  @override
  State<QuizStarfield> createState() => _QuizStarfieldState();
}

class _QuizStarfieldState extends State<QuizStarfield>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2A3F), Color(0xFF0E3B3A), Color(0xFF071625)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) =>
                      CustomPaint(painter: _LatticePainter(_c.value)),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Two squares, one turned 45 degrees: the eight-pointed star (khatam).
Path khatamPath(Offset c, double r, [double turn = 0]) {
  final p = Path();
  for (final base in const [0.0, math.pi / 4]) {
    for (var k = 0; k < 4; k++) {
      final a = turn + base + k * math.pi / 2 + math.pi / 4;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
  }
  return p;
}

class _LatticePainter extends CustomPainter {
  final double t;
  _LatticePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const step = 92.0;
    final drift = t * step;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cols = (size.width / step).ceil() + 2;
    final rows = (size.height / step).ceil() + 2;
    for (var i = -1; i < cols; i++) {
      for (var j = -1; j < rows; j++) {
        final c = Offset(
          i * step + (j.isOdd ? step / 2 : 0),
          j * step + drift - step,
        );
        // Each star breathes on its own phase.
        final phase = (i * 0.37 + j * 0.61 + t * 6) % 1.0;
        final glow = 0.05 + 0.07 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
        line.color = AppColors.goldSoft.withValues(alpha: glow);
        canvas.drawPath(khatamPath(c, 18), line);
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.t != t;
}

/// A burst of little gold and green stars from [origin], played once each
/// time [trigger] changes.
class StarBurst extends StatefulWidget {
  final int trigger;
  final Widget child;
  const StarBurst({super.key, required this.trigger, required this.child});

  @override
  State<StarBurst> createState() => _StarBurstState();
}

class _StarBurstState extends State<StarBurst>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _rnd = math.Random();
  List<_Bit> _bits = const [];

  @override
  void didUpdateWidget(StarBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _bits = [
        for (var i = 0; i < 46; i++)
          _Bit(
            angle: -math.pi / 2 + (_rnd.nextDouble() - 0.5) * math.pi * 1.5,
            speed: 260 + _rnd.nextDouble() * 360,
            size: 4 + _rnd.nextDouble() * 6,
            spin: (_rnd.nextDouble() - 0.5) * 8,
            color: const [
              AppColors.gold,
              AppColors.goldSoft,
              AppColors.primarySoft,
              Colors.white,
            ][i % 4],
          ),
      ];
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => _c.isAnimating
                  ? CustomPaint(painter: _BurstPainter(_bits, _c.value))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bit {
  final double angle, speed, size, spin;
  final Color color;
  const _Bit({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Bit> bits;
  final double t;
  _BurstPainter(this.bits, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final secs = t * 1.4;
    final fill = Paint();
    for (final b in bits) {
      final v = Offset(math.cos(b.angle), math.sin(b.angle)) * b.speed;
      final pos = origin + v * secs + Offset(0, 420 * secs * secs);
      fill.color = b.color.withValues(alpha: (1 - t).clamp(0, 1));
      canvas.drawPath(khatamPath(pos, b.size, b.spin * secs), fill);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => true;
}

/// Shakes its child sideways once each time [trigger] changes.
class Shake extends StatelessWidget {
  final int trigger;
  final Widget child;
  const Shake({super.key, required this.trigger, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: trigger == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 480),
      builder: (_, v, child) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 6) * 10 * (1 - v), 0),
        child: child,
      ),
      child: child,
    );
  }
}
