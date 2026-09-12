import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/rafeeq_app.dart' show sharedPrefsProvider;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/tutorial_state.dart';

/// The guided tour: one page per part of the app, in the order the bottom bar
/// puts them, so a reader who follows it ends up knowing where everything is.
///
/// «عايزك تعمل توتوريال احترافي يشرح استخدام كل الفيتشرز اللي في التطبيق شاشة
/// شاشة … وخليه يتفاعل مع الثيم وخليه توتوريال روعة بصريًا».
///
/// WHY IT IS DRAWN AND NOT SCREENSHOTTED.
/// The obvious way to illustrate a tour is a screenshot per page. This app has
/// four themes, seven languages and both text and image mushaf modes, so a
/// screenshot is wrong for most readers the day it is taken and wrong for
/// everyone the first time a screen is restyled — a second catalogue of claims
/// (§1.1), in picture form. Every page here is painted instead, from the
/// theme's own colours and the same `Icons` the real screens use, so it cannot
/// disagree with the app it describes and it follows the theme the reader
/// actually chose.
///
/// The skip control is present on every page, including the last, and the
/// system back gesture closes the tour the same way — `_finish` is the single
/// exit, so "seen" is recorded however the reader leaves.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  /// Opens the tour over whatever is on screen.
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, _, _) => const TutorialScreen(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    ),
  );

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();

  /// The live page position, fractional while a swipe is in flight — the
  /// medallion and the text parallax off it, so the pages feel joined rather
  /// than cut.
  double _page = 0;

  /// Drives the medallion's slow rotation and the motes around it. One
  /// controller for the whole screen; the pages are stateless.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = _controller.page;
      if (p != null && p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _chapters.length - 1);
  bool get _isLast => _index == _chapters.length - 1;

  Future<void> _finish() async {
    // Whatever the exit — «ابدأ», the skip button, or the back gesture — the
    // tour counts as seen, so it does not ambush the reader again tomorrow
    // unless they asked for it on every launch.
    await markTutorialSeen(ref.read(sharedPrefsProvider));
    if (mounted) Navigator.of(context).maybePop();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() => _controller.previousPage(
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final chapter = _chapters[_index];
    final accent = chapter.accent;

    return PopScope(
      // The back gesture is a legitimate way out, but it has to go through
      // `_finish` so "seen" is written. `canPop: false` + this handler is the
      // only way to get both.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        // The tour is pushed over the app on a translucent route, so its own
        // ground has to be opaque or the Home screen shows through the text.
        backgroundColor: dark ? AppColors.night : AppColors.lightScaffold,
        body: Stack(
          children: [
            // The accent wash behind everything, easing from one chapter's
            // colour to the next as the pages move.
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.55),
                    radius: 1.1,
                    colors: [
                      accent.withValues(alpha: dark ? 0.22 : 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(theme, scheme),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _chapters.length,
                      itemBuilder: (context, i) => _Page(
                        chapter: _chapters[i],
                        spin: _spin,
                        // How far this page is from the centre, -1..1. The
                        // medallion counter-rotates and the text slides, both
                        // off this one number.
                        offset: i - _page,
                      ),
                    ),
                  ),
                  _bottomBar(theme, scheme, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(ThemeData theme, ColorScheme scheme) {
    final locale = context.locale.languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          Text(
            '${localizeDigits('${_index + 1}', locale)}'
            ' / ${localizeDigits('${_chapters.length}', locale)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Present on every page, the last one included: «وزرار اسكيب في أي
          // وقت» means at any time, not "until the end".
          TextButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text('tutorial.skip'.tr()),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme, ColorScheme scheme, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        children: [
          // The rail: one segment per chapter, the current one wide and lit.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _chapters.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? accent
                        : scheme.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Nothing to go back to on the first page; the slot is kept so
              // the «التالي» button does not jump sideways.
              SizedBox(
                width: 96,
                child: _index == 0
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text('tutorial.back'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _next,
                icon: Icon(
                  _isLast
                      ? Icons.check_rounded
                      // Trap #7: `arrow_forward` mirrors in RTL, which is
                      // right here — "next" really does point the way the
                      // pages move, and the pages move with the language.
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
                label: Text(
                  _isLast ? 'tutorial.start'.tr() : 'tutorial.next'.tr(),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One chapter of the tour.
class _Chapter {
  final IconData icon;
  final Color accent;

  /// `tutorial.<key>_title` and `tutorial.<key>_body`.
  final String key;

  const _Chapter(this.key, this.icon, this.accent);
}

/// The app, in the order its bottom bar puts it — Home, Quran, Prayer, Azkar,
/// Tasbeeh, Library, More — with the three things that cut across all of them
/// (themes and languages, working offline, and where the content comes from)
/// at the end.
///
/// Every line of this describes something that is actually in the build. When
/// a feature is added or removed, its chapter moves with it.
const _chapters = <_Chapter>[
  _Chapter('welcome', Icons.mosque_rounded, AppColors.gold),
  _Chapter('home', Icons.home_rounded, AppColors.primarySoft),
  _Chapter('quran', Icons.menu_book_rounded, AppColors.gold),
  _Chapter('recite', Icons.headphones_rounded, Color(0xFF2E9FE8)),
  _Chapter('prayer', Icons.mosque_outlined, Color(0xFF6C5FBC)),
  _Chapter('azkar', Icons.spa_rounded, Color(0xFF2E9D6F)),
  _Chapter('tasbeeh', Icons.radio_button_checked, Color(0xFFD4785A)),
  _Chapter('library', Icons.local_library_rounded, Color(0xFF3F7A8C)),
  _Chapter('more', Icons.widgets_rounded, AppColors.goldSoft),
  _Chapter('themes', Icons.palette_rounded, Color(0xFF5C8A6E)),
  _Chapter('offline', Icons.cloud_off_rounded, AppColors.info),
  _Chapter('sources', Icons.verified_rounded, AppColors.gold),
];

class _Page extends StatelessWidget {
  final _Chapter chapter;
  final Animation<double> spin;

  /// Distance from the centre of the viewport, in pages.
  final double offset;

  const _Page({
    required this.chapter,
    required this.spin,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Anything off-centre is dimmed and pushed down a little, so the page
    // being read is plainly the one in focus.
    final t = offset.abs().clamp(0.0, 1.0);
    final fade = 1 - t;

    // Centred in the viewport, and only scrollable when the text is longer
    // than it — seen on emulator-5554: top-aligned, every page hung from the
    // top with a third of the screen empty under it, which reads as a page
    // that has not finished loading.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 6, 26, 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                // The medallion drifts against the swipe: a parallax, not a slide.
                offset: Offset(offset * -46, 0),
                child: Opacity(
                  opacity: (0.35 + 0.65 * fade).clamp(0.0, 1.0),
                  child: _Medallion(
                    icon: chapter.icon,
                    accent: chapter.accent,
                    spin: spin,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(0, 18 * t),
                  child: Column(
                    children: [
                      Text(
                        'tutorial.${chapter.key}_title'.tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 64,
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                chapter.accent.withValues(alpha: 0),
                                chapter.accent,
                                chapter.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'tutorial.${chapter.key}_body'.tr(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.95,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chapter's mark: its icon inside a turning eight-point medallion, with a
/// glow and a few orbiting motes. The app's own geometry rather than generic
/// onboarding art, and it takes the chapter's accent so the whole page — wash,
/// rule, rail and button — is one colour.
class _Medallion extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Animation<double> spin;

  const _Medallion({
    required this.icon,
    required this.accent,
    required this.spin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, child) => CustomPaint(
          painter: _MedallionPainter(t: spin.value, accent: accent),
          child: child,
        ),
        child: Center(child: Icon(icon, size: 62, color: accent)),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  /// 0..1 phase of the loop.
  final double t;
  final Color accent;

  const _MedallionPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final tau = 2 * math.pi;

    // The glow.
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..color = accent.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );

    // Two squares at 45° — the rub el hizb — turning slowly one way, and a
    // ring of eight points turning the other, so the mark is never static but
    // never distracting either.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.55);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * tau * 0.25);
    for (var k = 0; k < 2; k++) {
      canvas.save();
      canvas.rotate(k * math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r * 1.05, height: r * 1.05),
        stroke,
      );
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.28),
    );

    // Eight motes on the outer ring, counter-turning.
    for (var i = 0; i < 8; i++) {
      final a = -t * tau * 0.4 + i * tau / 8;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 0.88);
      canvas.drawCircle(
        p,
        2.2 + 1.2 * (0.5 + 0.5 * math.sin(t * tau * 2 + i)),
        Paint()..color = accent.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) =>
      old.t != t || old.accent != accent;
}
