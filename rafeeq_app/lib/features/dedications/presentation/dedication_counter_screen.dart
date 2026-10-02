import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';
import '../data/dedication.dart';
import 'dedication_look.dart';

/// Counting for one person, on a screen of its own.
///
/// «شكلها وحش قوي إن أنا أضغط على علامة الزائد يزيد الرقم … عايز قسم
/// الإهداء يبقى أجمل» (owner, 2026-10-02). A «+» on a list card is a form
/// field; counting dhikr for someone you love is not. Here the whole screen
/// is the counter, in that kind's colour, with the person's name over it: a
/// tap anywhere counts, the phone answers each one, the ring fills toward
/// the reader's own goal if they set one, and reaching it is marked.
class DedicationCounterScreen extends ConsumerStatefulWidget {
  const DedicationCounterScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DedicationCounterScreen> createState() =>
      _DedicationCounterScreenState();
}

class _DedicationCounterScreenState
    extends ConsumerState<DedicationCounterScreen>
    with TickerProviderStateMixin {
  /// The press: the circle gives a little under the finger.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 160),
  );

  /// One ring going out from the circle per count.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _press.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _count(Dedication d) async {
    final reaching = d.hasGoal && d.count + 1 == d.goal;
    if (reaching) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _press.forward().then((_) => _press.reverse());
    _pulse.forward(from: 0);
    await ref.read(dedicationsProvider.notifier).bump(d.id, 1);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref
        .watch(dedicationsProvider)
        .where((x) => x.id == widget.id)
        .firstOrNull;
    if (d == null) return const Scaffold();
    final (icon, color) = dedicationLook(d.kind);
    final deep = Color.lerp(color, Colors.black, 0.55)!;
    final lang = context.locale.languageCode;
    final progress =
        d.hasGoal ? (d.count / d.goal).clamp(0.0, 1.0).toDouble() : null;

    return Scaffold(
      backgroundColor: deep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _count(d),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.1,
              colors: [Color.lerp(color, Colors.black, 0.25)!, deep],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── top: close, what is being counted, undo ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'dedication.counter_done'.tr(),
                        color: Colors.white,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.white70, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              d.kind.titleKey.tr(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'dedication.counter_undo'.tr(),
                        color: Colors.white,
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: d.count == 0
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(dedicationsProvider.notifier)
                                    .bump(d.id, -1);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── for whom ──
                Text(
                  'dedication.counter_for'.tr(),
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    d.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (d.note.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                    child: Text(
                      d.note.trim(),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ),
                // ── the counter ──
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final side = math.min(
                          math.min(box.maxWidth, box.maxHeight) * 0.82,
                          320.0,
                        );
                        return AnimatedBuilder(
                          animation: Listenable.merge([_press, _pulse]),
                          builder: (context, _) => SizedBox(
                            width: side * 1.25,
                            height: side * 1.25,
                            child: CustomPaint(
                              painter: _PulsePainter(
                                t: _pulse.value,
                                radius: side / 2,
                                color: color,
                              ),
                              child: Center(
                                child: Transform.scale(
                                  scale: 1 - 0.05 * _press.value,
                                  child: _Dial(
                                    side: side,
                                    color: color,
                                    progress: progress,
                                    count: d.count,
                                    lang: lang,
                                    unit: d.kind.unitKey!.tr(),
                                    goal: d.hasGoal ? d.goal : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // ── what a tap does / the goal reached ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: d.goalReached
                      ? Container(
                          key: const ValueKey('reached'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFFFD166),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'dedication.goal_reached'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          key: const ValueKey('hint'),
                          d.kind == DedicationKind.quran
                              ? 'dedication.counter_hint_pages'.tr()
                              : 'dedication.counter_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The circle: the count, what it counts, and — with a goal — a ring that
/// fills toward it.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.side,
    required this.color,
    required this.progress,
    required this.count,
    required this.lang,
    required this.unit,
    required this.goal,
  });

  final double side;
  final Color color;
  final double? progress;
  final int count;
  final String lang;
  final String unit;
  final int? goal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  localizeDigits('$count', lang),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: side * 0.28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              Text(
                goal == null
                    ? unit
                    : 'dedication.of_goal'.tr(namedArgs: {
                        'goal': localizeDigits('$goal', lang),
                      }),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double? progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // The disc itself.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.12)!,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final stroke = r * 0.07;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.18);
    final ringR = r - stroke * 1.2;
    canvas.drawCircle(c, ringR, track);
    final p = progress;
    if (p == null || p <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = p >= 1 ? const Color(0xFFFFD166) : Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// The ring that goes out from the circle on each count.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.t, required this.radius, required this.color});

  final double t;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      radius * (1 + 0.22 * Curves.easeOut.transform(t)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t) + 0.5
        ..color = Color.lerp(color, Colors.white, 0.5)!
            .withValues(alpha: 0.6 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}
