/// Tawaf, counted: seven circuits around the Kaaba.
///
/// It only draws what the source text says (`hajj_guide.dart`, p41–42): the
/// circuit begins and ends at the Black Stone, and the House is on the
/// pilgrim's left — so the marker travels anticlockwise as seen from above.
/// It rules on nothing; the ruling is in the paragraphs beside it.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/remote_tap.dart';

class TawafCounter extends StatefulWidget {
  const TawafCounter({super.key, this.compact = false});

  /// A looping illustration - no count, no hint, no tap - for the Umrah header,
  /// where the counter itself belongs to the «الطواف» step below.
  final bool compact;

  @override
  State<TawafCounter> createState() => _TawafCounterState();
}

class _TawafCounterState extends State<TawafCounter>
    with SingleTickerProviderStateMixin {
  static const laps = 7;
  int _done = 0;

  /// One full circuit per run.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.compact) _walk.repeat(period: const Duration(seconds: 7));
  }

  @override
  void didUpdateWidget(covariant TawafCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact == widget.compact) return;
    _walk.stop();
    _walk.reset();
    if (widget.compact) _walk.repeat(period: const Duration(seconds: 7));
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  void _tap() {
    if (_walk.isAnimating) return;
    if (_done >= laps) {
      setState(() => _done = 0);
      return;
    }
    _walk.forward(from: 0).whenComplete(() {
      // Reset with the count: left at 1.0, the next frame drew the finished
      // circuit's full trail on the NEXT ring, as if it too were walked.
      if (mounted) {
        setState(() {
          _done++;
          _walk.reset();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final complete = _done >= laps;
    if (widget.compact) {
      return AspectRatio(
        aspectRatio: 1,
        child: AnimatedBuilder(
          animation: _walk,
          builder: (context, _) => CustomPaint(
            painter: _TawafPainter(
              done: 0,
              progress: _walk.value,
              track: scheme.outlineVariant,
              ink: scheme.onSurface,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        RemoteTap(
          onTap: _tap,
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedBuilder(
              animation: _walk,
              builder: (context, _) => CustomPaint(
                painter: _TawafPainter(
                  done: _done,
                  progress: Curves.easeInOut.transform(_walk.value),
                  track: scheme.outlineVariant,
                  ink: scheme.onSurface,
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
                    ' / ${localizeDigits('$laps', locale)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: complete ? AppColors.success : AppColors.gold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'hajj.tawaf_hint'.tr(),
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

class _TawafPainter extends CustomPainter {
  final int done;
  final double progress;
  final Color track;
  final Color ink;

  const _TawafPainter({
    required this.done,
    required this.progress,
    required this.track,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide * 0.40;

    // The mataf: seven faint rings, the completed ones filled in gold.
    for (var i = 0; i < 7; i++) {
      final ring = radius - i * (radius * 0.055);
      canvas.drawCircle(
        c,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = i < done
              ? AppColors.gold.withValues(alpha: 0.85 - i * 0.07)
              : track.withValues(alpha: 0.45),
      );
    }

    // The Kaaba: a black cube with its gold band.
    final side = size.shortestSide * 0.26;
    final kaaba = Rect.fromCenter(center: c, width: side, height: side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kaaba, const Radius.circular(3)),
      Paint()..color = const Color(0xFF111111),
    );
    canvas.drawRect(
      Rect.fromLTWH(kaaba.left, kaaba.top + side * 0.22, side, side * 0.09),
      Paint()..color = AppColors.gold,
    );

    // The Black Stone, on the corner the circuits start from.
    final stone = kaaba.bottomRight;
    canvas.drawCircle(stone, 4.5, Paint()..color = AppColors.gold);

    // Start line from the stone's corner out across the mataf.
    final startAngle = math.atan2(stone.dy - c.dy, stone.dx - c.dx);
    final startLine = Offset(math.cos(startAngle), math.sin(startAngle));
    canvas.drawLine(
      c + startLine * (side * 0.75),
      c + startLine * (radius + 8),
      Paint()
        ..strokeWidth = 1.6
        ..color = AppColors.gold.withValues(alpha: 0.7),
    );

    if (done >= 7) return;

    // The walker: anticlockwise on screen, so the House stays on the left.
    final ringRadius = radius - done * (radius * 0.055);
    final angle = startAngle - progress * 2 * math.pi;
    final pos = c + Offset(math.cos(angle), math.sin(angle)) * ringRadius;

    final trail = Path();
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final a = startAngle - progress * 2 * math.pi * (i / steps);
      final p = c + Offset(math.cos(a), math.sin(a)) * ringRadius;
      i == 0 ? trail.moveTo(p.dx, p.dy) : trail.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(alpha: 0.5),
    );
    canvas.drawCircle(pos, 7, Paint()..color = AppColors.gold);
    canvas.drawCircle(
      pos,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_TawafPainter old) =>
      old.done != done ||
      old.progress != progress ||
      old.track != track ||
      old.ink != ink;
}
