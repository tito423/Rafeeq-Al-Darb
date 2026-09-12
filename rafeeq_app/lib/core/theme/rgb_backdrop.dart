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

/// «غيّر فيها تأثير الـRGB لإسلامي في التطبيق كله».
///
/// WHAT THIS USED TO BE, AND WHY IT CHANGED.
/// The backdrop was an *aurora*: three coloured glow rings drifting on
/// sine paths, a teal→violet→gold band sweeping the upper third, and forty
/// coloured motes rising through it. It was pretty, and it was the visual
/// language of a gaming RGB strip — nothing in it said which app it belonged
/// to. The owner asked for that replaced by something Islamic, everywhere the
/// theme is on.
///
/// So the aurora is gone and what is left is the app's own geometry, drawn
/// the way a tiled wall is drawn:
///
///   1. a **girih lattice** — the eight-point khātim tessellated across the
///      whole screen with the interlacing diamond that joins the stars into
///      a wall rather than a field of separate ornaments. It drifts by less
///      than one tile over the loop, so it reads as depth, not motion.
///   2. one large **rub el hizb** medallion turning very slowly behind the
///      content, the same mark the app uses for a juz division.
///   3. a **lamp sweep** — a single warm pass of light travelling across the
///      lattice, which is what makes a still pattern feel lit rather than
///      printed.
///
/// Everything is gold on deep navy, the app's own two colours, at alphas
/// between 0.03 and 0.10: this sits *behind* every screen in the app, so it
/// has to be legible-under rather than beautiful-alone. No blur mask filters
/// any more either — the old ring glows needed three full-screen blur passes
/// per frame, and the lattice needs none.
class _RgbPainter extends CustomPainter {
  _RgbPainter(this.t);

  /// 0..1 phase of the loop.
  final double t;

  /// The app's night navy, a shade deeper than `AppColors.night` so the
  /// scaffolds sitting on it still read as raised.
  static const _base = Color(0xFF04101C);
  static const _deep = Color(0xFF071A2B);
  static const _gold = Color(0xFFD4AF37);

  /// Tile size of the lattice, in logical pixels.
  static const _tile = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    final tau = 2 * math.pi;

    // The ground: a vertical fall from navy to a deeper navy, so the screen
    // has a horizon rather than one flat colour.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_deep, _base],
        ).createShader(rect),
    );

    // 1. The girih lattice. One Path, stroked once — a stroke per star would
    // be several hundred draw calls on a tall screen — and the Path itself is
    // built once per size and then only *translated*, because its shape never
    // changes. This backdrop repaints on every frame for the whole life of
    // the app while the theme is on, so re-tessellating ~320 sixteen-point
    // stars sixty times a second is work worth not doing.
    final drift = Offset(
      math.sin(t * tau) * _tile * 0.35,
      math.cos(t * tau) * _tile * 0.35,
    );
    canvas.save();
    canvas.translate(drift.dx, drift.dy);
    canvas.drawPath(
      _latticeFor(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = true
        ..color = _gold.withValues(alpha: 0.055),
    );
    canvas.restore();

    // 2. The rub el hizb, low and centred, turning once every four loops.
    final medallion = Offset(w * 0.5, h * 0.6);
    final mr = math.min(w, h) * 0.44;
    canvas.save();
    canvas.translate(medallion.dx, medallion.dy);
    canvas.rotate(t * tau * 0.25);
    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = _gold.withValues(alpha: 0.10);
    for (var k = 0; k < 2; k++) {
      canvas.save();
      canvas.rotate(k * math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: mr, height: mr),
        markPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, mr * 0.38, markPaint);
    canvas.drawCircle(Offset.zero, mr * 0.70, markPaint);
    canvas.restore();

    // 3. The lamp sweep: a soft diagonal band of gold that crosses the screen
    // once per loop, brightening the lattice as it passes. A gradient fill,
    // not a blur — same look, no second render pass.
    final sweepCentre = -0.35 + 1.7 * t;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _gold.withValues(alpha: 0.0),
            _gold.withValues(alpha: 0.085),
            _gold.withValues(alpha: 0.0),
          ],
          stops: [
            (sweepCentre - 0.30).clamp(0.0, 1.0),
            sweepCentre.clamp(0.0, 1.0),
            (sweepCentre + 0.30).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );

    // Gentle top-down vignette so status-bar / app-bar text stays legible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59000000), Color(0x00000000), Color(0x40000000)],
          stops: [0.0, 0.38, 1.0],
        ).createShader(rect),
    );
  }

  /// The tessellation for a screen of [size], built once and kept. Static
  /// because a new `_RgbPainter` is constructed on every frame (it carries
  /// `t`), so an instance field would cache nothing.
  ///
  /// It is one entry, not a map: a running app has one window, and a rotation
  /// simply replaces it. The lattice runs one tile past every edge so the
  /// drift never exposes a cut first row.
  static Size? _latticeSize;
  static Path? _lattice;

  static Path _latticeFor(Size size) {
    final cached = _lattice;
    if (cached != null && _latticeSize == size) return cached;
    final path = Path();
    final r = _tile * 0.42;
    for (var y = -_tile * 2; y < size.height + _tile * 2; y += _tile) {
      for (var x = -_tile * 2; x < size.width + _tile * 2; x += _tile) {
        final c = Offset(x + _tile / 2, y + _tile / 2);
        _addStar(path, c, r);
        _addDiamond(path, c, r * 0.52);
      }
    }
    _lattice = path;
    _latticeSize = size;
    return path;
  }

  /// One eight-point khātim, appended to [path].
  static void _addStar(Path path, Offset centre, double radius) {
    const points = 8;
    final inner = radius * 0.52;
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? radius : inner;
      final a = (math.pi / points) * i - math.pi / 2;
      final p = Offset(centre.dx + rr * math.cos(a), centre.dy + rr * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
  }

  /// The 45° square through the star's inner vertices — the interlace that
  /// turns separate stars into one wall.
  static void _addDiamond(Path path, Offset centre, double radius) {
    path
      ..moveTo(centre.dx, centre.dy - radius)
      ..lineTo(centre.dx + radius, centre.dy)
      ..lineTo(centre.dx, centre.dy + radius)
      ..lineTo(centre.dx - radius, centre.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _RgbPainter old) => old.t != t;
}
