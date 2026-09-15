import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/articulation.dart';
import '../../data/makharij.dart';

/// مخارج الحروف on a real anatomical section, with the movement on top.
///
/// TWO COMPLAINTS BUILT THIS. «التصميم بعيد كل البعد عن الحقيقي» and «مفيش فيه
/// حركة توضح ازاي بتخرج الحروف». The first is answered by not drawing the
/// anatomy myself any more: the section under everything is
/// `assets/diagrams/vocal_tract.svg`, a **CC0** sagittal section by Richard
/// Wright and Dan McCloy (University of Washington, Linguistics 450/550,
/// via Wikimedia Commons). CC0 waives everything — no attribution is
/// required, modification and commercial use are explicit — and the file is
/// **vector**, which is what lets it be cropped to the tract and scaled to any
/// screen. The licence was read on the Commons file page before the file was
/// downloaded, and the credit is shown on the screen anyway, because that is
/// right even when it is not required.
///
/// The second is answered by the layer over it: for a tongue makhraj a wedge
/// of contact grows from the tongue up to the place, the lips close for
/// «مع انطباق», the throat narrows and pulses, and a stream of dashes runs the
/// air out through the mouth — or out through the nose for الغنة والنون، or
/// stops dead where the mouth is shut. Every one of those comes from
/// `articulation.dart`, which is the book's own sentence turned into a
/// movement.
///
/// The seventeen points were calibrated **against this drawing**, not guessed:
/// the SVG was rendered with a tenths grid over it and each point read off
/// the anatomy it names.
class MakharijDiagram extends StatelessWidget {
  final Makhraj? selected;
  final ValueChanged<Makhraj> onPick;

  /// 0 → 1 as the mouth takes up the position, then held.
  final Animation<double> articulation;

  /// Free-running, so the air keeps moving after the mouth has arrived.
  final Animation<double> flow;

  const MakharijDiagram({
    super.key,
    required this.selected,
    required this.onPick,
    required this.articulation,
    required this.flow,
  });

  /// Read off the rendered section, lips at the left. The SVG is mirrored on
  /// screen, so these are in the mirrored (reading) frame.
  static const points = <String, Offset>{
    'shafa_bmw': Offset(0.105, 0.500),
    'shafa_fa': Offset(0.160, 0.487),
    'lisan_asaliyya': Offset(0.200, 0.505),
    'lisan_lithawiyya': Offset(0.200, 0.440),
    'lisan_nitiyya': Offset(0.243, 0.420),
    'lisan_taraf_ra': Offset(0.275, 0.455),
    'lisan_taraf_nun': Offset(0.300, 0.438),
    'lisan_hafa_lam': Offset(0.345, 0.420),
    'jawf': Offset(0.420, 0.410),
    'lisan_hafa_dad': Offset(0.450, 0.445),
    'lisan_wasat': Offset(0.510, 0.385),
    'lisan_aqsa_kaf': Offset(0.630, 0.370),
    'lisan_aqsa_qaf': Offset(0.720, 0.385),
    'halq_adna': Offset(0.780, 0.570),
    'halq_wasat': Offset(0.792, 0.720),
    'halq_aqsa': Offset(0.785, 0.855),
    'khayshum': Offset(0.350, 0.260),
  };

  /// The five region names, placed **inside** the anatomy they name. Read off
  /// the same gridded render as the points: the first set put الشفتان out in
  /// the white margin beside the face and الجوف on top of the letter cluster.
  static const regionLabels = <MakhrajRegion, Offset>{
    MakhrajRegion.khayshum: Offset(0.520, 0.270),
    MakhrajRegion.jawf: Offset(0.400, 0.478),
    MakhrajRegion.shafatan: Offset(0.200, 0.630),
    MakhrajRegion.lisan: Offset(0.470, 0.630),
    MakhrajRegion.halq: Offset(0.720, 0.680),
  };

  /// The SVG's own aspect after cropping to the tract (90 × 136 units).
  static const _aspect = 90 / 136;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: _aspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _pickNearest(d.localPosition, size),
            child: AnimatedBuilder(
              animation: Listenable.merge([articulation, flow]),
              builder: (context, _) {
                final t = articulation.value;
                return ClipRect(
                  child: Transform(
                    // A gentle push in towards whatever was picked, so the
                    // detail is bigger without the rest leaving the frame.
                    transform: _zoom(size, t),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _svg('assets/diagrams/vocal_tract_base.svg', isDark),
                        // The tongue is its own path in the drawing, so it is
                        // its own layer here: it really rotates into the
                        // position, rather than a marker appearing on a
                        // tongue that never moved.
                        Transform(
                          transform: _tongue(size, t),
                          child: _svg(
                            'assets/diagrams/vocal_tract_tongue.svg',
                            isDark,
                          ),
                        ),
                        CustomPaint(
                          size: size,
                          painter: _ArticulationPainter(
                            selected: selected,
                            articulation: t,
                            flow: flow.value,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }


  /// Both layers are mirrored the same way, so they stay registered.
  Widget _svg(String asset, bool isDark) => Transform.scale(
        scaleX: -1,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          colorFilter: isDark
              ? const ColorFilter.mode(Color(0xFF8FA3B8), BlendMode.srcIn)
              : null,
        ),
      );

  /// How the tongue moves for the chosen makhraj.
  ///
  /// A rigid rotation about a pivot, not a bulge: the drawing's tongue is one
  /// path and rotating it is honest about that. Which way it turns comes from
  /// **where along the tongue the book puts the contact** — a front makhraj
  /// lifts the tip, a back one lifts the root — so the parameters are derived
  /// from `contactX` rather than typed in per letter, and a new makhraj cannot
  /// be added with a movement that contradicts its own description.
  Matrix4 _tongue(Size size, double t) {
    final spec =
        selected == null ? null : articulationByMakhraj[selected!.id];
    if (spec == null ||
        spec.articulator != Articulator.tongue ||
        spec.contactX == null) {
      return Matrix4.identity();
    }
    final cx = spec.contactX!;
    final double angle;
    final Offset pivot;
    if (cx < 0.35) {
      // tip to the ridge or the teeth
      pivot = const Offset(0.62, 0.66);
      angle = -0.105;
    } else if (cx < 0.55) {
      pivot = const Offset(0.62, 0.68);
      angle = -0.055;
    } else {
      // the root climbs to the soft palate
      pivot = const Offset(0.26, 0.66);
      angle = 0.080;
    }
    final px = pivot.dx * size.width;
    final py = pivot.dy * size.height;
    return Matrix4.identity()
      ..translateByDouble(px, py, 0, 1)
      ..rotateZ(angle * spec.closure * t)
      ..translateByDouble(-px, -py, 0, 1);
  }

  /// A small zoom towards the chosen point.
  Matrix4 _zoom(Size size, double t) {
    final n = selected == null ? null : points[selected!.id];
    if (n == null) return Matrix4.identity();
    const maxScale = 1.16;
    final s = 1 + (maxScale - 1) * t;
    final cx = n.dx * size.width;
    final cy = n.dy * size.height;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
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
    if (best != null && bestDistance <= size.shortestSide * 0.16) {
      onPick(best);
    }
  }
}

/// Everything that moves. The anatomy underneath never changes.
class _ArticulationPainter extends CustomPainter {
  final Makhraj? selected;
  final double articulation;
  final double flow;
  final bool isDark;

  _ArticulationPainter({
    required this.selected,
    required this.articulation,
    required this.flow,
    required this.isDark,
  });

  ArticulationSpec? get _spec =>
      selected == null ? null : articulationByMakhraj[selected!.id];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final spec = _spec;
    final sel = selected;

    if (sel != null && spec != null && articulation > 0.01) {
      final at = Offset(
        MakharijDiagram.points[sel.id]!.dx * w,
        MakharijDiagram.points[sel.id]!.dy * h,
      );
      switch (spec.articulator) {
        case Articulator.tongue:
          _drawContact(canvas, size, at, spec);
        case Articulator.lips:
        case Articulator.lipToTeeth:
          _drawLipClosure(canvas, size, at);
        case Articulator.throat:
          _drawConstriction(canvas, size, at);
        case Articulator.nose:
        case Articulator.open:
          _drawOpenGlow(canvas, size, at);
      }
      _drawAirstream(canvas, size, spec, at);
    }

    // ── the five region names ─────────────────────────────────────────────
    for (final entry in MakharijDiagram.regionLabels.entries) {
      _label(canvas, size, entry.key, entry.value);
    }

    // ── the seventeen points ──────────────────────────────────────────────
    for (final m in makharij) {
      final n = MakharijDiagram.points[m.id];
      if (n == null) continue;
      final p = Offset(n.dx * w, n.dy * h);
      final on = sel?.id == m.id;
      final r = w * (on ? 0.030 : 0.020);
      canvas.drawCircle(
        p,
        r + w * 0.006,
        Paint()..color = (isDark ? Colors.black : Colors.white)
            .withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = on
              ? AppColors.gold
              : (isDark ? Colors.white : const Color(0xFF5A6B7C))
                  .withValues(alpha: 0.45),
      );
      if (on) {
        canvas.drawCircle(
          p,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.6, w * 0.006)
            ..color = isDark ? Colors.white : const Color(0xFF3A2F14),
        );
      }
    }
  }

  /// The tongue reaching its place: a wedge that grows upward out of the
  /// tongue until it meets the point, which is what «يخرج منه» looks like.
  void _drawContact(Canvas canvas, Size size, Offset at, ArticulationSpec s) {
    final w = size.width;
    final reach = w * 0.085 * s.closure * articulation;
    final width = w * 0.075;
    final wedge = Path()
      ..moveTo(at.dx - width / 2, at.dy + reach)
      ..quadraticBezierTo(at.dx, at.dy + reach * 0.35, at.dx, at.dy)
      ..quadraticBezierTo(
          at.dx, at.dy + reach * 0.35, at.dx + width / 2, at.dy + reach)
      ..close();
    canvas.drawPath(
      wedge,
      Paint()..color = AppColors.gold.withValues(alpha: 0.55 * articulation),
    );
    // A full closure gets a bright seal at the top; a partial one does not.
    if (s.closure >= 0.95) {
      canvas.drawCircle(
        at,
        w * 0.018 * articulation,
        Paint()..color = AppColors.gold,
      );
    }
  }

  void _drawLipClosure(Canvas canvas, Size size, Offset at) {
    final w = size.width;
    final gap = w * 0.055 * (1 - articulation);
    final bar = Paint()..color = AppColors.gold.withValues(alpha: 0.75);
    for (final dy in [-gap / 2 - w * 0.016, gap / 2 + w * 0.016]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: at.translate(0, dy),
            width: w * 0.10,
            height: w * 0.028,
          ),
          Radius.circular(w * 0.014),
        ),
        bar,
      );
    }
  }

  void _drawConstriction(Canvas canvas, Size size, Offset at) {
    final w = size.width;
    final breathe = 0.5 + 0.5 * math.sin(flow * math.pi * 2);
    canvas.drawCircle(
      at,
      w * (0.055 + 0.020 * breathe) * articulation,
      Paint()..color = AppColors.gold.withValues(alpha: 0.28 * articulation),
    );
  }

  void _drawOpenGlow(Canvas canvas, Size size, Offset at) {
    final w = size.width;
    final breathe = 0.5 + 0.5 * math.sin(flow * math.pi * 2);
    canvas.drawCircle(
      at,
      w * (0.075 + 0.025 * breathe) * articulation,
      Paint()..color = AppColors.gold.withValues(alpha: 0.18 * articulation),
    );
  }

  /// The air, as dashes moving along the tract.
  void _drawAirstream(
      Canvas canvas, Size size, ArticulationSpec spec, Offset at) {
    final w = size.width;
    final h = size.height;
    // Everything starts at the larynx except the throat letters, which start
    // at their own constriction.
    final from = spec.articulator == Articulator.throat
        ? at
        : Offset(w * 0.86, h * 0.93);
    final Offset to;
    switch (spec.air) {
      case AirPath.outNose:
        to = Offset(w * 0.075, h * 0.215);
      case AirPath.blocked:
        to = at;
      case AirPath.outMouth:
        to = Offset(w * 0.020, h * 0.500);
    }
    final control = spec.air == AirPath.outNose
        ? Offset(w * 0.55, h * 0.300)
        : Offset(w * 0.52, h * 0.440);

    const dots = 14;
    for (var i = 0; i < dots; i++) {
      final t = ((i / dots) + flow) % 1.0;
      final a = Offset.lerp(from, control, t)!;
      final b = Offset.lerp(control, to, t)!;
      final at2 = Offset.lerp(a, b, t)!;
      final fade = math.sin(t * math.pi);
      canvas.drawCircle(
        at2,
        w * (0.008 + 0.006 * fade) * articulation,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.6 * fade * articulation),
      );
    }
  }

  /// A region's name, lit while one of its makharij is the chosen one.
  void _label(Canvas canvas, Size size, MakhrajRegion region, Offset at) {
    final on = selected?.region == region;
    final info = makhrajRegions.firstWhere((i) => i.region == region);
    final tp = TextPainter(
      text: TextSpan(
        text: info.name,
        style: TextStyle(
          fontSize: math.max(10.0, size.width * 0.040),
          fontWeight: on ? FontWeight.bold : FontWeight.w600,
          color: on
              ? AppColors.gold
              : (isDark ? Colors.white : const Color(0xFF44535F))
                  .withValues(alpha: 0.75),
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    final o = Offset(at.dx * size.width, at.dy * size.height) -
        Offset(tp.width / 2, tp.height / 2);
    // A soft plate behind the word, so it stays legible over the grey fill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx - 5, o.dy - 2, tp.width + 10, tp.height + 4),
        Radius.circular(size.width * 0.012),
      ),
      Paint()
        ..color = (isDark ? Colors.black : Colors.white)
            .withValues(alpha: on ? 0.82 : 0.62),
    );
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_ArticulationPainter old) =>
      old.selected?.id != selected?.id ||
      old.articulation != articulation ||
      old.flow != flow ||
      old.isDark != isDark;
}
