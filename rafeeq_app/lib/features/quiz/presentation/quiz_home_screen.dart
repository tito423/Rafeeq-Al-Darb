import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/proper_name.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart' show localizeDigits;
import '../../library/data/book_catalog.dart';
import '../data/history_quiz.dart';
import '../data/quiz_progress.dart';
import 'quiz_play_screen.dart';
import 'widgets/quiz_effects.dart';

/// Colours and icon of each level's card.
(List<Color>, IconData) quizLevelLook(QuizLevel l) => switch (l) {
  QuizLevel.l1 => (
    const [Color(0xFF7ED957), Color(0xFF2E9E6B)],
    Icons.eco_rounded,
  ),
  QuizLevel.l2 => (
    const [Color(0xFFF7B733), Color(0xFFFC8E3A)],
    Icons.wb_sunny_rounded,
  ),
  QuizLevel.l3 => (
    const [Color(0xFF1FB5C9), Color(0xFF0E7C9A)],
    Icons.explore_rounded,
  ),
  QuizLevel.l4 => (
    const [Color(0xFF7F5AF0), Color(0xFF4834D4)],
    Icons.auto_stories_rounded,
  ),
  QuizLevel.l5 => (
    const [Color(0xFFE0457B), Color(0xFF9B1D5A)],
    Icons.workspace_premium_rounded,
  ),
};

class QuizHomeScreen extends ConsumerStatefulWidget {
  const QuizHomeScreen({super.key});

  @override
  ConsumerState<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends ConsumerState<QuizHomeScreen> {
  final _bank = HistoryQuiz.all();

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final progress = ref.watch(quizProgressProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        // The theme's AppBar gives the title, the icons and the status bar
        // explicit dark colours for a light page, and those win over
        // [foregroundColor]: on this night ground the title was dark on
        // dark (seen on emulator-5554, 3.79.0).
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text('quiz.title'.tr()),
      ),
      body: QuizStarfield(
        child: SafeArea(
          child: FutureBuilder<List<QuizQuestion>>(
            future: _bank,
            builder: (context, snap) {
              final bank = snap.data ?? const <QuizQuestion>[];
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const _Hero(),
                  const SizedBox(height: 8),
                  Text(
                    'quiz.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                  if (progress.answered > 0) ...[
                    const SizedBox(height: 16),
                    _Stats(progress: progress, lang: lang),
                  ],
                  const SizedBox(height: 18),
                  for (final (i, l) in QuizLevel.values.indexed)
                    _Entrance(
                      delay: i,
                      child: _LevelCard(
                        level: l,
                        count: bank.where((q) => q.level == l).length,
                        best: progress.best[l] ?? 0,
                        locked: !progress.unlocked(l),
                        onTap: bank.isEmpty || !progress.unlocked(l)
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      QuizPlayScreen(level: l, bank: bank),
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _SourcesNote(bank: bank),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A large khatam turning slowly in a gold halo.
class _Hero extends StatefulWidget {
  const _Hero();
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _HeroPainter(_c.value),
          child: const Center(
            child: Icon(
              Icons.history_edu_rounded,
              size: 46,
              color: AppColors.goldSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final double t;
  _HeroPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 3);
    canvas.drawCircle(
      c,
      62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.30 + 0.15 * pulse),
            AppColors.gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 70)),
    );
    canvas.drawPath(
      khatamPath(c, 58, t * 2 * math.pi),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.goldSoft.withValues(alpha: 0.9),
    );
    canvas.drawPath(
      khatamPath(c, 44, -t * 2 * math.pi),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.t != t;
}

class _Stats extends StatelessWidget {
  final QuizProgress progress;
  final String lang;
  const _Stats({required this.progress, required this.lang});

  @override
  Widget build(BuildContext context) {
    final pct = progress.answered == 0
        ? 0
        : (progress.correct * 100 / progress.answered).round();
    Widget cell(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.goldSoft, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          cell(
            Icons.quiz_rounded,
            localizeDigits('${progress.answered}', lang),
            'quiz.stat_answered'.tr(),
          ),
          cell(
            Icons.verified_rounded,
            'quiz.percent'.tr(args: [localizeDigits('$pct', lang)]),
            'quiz.stat_accuracy'.tr(),
          ),
          cell(
            Icons.local_fire_department_rounded,
            localizeDigits('${progress.bestStreak}', lang),
            'quiz.stat_streak'.tr(),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final QuizLevel level;
  final int count;
  final int best;
  final bool locked;
  final VoidCallback? onTap;
  const _LevelCard({
    required this.level,
    required this.count,
    required this.best,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final (look, icon) = quizLevelLook(level);
    // A locked stage keeps its shape in grey, so the road ahead shows.
    final colors = locked ? const [Color(0xFF5C6B73), Color(0xFF39464E)] : look;
    final stars = QuizProgress.starsFor(best, 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        shadowColor: colors.last.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: colors,
              ),
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  end: -24,
                  top: -24,
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: _CornerStar(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'quiz.level_${level.name}'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locked
                                  ? 'quiz.locked'.tr(
                                      args: [
                                        localizeDigits(
                                          '${QuizProgress.passMark}',
                                          lang,
                                        ),
                                      ],
                                    )
                                  : 'quiz.level_${level.name}_desc'.tr(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Icon(
                                    i < stars
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  'quiz.count'.tr(
                                    args: [localizeDigits('$count', lang)],
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        locked
                            ? Icons.lock_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
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

class _CornerStar extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      khatamPath(size.center(Offset.zero), size.width / 2),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_CornerStar old) => false;
}

/// Slides and fades its child in, [delay] steps after the screen opens.
class _Entrance extends StatelessWidget {
  final int delay;
  final Widget child;
  const _Entrance({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay * 140),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _SourcesNote extends StatelessWidget {
  final List<QuizQuestion> bank;
  const _SourcesNote({required this.bank});

  @override
  Widget build(BuildContext context) {
    final books = {for (final q in bank) q.book};
    final titles = [
      for (final id in books)
        if (bookById(id) case final b?) '«${properName(b.titleAr, b.titleEn)}»',
    ];
    if (titles.isEmpty) return const SizedBox.shrink();
    return Text(
      'quiz.sources'.tr(args: [titles.join(' · ')]),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12.5,
        height: 1.6,
      ),
    );
  }
}
