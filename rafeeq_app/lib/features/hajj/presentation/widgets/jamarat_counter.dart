/// Stoning the jamarat, counted.
///
/// From the source (p63–64, p71–72): on the Day of Sacrifice, Jamrat al-Aqabah
/// alone with seven pebbles; on the Days of Tashreeq, seven at each of the
/// three in order — the one beside Masjid al-Khayf first, then the middle,
/// then al-Aqabah. [nahr] picks which of the two days this shows.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';

class JamaratCounter extends StatefulWidget {
  /// True for the Day of Sacrifice (al-Aqabah only).
  final bool nahr;

  const JamaratCounter({super.key, required this.nahr});

  @override
  State<JamaratCounter> createState() => _JamaratCounterState();
}

class _JamaratCounterState extends State<JamaratCounter>
    with SingleTickerProviderStateMixin {
  static const perJamrah = 7;

  /// Pebbles thrown at each jamrah, in order.
  late List<int> _thrown = List.filled(_count, 0);

  int get _count => widget.nahr ? 1 : 3;

  late final AnimationController _throw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(JamaratCounter old) {
    super.didUpdateWidget(old);
    if (old.nahr != widget.nahr) _thrown = List.filled(_count, 0);
  }

  @override
  void dispose() {
    _throw.dispose();
    super.dispose();
  }

  int get _current => _thrown.indexWhere((n) => n < perJamrah);

  void _tap() {
    if (_throw.isAnimating) return;
    final i = _current;
    if (i < 0) {
      setState(() => _thrown = List.filled(_count, 0));
      return;
    }
    _throw.forward(from: 0).whenComplete(() {
      // Reset with the count, or the pebble stays drawn on the pillar.
      if (mounted) {
        setState(() {
          _thrown[i]++;
          _throw.reset();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final names = widget.nahr
        ? ['hajj.jamrah_aqabah'.tr()]
        : [
            'hajj.jamrah_small'.tr(),
            'hajj.jamrah_middle'.tr(),
            'hajj.jamrah_aqabah'.tr(),
          ];
    final current = _current;
    final complete = current < 0;
    return Column(
      children: [
        GestureDetector(
          onTap: _tap,
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _throw,
              builder: (context, _) => CustomPaint(
                painter: _JamaratPainter(
                  thrown: _thrown,
                  current: current,
                  flight: _throw.value,
                  track: scheme.outlineVariant,
                  label: scheme.onSurface,
                  names: names,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          complete
              ? 'hajj.done'.tr()
              : '${names[current]} · ${'hajj.pebble'.tr()} '
                  '${localizeDigits('${_thrown[current] + 1}', locale)}'
                  ' / ${localizeDigits('$perJamrah', locale)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: complete ? AppColors.success : AppColors.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.nahr ? 'hajj.jamarat_nahr_hint'.tr() : 'hajj.jamarat_hint'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        TextButton.icon(
          onPressed: _tap,
          icon: Icon(complete ? Icons.replay_rounded : Icons.touch_app_rounded),
          label: Text(complete ? 'hajj.reset'.tr() : 'hajj.tap_to_count'.tr()),
        ),
      ],
    );
  }
}

class _JamaratPainter extends CustomPainter {
  final List<int> thrown;
  final int current;
  final double flight;
  final Color track;
  final Color label;
  final List<String> names;

  const _JamaratPainter({
    required this.thrown,
    required this.current,
    required this.flight,
    required this.track,
    required this.label,
    required this.names,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = thrown.length;
    final baseY = size.height * 0.72;
    // Reading order right-to-left in the drawing, first jamrah on the right.
    double xOf(int i) => size.width * (n == 1 ? 0.5 : 0.82 - i * 0.32);

    for (var i = 0; i < n; i++) {
      final x = xOf(i);
      final active = i == current;
      // The basin.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, baseY), width: 78, height: 22),
        Paint()..color = track.withValues(alpha: active ? 0.7 : 0.4),
      );
      // The pillar.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, baseY - 40), width: 22, height: 80),
          const Radius.circular(6),
        ),
        Paint()
          ..color = thrown[i] >= 7
              ? AppColors.success
              : (active ? AppColors.gold : const Color(0xFF9E9E9E)),
      );
      // Seven pebble slots under the basin.
      for (var p = 0; p < 7; p++) {
        canvas.drawCircle(
          Offset(x - 27 + p * 9, baseY + 22),
          3.2,
          Paint()
            ..color = p < thrown[i]
                ? AppColors.gold
                : track.withValues(alpha: 0.6),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
              color: label, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, baseY + 32));
    }

    if (current < 0 || flight <= 0) return;
    // A pebble arcs in from below the view onto the active pillar.
    final tx = xOf(current);
    final start = Offset(size.width * 0.5, size.height);
    final end = Offset(tx, baseY - 30);
    final t = flight;
    final x = start.dx + (end.dx - start.dx) * t;
    final y = start.dy + (end.dy - start.dy) * t -
        math.sin(t * math.pi) * size.height * 0.35;
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(_JamaratPainter old) =>
      old.flight != flight || old.current != current || old.thrown != thrown;
}
