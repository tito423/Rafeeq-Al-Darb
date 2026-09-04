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

/// P3‑3: restyled toward `design_refs/ref_tasbeeh.jpg`'s own look — the
/// owner's exact words were "خلي ثيم التطبيق rgb قريب للثيم اللي انت شايف
/// في صورة المسبحة" (make the RGB theme close to the tasbeeh reference's
/// theme). That reference is near-black, dominated by one soft emerald/teal
/// **glow ring** around the tasbeeh counter (not a filled wash), with a
/// handful of small static star-dots — calmer and darker than this used to
/// be. Kept the same `CustomPainter`/slow-`AnimationController` seam (per
/// `HANDOVER.md` §5.6) but replaced the three large filled radial-gradient
/// blobs with a few soft **ring** strokes (echoing the reference's actual
/// glow-ring motif, not a solid disc), teal-weighted rather than an equal
/// three-way rotation, and replaced the tiled rub-el-hizb star grid — which
/// read as much busier than the reference's few scattered dots — with a
/// small fixed set of twinkling star-dots.
class _RgbPainter extends CustomPainter {
  _RgbPainter(this.t);

  /// 0..1 phase of the loop.
  final double t;

  static const _base = Color(0xFF05060B);
  static const _teal = Color(0xFF15C7B0);
  static const _violet = Color(0xFF7C4DFF);
  static const _gold = Color(0xFFD4AF37);

  /// Teal-weighted so the dominant colour reads as the reference's emerald
  /// glow, with violet/gold only as occasional accents.
  static const _ringColors = [_teal, _teal, _violet, _gold];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _base);

    final w = size.width, h = size.height;
    final tau = 2 * math.pi;

    // A few soft glow RINGS drifting on slow, gentle paths — much slower
    // and much fainter than the old filled blobs, so this reads as a calm
    // ambient accent rather than a full-screen aurora wash.
    for (var i = 0; i < 3; i++) {
      final p = t * tau * 0.4 + i * (tau / 3);
      final cx = w * (0.5 + 0.30 * math.sin(p * (0.6 + i * 0.1)));
      final cy = h * (0.35 + 0.22 * math.cos(p * (0.5 + i * 0.15)));
      final radius = math.min(w, h) * (0.20 + i * 0.06);
      final color = _ringColors[i % _ringColors.length];
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26)
          ..color = color.withValues(alpha: 0.11),
      );
    }

    // A small, fixed set of twinkling star-dots — a seeded `Random` so the
    // positions never jitter frame to frame, only their alpha does.
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final dx = rnd.nextDouble() * w;
      final dy = rnd.nextDouble() * h;
      final twinkle = (0.4 + 0.4 * math.sin(t * tau + i)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(dx, dy),
        1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.28 * twinkle),
      );
    }

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

  @override
  bool shouldRepaint(covariant _RgbPainter old) => old.t != t;
}
