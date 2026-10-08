/// What carries the player on a leg of «قافلة الدرب» besides camels: a
/// horse for the expeditions, a dhow on the sea and the rivers, and a
/// hoopoe - the bird of Surat al-Naml - for the legs flown over the
/// mountains.
///
/// Owner, 2026-10-08: «مش شرط يمشوا بجمال في كل حاجة شوية طايرين شوية
/// سفينة … نوع براحتك بشكل جذاب». No people are drawn on any of them.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/caravan_world.dart';

class CaravanRides {
  final CaravanWorld w;
  const CaravanRides(this.w);

  static const _gold = Color(0xFFE8C766);

  Color _shade(Color c) =>
      Color.lerp(c, const Color(0xFF3A4270), 0.35 * w.night)!;

  /// A horse at a gallop, [foot] under its middle, [h] its height.
  void horse(
    Canvas canvas,
    Offset foot,
    double h,
    double stride, {
    bool hurt = false,
    int coat = 0,
  }) {
    const coats = [Color(0xFF8A5A33), Color(0xFFDDD3C2), Color(0xFF3B2A22)];
    final body = hurt ? const Color(0xFF9B4A32) : _shade(coats[coat % 3]);
    final dark = Color.lerp(body, Colors.black, 0.45)!;
    final legLen = h * 0.46;
    final hip = foot.translate(0, -legLen);
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(body, Colors.white, 0.2)!,
              body,
              Color.lerp(body, Colors.black, 0.25)!,
            ],
          ).createShader(
            Rect.fromLTWH(hip.dx - h * 0.5, hip.dy - h * 0.6, h, h * 0.7),
          );
    // A gallop: the pairs reach far forward and back.
    final legPaint = Paint()
      ..color = dark
      ..strokeWidth = h * 0.055
      ..strokeCap = StrokeCap.round;
    final swing = math.sin(stride * 2 * math.pi) * 0.7;
    for (final (dx, ph) in [
      (-h * 0.3, swing),
      (-h * 0.2, swing * 0.7),
      (h * 0.22, -swing),
      (h * 0.32, -swing * 0.7),
    ]) {
      final top = hip.translate(dx, -h * 0.02);
      final knee = top.translate(math.sin(ph) * legLen * 0.45, legLen * 0.5);
      final hoof = knee.translate(
        math.sin(ph * 1.4) * legLen * 0.3,
        legLen * 0.5,
      );
      canvas.drawLine(top, knee, legPaint);
      canvas.drawLine(knee, hoof, legPaint);
    }
    // Barrel, chest and haunch.
    canvas.drawOval(
      Rect.fromCenter(
        center: hip.translate(0, -h * 0.1),
        width: h * 0.9,
        height: h * 0.3,
      ),
      paint,
    );
    // Neck and head, held high and forward.
    final nod = math.sin(stride * 2 * math.pi) * h * 0.025;
    final neck = Path()
      ..moveTo(hip.dx + h * 0.25, hip.dy - h * 0.2)
      ..lineTo(hip.dx + h * 0.5, hip.dy - h * 0.55 + nod)
      ..lineTo(hip.dx + h * 0.62, hip.dy - h * 0.5 + nod)
      ..lineTo(hip.dx + h * 0.42, hip.dy - h * 0.08)
      ..close();
    canvas.drawPath(neck, paint);
    final head = Path()
      ..moveTo(hip.dx + h * 0.5, hip.dy - h * 0.58 + nod)
      ..lineTo(hip.dx + h * 0.78, hip.dy - h * 0.42 + nod)
      ..lineTo(hip.dx + h * 0.74, hip.dy - h * 0.35 + nod)
      ..lineTo(hip.dx + h * 0.55, hip.dy - h * 0.45 + nod)
      ..close();
    canvas.drawPath(head, paint);
    // Mane and tail streaming in the wind.
    final hair = Paint()
      ..color = dark
      ..strokeWidth = h * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final flow = math.sin(w.time * 9) * h * 0.03;
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx + h * 0.5, hip.dy - h * 0.58 + nod)
        ..quadraticBezierTo(
          hip.dx + h * 0.3,
          hip.dy - h * 0.45 + flow,
          hip.dx + h * 0.25,
          hip.dy - h * 0.22,
        ),
      hair,
    );
    canvas.drawPath(
      Path()
        ..moveTo(hip.dx - h * 0.44, hip.dy - h * 0.16)
        ..quadraticBezierTo(
          hip.dx - h * 0.62,
          hip.dy - h * 0.12 + flow,
          hip.dx - h * 0.6,
          hip.dy + h * 0.1,
        ),
      hair,
    );
    // A saddle cloth in the caravan's colours.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hip.translate(-h * 0.02, -h * 0.24),
          width: h * 0.32,
          height: h * 0.12,
        ),
        Radius.circular(h * 0.03),
      ),
      Paint()..color = const Color(0xFF1F6B5A),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: hip.translate(-h * 0.02, -h * 0.18),
        width: h * 0.32,
        height: h * 0.022,
      ),
      Paint()..color = _gold,
    );
    canvas.drawCircle(
      Offset(hip.dx + h * 0.66, hip.dy - h * 0.47 + nod),
      h * 0.014,
      Paint()..color = const Color(0xFF1B0F08),
    );
  }

  /// A dhow with a lateen sail, rocking on the swell; [foot] is the
  /// waterline under its middle.
  void boat(Canvas canvas, Offset foot, double h, {bool hurt = false}) {
    final rock = math.sin(w.time * 2.4) * 0.05;
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.rotate(rock);
    final hull = Path()
      ..moveTo(-h * 0.75, -h * 0.28)
      ..lineTo(h * 0.8, -h * 0.32)
      ..quadraticBezierTo(h * 0.55, h * 0.05, h * 0.3, h * 0.06)
      ..lineTo(-h * 0.45, h * 0.06)
      ..quadraticBezierTo(-h * 0.65, 0, -h * 0.75, -h * 0.28)
      ..close();
    canvas.drawPath(
      hull,
      Paint()
        ..color = hurt
            ? const Color(0xFF9B4A32)
            : _shade(const Color(0xFF6B3E22)),
    );
    canvas.drawLine(
      Offset(-h * 0.7, -h * 0.24),
      Offset(h * 0.75, -h * 0.28),
      Paint()
        ..color = _gold
        ..strokeWidth = h * 0.03,
    );
    final mast = Paint()
      ..color = const Color(0xFF4E2F1A)
      ..strokeWidth = h * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -h * 0.3), Offset(0, -h * 1.25), mast);
    final belly = math.sin(w.time * 1.7) * h * 0.04;
    canvas.drawPath(
      Path()
        ..moveTo(-h * 0.55, -h * 0.42)
        ..lineTo(h * 0.15, -h * 1.3)
        ..quadraticBezierTo(h * 0.55 + belly, -h * 0.75, h * 0.42, -h * 0.38)
        ..close(),
      Paint()..color = _shade(const Color(0xFFF6EBD2)),
    );
    canvas.drawLine(
      Offset(-h * 0.55, -h * 0.42),
      Offset(h * 0.15, -h * 1.3),
      mast,
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: foot.translate(h * 0.75, h * 0.02),
        width: h * 0.35,
        height: h * 0.1,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// A hoopoe in flight: crest fanned, barred wings beating. [c] is its
  /// body's centre, [h] the caravan unit.
  void hoopoe(
    Canvas canvas,
    Offset c,
    double h, {
    bool hurt = false,
    double phase = 0,
  }) {
    final s = h * 0.5;
    final flap = math.sin(w.time * 12 + phase);
    final body = hurt ? const Color(0xFF9B4A32) : const Color(0xFFD9925A);
    // Far wing, body, near wing.
    void wing(double k, Color base) {
      final tip = c.translate(-s * 0.2, -s * (0.9 * flap) * k);
      final wingPath = Path()
        ..moveTo(c.dx - s * 0.25, c.dy - s * 0.05)
        ..quadraticBezierTo(tip.dx - s * 0.5, tip.dy, tip.dx - s * 0.1, tip.dy)
        ..quadraticBezierTo(
          c.dx + s * 0.2,
          c.dy - s * 0.2 * flap,
          c.dx + s * 0.2,
          c.dy,
        )
        ..close();
      canvas.drawPath(wingPath, Paint()..color = base);
      final bar = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = s * 0.06;
      for (var i = 1; i <= 3; i++) {
        final t = i / 4;
        final a = Offset.lerp(Offset(c.dx - s * 0.25, c.dy), tip, t)!;
        canvas.drawLine(a, a.translate(s * 0.25, s * 0.05), bar);
      }
    }

    wing(0.7, const Color(0xFF2B2420));
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 1.2, height: s * 0.5),
      Paint()..color = _shade(body),
    );
    // Head, long curved bill, crest with black tips.
    final head = c.translate(s * 0.55, -s * 0.18);
    canvas.drawCircle(head, s * 0.2, Paint()..color = _shade(body));
    canvas.drawPath(
      Path()
        ..moveTo(head.dx + s * 0.15, head.dy)
        ..quadraticBezierTo(
          head.dx + s * 0.45,
          head.dy + s * 0.02,
          head.dx + s * 0.62,
          head.dy + s * 0.16,
        ),
      Paint()
        ..color = const Color(0xFF2B2420)
        ..strokeWidth = s * 0.06
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 - 0.9 + i * 0.3;
      final end = head + Offset(math.cos(a), math.sin(a)) * s * 0.42;
      canvas.drawLine(
        head,
        end,
        Paint()
          ..color = _shade(const Color(0xFFE8A060))
          ..strokeWidth = s * 0.09
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        end,
        s * 0.05,
        Paint()..color = const Color(0xFF2B2420),
      );
    }
    canvas.drawCircle(
      head.translate(s * 0.06, -s * 0.03),
      s * 0.04,
      Paint()..color = Colors.black,
    );
    // Tail.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.5, c.dy)
        ..lineTo(c.dx - s * 0.95, c.dy - s * 0.12)
        ..lineTo(c.dx - s * 0.95, c.dy + s * 0.14)
        ..close(),
      Paint()..color = const Color(0xFF2B2420),
    );
    wing(1.0, const Color(0xFF3A302A));
  }
}
