/// Ten Islamic grounds for the adhan screen, drawn.
///
/// Every one of them takes the same three things: the prayer's own two sky
/// colours, the accent the scene already uses for light, and `t` — seconds on
/// the scene's thirty-minute clock. Nothing here loops in under a minute, and
/// nothing here uses a blur: three full-screen `MaskFilter` passes per frame
/// is what the old RGB backdrop did before it was rewritten, and it cost more
/// than it was worth.
///
/// The sky itself is always painted first, so text laid over any of the ten
/// sits on a known gradient rather than on whatever the pattern happens to
/// leave behind.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../data/adhan_background.dart';

/// Paints [style] across [rect]. [top] and [bottom] are the prayer's sky,
/// [accent] the colour its light is drawn in.
void paintAdhanBackground(
  Canvas canvas,
  Rect rect,
  AdhanBackground style,
  Color top,
  Color bottom,
  Color accent,
  double t,
) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect),
  );
  canvas.save();
  canvas.clipRect(rect);
  switch (style) {
    case AdhanBackground.horizon:
      _stars(canvas, rect, accent, t);
    case AdhanBackground.girih:
      _girih(canvas, rect, accent, t);
    case AdhanBackground.medallions:
      _medallions(canvas, rect, accent, t);
    case AdhanBackground.arabesque:
      _arabesque(canvas, rect, accent, t);
    case AdhanBackground.muqarnas:
      _muqarnas(canvas, rect, accent, t);
    case AdhanBackground.lanterns:
      _lanterns(canvas, rect, accent, t);
    case AdhanBackground.khatim:
      _khatim(canvas, rect, accent, t);
    case AdhanBackground.crescents:
      _crescents(canvas, rect, accent, t);
    case AdhanBackground.ribbons:
      _ribbons(canvas, rect, accent, t);
    case AdhanBackground.domes:
      _domes(canvas, rect, accent, t);
  }
  canvas.restore();
}

Paint _line(Color c, double a, [double w = 1.2]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..color = c.withValues(alpha: a);

Paint _fill(Color c, double a) => Paint()..color = c.withValues(alpha: a);

/// A deterministic pseudo-random in [0,1) — the same seed gives the same sky
/// every time, so a star does not jump when the widget rebuilds.
double _rnd(int seed) {
  final x = math.sin(seed * 127.1) * 43758.5453;
  return x - x.floorToDouble();
}

// ── 1. horizon ──────────────────────────────────────────────────────────
void _stars(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 70; i++) {
    final x = r.left + _rnd(i * 3) * r.width;
    final y = r.top + _rnd(i * 3 + 1) * r.height * 0.78;
    // Every star breathes on its own period, all of them long.
    final phase = _rnd(i * 3 + 2) * math.pi * 2;
    final a = 0.18 + 0.42 * (0.5 + 0.5 * math.sin(t * 0.22 + phase));
    canvas.drawCircle(Offset(x, y), 0.8 + _rnd(i * 7) * 1.5, _fill(accent, a));
  }
}

// ── 2. girih ────────────────────────────────────────────────────────────
void _girih(Canvas canvas, Rect r, Color accent, double t) {
  const cell = 120.0;
  final drift = (t * 3.0) % cell;
  final paint = _line(accent, 0.22);
  for (var gy = -1; gy * cell < r.height + cell; gy++) {
    for (var gx = -1; gx * cell < r.width + cell; gx++) {
      final cx = r.left + gx * cell + drift;
      final cy = r.top + gy * cell + drift * 0.5;
      _star10(canvas, Offset(cx, cy), cell * 0.46, paint);
      // The strapwork between stars: the diagonals that make it interlace.
      canvas.drawLine(Offset(cx, cy + cell * 0.5),
          Offset(cx + cell * 0.5, cy), _line(accent, 0.10));
      canvas.drawLine(Offset(cx, cy + cell * 0.5),
          Offset(cx - cell * 0.5, cy), _line(accent, 0.10));
    }
  }
}

void _star10(Canvas canvas, Offset c, double rOut, Paint p) {
  final path = Path();
  const points = 10;
  for (var i = 0; i < points * 2; i++) {
    final rad = i.isEven ? rOut : rOut * 0.52;
    final a = i * math.pi / points - math.pi / 2;
    final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  canvas.drawPath(path..close(), p);
}

// ── 3. medallions ───────────────────────────────────────────────────────
void _medallions(Canvas canvas, Rect r, Color accent, double t) {
  final c = r.center;
  for (var ring = 0; ring < 4; ring++) {
    final radius = r.shortestSide * (0.18 + ring * 0.17);
    // Alternate rings turn against each other: two speeds, no shared period.
    final spin = t * (ring.isEven ? 0.05 : -0.037) + ring;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    _rubElHizb(canvas, radius, _line(accent, 0.26 - ring * 0.045));
    canvas.restore();
  }
}

void _rubElHizb(Canvas canvas, double radius, Paint p) {
  final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
  canvas.drawRect(rect, p);
  canvas.save();
  canvas.rotate(math.pi / 4);
  canvas.drawRect(rect, p);
  canvas.restore();
  canvas.drawCircle(Offset.zero, radius * 0.24, p);
}

// ── 4. arabesque ────────────────────────────────────────────────────────
void _arabesque(Canvas canvas, Rect r, Color accent, double t) {
  for (var v = 0; v < 5; v++) {
    final path = Path();
    final baseY = r.top + r.height * (0.16 + v * 0.17);
    final amp = r.height * 0.055 * (1 + v * 0.18);
    final speed = 0.06 + v * 0.013;
    path.moveTo(r.left - 40, baseY);
    for (var x = r.left - 40.0; x <= r.right + 40; x += 14) {
      final y = baseY +
          math.sin((x / r.width) * math.pi * 3 + t * speed + v) * amp +
          math.sin((x / r.width) * math.pi * 7 - t * speed * 0.6) * amp * 0.3;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, _line(accent, 0.16 + v * 0.02, 1.6));
    // Leaves along the vine, sized by where they sit on it.
    for (final m in path.computeMetrics()) {
      _leaves(canvas, m, accent, t + v);
    }
  }
}

void _leaves(Canvas canvas, PathMetric m, Color accent, double t) {
  const step = 90.0;
  for (var d = (t * 6) % step; d < m.length; d += step) {
    final tan = m.getTangentForOffset(d);
    if (tan == null) continue;
    canvas.save();
    canvas.translate(tan.position.dx, tan.position.dy);
    canvas.rotate(tan.angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(7, -6, 15, 0)
      ..quadraticBezierTo(7, 6, 0, 0);
    canvas.drawPath(path, _fill(accent, 0.13));
    canvas.restore();
  }
}

// ── 5. muqarnas ─────────────────────────────────────────────────────────
void _muqarnas(Canvas canvas, Rect r, Color accent, double t) {
  const tiers = 6;
  for (var tier = 0; tier < tiers; tier++) {
    final cells = 3 + tier * 2;
    final w = r.width / cells;
    final h = r.height * 0.13;
    final y = r.top + tier * h * 0.82;
    for (var i = 0; i < cells; i++) {
      final x = r.left + i * w;
      // One travelling highlight, crossing all tiers on a long diagonal.
      final lit = math.sin(t * 0.18 - tier * 0.5 - i * 0.35);
      final a = 0.06 + 0.14 * (0.5 + 0.5 * lit);
      final niche = Path()
        ..moveTo(x, y + h)
        ..lineTo(x, y + h * 0.42)
        ..arcToPoint(Offset(x + w, y + h * 0.42),
            radius: Radius.circular(w * 0.6))
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(niche, _fill(accent, a));
      canvas.drawPath(niche, _line(accent, 0.12));
    }
  }
}

// ── 6. lanterns ─────────────────────────────────────────────────────────
void _lanterns(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 11; i++) {
    final speed = 9 + _rnd(i) * 11;
    // Each lantern has its own travel, so they never line up.
    final y = r.bottom - ((t * speed + _rnd(i + 40) * 900) % (r.height + 160));
    final x = r.left +
        r.width * _rnd(i + 80) +
        math.sin(t * 0.15 + i) * r.width * 0.035;
    final s = 12 + _rnd(i + 120) * 16;
    final a = 0.5 * (1 - (y - r.top).abs() / (r.height * 1.4)).clamp(0.0, 1.0);
    final body = Path()
      ..moveTo(x, y - s)
      ..lineTo(x + s * 0.5, y - s * 0.35)
      ..lineTo(x + s * 0.36, y + s * 0.55)
      ..lineTo(x - s * 0.36, y + s * 0.55)
      ..lineTo(x - s * 0.5, y - s * 0.35)
      ..close();
    canvas.drawPath(body, _fill(accent, a * 0.35));
    canvas.drawPath(body, _line(accent, a * 0.8));
    canvas.drawCircle(Offset(x, y + s * 0.1), s * 0.16, _fill(accent, a));
  }
}

// ── 7. khatim ───────────────────────────────────────────────────────────
void _khatim(Canvas canvas, Rect r, Color accent, double t) {
  const cell = 96.0;
  for (var gy = 0; gy * cell < r.height + cell; gy++) {
    for (var gx = 0; gx * cell < r.width + cell; gx++) {
      final c = Offset(r.left + gx * cell + cell / 2,
          r.top + gy * cell + cell / 2);
      // The breath travels as a wave across the grid, not all at once.
      final wave = math.sin(t * 0.5 - (gx + gy) * 0.6);
      final size = cell * (0.22 + 0.05 * wave);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * 0.01 + (gx + gy) * 0.2);
      final sq = Rect.fromCenter(
          center: Offset.zero, width: size * 2, height: size * 2);
      final p = _line(accent, 0.10 + 0.10 * (0.5 + 0.5 * wave));
      canvas.drawRect(sq, p);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(sq, p);
      canvas.restore();
    }
  }
}

// ── 8. crescents ────────────────────────────────────────────────────────
void _crescents(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 9; i++) {
    final radius = r.shortestSide * (0.07 + _rnd(i) * 0.16);
    final speed = 4 + _rnd(i + 11) * 7;
    final x = r.left + ((t * speed + _rnd(i + 22) * 2000) % (r.width + 300)) -
        150;
    final y = r.top + r.height * (0.08 + _rnd(i + 33) * 0.7);
    // The crescent is a circle with a circle taken out of it, which needs a
    // layer — the same trick the app's own moon uses.
    canvas.saveLayer(
        Rect.fromCircle(center: Offset(x, y), radius: radius * 1.4), Paint());
    canvas.drawCircle(Offset(x, y), radius, _fill(accent, 0.16));
    canvas.drawCircle(Offset(x + radius * 0.42, y - radius * 0.16), radius,
        Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }
}

// ── 9. ribbons ──────────────────────────────────────────────────────────
void _ribbons(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 4; i++) {
    final path = Path();
    final baseY = r.top + r.height * (0.22 + i * 0.19);
    final amp = r.height * (0.06 + i * 0.012);
    path.moveTo(r.left - 30, baseY);
    for (var x = r.left - 30.0; x <= r.right + 30; x += 10) {
      final u = (x - r.left) / r.width;
      final y = baseY +
          math.sin(u * math.pi * 2.2 + t * (0.05 + i * 0.008)) * amp +
          math.cos(u * math.pi * 5 - t * 0.03) * amp * 0.25;
      path.lineTo(x, y);
    }
    // Drawn twice at two widths: a calligraphic stroke is thick and thin, and
    // two passes give that without a shader.
    canvas.drawPath(path, _line(accent, 0.10, 9));
    canvas.drawPath(path, _line(accent, 0.26, 2.2));
  }
}

// ── 10. domes ───────────────────────────────────────────────────────────
void _domes(Canvas canvas, Rect r, Color accent, double t) {
  final origin = Offset(r.center.dx, r.bottom - r.height * 0.08);
  const period = 7.0;
  for (var i = 0; i < 7; i++) {
    final phase = ((t / period) + i / 7) % 1.0;
    final radius = r.width * (0.08 + phase * 0.95);
    final a = 0.30 * (1 - phase) * (1 - phase);
    // A dome, not a circle: the arc is carried on a short vertical neck.
    final path = Path()
      ..moveTo(origin.dx - radius, origin.dy)
      ..lineTo(origin.dx - radius, origin.dy - radius * 0.18)
      ..arcToPoint(
        Offset(origin.dx + radius, origin.dy - radius * 0.18),
        radius: Radius.circular(radius),
      )
      ..lineTo(origin.dx + radius, origin.dy);
    canvas.drawPath(path, _line(accent, a, 2));
  }
}
