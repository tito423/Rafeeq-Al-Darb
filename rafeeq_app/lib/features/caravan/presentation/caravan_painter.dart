/// Everything «قافلة الدرب» draws: the sky turning from dawn to gold, three
/// ranges of dunes moving at their own pace, the caravan, the lanterns, the
/// rocks, and the city gate at the end of the road.
///
/// No people are drawn anywhere - camels, land and buildings only.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/caravan_world.dart';
import 'caravan_scenery.dart';

class CaravanPainter extends CustomPainter {
  final CaravanWorld w;
  CaravanPainter(this.w) : super(repaint: w);

  static const _gold = Color(0xFFE8C766);
  static const _goldDeep = Color(0xFFB8892A);

  @override
  void paint(Canvas canvas, Size size) {
    final ground = size.height * CaravanWorld.groundY;
    final camel = w.camelH * size.height;
    final sc = CaravanScenery(w);
    sc.sky(canvas, size);
    sc.sun(canvas, size);
    sc.clouds(canvas, size);
    sc.mountains(canvas, size);
    sc.dunes(
      canvas,
      size,
      depth: 0.15,
      base: 0.62,
      amp: 0.05,
      light: const Color(0xFFE7B57A),
      dark: const Color(0xFFC08048),
      seed: 1,
    );
    sc.dunes(
      canvas,
      size,
      depth: 0.35,
      base: 0.68,
      amp: 0.045,
      light: const Color(0xFFDDA160),
      dark: const Color(0xFFAE6E37),
      seed: 2,
    );
    if (w.oasisX != null) {
      _oasis(canvas, size, w.oasisX! * size.width, size.height * 0.74, camel);
    }
    if (w.gateX != null) _gate(canvas, size, w.gateX! * size.width, ground);
    sc.dunes(
      canvas,
      size,
      depth: 1.0,
      base: CaravanWorld.groundY,
      amp: 0.012,
      light: const Color(0xFFCB8A4A),
      dark: const Color(0xFF9A5E2C),
      seed: 3,
    );
    sc.roadDetail(canvas, size, camel);
    for (final r in w.rocks) {
      final at = Offset(r.x * size.width, ground);
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(camel * 0.05, 0),
          width: camel * 0.75,
          height: camel * 0.1,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      _rock(canvas, at, camel * 0.3);
    }
    for (final b in w.birds) {
      _birds(canvas, Offset(b.x * size.width, ground - camel * 0.95), camel);
    }
    for (final l in w.lanterns) {
      if (l.taken) continue;
      final at = Offset(l.x * size.width, size.height * w.ly(l));
      l.golden
          ? _star(canvas, at, camel * 0.3)
          : _lantern(canvas, at, camel * 0.22);
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
      final foot = Offset(x, ground - lift);
      sc.camelShadow(canvas, foot, camel, lift);
      if (i == 0) sc.dust(canvas, Offset(x, ground), camel, lift < 1);
      // A crouch squashes the camel down toward its feet.
      final squash = 1 - 0.45 * w.crouchAt(i);
      canvas.save();
      canvas.translate(foot.dx, foot.dy);
      canvas.scale(1, squash);
      canvas.translate(-foot.dx, -foot.dy);
      _camel(
        canvas,
        foot,
        camel,
        w.stride + i * 0.33,
        hurt: i == 0 && w.hurtFor > 0,
      );
      canvas.restore();
    }
    if (w.storm > 0.01) _storm(canvas, size);
    sc.vignette(canvas, size);
    for (final p in w.popups) {
      _popup(canvas, size, p, camel);
    }
  }

  /// A flock of five birds in a loose V, wings beating.
  void _birds(Canvas canvas, Offset c, double camel) {
    final paint = Paint()
      ..color = const Color(0xFF3B2A20)
      ..strokeWidth = camel * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const spots = [
      (0.0, 0.0),
      (-0.28, -0.18),
      (0.28, -0.16),
      (-0.5, -0.32),
      (0.5, 0.06),
    ];
    for (var i = 0; i < spots.length; i++) {
      final (dx, dy) = spots[i];
      final o = c.translate(dx * camel, dy * camel);
      final flap = math.sin(w.time * 14 + i) * camel * 0.08;
      final span = camel * 0.16;
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - span, o.dy - flap)
          ..quadraticBezierTo(
            o.dx - span * 0.4,
            o.dy - flap * 0.2 - camel * 0.04,
            o.dx,
            o.dy,
          )
          ..quadraticBezierTo(
            o.dx + span * 0.4,
            o.dy - flap * 0.2 - camel * 0.04,
            o.dx + span,
            o.dy - flap,
          ),
        paint,
      );
    }
  }

  /// The golden star: an eight-pointed star that turns and glows.
  void _star(Canvas canvas, Offset c, double s) {
    final pulse = 1 + math.sin(w.time * 5) * 0.12;
    canvas.drawCircle(
      c,
      s * 2.2 * pulse,
      Paint()
        ..color = _gold.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(w.time * 0.8);
    for (final a in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.rotate(a);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: s * 1.5 * pulse,
          height: s * 1.5 * pulse,
        ),
        Paint()..color = a == 0 ? _gold : const Color(0xFFFFF2B8),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// The oasis passing in the middle distance: a pool and its palms.
  void _oasis(Canvas canvas, Size size, double cx, double base, double camel) {
    final pool = Rect.fromCenter(
      center: Offset(cx, base),
      width: camel * 3.2,
      height: camel * 0.45,
    );
    canvas.drawOval(
      pool.inflate(camel * 0.12),
      Paint()..color = const Color(0xFF7FA35A),
    );
    canvas.drawOval(
      pool,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FA3C7), Color(0xFF2E6F9E)],
        ).createShader(pool),
    );
    // Light on the water.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x =
          cx - camel + i * camel * 0.8 + math.sin(w.time * 2 + i) * camel * 0.1;
      canvas.drawLine(
        Offset(x, base - camel * 0.05 + i * 4),
        Offset(x + camel * 0.3, base - camel * 0.05 + i * 4),
        shine,
      );
    }
    for (final (dx, k) in [
      (-1.7, 1.25),
      (-1.1, 0.95),
      (1.3, 1.15),
      (1.85, 0.8),
    ]) {
      _palm(
        canvas,
        Offset(cx + dx * camel, base + camel * 0.05),
        camel * 1.9 * k,
      );
    }
  }

  /// The sandstorm: an ochre veil and streaks of blown sand.
  void _storm(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFD9A35F).withValues(alpha: 0.42 * w.storm),
    );
    final streak = Paint()
      ..color = const Color(0xFFFFE2B0).withValues(alpha: 0.55 * w.storm)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(11);
    for (var i = 0; i < 70; i++) {
      final y = rnd.nextDouble() * size.height;
      final speed = 0.8 + rnd.nextDouble() * 1.4;
      final x =
          size.width -
          ((w.time * speed * size.width + rnd.nextDouble() * size.width) %
              (size.width * 1.2));
      final len = 18 + rnd.nextDouble() * 40;
      canvas.drawLine(Offset(x, y), Offset(x + len, y - len * 0.08), streak);
    }
  }

  void _popup(Canvas canvas, Size size, Popup p, double camel) {
    final a = (1 - p.age / 1.1).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: p.text,
        style: TextStyle(
          color: (p.gold ? const Color(0xFFFFE08A) : Colors.white).withValues(
            alpha: a,
          ),
          fontSize: camel * (p.gold ? 0.24 : 0.2),
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        p.x * size.width - tp.width / 2,
        p.y * size.height - camel * 0.3 - p.age * camel * 0.7,
      ),
    );
    tp.dispose();
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
    final body = hurt ? const Color(0xFF9B4A32) : const Color(0xFF7A4B2A);
    const shade = Color(0xFF4E2F1A);
    final legLen = h * 0.42;
    final hip = foot.translate(0, -legLen);
    // Sunlit back, shaded belly: one gradient over the whole animal.
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(body, const Color(0xFFE0A86A), 0.35)!,
          body,
          Color.lerp(body, Colors.black, 0.3)!,
        ],
      ).createShader(
        Rect.fromLTWH(hip.dx - h * 0.5, hip.dy - h * 0.6, h * 1.1, h * 0.7),
      );
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
    // Tassels hanging from the saddle cloth, swinging with the walk.
    final tassel = Paint()
      ..color = _gold
      ..strokeWidth = h * 0.018
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final top = hip.translate(-h * 0.19 + k * h * 0.1, -h * 0.13);
      final sw = math.sin(stride * 2 * math.pi + k) * h * 0.035;
      final end = top.translate(sw, h * 0.09);
      canvas.drawLine(top, end, tassel);
      canvas.drawCircle(end, h * 0.018, Paint()..color = const Color(0xFFC0392B));
    }
    // Ear and eye.
    final head = Offset(hip.dx + h * 0.52, hip.dy - h * 0.46 + nod);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - h * 0.06, head.dy - h * 0.03)
        ..lineTo(head.dx - h * 0.09, head.dy - h * 0.1)
        ..lineTo(head.dx - h * 0.02, head.dy - h * 0.045)
        ..close(),
      Paint()..color = shade,
    );
    canvas.drawCircle(
      head.translate(h * 0.02, -h * 0.015),
      h * 0.016,
      Paint()..color = const Color(0xFF1B0F08),
    );
    canvas.drawCircle(
      head.translate(h * 0.026, -h * 0.02),
      h * 0.005,
      Paint()..color = Colors.white,
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
