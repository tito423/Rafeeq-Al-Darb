/// «قافلة الدرب» - a caravan journey between the cities of Islamic history.
///
/// Owner, 2026-10-07: «لعبة حقيقية كلها انيمشن بس بصبغه اسلامية تناسب
/// الصغار والكبار». Leg one: Makkah to Madinah. Tap to make the lead camel
/// jump the rocks and reach the lanterns; at the city gate a question from
/// the verified quiz bank opens the doors, and the arrival card carries
/// that question's source - the book and its page.
///
/// Drawn with a plain Ticker and a CustomPainter: Flame 1.38 needs Flutter
/// 3.41 and this app is on 3.38.7 (checked 2026-10-07), and one journey
/// game does not need an engine.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/proper_name.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../library/data/book_catalog.dart';
import '../../quiz/data/history_quiz.dart';
import '../data/caravan_world.dart';
import 'caravan_painter.dart';

/// The gate question of leg one: «إلى أي مدينة أذن النبي ﷺ للمسلمين أن
/// يهاجروا من مكة؟» - from the quiz bank, so it is sourced and translated.
const _gateQuestionId = 'ef3e67153c';

class CaravanScreen extends StatefulWidget {
  const CaravanScreen({super.key});

  @override
  State<CaravanScreen> createState() => _CaravanScreenState();
}

class _CaravanScreenState extends State<CaravanScreen>
    with SingleTickerProviderStateMixin {
  CaravanWorld? _world;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  QuizQuestion? _gateQ;
  List<String> _choices = const [];
  String? _wrong;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const []);
    HistoryQuiz.all().then((bank) {
      final q = bank.where((q) => q.id == _gateQuestionId).firstOrNull;
      if (!mounted || q == null) return;
      setState(() => _gateQ = q.localized(context.locale.languageCode));
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world?.dispose();
    super.dispose();
  }

  void _start(CaravanMode mode) {
    _world?.dispose();
    setState(() {
      _world = CaravanWorld(mode: mode, seed: DateTime.now().millisecond);
      _wrong = null;
      final q = _gateQ;
      if (q != null) _choices = q.shuffled(math.Random());
    });
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration now) {
    final w = _world;
    if (w == null) return;
    final dt = _last == Duration.zero
        ? 0.0
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final before = w.phase;
    w.step(dt);
    if (w.phase != before) setState(() {});
  }

  void _answer(String c) {
    final w = _world!;
    if (c == _gateQ!.answer) {
      HapticFeedback.lightImpact();
      setState(w.open);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = c;
        if (w.mode == CaravanMode.adults) {
          w.hearts -= 1;
          if (w.hearts <= 0) w.phase = CaravanPhase.lost;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _world;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF2B2A5C),
        body: w == null
            ? _Intro(onStart: _start)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => w.jump(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (_, box) {
                        w.fit(box.maxWidth, box.maxHeight);
                        return RepaintBoundary(
                          child: CustomPaint(painter: CaravanPainter(w)),
                        );
                      },
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _Hud(world: w),
                      ),
                    ),
                    // The hint fades out after the first seconds; it is
                    // driven by the world's clock, not by a rebuild.
                    AnimatedBuilder(
                      animation: w,
                      builder: (_, _) => IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: w.phase == CaravanPhase.running && w.time < 4
                              ? 1
                              : 0,
                          duration: const Duration(milliseconds: 400),
                          child: Center(
                            child: _Bubble(text: 'caravan.tap_to_jump'.tr()),
                          ),
                        ),
                      ),
                    ),
                    if (w.phase == CaravanPhase.atGate && _gateQ != null)
                      _GateQuestion(
                        question: _gateQ!,
                        choices: _choices,
                        wrong: _wrong,
                        kids: w.mode == CaravanMode.kids,
                        onAnswer: _answer,
                      ),
                    if (w.phase == CaravanPhase.won)
                      _Arrived(
                        world: w,
                        question: _gateQ!,
                        onAgain: () => _start(w.mode),
                        onExit: () => Navigator.of(context).pop(),
                      ),
                    if (w.phase == CaravanPhase.lost)
                      _Lost(
                        onAgain: () => _start(w.mode),
                        onExit: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final void Function(CaravanMode) onStart;
  const _Intro({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final preview = CaravanWorld(mode: CaravanMode.kids);
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (_, box) {
            preview.fit(box.maxWidth, box.maxHeight);
            return CustomPaint(painter: CaravanPainter(preview));
          },
        ),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: IconButton(
              icon: const BackButtonIcon(),
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (_, s, c) => Transform.scale(scale: s, child: c),
                    child: Text(
                      'caravan.title'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFE9B0),
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(blurRadius: 18, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'caravan.leg1'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  const SizedBox(height: 28),
                  _ModeButton(
                    icon: Icons.child_care_outlined,
                    title: 'caravan.kids'.tr(),
                    hint: 'caravan.kids_hint'.tr(),
                    color: const Color(0xFF1F8A70),
                    onTap: () => onStart(CaravanMode.kids),
                  ),
                  const SizedBox(height: 12),
                  _ModeButton(
                    icon: Icons.local_fire_department_outlined,
                    title: 'caravan.adults'.tr(),
                    hint: 'caravan.adults_hint'.tr(),
                    color: const Color(0xFFB8572A),
                    onTap: () => onStart(CaravanMode.adults),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  final Color color;
  final VoidCallback onTap;
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Hud extends StatelessWidget {
  final CaravanWorld world;
  const _Hud({required this.world});

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return AnimatedBuilder(
      animation: world,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            IconButton(
              icon: const BackButtonIcon(),
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
            _Chip(
              icon: Icons.light_outlined,
              text: localizeDigits('${world.collected}', lang),
            ),
            if (world.mode == CaravanMode.adults) ...[
              const SizedBox(width: 6),
              _Chip(
                icon: Icons.favorite_rounded,
                text: localizeDigits('${world.hearts}', lang),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(child: _Road(progress: world.progress)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFFE08A), size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Makkah ... Madinah, with the caravan's place between them.
class _Road extends StatelessWidget {
  final double progress;
  const _Road({required this.progress});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    // Laid out left to right in every language: the caravan walks from the
    // left of the screen to the right, and the road has to match it.
    return Directionality(textDirection: TextDirection.ltr, child: _row(style));
  }

  Widget _row(TextStyle style) {
    return Row(
      children: [
        Text('caravan.makkah'.tr(), style: style),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => SizedBox(
              height: 22,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE08A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: (box.maxWidth - 18) * progress,
                    child: const Icon(
                      Icons.circle,
                      size: 14,
                      color: Color(0xFFFFE08A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('caravan.madinah'.tr(), style: style),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: c),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8C766), width: 2),
            boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black45)],
          ),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

class _GateQuestion extends StatelessWidget {
  final QuizQuestion question;
  final List<String> choices;
  final String? wrong;
  final bool kids;
  final void Function(String) onAnswer;
  const _GateQuestion({
    required this.question,
    required this.choices,
    required this.wrong,
    required this.kids,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.door_front_door_outlined,
          color: Color(0xFFB8892A),
          size: 40,
        ),
        Text(
          'caravan.gate_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'caravan.gate_hint'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Text(
          question.question,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c == wrong
                    ? const Color(0xFFC0392B)
                    : const Color(0xFF1F6B5A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: c == wrong ? null : () => onAnswer(c),
              child: Text(c, textAlign: TextAlign.center),
            ),
          ),
        if (wrong != null)
          Text(
            (kids ? 'caravan.try_again_kids' : 'caravan.try_again').tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC0392B),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );
}

class _Arrived extends StatelessWidget {
  final CaravanWorld world;
  final QuizQuestion question;
  final VoidCallback onAgain, onExit;
  const _Arrived({
    required this.world,
    required this.question,
    required this.onAgain,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final book = libraryBookCatalog
        .where((b) => b.id == question.book)
        .firstOrNull;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFB8892A), size: 44),
          Text(
            'caravan.won_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            localizeDigits(
              'caravan.won_lanterns'.tr(
                args: ['${world.collected}', '${world.lanternsTotal}'],
              ),
              lang,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E7C9),
              borderRadius: BorderRadius.circular(14),
              border: const BorderDirectional(
                start: BorderSide(color: Color(0xFFB8892A), width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.explain,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '«${question.quote}»',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontFamily: 'AmiriQuran',
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'quiz.source'.tr(
                    args: [
                      book == null
                          ? question.book
                          : '${properName(book.titleAr, book.titleEn)} — '
                                '${properName(book.authorAr, book.authorEn)}',
                      localizeDigits('${question.page}', lang),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAgain,
            icon: const Icon(Icons.replay_rounded),
            label: Text('caravan.play_again'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F6B5A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          TextButton(onPressed: onExit, child: Text('caravan.exit'.tr())),
        ],
      ),
    );
  }
}

class _Lost extends StatelessWidget {
  final VoidCallback onAgain, onExit;
  const _Lost({required this.onAgain, required this.onExit});

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.landscape_outlined,
          color: Color(0xFFB8572A),
          size: 44,
        ),
        Text(
          'caravan.lost_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.replay_rounded),
          label: Text('caravan.play_again'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB8572A),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        TextButton(onPressed: onExit, child: Text('caravan.exit'.tr())),
      ],
    ),
  );
}
