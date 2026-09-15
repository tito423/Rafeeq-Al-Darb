import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/articulation.dart';
import '../../data/makharij.dart';

/// A side view of the mouth and throat that **moves the way the letter is
/// made**.
///
/// «التصميم بعيد كل البعد عن الحقيقي ومفيش فيه حركة توضح ازاي بتخرج الحروف» —
/// the owner, after the first cut, and he was right twice over. That version
/// drew a face and pulsed a dot on it; a dot says "here" and says nothing about
/// how. So:
///
///  * the **tongue is a contour, not a blob**: its upper edge is sampled as a
///    curve and a bump is raised at the contact point of the chosen makhraj,
///    so the tongue rises to the roof exactly where the book says it does;
///  * the **lips close** for الباء والميم («مع انطباق»), and the lower lip
///    rises to the upper teeth for الفاء («بطن الشَّفة السفلى مع أطراف الثنايا
///    العليا»);
///  * the **air moves**, as a stream of dashes running from where the sound
///    starts out through the mouth — or out through the nose for الغنة والنون،
///    or stopping dead at a closure;
///  * حروف المد get no closure at all and the stream runs the whole length,
///    which is what «الخلاء الواقع داخل الحلق والفم» looks like.
///
/// Every movement comes from `articulation.dart`, which turns the book's own
/// sentence for each makhraj into a movement. Nothing here invents science,
/// and every stroke is a `Path` in normalised coordinates — no image to
/// license, nothing to download, nothing to 404.
class MakharijDiagram extends StatelessWidget {
  final Makhraj? selected;
  final ValueChanged<Makhraj> onPick;

  /// 0 → 1 as the mouth takes up the position. Held at 1 while it is held.
  final Animation<double> articulation;

  /// A free-running 0 → 1 that moves the air along. Separate from
  /// [articulation] so the stream keeps flowing after the mouth has arrived.
  final Animation<double> flow;

  const MakharijDiagram({
    super.key,
    required this.selected,
    required this.onPick,
    required this.articulation,
    required this.flow,
  });

  /// Where each makhraj sits, in the same 0..1 space the paths use.
  static const points = <String, Offset>{
    'jawf': Offset(0.42, 0.515),
    'halq_aqsa': Offset(0.795, 0.88),
    'halq_wasat': Offset(0.785, 0.775),
    'halq_adna': Offset(0.775, 0.67),
    'lisan_aqsa_qaf': Offset(0.685, 0.60),
    'lisan_aqsa_kaf': Offset(0.615, 0.585),
    'lisan_wasat': Offset(0.50, 0.565),
    'lisan_hafa_dad': Offset(0.42, 0.565),
    'lisan_hafa_lam': Offset(0.315, 0.555),
    'lisan_taraf_nun': Offset(0.255, 0.555),
    'lisan_taraf_ra': Offset(0.225, 0.550),
    'lisan_asaliyya': Offset(0.185, 0.560),
    'lisan_nitiyya': Offset(0.185, 0.512),
    'lisan_lithawiyya': Offset(0.152, 0.500),
    'shafa_fa': Offset(0.093, 0.545),
    'shafa_bmw': Offset(0.072, 0.497),
    'khayshum': Offset(0.42, 0.295),
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _pickNearest(d.localPosition, size),
            child: AnimatedBuilder(
              animation: Listenable.merge([articulation, flow]),
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _MouthPainter(
                  selected: selected,
                  articulation: articulation.value,
                  flow: flow.value,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _pickNearest(Offset tap, Size size) {
    Makhraj? best;
    var bestDistance = double.infinity;
    for (final m in makharij) {
      final p = points[m.id];
      if (p == null) continue;
      final at = Offset(p.dx * size.width, p.dy * size.height);
      final d = (at - tap).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = m;
      }
    }
    if (best != null && bestDistance <= size.shortestSide * 0.13) {
      onPick(best);
    }
  }
}

class _MouthPainter extends CustomPainter {
  final Makhraj? selected;
  final double articulation;
  final double flow;
  final bool isDark;

  _MouthPainter({
    required this.selected,
    required this.articulation,
    required this.flow,
    required this.isDark,
  });

  ArticulationSpec? get _spec =>
      selected == null ? null : articulationByMakhraj[selected!.id];

  Color get _ink => isDark ? const Color(0xFF9FB3C8) : const Color(0xFF5A6B7C);
  Color get _flesh => isDark ? const Color(0xFF243447) : const Color(0xFFF7E7E0);
  Color get _tongue =>
      isDark ? const Color(0xFF8A4450) : const Color(0xFFE39AA4);
  Color get _cavity =>
      isDark ? const Color(0xFF131C26) : const Color(0xFFFFFDF8);

  /// The roof of the mouth as a function of x, in normalised space. The
  /// tongue is raised *to* this, so contact is real rather than approximate.
  double _palateY(double x) {
    if (x <= 0.105) return 0.455;
    if (x >= 0.80) return 0.61;
    // Two cubics flattened into one readable curve; close enough to the drawn
    // palate that the tongue meets the line the eye sees.
    final t = (x - 0.105) / (0.80 - 0.105);
    return 0.455 - 0.045 * math.sin(t * math.pi) + 0.20 * t * t;
  }

  /// The tongue's resting upper edge.
  double _tongueRestY(double x) {
    if (x <= 0.135) return 0.585;
    if (x >= 0.725) return 0.74;
    final t = (x - 0.135) / (0.725 - 0.135);
    return 0.585 + 0.155 * t * t;
  }

  /// The tongue's edge with the chosen makhraj's bump raised into it.
  double _tongueY(double x) {
    final rest = _tongueRestY(x);
    final spec = _spec;
    if (spec == null ||
        spec.articulator != Articulator.tongue ||
        spec.contactX == null) {
      return rest;
    }
    final cx = spec.contactX!;
    // A narrow raise, so «طرف اللسان» does not lift the whole tongue.
    final d = (x - cx) / 0.115;
    final bump = math.exp(-d * d);
    final target = _palateY(x);
    return rest + (target - rest) * bump * spec.closure * articulation;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);
    final line = math.max(1.6, w * 0.0042);

    Paint stroke(double alpha, [double mul = 1]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line * mul
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _ink.withValues(alpha: alpha);

    final spec = _spec;
    // How far the lips have closed, 0 open .. 1 shut.
    final lipClose = spec?.articulator == Articulator.lips
        ? articulation
        : (spec?.articulator == Articulator.lipToTeeth ? articulation : 0.0);

    // ── head ──────────────────────────────────────────────────────────────
    final head = Path()
      ..moveTo(w * 0.22, h * 0.03)
      ..cubicTo(w * 0.62, h * 0.00, w * 0.95, h * 0.14, w * 0.95, h * 0.44)
      ..cubicTo(w * 0.95, h * 0.70, w * 0.90, h * 0.86, w * 0.87, h * 0.99)
      ..lineTo(w * 0.30, h * 0.99)
      ..cubicTo(w * 0.30, h * 0.88, w * 0.22, h * 0.84, w * 0.17, h * 0.79)
      ..cubicTo(w * 0.10, h * 0.73, w * 0.08, h * 0.65, w * 0.10, h * 0.60)
      ..lineTo(w * 0.055, h * 0.565)
      ..cubicTo(w * 0.022, h * 0.535, w * 0.022, h * 0.50, w * 0.05, h * 0.475)
      ..lineTo(w * 0.075, h * 0.45)
      ..cubicTo(w * 0.042, h * 0.40, w * 0.055, h * 0.33, w * 0.09, h * 0.30)
      ..cubicTo(w * 0.10, h * 0.20, w * 0.14, h * 0.08, w * 0.22, h * 0.03)
      ..close();
    canvas.drawPath(head, Paint()..color = _flesh);
    canvas.drawPath(head, stroke(0.5));

    // ── nasal chamber ─────────────────────────────────────────────────────
    final nose = Path()
      ..moveTo(w * 0.105, h * 0.335)
      ..cubicTo(w * 0.24, h * 0.245, w * 0.50, h * 0.205, w * 0.66, h * 0.245)
      ..cubicTo(w * 0.74, h * 0.265, w * 0.78, h * 0.315, w * 0.78, h * 0.375)
      ..cubicTo(w * 0.60, h * 0.345, w * 0.34, h * 0.35, w * 0.135, h * 0.395)
      ..cubicTo(w * 0.115, h * 0.375, w * 0.105, h * 0.355, w * 0.105, h * 0.335)
      ..close();
    canvas.drawPath(nose, Paint()..color = _cavity);
    canvas.drawPath(nose, stroke(0.45, 0.9));

    // ── oral cavity ───────────────────────────────────────────────────────
    final mouth = Path()
      ..moveTo(w * 0.105, h * 0.455)
      ..cubicTo(w * 0.30, h * 0.415, w * 0.54, h * 0.425, w * 0.70, h * 0.475)
      ..cubicTo(w * 0.76, h * 0.495, w * 0.795, h * 0.545, w * 0.80, h * 0.61)
      ..cubicTo(w * 0.80, h * 0.71, w * 0.78, h * 0.81, w * 0.75, h * 0.89)
      ..lineTo(w * 0.62, h * 0.89)
      ..cubicTo(w * 0.60, h * 0.75, w * 0.46, h * 0.675, w * 0.28, h * 0.655)
      ..cubicTo(w * 0.19, h * 0.645, w * 0.135, h * 0.61, w * 0.105, h * 0.565)
      ..close();
    canvas.drawPath(mouth, Paint()..color = _cavity);

    final palate = Path()
      ..moveTo(w * 0.105, h * 0.455)
      ..cubicTo(w * 0.30, h * 0.415, w * 0.54, h * 0.425, w * 0.70, h * 0.475)
      ..cubicTo(w * 0.76, h * 0.495, w * 0.795, h * 0.545, w * 0.80, h * 0.61);
    canvas.drawPath(palate, stroke(0.7, 1.5));

    // ── the tongue, sampled so its edge can be deformed ───────────────────
    final tongue = Path()..moveTo(w * 0.135, h * _tongueY(0.135));
    for (var i = 1; i <= 48; i++) {
      final x = 0.135 + (0.725 - 0.135) * i / 48;
      tongue.lineTo(w * x, h * _tongueY(x));
    }
    tongue
      ..cubicTo(w * 0.73, h * 0.80, w * 0.70, h * 0.86, w * 0.64, h * 0.88)
      ..cubicTo(w * 0.46, h * 0.89, w * 0.28, h * 0.85, w * 0.17, h * 0.78)
      ..cubicTo(w * 0.125, h * 0.74, w * 0.115, h * 0.655, w * 0.135, h * 0.585)
      ..close();
    canvas.drawPath(tongue, Paint()..color = _tongue.withValues(alpha: 0.78));
    canvas.drawPath(tongue, stroke(0.4));

    // ── teeth ─────────────────────────────────────────────────────────────
    final enamel = Paint()..color = isDark ? Colors.white70 : Colors.white;
    final enamelEdge = stroke(0.35, 0.7);
    for (var i = 0; i < 2; i++) {
      final x = 0.126 + i * 0.026;
      final upper = RRect.fromRectAndCorners(
        Rect.fromLTWH(w * x, h * 0.462, w * 0.022, h * 0.043),
        bottomLeft: Radius.circular(w * 0.008),
        bottomRight: Radius.circular(w * 0.008),
      );
      final lower = RRect.fromRectAndCorners(
        Rect.fromLTWH(w * x, h * 0.540, w * 0.022, h * 0.043),
        topLeft: Radius.circular(w * 0.008),
        topRight: Radius.circular(w * 0.008),
      );
      canvas.drawRRect(upper, enamel);
      canvas.drawRRect(upper, enamelEdge);
      canvas.drawRRect(lower, enamel);
      canvas.drawRRect(lower, enamelEdge);
    }

    // ── the lips ──────────────────────────────────────────────────────────
    // Two tapered shapes hinged at the face, not two floating pills: the
    // first cut drew rounded rectangles that sat outside the head and read as
    // a beak — seen on the owner's Honor. They pivot towards each other, so
    // «مع انطباق» is something the eye watches happen.
    final lipInk = isDark ? const Color(0xFF8A4450) : const Color(0xFFD98892);
    final aperture = 0.052 * (1 - lipClose);
    final midY = 0.506;

    Path lip(double fromY, double toY) => Path()
      ..moveTo(w * 0.112, h * fromY)
      ..cubicTo(w * 0.082, h * fromY, w * 0.060, h * (fromY + toY) / 2,
          w * 0.052, h * toY)
      ..cubicTo(w * 0.068, h * (toY + fromY) / 2, w * 0.092, h * toY,
          w * 0.112, h * (fromY + (toY - fromY) * 0.45))
      ..close();

    final upper = lip(0.452, midY - aperture / 2);
    final lower = lip(0.560, midY + aperture / 2);
    for (final path in [upper, lower]) {
      canvas.drawPath(path, Paint()..color = lipInk.withValues(alpha: 0.9));
      canvas.drawPath(path, stroke(0.35, 0.8));
    }

    // ── throat ────────────────────────────────────────────────────────────
    final throat = Path()
      ..moveTo(w * 0.80, h * 0.61)
      ..cubicTo(w * 0.845, h * 0.69, w * 0.855, h * 0.83, w * 0.838, h * 0.99)
      ..lineTo(w * 0.748, h * 0.99)
      ..cubicTo(w * 0.768, h * 0.85, w * 0.758, h * 0.73, w * 0.728, h * 0.665)
      ..close();
    canvas.drawPath(throat, Paint()..color = _cavity);
    canvas.drawPath(throat, stroke(0.45, 0.9));

    // a narrowing where the throat letters are squeezed
    if (spec?.articulator == Articulator.throat && selected != null) {
      final at = Offset(
        MakharijDiagram.points[selected!.id]!.dx * w,
        MakharijDiagram.points[selected!.id]!.dy * h,
      );
      canvas.drawCircle(
        at,
        w * (0.05 + 0.012 * math.sin(flow * math.pi * 2)),
        Paint()..color = AppColors.gold.withValues(alpha: 0.18 * articulation),
      );
    }

    // ── the air, moving ───────────────────────────────────────────────────
    _drawAirstream(canvas, size);

    // ── labels ────────────────────────────────────────────────────────────
    _label(canvas, 'الخيشوم', p(0.43, 0.175), size, MakhrajRegion.khayshum);
    _label(canvas, 'الجوف', p(0.40, 0.475), size, MakhrajRegion.jawf);
    _label(canvas, 'الشفتان', p(0.155, 0.365), size, MakhrajRegion.shafatan);
    _label(canvas, 'اللسان', p(0.43, 0.80), size, MakhrajRegion.lisan);
    _label(canvas, 'الحلق', p(0.898, 0.79), size, MakhrajRegion.halq);

    // ── the seventeen points ──────────────────────────────────────────────
    for (final m in makharij) {
      final n = MakharijDiagram.points[m.id];
      if (n == null) continue;
      final at = Offset(n.dx * w, n.dy * h);
      final isOn = selected?.id == m.id;
      final r = w * (isOn ? 0.020 : 0.0115);

      canvas.drawCircle(at, r + line * 0.9, Paint()..color = _cavity);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = isOn
              ? AppColors.gold
              : _ink.withValues(alpha: isDark ? 0.5 : 0.38),
      );
      if (isOn) {
        canvas.drawCircle(
          at,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = line
            ..color = isDark ? Colors.white : const Color(0xFF3A2F14),
        );
      }
    }
  }

  /// Dashes running along the path the air takes, so the reader sees where the
  /// sound comes from and where it leaves. A blocked makhraj stops the stream
  /// at the closure — which is the point of a stop.
  void _drawAirstream(Canvas canvas, Size size) {
    final spec = _spec;
    if (spec == null || articulation <= 0.02) return;
    final w = size.width;
    final h = size.height;

    // Source: deep in the throat for everything except the lips, which start
    // their air just behind the closure.
    final from = switch (spec.articulator) {
      Articulator.throat => Offset(
          MakharijDiagram.points[selected!.id]!.dx * w,
          MakharijDiagram.points[selected!.id]!.dy * h,
        ),
      _ => Offset(w * 0.79, h * 0.85),
    };

    // Where it stops.
    final Offset to;
    switch (spec.air) {
      case AirPath.outNose:
        to = Offset(w * 0.085, h * 0.345);
      case AirPath.blocked:
        final cx = spec.contactX ?? 0.075;
        to = Offset(w * cx, h * (_tongueY(cx) - 0.01));
      case AirPath.outMouth:
        to = Offset(w * 0.045, h * 0.508);
    }

    // A gentle arc through the mouth rather than a straight line.
    final control = spec.air == AirPath.outNose
        ? Offset(w * 0.45, h * 0.30)
        : Offset(w * 0.45, h * (0.50 + 0.02));

    const dots = 16;
    for (var i = 0; i < dots; i++) {
      final t = ((i / dots) + flow) % 1.0;
      final a = Offset.lerp(from, control, t)!;
      final b = Offset.lerp(control, to, t)!;
      final at = Offset.lerp(a, b, t)!;
      // Fades in at the source and out at the end, so it reads as movement
      // rather than a row of beads.
      final fade = math.sin(t * math.pi);
      canvas.drawCircle(
        at,
        w * (0.006 + 0.004 * fade) * articulation,
        Paint()
          ..color = (spec.air == AirPath.blocked && t > 0.92
                  ? AppColors.gold
                  : AppColors.gold)
              .withValues(alpha: 0.55 * fade * articulation),
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Size size,
    MakhrajRegion region,
  ) {
    final on = selected?.region == region;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: math.max(9.0, size.width * 0.031),
          fontWeight: on ? FontWeight.bold : FontWeight.w500,
          color:
              on ? AppColors.gold : _ink.withValues(alpha: isDark ? 0.8 : 0.7),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.selected?.id != selected?.id ||
      old.articulation != articulation ||
      old.flow != flow ||
      old.isDark != isDark;
}
