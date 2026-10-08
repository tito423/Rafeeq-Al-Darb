/// The scenery of «قافلة الدرب», drawn behind and around the caravan: a sky
/// that warms from dawn to the gold of afternoon, light pouring from the sun,
/// clouds and far mountains each sliding at its own pace, dunes lit on their
/// crests and shaded in their hollows, dust kicked up by the camels, and a
/// soft frame that holds the eye on the road.
///
/// Leg two runs the other way through the day: afternoon, a sunset, then
/// night under a crescent and the stars, while the sand turns to the
/// greener ground of al-Sham.
///
/// Owner, 2026-10-08: «خليها فيجوالي احمل واروع». Every layer moves at its
/// own depth ([CaravanWorld.distance] x depth), which is what makes a flat
/// road read as a land the caravan is crossing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/caravan_world.dart';

class CaravanScenery {
  final CaravanWorld w;
  const CaravanScenery(this.w);

  double get _p => w.progress.clamp(0.0, 1.0);

  /// a -> b -> c as t goes 0 -> 0.5 -> 1.
  static Color _three(Color a, Color b, Color c, double t) =>
      t < 0.5 ? Color.lerp(a, b, t * 2)! : Color.lerp(b, c, (t - 0.5) * 2)!;

  /// A colour of the land, as the leg's light makes it: on leg two the sand
  /// greens as the road climbs into al-Sham, then sinks into the night blue.
  Color land(Color c) {
    if (!w.toNight && !w.leg.north) return c;
    // The north is green from the first step; Arabia stays sand.
    final green = w.leg.north
        ? Color.lerp(c, const Color(0xFF9FA36C), 0.45)!
        : c;
    // Moonlit sand: towards a silver blue, not towards black - mixing the
    // sand with a near-black navy read as a grey fog on the emulator.
    return Color.lerp(green, const Color(0xFF4C5C92), 0.72 * w.night)!;
  }

  /// Three stops instead of two: a deep top, a warm band low on the horizon,
  /// and the haze right above the land.
  void sky(Canvas canvas, Size size) {
    final p = _p;
    if (w.toNight) {
      _skyToNight(canvas, size, p);
      return;
    }
    final top = Color.lerp(
      const Color(0xFF1E2152),
      const Color(0xFF2F6FA8),
      (p * 2).clamp(0.0, 1.0),
    )!;
    final mid = Color.lerp(
      const Color(0xFF8E4E7A),
      const Color(0xFF8CC2E3),
      (p * 1.6).clamp(0.0, 1.0),
    )!;
    final low = Color.lerp(
      const Color(0xFFF59E5B),
      const Color(0xFFFBE7B9),
      (p * 1.4).clamp(0.0, 1.0),
    )!;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, low],
          stops: const [0.0, 0.42, 0.7],
        ).createShader(rect),
    );
    // Stars that fade as the sun climbs, each twinkling on its own beat.
    _stars(canvas, size, (1 - p * 3).clamp(0.0, 1.0));
  }

  void _skyToNight(Canvas canvas, Size size, double p) {
    final top = _three(
      const Color(0xFF2F6FA8),
      const Color(0xFF3B3A7A),
      const Color(0xFF070B26),
      p,
    );
    final mid = _three(
      const Color(0xFF8CC2E3),
      const Color(0xFFC8648A),
      const Color(0xFF1A2152),
      p,
    );
    final low = _three(
      const Color(0xFFFBE7B9),
      const Color(0xFFFFA25C),
      const Color(0xFF3B3570),
      p,
    );
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, low],
          stops: const [0.0, 0.42, 0.7],
        ).createShader(rect),
    );
    _stars(canvas, size, ((p - 0.5) * 2.5).clamp(0.0, 1.0));
  }

  void _stars(Canvas canvas, Size size, double starA) {
    if (starA > 0) {
      final rnd = math.Random(7);
      for (var i = 0; i < 60; i++) {
        final tw = 0.6 + 0.4 * math.sin(w.time * (1.5 + i % 5) + i);
        canvas.drawCircle(
          Offset(
            rnd.nextDouble() * size.width,
            rnd.nextDouble() * size.height * 0.45,
          ),
          rnd.nextDouble() * 1.5 + 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * starA * tw),
        );
      }
    }
  }

  Offset sunCentre(Size size) => w.toNight
      ? Offset(
          size.width * (0.32 - 0.14 * _p),
          size.height * (0.22 + 0.62 * _p),
        )
      : Offset(
          size.width * (0.82 - 0.5 * _p),
          size.height * (0.55 - 0.38 * math.sin(_p * math.pi * 0.9)),
        );

  /// The sun, its halo, and slow rays turning out of it.
  void sun(Canvas canvas, Size size) {
    final c = sunCentre(size);
    // On leg two the sun is gone below the far hills by the time night falls.
    if (w.toNight && c.dy > size.height * 0.75) return;
    final r = math.min(size.width, size.height) * 0.07;
    // Rays: long soft wedges, turning very slowly.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(w.time * 0.03);
    final ray = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF1C7).withValues(alpha: 0.16),
          const Color(0xFFFFF1C7).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 9))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final spread = 0.07 + 0.03 * math.sin(w.time * 0.7 + i);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a - spread) * r * 9, math.sin(a - spread) * r * 9)
          ..lineTo(math.cos(a + spread) * r * 9, math.sin(a + spread) * r * 9)
          ..close(),
        ray,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFBEA), Color(0xFFFFE08A)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// Soft clouds drifting far above, slower than anything on the ground.
  void clouds(Canvas canvas, Size size) {
    final a = w.toNight ? 0.6 * (1 - 0.75 * w.night) : 0.35 + 0.35 * _p;
    // At sunset the clouds catch the light.
    final tint = w.toNight
        ? Color.lerp(
            Colors.white,
            const Color(0xFFFFB38A),
            (_p * 2).clamp(0.0, 1.0),
          )!
        : Colors.white;
    final paint = Paint()
      ..color = tint.withValues(alpha: a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final rnd = math.Random(23);
    for (var i = 0; i < 5; i++) {
      final speed = 0.02 + rnd.nextDouble() * 0.03;
      final fx = (rnd.nextDouble() - w.distance * speed - w.time * 0.004) % 1.2;
      final x = (fx - 0.1) * size.width;
      final y = size.height * (0.08 + rnd.nextDouble() * 0.22);
      final s = size.width * (0.05 + rnd.nextDouble() * 0.05);
      for (final (dx, dy, k) in [
        (0.0, 0.0, 1.0),
        (0.9, 0.15, 0.8),
        (-0.85, 0.2, 0.75),
        (0.35, -0.35, 0.85),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + dx * s, y + dy * s),
            width: s * 2 * k,
            height: s * 1.1 * k,
          ),
          paint,
        );
      }
    }
  }

  /// Far mountains in the haze of distance, barely moving.
  void mountains(Canvas canvas, Size size) {
    final off = (w.distance * 0.05) % 1.0;
    final base = size.height * 0.6;
    final path = Path()..moveTo(0, size.height);
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final fx = i / steps;
      final u = (fx + off) * 2 * math.pi;
      final peak =
          0.075 * (0.5 + 0.5 * math.sin(u * 1.3 + 1)) +
          0.03 * math.sin(u * 2.9 + 2) +
          0.008 * math.sin(u * 7);
      path.lineTo(fx * size.width, base - peak * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final haze = w.toNight
        ? _three(
            const Color(0xFF8C9A86),
            const Color(0xFF7A5878),
            const Color(0xFF242A4E),
            _p,
          )
        : Color.lerp(const Color(0xFF6E4A78), const Color(0xFFB59AA8), _p)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                haze.withValues(alpha: 0.75),
                haze.withValues(alpha: 0.2),
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                base - size.height * 0.16,
                size.width,
                size.height * 0.3,
              ),
            ),
    );
  }

  /// A range of dunes: lit on the crest, darker in the hollow, with a thin
  /// line of light along the top where the sun catches the sand.
  void dunes(
    Canvas canvas,
    Size size, {
    required double depth,
    required double base,
    required double amp,
    required Color light,
    required Color dark,
    required int seed,
    bool rim = true,
  }) {
    final off = (w.distance * depth) % 1.0;
    final crest = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final fx = i / steps;
      final u = (fx + off) * 2 * math.pi;
      final y =
          base +
          amp * math.sin(u * 2 + seed) +
          amp * 0.5 * math.sin(u * 5 + seed * 2);
      final pt = Offset(fx * size.width, y * size.height);
      i == 0 ? crest.moveTo(pt.dx, pt.dy) : crest.lineTo(pt.dx, pt.dy);
    }
    final body = Path.from(crest)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final top = (base - amp * 1.5) * size.height;
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [land(light), land(dark)],
        ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top)),
    );
    if (rim) {
      canvas.drawPath(
        crest,
        Paint()
          ..color =
              (w.night > 0.3
                      ? const Color(0xFFB8C4FF)
                      : const Color(0xFFFFE9C2))
                  .withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  /// The road itself: ripples, hoof prints trailing behind the caravan, and
  /// a few pebbles, all sliding at the road's own speed.
  void roadDetail(Canvas canvas, Size size, double camel) {
    final off = w.distance % 1.0;
    final ground = size.height * CaravanWorld.groundY;
    final ripple = Paint()
      ..color = const Color(0xFF8E5426).withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 11; i++) {
      final x = ((i / 11 - off) % 1.0) * size.width;
      final y = ground + size.height * (0.05 + (i % 3) * 0.045);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: 64, height: 10),
        math.pi,
        math.pi,
        false,
        ripple,
      );
    }
    // Prints left behind the caravan: they start under the last camel and
    // slide back with the road.
    final print = Paint()
      ..color = const Color(0xFF7A4520).withValues(alpha: 0.35);
    final lead = CaravanWorld.leadX * size.width;
    final step = camel * 0.42;
    final shift = (w.distance * size.width) % step;
    for (var x = lead - camel * 2.4 + shift; x > -step; x -= step) {
      final k = (x / lead).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, ground + camel * 0.05),
          width: camel * 0.09,
          height: camel * 0.035,
        ),
        print..color = const Color(0xFF7A4520).withValues(alpha: 0.35 * k),
      );
    }
    final pebble = Paint()
      ..color = const Color(0xFFB98A55).withValues(alpha: 0.45);
    final rnd = math.Random(5);
    for (var i = 0; i < 14; i++) {
      final fx = (rnd.nextDouble() - off) % 1.0;
      canvas.drawCircle(
        Offset(
          fx * size.width,
          ground + size.height * (0.03 + rnd.nextDouble() * 0.14),
        ),
        1 + rnd.nextDouble() * 1.5,
        pebble,
      );
    }
  }

  /// A soft shadow on the sand under a camel; it shrinks and fades as the
  /// camel leaves the ground.
  void camelShadow(Canvas canvas, Offset foot, double camel, double liftPx) {
    final k = (1 - liftPx / (camel * 1.6)).clamp(0.25, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(foot.dx, foot.dy + liftPx + camel * 0.02),
        width: camel * 0.95 * k,
        height: camel * 0.12 * k,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  /// Puffs of dust behind the lead camel's feet while it walks on the ground.
  void dust(Canvas canvas, Offset foot, double camel, bool grounded) {
    if (!grounded) return;
    for (var i = 0; i < 5; i++) {
      final t = (w.time * 1.6 + i / 5) % 1.0;
      final o = Offset(
        foot.dx - camel * (0.3 + t * 0.9),
        foot.dy - camel * (0.02 + t * 0.12),
      );
      canvas.drawCircle(
        o,
        camel * (0.04 + t * 0.09),
        Paint()
          ..color = const Color(0xFFE2B47C).withValues(alpha: 0.35 * (1 - t))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  /// A dark soft frame round the picture, so the eye stays on the road.
  void vignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }
}
