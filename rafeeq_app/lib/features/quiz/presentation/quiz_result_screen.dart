import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart' show localizeDigits;
import '../data/history_quiz.dart';
import '../data/quiz_progress.dart';
import 'quiz_play_screen.dart';
import 'widgets/quiz_effects.dart';

/// The end of a round: the score fills its ring, the stars drop in one by
/// one, and a full round sets off the stars once more.
class QuizResultScreen extends StatefulWidget {
  final QuizLevel level;
  final List<QuizQuestion> bank;
  final int score;
  final int total;
  final int bestStreak;
  final bool newRecord;

  /// This round passed the stage and opened the next one.
  final bool openedNext;
  const QuizResultScreen({
    super.key,
    required this.level,
    required this.bank,
    required this.score,
    required this.total,
    required this.bestStreak,
    required this.newRecord,
    this.openedNext = false,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  int _burst = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openedNext ||
        QuizProgress.starsFor(widget.score, widget.total) >= 2) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _burst++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final stars = QuizProgress.starsFor(widget.score, widget.total);
    final ratio = widget.total == 0 ? 0.0 : widget.score / widget.total;
    return Scaffold(
      body: QuizStarfield(
        child: StarBurst(
          trigger: _burst,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
              children: [
                Text(
                  'quiz.result_title_$stars'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => SizedBox(
                      width: 190,
                      height: 190,
                      child: CustomPaint(
                        painter: _Ring(v),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                localizeDigits(
                                  '${(v * widget.total).round()}',
                                  lang,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 54,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'quiz.of_total'.tr(
                                  args: [
                                    localizeDigits('${widget.total}', lang),
                                  ],
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 700 + i * 300),
                        curve: Interval(
                          0.45 + i * 0.12,
                          1,
                          curve: Curves.elasticOut,
                        ),
                        builder: (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: i == 1 ? 64 : 50,
                            color: i < stars
                                ? AppColors.gold
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (widget.openedNext)
                  _Badge(
                    icon: Icons.lock_open_rounded,
                    text: 'quiz.unlocked'.tr(),
                  ),
                if (widget.newRecord)
                  _Badge(
                    icon: Icons.military_tech_rounded,
                    text: 'quiz.new_record'.tr(),
                  ),
                if (widget.bestStreak >= 3)
                  _Badge(
                    icon: Icons.local_fire_department_rounded,
                    text: 'quiz.streak_badge'.tr(
                      args: [localizeDigits('${widget.bestStreak}', lang)],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'quiz.result_note'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizPlayScreen(
                        level: widget.level,
                        bank: widget.bank,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('quiz.play_again'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('quiz.back_levels'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.goldSoft),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  final double v;
  _Ring(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [AppColors.primarySoft, AppColors.gold, AppColors.goldSoft],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.v != v;
}
