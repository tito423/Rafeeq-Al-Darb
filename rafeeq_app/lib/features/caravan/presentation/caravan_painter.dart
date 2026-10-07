/// Everything «قافلة الدرب» draws: the sky turning from dawn to gold, three
/// ranges of dunes moving at their own pace, the caravan, the lanterns, the
/// rocks, and the city gate at the end of the road.
///
/// No people are drawn anywhere - camels, land and buildings only.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/caravan_world.dart';

class CaravanPainter extends CustomPainter {
  final CaravanWorld w;
  CaravanPainter(this.w) : super(repaint: w);

  static const _gold = Color(0xFFE8C766);
  static const _goldDeep = Color(0xFFB8892A);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = size.height * CaravanWorld.groundY;
    final camel = w.camelH * size.height;
    _sky(canvas, size);
    _sun(canvas, size);
    _dunes(
      canvas,
      size,
      depth: 0.15,
      base: 0.62,
      amp: 0.05,
      color: const Color(0xFFD9A066).withValues(alpha: 0.55),
      seed: 1,
    );
    _dunes(
      canvas,
      size,
      depth: 0.35,
      base: 0.68,
      amp: 0.045,
      color: const Color(0xFFC98B4E).withValues(alpha: 0.8),
      seed: 2,
    );
    if (w.gateX != null) _gate(canvas, size, w.gateX! * size.width, ground);
    _dunes(
      canvas,
      size,
      depth: 1.0,
      base: CaravanWorld.groundY,
      amp: 0.012,
      color: const Color(0xFFB9763A),
      seed: 3,
      fill: true,
    );
    for (final r in w.rocks) {
      _rock(canvas, Offset(r.x * size.width, ground), camel * 0.3);
    }
    for (final l in w.lanterns) {
      if (!l.taken) {
        _lantern(
          canvas,
          Offset(l.x * size.width, size.height * w.ly(l)),
          camel * 0.22,
        );
      }
    }
    for (final s in w.sparks) {
      final a = (1 - s.age / 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height - s.age * 60),
        3 + 6 * s.age,
        Paint()..color = _gold.withValues(alpha: a),
      );
    }
    // The caravan: three camels, the lead one is the player; each follower
    // repeats the lead's jump a beat later.
    for (var i = 2; i >= 0; i--) {
      final x = CaravanWorld.leadX * size.width - i * camel * 1.05;
      final lift = w.liftAt(i) * size.height;
      _camel(
        canvas,
        Offset(x, ground - lift),
        camel,
        w.stride + i * 0.33,
        hurt: i == 0 && w.hurtFor > 0,
      );
    }
  }

  void _sky(Canvas canvas, Size size) {
    // Dawn violet to morning blue to the gold of afternoon, with the road.
    final p = w.progress.clamp(0.0, 1.0);
    final top = Color.lerp(
      const Color(0xFF2B2A5C),
      const Color(0xFF3E7CB1),
      (p * 2).clamp(0.0, 1.0),
    )!;
    final bottom = Color.lerp(
      const Color(0xFFF2A65A),
      const Color(0xFFF7E3B5),
      (p * 1.5).clamp(0.0, 1.0),
    )!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );
    // A few stars that fade as the sun climbs.
    final starA = (1 - p * 3).clamp(0.0, 1.0);
    if (starA > 0) {
      final rnd = math.Random(7);
      final star = Paint()..color = Colors.white.withValues(alpha: 0.8 * starA);
      for (var i = 0; i < 40; i++) {
        canvas.drawCircle(
          Offset(
            rnd.nextDouble() * size.width,
            rnd.nextDouble() * size.height * 0.45,
          ),
          rnd.nextDouble() * 1.6 + 0.4,
          star,
        );
      }
    }
  }

  void _sun(Canvas canvas, Size size) {
    final p = w.progress.clamp(0.0, 1.0);
    final c = Offset(
      size.width * (0.82 - 0.5 * p),
      size.height * (0.55 - 0.38 * math.sin(p * math.pi * 0.9)),
    );
    final r = math.min(size.width, size.height) * 0.07;
    canvas.drawCircle(
      c,
      r * 2.4,
      Paint()
        ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE9B0));
  }

  void _dunes(
    Canvas canvas,
    Size size, {
    required double depth,
    required double base,
    required double amp,
    required Color color,
    required int seed,
    bool fill = false,
  }) {
    final off = (w.distance * depth) % 1.0;
    final path = Path()..moveTo(0, size.height);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final fx = i / steps;
      final x = fx * size.width;
      final u = (fx + off) * 2 * math.pi;
      final y =
          base +
          amp * math.sin(u * 2 + seed) +
          amp * 0.5 * math.sin(u * 5 + seed * 2);
      path.lineTo(x, y * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    if (fill) {
      // Ripples in the sand of the road.
      final ripple = Paint()
        ..color = const Color(0xFF8E5426).withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 9; i++) {
        final x = ((i / 9 - off * 1.0) % 1.0) * size.width;
        final y = size.height * (base + 0.05 + (i % 3) * 0.045);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, y), width: 60, height: 10),
          math.pi,
          math.pi,
          false,
          ripple,
        );
      }
    }
  }

  void _rock(Canvas canvas, Offset foot, double s) {
    final path = Path()
      ..moveTo(foot.dx - s, foot.dy)
      ..lineTo(foot.dx - s * 0.7, foot.dy - s * 0.8)
      ..lineTo(foot.dx - s * 0.1, foot.dy - s * 1.15)
      ..lineTo(foot.dx + s * 0.6, foot.dy - s * 0.85)
      ..lineTo(foot.dx + s, foot.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF6D4C3D));
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx - s * 0.1, foot.dy - s * 1.15)
        ..lineTo(foot.dx + s * 0.6, foot.dy - s * 0.85)
        ..lineTo(foot.dx + s * 0.2, foot.dy - s * 0.4)
        ..close(),
      Paint()..color = const Color(0xFF8A6450),
    );
  }

  void _lantern(Canvas canvas, Offset c, double s) {
    final bob = math.sin(w.time * 3 + c.dx / 40) * s * 0.25;
    final o = c.translate(0, bob);
    canvas.drawCircle(
      o,
      s * 1.8,
      Paint()
        ..color = _gold.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    // Cap, body with a lit window, base.
    canvas.drawLine(
      o.translate(0, -s * 1.5),
      o.translate(0, -s * 1.0),
      Paint()
        ..color = _goldDeep
        ..strokeWidth = 2,
    );
    final body = Path()
      ..moveTo(o.dx - s * 0.55, o.dy - s * 0.7)
      ..lineTo(o.dx + s * 0.55, o.dy - s * 0.7)
      ..lineTo(o.dx + s * 0.7, o.dy + s * 0.5)
      ..lineTo(o.dx - s * 0.7, o.dy + s * 0.5)
      ..close();
    canvas.drawPath(body, Paint()..color = _goldDeep);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: s * 0.75, height: s * 0.9),
        Radius.circular(s * 0.3),
      ),
      Paint()..color = const Color(0xFFFFF2B8),
    );
    canvas.drawPath(
      Path()
        ..moveTo(o.dx - s * 0.6, o.dy - s * 0.7)
        ..lineTo(o.dx, o.dy - s * 1.1)
        ..lineTo(o.dx + s * 0.6, o.dy - s * 0.7)
        ..close(),
      Paint()..color = _goldDeep,
    );
  }

  void _camel(
    Canvas canvas,
    Offset foot,
    double h,
    double stride, {
    bool hurt = false,
  }) {
    final body = hurt ? const Color(0xFF9B4A32) : const Color(0xFF6B4226);
    const shade = Color(0xFF4E2F1A);
    final paint = Paint()..color = body;
    final legLen = h * 0.42;
    final hip = foot.translate(0, -legLen);
    // Legs: four, swinging in pairs.
    final legPaint = Paint()
      ..color = shade
      ..strokeWidth = h * 0.06
      ..strokeCap = StrokeCap.round;
    final swing = math.sin(stride * 2 * math.pi) * 0.45;
    for (final (dx, ph) in [
      (-h * 0.32, swing),
      (-h * 0.22, -swing),
      (h * 0.2, -swing),
      (h * 0.3, swing),
    ]) {
      final top = hip.translate(dx, 0);
      final knee = top.translate(math.sin(ph) * legLen * 0.5, legLen * 0.5);
      final toe = knee.translate(
        math.sin(ph * 0.6) * legLen * 0.4,
        legLen * 0.5,
      );
      canvas.drawLine(top, knee, legPaint);
      canvas.drawLine(knee, toe, legPaint);
    }
    // Body and hump.
    canvas.drawOval(
      Rect.fromCenter(
        center: hip.translate(0, -h * 0.08),
        width: h * 0.82,
        height: h * 0.32,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: hip.translate(-h * 0.04, -h * 0.25),
        width: h * 0.42,
        height: h * 0.3,
      ),
      paint,
    );
    // Neck and head, nodding with the walk.
    final nod = math.sin(stride * 2 * math.pi) * h * 0.02;
    final neck = Path()
      ..moveTo(hip.dx + h * 0.3, hip.dy - h * 0.12)
      ..quadraticBezierTo(
        hip.dx + h * 0.52,
        hip.dy - h * 0.1,
        hip.dx + h * 0.5,
        hip.dy - h * 0.42 + nod,
      )
      ..lineTo(hip.dx + h * 0.42, hip.dy - h * 0.42 + nod)
      ..quadraticBezierTo(
        hip.dx + h * 0.42,
        hip.dy - h * 0.18,
        hip.dx + h * 0.24,
        hip.dy - h * 0.2,
      )
      ..close();
    canvas.drawPath(neck, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hip.dx + h * 0.52, hip.dy - h * 0.46 + nod),
        width: h * 0.2,
        height: h * 0.1,
      ),
      paint,
    );
    // A saddle cloth with a gold edge, the caravan's colour.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hip.translate(-h * 0.04, -h * 0.2),
          width: h * 0.34,
          height: h * 0.14,
        ),
        Radius.circular(h * 0.03),
      ),
      Paint()..color = const Color(0xFF1F6B5A),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: hip.translate(-h * 0.04, -h * 0.14),
        width: h * 0.34,
        height: h * 0.025,
      ),
      Paint()..color = _gold,
    );
  }

  void _gate(Canvas canvas, Size size, double cx, double ground) {
    // The city on the horizon: walls, a gate of two arches, palms.
    final h = size.height * 0.34;
    final wall = Paint()..color = const Color(0xFFE9D6B0);
    final line = Paint()
      ..color = const Color(0xFFB8956A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(cx - h * 1.2, ground - h, h * 2.4, h);
    canvas.drawRect(rect, wall);
    // Crenellations.
    for (var x = rect.left; x < rect.right; x += h * 0.16) {
      canvas.drawRect(
        Rect.fromLTWH(x, rect.top - h * 0.08, h * 0.09, h * 0.08),
        wall,
      );
    }
    // The gate: an arch that opens as [gateOpen] goes 0 -> 1.
    final archW = h * 0.6, archH = h * 0.72;
    final arch = Path()
      ..moveTo(cx - archW / 2, ground)
      ..lineTo(cx - archW / 2, ground - archH * 0.6)
      ..quadraticBezierTo(cx - archW / 2, ground - archH, cx, ground - archH)
      ..quadraticBezierTo(
        cx + archW / 2,
        ground - archH,
        cx + archW / 2,
        ground - archH * 0.6,
      )
      ..lineTo(cx + archW / 2, ground)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFFFFE9B0));
    final doorW = archW / 2 * (1 - w.gateOpen);
    final door = Paint()..color = const Color(0xFF7A4E2A);
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(
      Rect.fromLTWH(cx - archW / 2, ground - archH, doorW, archH),
      door,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + archW / 2 - doorW, ground - archH, doorW, archH),
      door,
    );
    canvas.restore();
    canvas.drawPath(arch, line);
    // Small windows.
    for (final dx in [-h * 0.8, h * 0.8]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + dx, ground - h * 0.6),
            width: h * 0.14,
            height: h * 0.22,
          ),
          Radius.circular(h * 0.07),
        ),
        Paint()..color = const Color(0xFFB8956A),
      );
    }
    for (final dx in [-h * 1.55, h * 1.5, h * 1.9]) {
      _palm(canvas, Offset(cx + dx, ground), h * 0.9);
    }
  }

  void _palm(Canvas canvas, Offset foot, double h) {
    final trunk = Paint()
      ..color = const Color(0xFF7A5230)
      ..strokeWidth = h * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final top = foot.translate(h * 0.08, -h);
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..quadraticBezierTo(
          foot.dx - h * 0.05,
          foot.dy - h * 0.5,
          top.dx,
          top.dy,
        ),
      trunk,
    );
    final leaf = Paint()..color = const Color(0xFF3F7A3A);
    final sway = math.sin(w.time * 1.5) * 0.08;
    for (var i = 0; i < 7; i++) {
      final a = -math.pi + i * math.pi / 6 + sway;
      final end = top.translate(
        math.cos(a) * h * 0.38,
        math.sin(a) * h * 0.2 + h * 0.12,
      );
      final mid = top.translate(
        math.cos(a) * h * 0.2,
        math.sin(a) * h * 0.2 - h * 0.05,
      );
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(mid.dx, mid.dy - h * 0.04, end.dx, end.dy)
          ..quadraticBezierTo(mid.dx, mid.dy + h * 0.04, top.dx, top.dy),
        leaf,
      );
    }
  }

  @override
  bool shouldRepaint(CaravanPainter old) => false;
}
