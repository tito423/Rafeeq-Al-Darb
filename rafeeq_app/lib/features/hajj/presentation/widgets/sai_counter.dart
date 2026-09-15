/// Sa'i, counted: seven passes between as-Safa and al-Marwah.
///
/// Drawn from what the source says (p46–47): it begins at as-Safa, going is
/// one pass and returning is another, so the seventh ends at al-Marwah; the
/// stretch between the two green markers is where a man hastens. Nothing
/// here adds a ruling.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';

class SaiCounter extends StatefulWidget {
  const SaiCounter({super.key});

  @override
  State<SaiCounter> createState() => _SaiCounterState();
}

class _SaiCounterState extends State<SaiCounter>
    with SingleTickerProviderStateMixin {
  static const passes = 7;
  int _done = 0;

  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  void _tap() {
    if (_walk.isAnimating) return;
    if (_done >= passes) {
      setState(() => _done = 0);
      return;
    }
    _walk.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _done++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final complete = _done >= passes;
    return Column(
      children: [
        GestureDetector(
          onTap: _tap,
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _walk,
              builder: (context, _) => CustomPaint(
                painter: _SaiPainter(
                  done: _done,
                  progress: Curves.easeInOut.transform(_walk.value),
                  track: scheme.outlineVariant,
                  label: scheme.onSurface,
                  rtl: Directionality.of(context) == TextDirection.rtl,
                  safa: locale == 'ar' ? 'الصفا' : 'as-Safa',
                  marwah: locale == 'ar' ? 'المروة' : 'al-Marwah',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          complete
              ? 'hajj.done'.tr()
              : '${'hajj.lap'.tr()} ${localizeDigits('${_done + 1}', locale)}'
                  ' / ${localizeDigits('$passes', locale)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: complete ? AppColors.success : AppColors.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text('hajj.sai_hint'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        TextButton.icon(
          onPressed: _tap,
          icon: Icon(complete ? Icons.replay_rounded : Icons.touch_app_rounded),
          label: Text(complete ? 'hajj.reset'.tr() : 'hajj.tap_to_count'.tr()),
        ),
      ],
    );
  }
}

class _SaiPainter extends CustomPainter {
  final int done;
  final double progress;
  final Color track;
  final Color label;
  final bool rtl;
  final String safa;
  final String marwah;

  const _SaiPainter({
    required this.done,
    required this.progress,
    required this.track,
    required this.label,
    required this.rtl,
    required this.safa,
    required this.marwah,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.55;
    // as-Safa sits at the reading start: the right edge in Arabic.
    final safaX = rtl ? size.width - 34 : 34.0;
    final marwahX = rtl ? 34.0 : size.width - 34;

    // The masaa, with a faint mark for every completed pass.
    canvas.drawLine(
      Offset(safaX, y),
      Offset(marwahX, y),
      Paint()
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = track.withValues(alpha: 0.5),
    );
    // The two green markers of the hastening stretch.
    for (final f in [0.38, 0.62]) {
      final x = safaX + (marwahX - safaX) * f;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 6, height: 34),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.success,
      );
    }

    void hill(double x, String name) {
      final path = Path()
        ..moveTo(x - 26, y + 14)
        ..quadraticBezierTo(x, y - 36, x + 26, y + 14)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF8D6E63));
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
              color: label, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 22));
    }

    hill(safaX, safa);
    hill(marwahX, marwah);

    // Dots for completed passes along the top.
    final dotY = size.height * 0.12;
    for (var i = 0; i < 7; i++) {
      final dx = safaX + (marwahX - safaX) * (i / 6);
      canvas.drawCircle(
        Offset(dx, dotY),
        5,
        Paint()
          ..color = i < done ? AppColors.gold : track.withValues(alpha: 0.5),
      );
    }

    if (done >= 7) return;
    // Odd passes go Safa -> Marwah, even ones come back.
    final forward = done.isEven;
    final from = forward ? safaX : marwahX;
    final to = forward ? marwahX : safaX;
    final x = from + (to - from) * progress;
    canvas.drawCircle(Offset(x, y), 9, Paint()..color = AppColors.gold);
    canvas.drawCircle(
        Offset(x, y),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = label);
  }

  @override
  bool shouldRepaint(_SaiPainter old) =>
      old.done != done || old.progress != progress || old.rtl != rtl;
}
