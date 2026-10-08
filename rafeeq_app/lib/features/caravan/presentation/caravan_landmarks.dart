/// What leg two of «قافلة الدرب» passes and reaches: olive groves and
/// cypresses on the road north into al-Sham, a crescent rising as the sun
/// sets, the night with its fireflies and lantern light, and the stone
/// walls of Bayt al-Maqdis lit for the caravan's arrival.
///
/// The city is drawn as walls, towers, a gate and lamps only - no dome,
/// because the gate question is about its opening in the caliphate of
/// ʿUmar ﵁, before any of the domes that stand there now were built. No
/// people are drawn.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/caravan_world.dart';

class CaravanLandmarks {
  final CaravanWorld w;
  const CaravanLandmarks(this.w);

  static const _lamp = Color(0xFFFFD27A);

  double get _p => w.progress.clamp(0.0, 1.0);

  /// A crescent that rises on the right as the sun goes down.
  void moon(Canvas canvas, Size size) {
    final t = ((_p - 0.45) / 0.45).clamp(0.0, 1.0);
    if (t <= 0) return;
    final r = math.min(size.width, size.height) * 0.05;
    final c = Offset(
      size.width * (0.86 - 0.08 * t),
      size.height * (0.6 - 0.44 * t),
    );
    canvas.drawCircle(
      c,
      r * 3,
      Paint()
        ..color = const Color(0xFFDDE6FF).withValues(alpha: 0.22 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    final rect = Rect.fromCircle(center: c, radius: r * 1.4);
    canvas.saveLayer(rect, Paint());
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFFFFF6D8).withValues(alpha: t),
    );
    canvas.drawCircle(
      c.translate(r * 0.42, -r * 0.18),
      r * 0.86,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  /// The grove passing in the middle distance where leg one had its oasis:
  /// olive trees, two dark cypresses, and a low stone terrace wall.
  void olives(Canvas canvas, Size size, double cx, double base, double camel) {
    final wall = Rect.fromLTWH(
      cx - camel * 2.4,
      base - camel * 0.12,
      camel * 4.8,
      camel * 0.16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wall, Radius.circular(camel * 0.04)),
      Paint()..color = _shade(const Color(0xFFCDB894)),
    );
    final joint = Paint()
      ..color = _shade(const Color(0xFF9C8763))
      ..strokeWidth = 1;
    for (var x = wall.left + camel * 0.3; x < wall.right; x += camel * 0.3) {
      canvas.drawLine(Offset(x, wall.top), Offset(x, wall.bottom), joint);
    }
    for (final (dx, k) in [
      (-2.0, 1.1),
      (-1.25, 0.85),
      (1.3, 1.0),
      (2.1, 0.8),
    ]) {
      _cypress(canvas, Offset(cx + dx * camel, base), camel * 1.6 * k);
    }
    for (final (dx, k) in [(-1.6, 1.0), (-0.5, 1.2), (0.6, 0.95), (1.7, 1.1)]) {
      _olive(canvas, Offset(cx + dx * camel, base), camel * k);
    }
  }

  /// An olive: a short twisted trunk and a wide silver-green crown.
  void _olive(Canvas canvas, Offset foot, double h) {
    final trunk = Paint()
      ..color = _shade(const Color(0xFF6B5138))
      ..strokeWidth = h * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..cubicTo(
          foot.dx - h * 0.12,
          foot.dy - h * 0.2,
          foot.dx + h * 0.1,
          foot.dy - h * 0.35,
          foot.dx,
          foot.dy - h * 0.55,
        ),
      trunk,
    );
    final sway = math.sin(w.time * 1.2 + foot.dx / 50) * h * 0.02;
    final crown = foot.translate(sway, -h * 0.72);
    final leaf = Paint()..color = _shade(const Color(0xFF7D8F5A));
    final light = Paint()..color = _shade(const Color(0xFFA9B884));
    for (final (dx, dy, r) in [
      (0.0, 0.0, 0.34),
      (-0.3, 0.08, 0.26),
      (0.3, 0.06, 0.27),
      (-0.14, -0.2, 0.24),
      (0.16, -0.18, 0.23),
    ]) {
      canvas.drawCircle(crown.translate(dx * h, dy * h), r * h, leaf);
    }
    for (final (dx, dy, r) in [(-0.1, -0.22, 0.12), (0.2, -0.16, 0.1)]) {
      canvas.drawCircle(crown.translate(dx * h, dy * h), r * h, light);
    }
  }

  /// A cypress: a tall dark flame of a tree.
  void _cypress(Canvas canvas, Offset foot, double h) {
    final sway = math.sin(w.time * 1.4 + foot.dx / 40) * h * 0.015;
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx - h * 0.09, foot.dy)
        ..quadraticBezierTo(
          foot.dx - h * 0.13,
          foot.dy - h * 0.55,
          foot.dx + sway,
          foot.dy - h,
        )
        ..quadraticBezierTo(
          foot.dx + h * 0.13,
          foot.dy - h * 0.55,
          foot.dx + h * 0.09,
          foot.dy,
        )
        ..close(),
      Paint()..color = _shade(const Color(0xFF2F5134)),
    );
  }

  /// The walls of Bayt al-Maqdis: pale stone, square towers with lamps,
  /// a pointed gate whose doors open as [CaravanWorld.gateOpen] goes 0 -> 1,
  /// and warm light behind the doors.
  void qudsGate(Canvas canvas, Size size, double cx, double ground) {
    final h = size.height * 0.34;
    final stone = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _shade(const Color(0xFFEADBB8)),
              _shade(const Color(0xFFC9B48C)),
            ],
          ).createShader(
            Rect.fromLTWH(cx - h * 1.6, ground - h * 1.2, h * 3.2, h * 1.2),
          );
    final course = Paint()
      ..color = _shade(const Color(0xFFAE9A72))
      ..strokeWidth = 1;
    final wall = Rect.fromLTWH(
      cx - h * 1.5,
      ground - h * 0.82,
      h * 3.0,
      h * 0.82,
    );
    canvas.drawRect(wall, stone);
    for (var y = wall.top + h * 0.12; y < ground; y += h * 0.12) {
      canvas.drawLine(Offset(wall.left, y), Offset(wall.right, y), course);
    }
    // Towers: two flanking the gate, two at the ends.
    for (final dx in [-1.45, -0.42, 0.42, 1.45]) {
      final tw = h * (dx.abs() < 1 ? 0.3 : 0.26);
      final th = h * (dx.abs() < 1 ? 1.08 : 0.98);
      final tower = Rect.fromLTWH(cx + dx * h - tw / 2, ground - th, tw, th);
      canvas.drawRect(tower, stone);
      for (var x = tower.left; x < tower.right - 1; x += tw / 3) {
        canvas.drawRect(
          Rect.fromLTWH(x, tower.top - h * 0.07, tw / 5, h * 0.07),
          stone,
        );
      }
      // An arrow-slit window, lit at night.
      final win = Rect.fromCenter(
        center: Offset(tower.center.dx, tower.top + th * 0.3),
        width: tw * 0.18,
        height: th * 0.16,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(win, Radius.circular(tw * 0.09)),
        Paint()..color = Color.lerp(const Color(0xFF6E5A3C), _lamp, w.night)!,
      );
      _glow(canvas, win.center, h * 0.12, w.night * 0.8);
    }
    // Battlements along the wall.
    for (var x = wall.left; x < wall.right; x += h * 0.14) {
      canvas.drawRect(
        Rect.fromLTWH(x, wall.top - h * 0.06, h * 0.08, h * 0.06),
        stone,
      );
    }
    // The gate: a pointed arch, warm light behind its doors.
    final archW = h * 0.42, archH = h * 0.62;
    final arch = Path()
      ..moveTo(cx - archW / 2, ground)
      ..lineTo(cx - archW / 2, ground - archH * 0.55)
      ..quadraticBezierTo(
        cx - archW / 2,
        ground - archH * 0.9,
        cx,
        ground - archH,
      )
      ..quadraticBezierTo(
        cx + archW / 2,
        ground - archH * 0.9,
        cx + archW / 2,
        ground - archH * 0.55,
      )
      ..lineTo(cx + archW / 2, ground)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFFFFE3A0));
    _glow(canvas, Offset(cx, ground - archH * 0.4), archW * w.gateOpen, 0.9);
    final doorW = archW / 2 * (1 - w.gateOpen);
    final door = Paint()..color = const Color(0xFF5E3B20);
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
    canvas.drawPath(
      arch,
      Paint()
        ..color = _shade(const Color(0xFF9C8763))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Two lamps on brackets either side of the gate, flickering.
    for (final dx in [-0.3, 0.3]) {
      final at = Offset(cx + dx * h, ground - archH * 0.85);
      final flicker = 0.85 + 0.15 * math.sin(w.time * 9 + dx * 10);
      _glow(canvas, at, h * 0.2 * flicker, 0.35 + 0.6 * w.night);
      canvas.drawCircle(at, h * 0.025, Paint()..color = _lamp);
    }
    for (final dx in [-1.85, 1.8, 2.15]) {
      _cypress(canvas, Offset(cx + dx * h, ground), h * 0.95);
    }
    _olive(canvas, Offset(cx - h * 2.2, ground), h * 0.55);
  }

  /// Night over the land: a deep blue veil, then the light that cuts
  /// through it - each lantern's glow and
  /// fireflies drifting over the road.
  void nightVeil(Canvas canvas, Size size, double camel) {
    final n = w.night;
    if (n < 0.01) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0F2E).withValues(alpha: 0.22 * n),
    );
    for (final l in w.lanterns) {
      if (l.taken) continue;
      _glow(
        canvas,
        Offset(l.x * size.width, w.ly(l) * size.height),
        camel * (l.golden ? 0.9 : 0.55),
        0.55 * n,
      );
    }
    final rnd = math.Random(31);
    for (var i = 0; i < 18; i++) {
      final fx =
          (rnd.nextDouble() -
              w.distance * 0.6 +
              math.sin(w.time * 0.7 + i) * 0.02) %
          1.0;
      final fy =
          0.55 +
          rnd.nextDouble() * 0.3 +
          math.sin(w.time * 1.3 + i * 2) * 0.015;
      final blink = 0.5 + 0.5 * math.sin(w.time * (2 + i % 3) + i);
      final at = Offset(fx * size.width, fy * size.height);
      _glow(canvas, at, camel * 0.06, 0.7 * n * blink);
      canvas.drawCircle(
        at,
        1.6,
        Paint()..color = const Color(0xFFF4FFB0).withValues(alpha: n * blink),
      );
    }
  }

  /// Water for the legs by boat - the sea to Abyssinia, the Tigris, the
  /// Nile: bands of blue from the horizon down, lines of light drifting
  /// at their own depth.
  void sea(Canvas canvas, Size size) {
    final top = size.height * 0.64;
    final rect = Rect.fromLTWH(0, top, size.width, size.height - top);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _shade(const Color(0xFF4FA3C7)),
            _shade(const Color(0xFF1B4F7A)),
          ],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * (1 - 0.5 * w.night))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(9);
    for (var i = 0; i < 26; i++) {
      final depth = 0.3 + rnd.nextDouble() * 0.9;
      final y = top + (size.height - top) * rnd.nextDouble();
      final x = ((rnd.nextDouble() - w.distance * depth) % 1.0) * size.width;
      final len = 14 + depth * 26;
      final bob = math.sin(w.time * 2 + i) * 2;
      canvas.drawLine(Offset(x, y + bob), Offset(x + len, y + bob), line);
    }
  }

  /// A breaking wave: the obstacle of a leg by boat.
  void wave(Canvas canvas, Offset foot, double s) {
    final curl = math.sin(w.time * 4 + foot.dx / 30) * s * 0.08;
    final path = Path()
      ..moveTo(foot.dx - s * 1.2, foot.dy)
      ..quadraticBezierTo(
        foot.dx - s * 0.6,
        foot.dy - s * 0.2,
        foot.dx - s * 0.2,
        foot.dy - s,
      )
      ..quadraticBezierTo(
        foot.dx + s * 0.3 + curl,
        foot.dy - s * 1.35,
        foot.dx + s * 0.55,
        foot.dy - s * 0.8,
      )
      ..quadraticBezierTo(
        foot.dx + s * 0.25,
        foot.dy - s * 0.85,
        foot.dx + s * 0.35,
        foot.dy - s * 0.55,
      )
      ..quadraticBezierTo(
        foot.dx + s * 0.8,
        foot.dy - s * 0.2,
        foot.dx + s * 1.2,
        foot.dy,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFBFE6F5),
                _shade(const Color(0xFF2E7DAA)),
              ],
            ).createShader(
              Rect.fromLTWH(foot.dx - s, foot.dy - s * 1.4, s * 2, s * 1.4),
            ),
    );
    canvas.drawCircle(
      foot.translate(s * 0.35, -s * 1.05),
      s * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  /// A small island passing where the land legs have their oasis.
  void island(Canvas canvas, double cx, double base, double camel) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, base),
        width: camel * 3,
        height: camel * 0.4,
      ),
      Paint()..color = _shade(const Color(0xFFE7C38A)),
    );
    for (final (dx, k) in [(-0.6, 1.1), (0.5, 0.85)]) {
      final foot = Offset(cx + dx * camel, base - camel * 0.05);
      final h = camel * 1.5 * k;
      final top = foot.translate(h * 0.1, -h);
      canvas.drawLine(
        foot,
        top,
        Paint()
          ..color = _shade(const Color(0xFF7A5230))
          ..strokeWidth = h * 0.06
          ..strokeCap = StrokeCap.round,
      );
      final leaf = Paint()..color = _shade(const Color(0xFF3F7A3A));
      for (var i = 0; i < 6; i++) {
        final a = -math.pi + i * math.pi / 5;
        canvas.drawOval(
          Rect.fromCenter(
            center: top.translate(
              math.cos(a) * h * 0.22,
              math.sin(a) * h * 0.1 + h * 0.06,
            ),
            width: h * 0.42,
            height: h * 0.1,
          ),
          leaf,
        );
      }
    }
  }

  /// A rocky peak rising from the ground: the obstacle of a flown leg.
  void peak(Canvas canvas, Offset foot, double camel) {
    final h = camel * 1.05, b = camel * 0.55;
    final path = Path()
      ..moveTo(foot.dx - b, foot.dy)
      ..lineTo(foot.dx - b * 0.2, foot.dy - h)
      ..lineTo(foot.dx + b * 0.15, foot.dy - h * 0.85)
      ..lineTo(foot.dx + b, foot.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _shade(const Color(0xFF6D5446)));
    canvas.drawPath(
      Path()
        ..moveTo(foot.dx - b * 0.2, foot.dy - h)
        ..lineTo(foot.dx + b * 0.15, foot.dy - h * 0.85)
        ..lineTo(foot.dx + b * 0.4, foot.dy - h * 0.4)
        ..close(),
      Paint()..color = _shade(const Color(0xFF8E7462)),
    );
  }

  /// A dark storm cloud with a flicker of lightning: the sky's obstacle.
  void cloud(Canvas canvas, Offset c, double camel) {
    final paint = Paint()..color = const Color(0xFF4A4F66);
    for (final (dx, dy, r) in [
      (0.0, 0.0, 0.32),
      (-0.3, 0.08, 0.24),
      (0.3, 0.06, 0.26),
      (0.12, -0.16, 0.22),
    ]) {
      canvas.drawCircle(c.translate(dx * camel, dy * camel), r * camel, paint);
    }
    if (math.sin(w.time * 3 + c.dx) > 0.92) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy + camel * 0.25)
          ..lineTo(c.dx - camel * 0.08, c.dy + camel * 0.45)
          ..lineTo(c.dx + camel * 0.02, c.dy + camel * 0.45)
          ..lineTo(c.dx - camel * 0.06, c.dy + camel * 0.68),
        Paint()
          ..color = const Color(0xFFFFF2A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _glow(Canvas canvas, Offset c, double r, double a) {
    if (r <= 0 || a <= 0) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _lamp.withValues(alpha: a),
            _lamp.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..blendMode = BlendMode.plus,
    );
  }

  /// Buildings and trees sink into the night with the land.
  Color _shade(Color c) =>
      Color.lerp(c, const Color(0xFF3A4270), 0.42 * w.night)!;
}
