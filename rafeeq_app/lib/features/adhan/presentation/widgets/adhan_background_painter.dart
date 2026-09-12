/// Ten Islamic grounds for the adhan screen, drawn.
///
/// Every one takes the same three things: the prayer's own two sky colours,
/// the accent its light is drawn in, and `t` — seconds on the scene's
/// thirty-minute clock. Nothing loops in under a minute, and nothing uses a
/// blur: three full-screen `MaskFilter` passes a frame is what the old RGB
/// backdrop did before it was rewritten, and it cost more than it was worth.
///
/// WHAT MAKES THEM READ AS DEPTH RATHER THAN AS WALLPAPER, since the first
/// attempt was thin strokes on a flat gradient and looked it:
///
///  * a **glow** behind everything — a radial gradient that drifts, so the
///    ground is lit from somewhere rather than evenly grey;
///  * **two or three layers** of the same motif at different scales, moving at
///    different speeds, which is parallax and costs nothing;
///  * **filled shapes under the strokes**, so an ornament has body;
///  * a **vignette** over everything, which is what keeps white text legible
///    at the edges and pushes the pattern back behind it.
///
/// All four are cheap: gradients and paths, no layers except where a crescent
/// genuinely needs one.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../data/adhan_background.dart';

/// Paints [style] across [rect].
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
  _glow(canvas, rect, accent, t);
  switch (style) {
    case AdhanBackground.horizon:
      _horizon(canvas, rect, accent, t);
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
  _vignette(canvas, rect);
  canvas.restore();
}

// ── shared ──────────────────────────────────────────────────────────────

Paint _line(Color c, double a, [double w = 1.2]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..color = c.withValues(alpha: a);

Paint _fill(Color c, double a) => Paint()..color = c.withValues(alpha: a);

/// The light behind the pattern. It wanders on a long ellipse, so the ground
/// is never lit the same way twice inside one adhan.
void _glow(Canvas canvas, Rect r, Color accent, double t) {
  final c = Offset(
    r.center.dx + math.cos(t * 0.035) * r.width * 0.26,
    r.top + r.height * 0.34 + math.sin(t * 0.028) * r.height * 0.12,
  );
  final radius = r.longestSide * 0.62;
  canvas.drawRect(
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.20),
          accent.withValues(alpha: 0.06),
          accent.withValues(alpha: 0.0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: c, radius: radius)),
  );
}

/// Darkens the corners. White text sits over these, and the pattern has to
/// stay behind it.
void _vignette(Canvas canvas, Rect r) {
  canvas.drawRect(
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.42),
        ],
        stops: const [0.35, 0.72, 1],
      ).createShader(
          Rect.fromCircle(center: r.center, radius: r.longestSide * 0.72)),
  );
}

/// Deterministic pseudo-random in [0,1): the same seed gives the same sky
/// every time, so nothing jumps when the widget rebuilds.
double _rnd(int seed) {
  final x = math.sin(seed * 127.1) * 43758.5453;
  return x - x.floorToDouble();
}

// ── 1. horizon ──────────────────────────────────────────────────────────
void _horizon(Canvas canvas, Rect r, Color accent, double t) {
  // Three depths of star, the nearest brightest and slowest — the oldest
  // trick there is for making a flat sky have a distance in it.
  for (var layer = 0; layer < 3; layer++) {
    final count = 34 - layer * 8;
    final size = 2.2 - layer * 0.6;
    final drift = t * (2.0 - layer * 0.6);
    for (var i = 0; i < count; i++) {
      final seed = layer * 200 + i * 3;
      final x = (r.left + _rnd(seed) * r.width + drift) % r.width;
      final y = r.top + _rnd(seed + 1) * r.height * 0.82;
      final a = (0.16 + 0.5 * (0.5 + 0.5 * math.sin(t * 0.25 + _rnd(seed + 2) * 6.28))) *
          (1 - layer * 0.26);
      canvas.drawCircle(Offset(x, y), size * (0.6 + _rnd(seed + 5) * 0.7),
          _fill(accent, a));
      // The brightest of the near stars get a four-point flare.
      if (layer == 0 && _rnd(seed + 9) > 0.82) {
        final s = size * 5;
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), _line(accent, a * 0.5, 0.9));
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), _line(accent, a * 0.5, 0.9));
      }
    }
  }
}

// ── 2. girih ────────────────────────────────────────────────────────────
void _girih(Canvas canvas, Rect r, Color accent, double t) {
  // Two lattices, the far one half the size and drifting the other way.
  _girihLayer(canvas, r, accent, t, 172, 1.0, 0.20);
  _girihLayer(canvas, r, accent, -t * 0.6, 96, 0.55, 0.10);
}

void _girihLayer(Canvas canvas, Rect r, Color accent, double t, double cell,
    double weight, double alpha) {
  final dx = (t * 2.4) % cell;
  final dy = (t * 1.2) % cell;
  final stroke = _line(accent, alpha, 1.4 * weight);
  final glint = _fill(accent, alpha * 0.32);
  for (var gy = -1; gy * cell < r.height + cell * 2; gy++) {
    for (var gx = -1; gx * cell < r.width + cell * 2; gx++) {
      final c = Offset(r.left + gx * cell + dx, r.top + gy * cell + dy);
      _star10(canvas, c, cell * 0.44, stroke, glint);
      // The strapwork that ties the stars together.
      final half = cell * 0.5;
      canvas.drawLine(c + Offset(0, half), c + Offset(half, 0),
          _line(accent, alpha * 0.55, 1.0 * weight));
      canvas.drawLine(c + Offset(0, half), c + Offset(-half, 0),
          _line(accent, alpha * 0.55, 1.0 * weight));
    }
  }
}

void _star10(Canvas canvas, Offset c, double rOut, Paint stroke, Paint fill) {
  final path = Path();
  const points = 10;
  for (var i = 0; i < points * 2; i++) {
    final rad = i.isEven ? rOut : rOut * 0.50;
    final a = i * math.pi / points - math.pi / 2;
    final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  canvas.drawPath(path, fill);
  canvas.drawPath(path, stroke);
}

// ── 3. medallions ───────────────────────────────────────────────────────
void _medallions(Canvas canvas, Rect r, Color accent, double t) {
  final c = Offset(r.center.dx, r.top + r.height * 0.42);
  for (var ring = 5; ring >= 0; ring--) {
    final radius = r.shortestSide * (0.13 + ring * 0.15);
    final spin = t * (ring.isEven ? 0.055 : -0.04) + ring * 0.7;
    final a = 0.30 - ring * 0.043;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    _rubElHizb(canvas, radius, _line(accent, a, 1.6), _fill(accent, a * 0.10));
    canvas.restore();
  }
  // A still centre, so the turning has something to turn around.
  canvas.drawCircle(c, r.shortestSide * 0.045, _fill(accent, 0.30));
  canvas.drawCircle(c, r.shortestSide * 0.072, _line(accent, 0.34, 1.6));
}

void _rubElHizb(Canvas canvas, double radius, Paint stroke, Paint fill) {
  final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
  canvas.drawRect(rect, fill);
  canvas.drawRect(rect, stroke);
  canvas.save();
  canvas.rotate(math.pi / 4);
  canvas.drawRect(rect, fill);
  canvas.drawRect(rect, stroke);
  canvas.restore();
  canvas.drawCircle(Offset.zero, radius * 0.22, stroke);
}

// ── 4. arabesque ────────────────────────────────────────────────────────
void _arabesque(Canvas canvas, Rect r, Color accent, double t) {
  for (var v = 0; v < 6; v++) {
    final path = Path();
    final baseY = r.top + r.height * (0.10 + v * 0.155);
    final amp = r.height * 0.06 * (1 + v * 0.14);
    final speed = 0.05 + v * 0.011;
    path.moveTo(r.left - 40, baseY);
    for (var x = r.left - 40.0; x <= r.right + 40; x += 12) {
      final u = (x - r.left) / r.width;
      final y = baseY +
          math.sin(u * math.pi * 3 + t * speed + v) * amp +
          math.sin(u * math.pi * 7 - t * speed * 0.6) * amp * 0.28;
      path.lineTo(x, y);
    }
    // The vine twice: a soft wide pass under a crisp thin one, which is how a
    // drawn line gets a body without a blur.
    canvas.drawPath(path, _line(accent, 0.07, 7));
    canvas.drawPath(path, _line(accent, 0.26, 1.7));
    for (final m in path.computeMetrics()) {
      _leaves(canvas, m, accent, t + v * 2);
    }
  }
}

void _leaves(Canvas canvas, PathMetric m, Color accent, double t) {
  const step = 74.0;
  for (var d = (t * 5) % step; d < m.length; d += step) {
    final tan = m.getTangentForOffset(d);
    if (tan == null) continue;
    canvas.save();
    canvas.translate(tan.position.dx, tan.position.dy);
    canvas.rotate(tan.angle);
    // A leaf and its mirror, so the vine has leaves on both sides.
    for (final s in const [1.0, -1.0]) {
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(9, -8 * s, 19, 0)
        ..quadraticBezierTo(9, 8 * s, 0, 0);
      canvas.drawPath(leaf, _fill(accent, 0.16));
      canvas.drawPath(leaf, _line(accent, 0.22, 0.9));
    }
    canvas.restore();
  }
}

// ── 5. muqarnas ─────────────────────────────────────────────────────────
void _muqarnas(Canvas canvas, Rect r, Color accent, double t) {
  const tiers = 9;
  final h = r.height / (tiers * 0.82);
  for (var tier = 0; tier < tiers; tier++) {
    final cells = 3 + tier * 2;
    final w = r.width / cells;
    final y = r.top + tier * h * 0.80;
    for (var i = 0; i < cells; i++) {
      // Alternate tiers are offset by half a cell, which is what makes
      // muqarnas read as stacked niches and not as a grid of arches.
      final x = r.left + i * w - (tier.isOdd ? w * 0.5 : 0);
      final lit = math.sin(t * 0.2 - tier * 0.55 - i * 0.3);
      final a = 0.05 + 0.18 * (0.5 + 0.5 * lit);
      final niche = Path()
        ..moveTo(x, y + h)
        ..lineTo(x, y + h * 0.46)
        ..arcToPoint(Offset(x + w, y + h * 0.46),
            radius: Radius.circular(w * 0.58))
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(
        niche,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.withValues(alpha: a),
              accent.withValues(alpha: a * 0.15),
            ],
          ).createShader(Rect.fromLTWH(x, y, w, h)),
      );
      canvas.drawPath(niche, _line(accent, 0.13 + 0.10 * (0.5 + 0.5 * lit)));
    }
  }
}

// ── 6. lanterns ─────────────────────────────────────────────────────────
void _lanterns(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 16; i++) {
    final depth = _rnd(i + 300);
    final speed = 7 + depth * 14;
    final y = r.bottom - ((t * speed + _rnd(i + 40) * 900) % (r.height + 200));
    final x = r.left +
        r.width * _rnd(i + 80) +
        math.sin(t * 0.14 + i) * r.width * 0.04;
    final s = 10 + depth * 22;
    final a = (0.25 + depth * 0.4) *
        (1 - ((y - r.top) / (r.height * 1.5)).abs()).clamp(0.0, 1.0);
    // The halo first, so the lantern sits inside its own light.
    canvas.drawCircle(
      Offset(x, y),
      s * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: a * 0.34),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: s * 2.2)),
    );
    final body = Path()
      ..moveTo(x, y - s * 1.15)
      ..lineTo(x + s * 0.52, y - s * 0.4)
      ..lineTo(x + s * 0.38, y + s * 0.6)
      ..lineTo(x - s * 0.38, y + s * 0.6)
      ..lineTo(x - s * 0.52, y - s * 0.4)
      ..close();
    canvas.drawPath(body, _fill(accent, a * 0.42));
    canvas.drawPath(body, _line(accent, a * 0.95, 1.3));
    // The little finial and the flame.
    canvas.drawLine(Offset(x, y - s * 1.15), Offset(x, y - s * 1.5),
        _line(accent, a * 0.7, 1.1));
    canvas.drawCircle(Offset(x, y + s * 0.05), s * 0.18, _fill(accent, a));
  }
}

// ── 7. khatim ───────────────────────────────────────────────────────────
void _khatim(Canvas canvas, Rect r, Color accent, double t) {
  const cell = 104.0;
  for (var gy = 0; gy * cell < r.height + cell; gy++) {
    for (var gx = 0; gx * cell < r.width + cell; gx++) {
      // Every other row is offset, so the field is a lattice and not a grid.
      final c = Offset(
        r.left + gx * cell + cell / 2 - (gy.isOdd ? cell * 0.5 : 0),
        r.top + gy * cell + cell / 2,
      );
      final wave = math.sin(t * 0.45 - (gx * 0.7 + gy * 0.5));
      final size = cell * (0.20 + 0.045 * wave);
      final a = 0.10 + 0.16 * (0.5 + 0.5 * wave);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * 0.012 + (gx + gy) * 0.2);
      final sq = Rect.fromCenter(
          center: Offset.zero, width: size * 2, height: size * 2);
      canvas.drawRect(sq, _fill(accent, a * 0.28));
      canvas.drawRect(sq, _line(accent, a, 1.3));
      canvas.rotate(math.pi / 4);
      canvas.drawRect(sq, _fill(accent, a * 0.28));
      canvas.drawRect(sq, _line(accent, a, 1.3));
      canvas.restore();
      canvas.drawCircle(c, size * 0.20, _fill(accent, a * 1.2));
    }
  }
}

// ── 8. crescents ────────────────────────────────────────────────────────
void _crescents(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 12; i++) {
    final depth = _rnd(i + 7);
    final radius = r.shortestSide * (0.05 + depth * 0.19);
    final speed = 3 + depth * 9;
    final x =
        r.left + ((t * speed + _rnd(i + 22) * 2000) % (r.width + 340)) - 170;
    final y = r.top + r.height * (0.06 + _rnd(i + 33) * 0.76);
    final a = 0.08 + depth * 0.20;
    // A circle with a circle cleared out of it — the same trick the scene's
    // own moon uses. It needs a layer, and it is the only one here that does.
    final bounds = Rect.fromCircle(center: Offset(x, y), radius: radius * 1.5);
    canvas.saveLayer(bounds, Paint());
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: a * 1.5),
            accent.withValues(alpha: a * 0.5),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius)),
    );
    canvas.drawCircle(Offset(x + radius * 0.40, y - radius * 0.18), radius,
        Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    // A star in the crook, as it is drawn on every minaret.
    if (depth > 0.55) {
      canvas.drawCircle(Offset(x + radius * 1.05, y + radius * 0.32),
          radius * 0.10, _fill(accent, a * 1.6));
    }
  }
}

// ── 9. ribbons ──────────────────────────────────────────────────────────
void _ribbons(Canvas canvas, Rect r, Color accent, double t) {
  for (var i = 0; i < 5; i++) {
    final path = Path();
    final baseY = r.top + r.height * (0.16 + i * 0.17);
    final amp = r.height * (0.055 + i * 0.011);
    path.moveTo(r.left - 30, baseY);
    for (var x = r.left - 30.0; x <= r.right + 30; x += 8) {
      final u = (x - r.left) / r.width;
      final y = baseY +
          math.sin(u * math.pi * 2.2 + t * (0.05 + i * 0.008)) * amp +
          math.cos(u * math.pi * 5 - t * 0.03) * amp * 0.26;
      path.lineTo(x, y);
    }
    // Three passes: a wide soft body, a bright core, and a hairline highlight
    // riding just above it. That is a calligraphic stroke without a shader.
    canvas.drawPath(path, _line(accent, 0.06, 14));
    canvas.drawPath(path, _line(accent, 0.13, 6));
    canvas.drawPath(path, _line(accent, 0.34, 1.8));
    canvas.save();
    canvas.translate(0, -2.5);
    canvas.drawPath(path, _line(Colors.white, 0.10, 0.9));
    canvas.restore();
  }
}

// ── 10. domes ───────────────────────────────────────────────────────────
void _domes(Canvas canvas, Rect r, Color accent, double t) {
  final origin = Offset(r.center.dx, r.bottom - r.height * 0.06);
  const period = 8.0;
  for (var i = 0; i < 9; i++) {
    final phase = ((t / period) + i / 9) % 1.0;
    final radius = r.width * (0.06 + phase * 1.05);
    final a = 0.34 * (1 - phase) * (1 - phase);
    final dome = Path()
      ..moveTo(origin.dx - radius, origin.dy)
      ..lineTo(origin.dx - radius, origin.dy - radius * 0.20)
      ..arcToPoint(
        Offset(origin.dx + radius, origin.dy - radius * 0.20),
        radius: Radius.circular(radius),
      )
      ..lineTo(origin.dx + radius, origin.dy);
    canvas.drawPath(dome, _line(accent, a * 0.35, 6));
    canvas.drawPath(dome, _line(accent, a, 1.8));
    // The finial on the crown of each dome, riding out with it.
    final crown = Offset(origin.dx, origin.dy - radius * 1.20);
    canvas.drawCircle(crown, 2.4 + radius * 0.012, _fill(accent, a * 1.1));
  }
}
