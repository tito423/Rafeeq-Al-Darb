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
///
/// Leg two (2026-10-08): Madinah to Bayt al-Maqdis, reached from the
/// arrival card of leg one. Every leg's gate question is an id in the quiz
/// bank ([CaravanLeg.gateQuestionId]); a test holds each one to the bank.
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

part 'caravan_cards.dart';

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
  CaravanLeg _leg = CaravanLeg.first;

  /// Gate questions by id, localized, loaded once from the bank.
  final _gates = <String, QuizQuestion>{};
  QuizQuestion? get _gateQ => _gates[_leg.gateQuestionId];
  List<String> _choices = const [];
  String? _wrong;
  Offset? _down;
  bool _swiped = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const []);
    final ids = {for (final l in CaravanLeg.all) l.gateQuestionId};
    HistoryQuiz.all().then((bank) {
      if (!mounted) return;
      final lang = context.locale.languageCode;
      setState(() {
        for (final q in bank) {
          if (ids.contains(q.id)) _gates[q.id] = q.localized(lang);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world?.dispose();
    super.dispose();
  }

  void _start(CaravanMode mode, [CaravanLeg? leg]) {
    _world?.dispose();
    setState(() {
      _leg = leg ?? _leg;
      _world = CaravanWorld(
        mode: mode,
        leg: _leg,
        lang: context.locale.languageCode,
        seed: DateTime.now().millisecond,
      );
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
            ? _Intro(onStart: (m) => _start(m, CaravanLeg.first))
            : Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _down = e.position;
                  _swiped = false;
                  w.jump();
                },
                onPointerMove: (e) {
                  final d = _down;
                  if (d != null && !_swiped && e.position.dy - d.dy > 28) {
                    _swiped = true;
                    w.duck();
                  }
                },
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
                    AnimatedBuilder(
                      animation: w,
                      builder: (_, _) {
                        final b = w.banner;
                        final t = w.bannerAge;
                        final a = b == null
                            ? 0.0
                            : (t < 0.3
                                      ? t / 0.3
                                      : (t > 1.8 ? (2.2 - t) / 0.4 : 1.0))
                                  .clamp(0.0, 1.0);
                        return IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, -0.45),
                            child: Opacity(
                              opacity: a,
                              child: Transform.scale(
                                scale: 0.9 + 0.1 * a,
                                child: b == null
                                    ? const SizedBox.shrink()
                                    : _Banner(text: b.tr()),
                              ),
                            ),
                          ),
                        );
                      },
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
                        onNext:
                            _leg.isLast ||
                                _gates[_leg.next.gateQuestionId] == null
                            ? null
                            : () => _start(w.mode, _leg.next),
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
            Expanded(
              child: _Road(leg: world.leg, progress: world.progress),
            ),
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

/// The leg's two cities, with the caravan's place between them.
class _Road extends StatelessWidget {
  final CaravanLeg leg;
  final double progress;
  const _Road({required this.leg, required this.progress});

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
        Text(leg.fromKey.tr(), style: style),
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
        Text(leg.toKey.tr(), style: style),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFB8892A), Color(0xFFE8C766), Color(0xFFB8892A)],
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF3B2A12),
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
