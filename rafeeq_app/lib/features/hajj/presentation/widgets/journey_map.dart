/// The route of Hajj, animated: Makkah → Mina → Arafat → Muzdalifah → Mina →
/// Makkah, in the order the source text walks it (p50–75). [highlight] lights
/// the leg the open step is about. A diagram of the order of the places, not
/// a map to scale.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/hajj_guide.dart';

class JourneyMap extends StatefulWidget {
  /// The stop the animation dwells on, or null to loop the whole route.
  final int? highlight;

  const JourneyMap({super.key, this.highlight});

  @override
  State<JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends State<JourneyMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = [for (final k in journeyPlaces) k.tr()];
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => CustomPaint(
          painter: _JourneyPainter(
            t: _loop.value,
            highlight: widget.highlight,
            names: names,
            line: scheme.outlineVariant,
            label: scheme.onSurface,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

class _JourneyPainter extends CustomPainter {
  final double t;
  final int? highlight;
  final List<String> names;
  final Color line;
  final Color label;
  final bool rtl;

  const _JourneyPainter({
    required this.t,
    required this.highlight,
    required this.names,
    required this.line,
    required this.label,
    required this.rtl,
  });

  /// The six stops laid on a gentle loop: out along the bottom, back along
  /// the top, so Mina appears twice without the path crossing itself.
  List<Offset> _points(Size s) {
    final w = s.width;
    final h = s.height;
    double x(double f) => rtl ? w * (1 - f) : w * f;
    return [
      Offset(x(0.10), h * 0.50),
      Offset(x(0.36), h * 0.78),
      Offset(x(0.88), h * 0.62),
      Offset(x(0.66), h * 0.28),
      Offset(x(0.38), h * 0.20),
      Offset(x(0.12), h * 0.50),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _points(size);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 10);
      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = line,
    );

    // The walked part of the route in gold.
    final metric = path.computeMetrics().first;
    final walked = highlight == null
        ? t
        : ((highlight! + 0.5 * (1 + math.sin(t * 2 * math.pi))) /
                (pts.length - 1))
            .clamp(0.0, 1.0);
    canvas.drawPath(
      metric.extractPath(0, metric.length * walked),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );
    final tangent = metric.getTangentForOffset(metric.length * walked);

    for (var i = 0; i < pts.length; i++) {
      // Makkah is drawn once (start and end share the spot on the loop).
      if (i == pts.length - 1) continue;
      final lit = highlight == null || highlight == i ||
          (highlight == 5 && i == 0) || (highlight == 4 && i == 1);
      canvas.drawCircle(
        pts[i],
        lit ? 11 : 8,
        Paint()..color = lit ? AppColors.gold : line,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
            color: label,
            fontSize: 12,
            fontWeight: lit ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, pts[i] + Offset(-tp.width / 2, 14));
    }

    if (tangent != null) {
      canvas.drawCircle(tangent.position, 7, Paint()..color = Colors.white);
      canvas.drawCircle(tangent.position, 5, Paint()..color = AppColors.gold);
    }
  }

  @override
  bool shouldRepaint(_JourneyPainter old) =>
      old.t != t || old.highlight != highlight || old.rtl != rtl;
}
