import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/clock_settings_provider.dart';

/// Ten analogue clock faces, all driven from one live `DateTime`.
///
/// The widget owns its own [Ticker] rather than leaning on the Home card's
/// once-a-second `setState`: a seconds hand that jumps in whole steps is the
/// single thing that makes an analogue clock look cheap, and every face here
/// carries the sub-second fraction into its sweep. The ticker is created and
/// disposed with the widget, so it stops the moment the clock leaves the tree
/// (the gallery sheet closing, the Home tab being replaced) instead of
/// repainting forever in the background.
class AnalogClockFaceView extends StatefulWidget {
  final AnalogClockFace face;
  final double size;

  /// Shown as a small AM/PM marker on the faces that have room for it; null
  /// hides it (24-hour mode).
  final String? meridiem;

  /// Arabic-Indic digits on the faces that draw numerals.
  final bool arabicDigits;

  /// The colour the dial's markings and numerals are drawn in. Defaults to
  /// white, which is what every face assumed before the Home card learned to
  /// follow the theme; the coloured parts of each face (the gold, the neon
  /// ring, the RGB sweep) are unaffected.
  final Color ink;

  const AnalogClockFaceView({
    super.key,
    required this.face,
    this.size = 176,
    this.meridiem,
    this.arabicDigits = false,
    this.ink = Colors.white,
  });

  @override
  State<AnalogClockFaceView> createState() => _AnalogClockFaceViewState();
}

class _AnalogClockFaceViewState extends State<AnalogClockFaceView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = DateTime.now();
      // ~30 fps is plenty for a sweeping hand and halves the repaints of a
      // free-running 60 fps ticker.
      if (now.difference(_now).inMilliseconds < 33) return;
      setState(() => _now = now);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _facePainter(
          widget.face,
          _now,
          arabicDigits: widget.arabicDigits,
          ink: widget.ink,
        ),
        // The AM/PM marker sits on the dial's vertical axis, which is exactly
        // where the minute and second hands spend a good part of every hour.
        // Bare text there is unreadable half the time — on the device it read
        // as a broken half-glyph with the minute hand through it. A capsule
        // in the dial's own dark gives it a ground of its own, so it stays
        // legible whatever the hands are doing. No letterSpacing: on a
        // one- or two-letter Arabic marker («ص» / «م») it only adds a
        // trailing gap that throws the centring off.
        child: widget.meridiem == null || !_hasMeridiemRoom(widget.face)
            ? null
            : Align(
                alignment: const Alignment(0, 0.52),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.size * 0.045,
                    vertical: widget.size * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(widget.size),
                  ),
                  child: Text(
                    widget.meridiem!,
                    style: TextStyle(
                      // On its own black capsule, so white whatever the card
                      // is: the capsule composites dark on either ground.
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: widget.size * 0.075,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// The two faces that already put their own artwork in the lower half.
  bool _hasMeridiemRoom(AnalogClockFace f) =>
      f != AnalogClockFace.sunMoon && f != AnalogClockFace.skeleton;
}

CustomPainter _facePainter(
  AnalogClockFace face,
  DateTime now, {
  required bool arabicDigits,
  required Color ink,
}) {
  switch (face) {
    case AnalogClockFace.rgb:
      return _RgbPainter(now, ink);
    case AnalogClockFace.classicGold:
      return _ClassicGoldPainter(now, ink, arabicDigits: arabicDigits);
    case AnalogClockFace.minimalDark:
      return _MinimalDarkPainter(now, ink);
    case AnalogClockFace.neonRing:
      return _NeonRingPainter(now, ink);
    case AnalogClockFace.arabicNumerals:
      return _ArabicNumeralsPainter(now, ink, arabicDigits: arabicDigits);
    case AnalogClockFace.islamicStar:
      return _IslamicStarPainter(now, ink);
    case AnalogClockFace.skeleton:
      return _SkeletonPainter(now, ink);
    case AnalogClockFace.sunMoon:
      return _SunMoonPainter(now, ink);
    case AnalogClockFace.halo:
      return _HaloPainter(now, ink);
    case AnalogClockFace.mosaic:
      return _MosaicPainter(now, ink);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────

/// The three hand angles as fractions of a full turn, seconds carrying their
/// millisecond fraction so every sweep is smooth.
({double hour, double minute, double second}) _turns(DateTime t) {
  final secs = t.second + t.millisecond / 1000;
  return (
    hour: ((t.hour % 12) + t.minute / 60 + secs / 3600) / 12,
    minute: (t.minute + secs / 60) / 60,
    second: secs / 60,
  );
}

Offset _at(Offset c, double turn, double radius) {
  final a = turn * math.pi * 2 - math.pi / 2;
  return c + Offset(math.cos(a), math.sin(a)) * radius;
}

void _drawHand(
  Canvas canvas,
  Offset c,
  double turn,
  double length,
  double width,
  Color color, {
  double tailFactor = 0.18,
  bool glow = false,
  StrokeCap cap = StrokeCap.round,
}) {
  final tip = _at(c, turn, length);
  final tail = _at(c, turn + 0.5, length * tailFactor);
  if (glow) {
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..strokeCap = cap
        ..strokeWidth = width * 2.6
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
  canvas.drawLine(
    tail,
    tip,
    Paint()
      ..strokeCap = cap
      ..strokeWidth = width
      ..color = color,
  );
}

void _drawLabel(
  Canvas canvas,
  Offset at,
  String text,
  double fontSize,
  Color color, {
  FontWeight weight = FontWeight.w700,
  String? fontFamily,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        fontFamily: fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
}

const _kTeal = Color(0xFF15C7B0);
const _kGold = Color(0xFFD4AF37);

/// Full-saturation hue wheel — [t] is 0..1 around the circle.
Color _spectrum(double t, {double alpha = 1}) =>
    HSVColor.fromAHSV(alpha, (t * 360) % 360, 0.85, 1).toColor();

/// Base class so every painter repaints exactly when the clock moves.
abstract class _FacePainter extends CustomPainter {
  final DateTime now;

  /// The dial's own ink, from the card underneath.
  final Color ink;
  const _FacePainter(this.now, this.ink);

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.now != now || old.ink != ink;
}

// ─────────────────────────────────────────────────────────────────────────
// 1. RGB spectrum — the face this app already had.
// ─────────────────────────────────────────────────────────────────────────

class _RgbPainter extends _FacePainter {
  const _RgbPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    final rimRect = Rect.fromCircle(center: c, radius: r - 6);
    canvas.drawArc(
      rimRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = SweepGradient(
          transform: GradientRotation(t.second * math.pi * 2),
          colors: [for (var i = 0; i <= 6; i++) _spectrum(i / 6)],
        ).createShader(rimRect),
    );

    for (var i = 0; i < 12; i++) {
      final long = i % 3 == 0;
      final outer = r - 14;
      canvas.drawLine(
        _at(c, i / 12, outer - (long ? 12 : 6)),
        _at(c, i / 12, outer),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = long ? 3 : 1.6
          ..color = ink.withValues(alpha: long ? 0.85 : 0.35),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.48, 6, _spectrum(t.second),
        glow: true);
    _drawHand(canvas, c, t.minute, r * 0.68, 4.5, _spectrum(t.second + 0.33),
        glow: true);
    _drawHand(canvas, c, t.second, r * 0.80, 2.2, _spectrum(t.second + 0.66),
        glow: true);

    canvas.drawCircle(c, 6.5, Paint()..color = ink);
    canvas.drawCircle(c, 3.2, Paint()..color = _spectrum(t.second));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Classic gold — a cream dial in a gold bezel.
// ─────────────────────────────────────────────────────────────────────────

class _ClassicGoldPainter extends _FacePainter {
  final bool arabicDigits;
  const _ClassicGoldPainter(super.now, super.ink, {required this.arabicDigits});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFDF7E4), Color(0xFFE8DCBC)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF8A6B12),
            _kGold,
            Color(0xFFF3E39A),
            _kGold,
            Color(0xFF8A6B12),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r - 4)),
    );

    const numerals = ['12', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'];
    const arabic = ['١٢', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠', '١١'];
    for (var i = 0; i < 12; i++) {
      _drawLabel(
        canvas,
        _at(c, i / 12, r * 0.76),
        arabicDigits ? arabic[i] : numerals[i],
        r * 0.15,
        const Color(0xFF4A3A12),
      );
    }
    for (var i = 0; i < 60; i++) {
      if (i % 5 == 0) continue;
      canvas.drawCircle(
        _at(c, i / 60, r * 0.90),
        1.1,
        Paint()..color = const Color(0xFF6B5A2A).withValues(alpha: 0.5),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.46, 5, const Color(0xFF3A2E0C));
    _drawHand(canvas, c, t.minute, r * 0.66, 3.4, const Color(0xFF3A2E0C));
    _drawHand(canvas, c, t.second, r * 0.78, 1.6, const Color(0xFFB3261E));
    canvas.drawCircle(c, 5, Paint()..color = const Color(0xFF3A2E0C));
    canvas.drawCircle(c, 2.2, Paint()..color = _kGold);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Minimal dark — a hairline circle and four ticks.
// ─────────────────────────────────────────────────────────────────────────

class _MinimalDarkPainter extends _FacePainter {
  const _MinimalDarkPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    canvas.drawCircle(
      c,
      r - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ink.withValues(alpha: 0.20),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        _at(c, i / 4, r - 20),
        _at(c, i / 4, r - 10),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = ink.withValues(alpha: 0.7),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.44, 3.4, ink, tailFactor: 0.12);
    _drawHand(canvas, c, t.minute, r * 0.66, 2.4,
        ink.withValues(alpha: 0.9),
        tailFactor: 0.12);
    _drawHand(canvas, c, t.second, r * 0.74, 1.2, _kTeal, tailFactor: 0.22);
    canvas.drawCircle(c, 3.4, Paint()..color = ink);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Neon ring.
// ─────────────────────────────────────────────────────────────────────────

class _NeonRingPainter extends _FacePainter {
  const _NeonRingPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);
    const neon = Color(0xFF3BE8FF);

    for (final spec in [(10.0, 0.18), (5.0, 0.45), (2.0, 1.0)]) {
      canvas.drawCircle(
        c,
        r - 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = spec.$1
          ..color = neon.withValues(alpha: spec.$2)
          ..maskFilter = spec.$2 < 1
              ? const MaskFilter.blur(BlurStyle.normal, 8)
              : null,
      );
    }

    // The travelled arc of the current minute, brighter than the rim.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 8),
      -math.pi / 2,
      t.minute * math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2
        ..color = const Color(0xFFFF4FD8),
    );

    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        _at(c, i / 12, r * 0.80),
        i % 3 == 0 ? 2.6 : 1.4,
        Paint()..color = neon.withValues(alpha: i % 3 == 0 ? 0.95 : 0.4),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.44, 5, neon, glow: true);
    _drawHand(canvas, c, t.minute, r * 0.64, 3.4, const Color(0xFFFF4FD8),
        glow: true);
    _drawHand(canvas, c, t.second, r * 0.74, 1.6, ink, glow: true);
    canvas.drawCircle(c, 5, Paint()..color = ink);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 5. Arabic numerals on a dark dial.
// ─────────────────────────────────────────────────────────────────────────

class _ArabicNumeralsPainter extends _FacePainter {
  final bool arabicDigits;
  const _ArabicNumeralsPainter(super.now, super.ink, {required this.arabicDigits});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    canvas.drawCircle(
      c,
      r - 5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF15243A),
            const Color(0xFF060A12),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kGold.withValues(alpha: 0.65),
    );

    const arabic = ['١٢', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠', '١١'];
    const latin = ['12', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'];
    for (var i = 0; i < 12; i++) {
      _drawLabel(
        canvas,
        _at(c, i / 12, r * 0.76),
        arabicDigits ? arabic[i] : latin[i],
        r * 0.17,
        _kGold,
        fontFamily: 'AmiriQuran',
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.44, 4.5, const Color(0xFFF6E7B4));
    _drawHand(canvas, c, t.minute, r * 0.62, 3, const Color(0xFFF6E7B4));
    _drawHand(canvas, c, t.second, r * 0.70, 1.4, _kTeal);
    canvas.drawCircle(c, 4.5, Paint()..color = _kGold);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 6. Islamic star — an eight-point star dial.
// ─────────────────────────────────────────────────────────────────────────

class _IslamicStarPainter extends _FacePainter {
  const _IslamicStarPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    Path square(double rotation) {
      final p = Path();
      for (var i = 0; i < 4; i++) {
        final pt = _at(c, rotation + i / 4, r * 0.86);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    final star = Path.combine(
      PathOperation.union,
      square(0),
      square(0.125),
    );
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11303F), Color(0xFF231A3D)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = _kGold.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      c,
      r * 0.60,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _kTeal.withValues(alpha: 0.55),
    );

    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        _at(c, i / 12, r * 0.60),
        i % 3 == 0 ? 2.8 : 1.5,
        Paint()..color = _kGold.withValues(alpha: i % 3 == 0 ? 0.95 : 0.45),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.36, 5, const Color(0xFFF6E7B4));
    _drawHand(canvas, c, t.minute, r * 0.52, 3.2, const Color(0xFFF6E7B4));
    _drawHand(canvas, c, t.second, r * 0.58, 1.4, _kTeal);
    canvas.drawCircle(c, 4.5, Paint()..color = _kGold);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 7. Skeleton — three concentric arcs instead of hands.
// ─────────────────────────────────────────────────────────────────────────

class _SkeletonPainter extends _FacePainter {
  const _SkeletonPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    void arc(double radius, double turn, double width, Color color) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.14),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        turn * math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color,
      );
      canvas.drawCircle(
        _at(c, turn, radius),
        width * 0.85,
        Paint()..color = color,
      );
    }

    arc(r - 10, t.hour, 7, _kGold);
    arc(r - 26, t.minute, 6, _kTeal);
    arc(r - 40, t.second, 4, const Color(0xFF9B6BFF));

    final hh = now.hour % 12 == 0 ? 12 : now.hour % 12;
    _drawLabel(
      canvas,
      c,
      '$hh:${now.minute.toString().padLeft(2, '0')}',
      r * 0.32,
      ink,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 8. Sun & moon — a real day/night arc.
// ─────────────────────────────────────────────────────────────────────────

class _SunMoonPainter extends _FacePainter {
  const _SunMoonPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);
    // One turn of this dial is a whole 24-hour day, so the marker really
    // does travel from midnight to midnight once.
    final dayTurn =
        (now.hour + now.minute / 60 + now.second / 3600) / 24;
    final isDay = now.hour >= 6 && now.hour < 18;

    final rect = Rect.fromCircle(center: c, radius: r - 8);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [
            Color(0xFF0B1220),
            Color(0xFF1B3A5C),
            Color(0xFFFFC46B),
            Color(0xFF4FA3FF),
            Color(0xFFFF9A5B),
            Color(0xFF1B2340),
            Color(0xFF0B1220),
          ],
        ).createShader(rect),
    );

    final marker = _at(c, dayTurn, r - 8);
    canvas.drawCircle(
      marker,
      9,
      Paint()
        ..color = (isDay ? const Color(0xFFFFD37A) : ink)
            .withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    if (isDay) {
      canvas.drawCircle(marker, 5.5, Paint()..color = const Color(0xFFFFD37A));
    } else {
      // A crescent: the disc minus an offset disc. `BlendMode.clear` needs
      // its own layer, or it would punch a hole straight through the card
      // behind the clock instead of just through the marker.
      canvas.saveLayer(Rect.fromCircle(center: marker, radius: 12), Paint());
      canvas.drawCircle(marker, 5.5, Paint()..color = ink);
      canvas.drawCircle(
        marker + const Offset(3, -2),
        4.6,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }

    _drawHand(canvas, c, t.hour, r * 0.42, 4.5, ink);
    _drawHand(canvas, c, t.minute, r * 0.60, 3, ink.withValues(alpha: 0.7));
    _drawHand(canvas, c, t.second, r * 0.68, 1.4, const Color(0xFFFFD37A));
    canvas.drawCircle(c, 4, Paint()..color = ink);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 9. Halo — a soft ring that breathes with the seconds.
// ─────────────────────────────────────────────────────────────────────────

class _HaloPainter extends _FacePainter {
  const _HaloPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);
    // A full breath every 4 seconds.
    final breath =
        0.5 + 0.5 * math.sin((now.millisecondsSinceEpoch / 4000) * math.pi * 2);

    canvas.drawCircle(
      c,
      r * (0.62 + 0.10 * breath),
      Paint()
        ..color = _kTeal.withValues(alpha: 0.10 + 0.10 * breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      c,
      r - 10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = SweepGradient(
          transform: GradientRotation(t.minute * math.pi * 2),
          colors: [
            _kTeal.withValues(alpha: 0.05),
            _kTeal,
            _kGold,
            _kTeal.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r - 10)),
    );

    for (var i = 0; i < 60; i++) {
      final on = i / 60 <= t.second;
      canvas.drawCircle(
        _at(c, i / 60, r - 22),
        on ? 1.6 : 1.0,
        Paint()
          ..color = (on ? _kGold : ink).withValues(
            alpha: on ? 0.9 : 0.16,
          ),
      );
    }

    _drawHand(canvas, c, t.hour, r * 0.40, 4.5, ink, glow: true);
    _drawHand(canvas, c, t.minute, r * 0.58, 3, _kTeal, glow: true);
    canvas.drawCircle(c, 4, Paint()..color = _kGold);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 10. Mosaic — sixty ticks along a teal→gold ramp.
// ─────────────────────────────────────────────────────────────────────────

class _MosaicPainter extends _FacePainter {
  const _MosaicPainter(super.now, super.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = _turns(now);

    for (var i = 0; i < 60; i++) {
      final passed = i / 60 <= t.second;
      final color = Color.lerp(_kTeal, _kGold, i / 59)!;
      final long = i % 5 == 0;
      canvas.drawLine(
        _at(c, i / 60, r - (long ? 22 : 16)),
        _at(c, i / 60, r - 6),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = long ? 3.4 : 1.8
          ..color = color.withValues(alpha: passed ? 0.95 : 0.18),
      );
    }

    canvas.drawCircle(
      c,
      r * 0.56,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.12),
    );

    _drawHand(canvas, c, t.hour, r * 0.38, 6, ink,
        cap: StrokeCap.square);
    _drawHand(canvas, c, t.minute, r * 0.54, 4,
        ink.withValues(alpha: 0.85),
        cap: StrokeCap.square);
    _drawHand(canvas, c, t.second, r * 0.62, 1.6, _kGold);
    canvas.drawCircle(c, 5.5, Paint()..color = ink);
    canvas.drawCircle(c, 2.6, Paint()..color = _kTeal);
  }
}
