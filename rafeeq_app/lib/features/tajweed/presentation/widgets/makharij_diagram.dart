import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/makharij.dart';

/// A side view of the mouth and throat, drawn rather than photographed.
///
/// «عايزه تحفه بصريا انيميشن وكده خاصة في مخارج الحروف» — so this is a real
/// sagittal section: the lips at the left, the teeth behind them, the tongue
/// lying along the floor, the hard palate above it, the throat turning down
/// at the right, and the nasal cavity over the palate. Every stroke is a
/// `Path` in normalised coordinates, so it scales to any screen and there is
/// no image to license, no asset to download and nothing to 404.
///
/// The seventeen points sit on that drawing where the book puts them, and the
/// selected one breathes. Nothing here states a ruling: the letters and the
/// wording all come from `makharij.dart`, which quotes «غاية المريد».
class MakharijDiagram extends StatelessWidget {
  final Makhraj? selected;
  final ValueChanged<Makhraj> onPick;

  /// Drives the breathing of the selected point. Passed in rather than owned
  /// so one controller can run the whole screen.
  final Animation<double> pulse;

  const MakharijDiagram({
    super.key,
    required this.selected,
    required this.onPick,
    required this.pulse,
  });

  /// Where each makhraj sits on the drawing, in the same 0..1 space the paths
  /// use. Ordered mouth-outwards so the tongue's ten run front to back the way
  /// the book walks them.
  static const points = <String, Offset>{
    'jawf': Offset(0.46, 0.46),
    'halq_aqsa': Offset(0.86, 0.74),
    'halq_wasat': Offset(0.82, 0.64),
    'halq_adna': Offset(0.77, 0.55),
    'lisan_aqsa_qaf': Offset(0.70, 0.46),
    'lisan_aqsa_kaf': Offset(0.63, 0.47),
    'lisan_wasat': Offset(0.53, 0.50),
    'lisan_hafa_dad': Offset(0.47, 0.585),
    'lisan_hafa_lam': Offset(0.34, 0.56),
    'lisan_taraf_nun': Offset(0.27, 0.53),
    'lisan_taraf_ra': Offset(0.245, 0.505),
    'lisan_asaliyya': Offset(0.20, 0.585),
    'lisan_nitiyya': Offset(0.205, 0.45),
    'lisan_lithawiyya': Offset(0.175, 0.415),
    'shafa_fa': Offset(0.10, 0.50),
    'shafa_bmw': Offset(0.075, 0.44),
    'khayshum': Offset(0.42, 0.20),
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _pickNearest(d.localPosition, size),
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _MouthPainter(
                  selected: selected,
                  pulse: pulse.value,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Nearest point wins, with a ceiling so a tap on empty anatomy selects
  /// nothing rather than jumping to a far-off makhraj.
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
    if (best != null && bestDistance <= size.shortestSide * 0.14) {
      onPick(best);
    }
  }
}

class _MouthPainter extends CustomPainter {
  final Makhraj? selected;
  final double pulse;
  final bool isDark;

  _MouthPainter({
    required this.selected,
    required this.pulse,
    required this.isDark,
  });

  Color get _ink => isDark ? const Color(0xFF9FB3C8) : const Color(0xFF5A6B7C);
  Color get _flesh => isDark ? const Color(0xFF243447) : const Color(0xFFF2E3DD);
  Color get _tongue =>
      isDark ? const Color(0xFF7A3B47) : const Color(0xFFE0A0A8);

  Offset _at(Offset n, Size s) => Offset(n.dx * s.width, n.dy * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.004)
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.55);

    // ── the head's profile, lips at the left ──────────────────────────────
    final face = Path()
      ..moveTo(w * 0.05, h * 0.10)
      ..cubicTo(w * 0.02, h * 0.28, w * 0.02, h * 0.34, w * 0.06, h * 0.40)
      ..lineTo(w * 0.03, h * 0.44)
      ..cubicTo(w * 0.03, h * 0.50, w * 0.05, h * 0.54, w * 0.09, h * 0.56)
      ..cubicTo(w * 0.07, h * 0.66, w * 0.10, h * 0.74, w * 0.16, h * 0.80)
      ..lineTo(w * 0.16, h * 0.95);
    canvas.drawPath(face, outline);

    final back = Path()
      ..moveTo(w * 0.05, h * 0.10)
      ..cubicTo(w * 0.40, h * 0.02, w * 0.86, h * 0.06, w * 0.93, h * 0.30)
      ..cubicTo(w * 0.97, h * 0.50, w * 0.93, h * 0.76, w * 0.88, h * 0.95);
    canvas.drawPath(back, outline);

    // ── the oral cavity: palate above, tongue below ───────────────────────
    final palate = Path()
      ..moveTo(w * 0.09, h * 0.41)
      ..cubicTo(w * 0.28, h * 0.33, w * 0.52, h * 0.34, w * 0.66, h * 0.42)
      ..cubicTo(w * 0.73, h * 0.46, w * 0.76, h * 0.52, w * 0.78, h * 0.60);
    canvas.drawPath(
      palate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, w * 0.006)
        ..strokeCap = StrokeCap.round
        ..color = _ink.withValues(alpha: 0.75),
    );

    final tongue = Path()
      ..moveTo(w * 0.14, h * 0.60)
      ..cubicTo(w * 0.26, h * 0.50, w * 0.46, h * 0.49, w * 0.60, h * 0.53)
      ..cubicTo(w * 0.70, h * 0.56, w * 0.74, h * 0.62, w * 0.74, h * 0.70)
      ..cubicTo(w * 0.60, h * 0.74, w * 0.30, h * 0.74, w * 0.14, h * 0.68)
      ..close();
    canvas.drawPath(tongue, Paint()..color = _tongue.withValues(alpha: 0.55));
    canvas.drawPath(tongue, outline);

    // ── teeth: two blocks, upper and lower, behind the lips ───────────────
    final tooth = Paint()..color = _flesh;
    for (var i = 0; i < 3; i++) {
      final x = 0.145 + i * 0.028;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * x, h * 0.415, w * 0.022, h * 0.055),
          Radius.circular(w * 0.004),
        ),
        tooth,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * x, h * 0.545, w * 0.022, h * 0.055),
          Radius.circular(w * 0.004),
        ),
        tooth,
      );
    }

    // ── the nasal cavity, which is where the ghunnah lives ────────────────
    final nose = Path()
      ..moveTo(w * 0.09, h * 0.33)
      ..cubicTo(w * 0.28, h * 0.22, w * 0.48, h * 0.18, w * 0.62, h * 0.22)
      ..cubicTo(w * 0.52, h * 0.30, w * 0.28, h * 0.32, w * 0.09, h * 0.36)
      ..close();
    canvas.drawPath(nose, Paint()..color = _flesh.withValues(alpha: 0.8));
    canvas.drawPath(nose, outline);

    // ── the throat, turning down behind the tongue ────────────────────────
    final throat = Path()
      ..moveTo(w * 0.78, h * 0.42)
      ..cubicTo(w * 0.86, h * 0.52, w * 0.88, h * 0.70, w * 0.84, h * 0.92);
    canvas.drawPath(
      throat,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, w * 0.006)
        ..color = _ink.withValues(alpha: 0.6),
    );

    // ── the seventeen points ──────────────────────────────────────────────
    for (final m in makharij) {
      final n = MakharijDiagram.points[m.id];
      if (n == null) continue;
      final at = _at(n, size);
      final isOn = selected?.id == m.id;
      final r = w * (isOn ? 0.020 + 0.006 * pulse : 0.014);

      if (isOn) {
        // A halo that breathes, so the eye is led to the place, not just told.
        canvas.drawCircle(
          at,
          r * (2.4 + pulse * 0.8),
          Paint()..color = AppColors.gold.withValues(alpha: 0.18 * (1 - pulse * 0.4)),
        );
      }
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color = isOn
              ? AppColors.gold
              : _ink.withValues(alpha: isDark ? 0.45 : 0.35),
      );
      if (isOn) {
        canvas.drawCircle(
          at,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, w * 0.004)
            ..color = isDark ? Colors.white70 : const Color(0xFF3A2F14),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.selected?.id != selected?.id ||
      old.pulse != pulse ||
      old.isDark != isDark;
}
