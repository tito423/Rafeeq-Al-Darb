import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An analogue clock face whose rim and hands travel through the RGB spectrum.
///
/// The colour is driven by the seconds hand's own angle rather than a separate
/// animation controller: the sweep and the hue then advance together by
/// construction, and the widget needs no ticker of its own — the Home card
/// already rebuilds once a second for the digital clock, and this repaints on
/// the same beat.
class RgbAnalogClock extends StatelessWidget {
  final DateTime time;
  final double size;

  /// Shown under the hands as a small AM/PM marker; null hides it.
  final String? meridiem;

  const RgbAnalogClock({
    super.key,
    required this.time,
    this.size = 168,
    this.meridiem,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ClockPainter(time: time),
        child: meridiem == null
            ? null
            : Align(
                alignment: const Alignment(0, 0.42),
                child: Text(
                  meridiem!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: size * 0.075,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime time;
  const _ClockPainter({required this.time});

  /// Full-saturation hue wheel — [t] is 0..1 around the circle.
  static Color _spectrum(double t, {double alpha = 1}) =>
      HSVColor.fromAHSV(alpha, (t * 360) % 360, 0.85, 1).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Seconds carry a fraction so the sweep is smooth rather than ticking.
    final secs = time.second + time.millisecond / 1000;
    final tSec = secs / 60;
    final tMin = (time.minute + secs / 60) / 60;
    final tHour = ((time.hour % 12) + time.minute / 60) / 12;

    // ── Rim: the whole spectrum, rotated so its start follows the seconds ──
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
          transform: GradientRotation(tSec * math.pi * 2),
          colors: [
            for (var i = 0; i <= 6; i++) _spectrum(i / 6),
          ],
        ).createShader(rimRect),
    );

    // ── Hour ticks ──
    for (var i = 0; i < 12; i++) {
      final a = (i / 12) * math.pi * 2 - math.pi / 2;
      final long = i % 3 == 0;
      final outer = r - 14;
      final inner = outer - (long ? 12 : 6);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * inner,
        c + Offset(math.cos(a), math.sin(a)) * outer,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = long ? 3 : 1.6
          ..color = Colors.white.withValues(alpha: long ? 0.85 : 0.35),
      );
    }

    void hand(double t, double length, double width, Color color,
        {bool glow = true}) {
      final a = t * math.pi * 2 - math.pi / 2;
      final tip = c + Offset(math.cos(a), math.sin(a)) * length;
      // A counterweight past the centre, the way a real hand is balanced.
      final tail = c - Offset(math.cos(a), math.sin(a)) * (length * 0.18);
      if (glow) {
        canvas.drawLine(
          tail,
          tip,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = width * 2.6
            ..color = color.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawLine(
        tail,
        tip,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width
          ..color = color,
      );
    }

    // Each hand sits at its own point on the wheel, so they stay legible
    // against one another instead of all being the same colour at once.
    hand(tHour, r * 0.48, 6, _spectrum(tSec + 0.00));
    hand(tMin, r * 0.68, 4.5, _spectrum(tSec + 0.33));
    hand(tSec, r * 0.80, 2.2, _spectrum(tSec + 0.66));

    // ── Hub ──
    canvas.drawCircle(c, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      3.2,
      Paint()..color = _spectrum(tSec),
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) => old.time != time;
}
