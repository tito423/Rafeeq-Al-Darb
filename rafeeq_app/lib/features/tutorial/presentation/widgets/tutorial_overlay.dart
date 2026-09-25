/// The guided tour, played **on the app itself**, one feature at a time.
///
/// «عايزه يشرح كل فيتشر على الشاشة، وحط النص اللي بيشرح في دايرة أو مستطيل
/// صغير … ويشاور عليه بسهم أو حاجة، ويكون أنيمتد».
///
/// So every stop does three things at once: it opens the real tab the feature
/// lives on, it cuts a **spotlight** out of the dim so that one card — or that
/// one navigation button — is the only lit thing on screen, and it puts a
/// small bubble beside it with a **pointer aimed at it**. The spotlight
/// travels between stops instead of jumping, so the eye follows it.
///
/// NO TIMER. The first version advanced itself every four seconds behind a
/// progress hairline; the owner asked for it gone («شيل المؤقت من التوتوريال»)
/// and he is right — a tour that moves while you are still reading is a tour
/// you have to fight. It waits for «التالي» now, and for nothing else.
///
/// The language row is on the first stop because that is the moment it is
/// useful: a reader who cannot read the tour cannot be told where the language
/// setting is.
library;

import 'dart:async';
import 'dart:math' as math;

// easy_localization re-exports package:intl, whose `TextDirection`
// (LTR/RTL) collides with the `dart:ui` enum (ltr/rtl) this file needs to
// decide which end of the navigation bar a tab sits at.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert' show jsonDecode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/utils/digits.dart';
import '../../data/tutorial_anchors.dart';
import '../../data/tutorial_chapters.dart';
import '../../data/tutorial_state.dart';

part 'tour_pieces.dart';
part 'tour_slides.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  /// Switches the shell's visible tab. The overlay drives the app rather than
  /// drawing a picture of it, so it needs the shell's own navigation.
  final void Function(int tab) onGoToTab;

  const TutorialOverlay({super.key, required this.onGoToTab});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with TickerProviderStateMixin {
  int _index = 0;

  /// The tour the reader sees is PICTURES of the app, not the app: «الأفضل
  /// تخلي الجولة اسكرين شوتات … لو ضغطت في أي مكان تاني هتخرج من الجولة»
  /// (owner, 2026-09-25). The live walk below survives only in the capture
  /// build (`--dart-define=RAFEEQ_TOUR_CAPTURE=true`), which drives the real
  /// screens, draws nothing, and logs where each feature is, so that
  /// `scripts/capture_tour.py` can photograph them in every language.
  static const bool _capture = bool.fromEnvironment('RAFEEQ_TOUR_CAPTURE');

  /// The tour being played, fixed when it starts. The capture build walks
  /// both tours in one pass.
  late final List<TutorialChapter> _chapters = _capture
      ? [
          ...quickTutorialChapters,
          for (final c in tutorialChapters)
            if (!quickTutorialChapters.any((q) => q.key == c.key)) c,
        ]
      : ref.read(tutorialModeProvider) == TutorialMode.quick
      ? quickTutorialChapters
      : tutorialChapters;

  /// The stop currently **on screen**, which is not the same thing as
  /// [_index], the stop being moved to.
  ///
  /// «في فليكر في التوتوريال في كل شاشة». Advancing used to rebuild the bubble
  /// with the new chapter immediately, while the new target had not been
  /// measured yet — so the reader got a frame with the old bubble gone and the
  /// new one not yet placed, then the entrance animation, and then the *same*
  /// entrance animation again once the measurement landed and the bubble moved
  /// from the centred branch to the positioned one (a different parent
  /// re-creates the `TweenAnimationBuilder`, key or no key). Recorded at 30 fps
  /// on the owner's Honor: mean frame brightness sat at 97, dropped to 59 in a
  /// single frame, climbed back over seven frames, and then did the whole thing
  /// a second time.
  ///
  /// So the stop on screen changes **once**, in the same `setState` that plants
  /// the measured spotlight. Until then the previous stop simply stays up.
  int _shown = 0;

  bool _closing = false;

  /// The screen drawn under the current stop, if it is about one.
  WidgetBuilder? _screen;

  /// Where the spotlight is now. Null on stops that have nothing to point at.
  Rect? _spot;

  /// Slides the spotlight from the previous target to the next, so the eye is
  /// led rather than teleported.
  late final AnimationController _move = AnimationController(
    vsync: this,
    // Long enough for the frame to be seen drawing itself round the feature.
    duration: const Duration(milliseconds: 900),
  );
  Rect? _from;

  /// The ring around the spotlight breathes, which is what makes a static
  /// highlight read as "look here" rather than as a rendering artefact.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    if (_capture) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enter(0));
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Open chapter [i]'s tab, then measure its target once that tab has had a
  /// frame to lay itself out.
  void _enter(int i) {
    widget.onGoToTab(_chapters[i].tab);
    // A stop about a pushed screen draws that screen under the tour; the
    // next stop takes it away. Rebuilt only when that changes.
    final screen = _chapters[i].screen;
    if (!identical(screen, _screen)) setState(() => _screen = screen);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // A part further down a scrolling screen is brought into view first,
      // then measured where it has come to rest.
      final anchor = _chapters[i].anchor;
      if (anchor != null) await revealAnchor(anchor);
      if (!mounted || _index != i) return;
      final next = await _settledTarget(_chapters[i]);
      if (!mounted || _index != i) return;
      // A feature that is not on screen — a Home card switched off in
      // Settings — is skipped in the direction the reader was going, never
      // stood in for by a navigation button.
      if (anchor != null && next == null) {
        final step = i >= _lastIndex ? 1 : -1;
        _lastIndex = i;
        final to = i + step;
        if (to < 0) return;
        if (to >= _chapters.length) {
          // The capture build goes on to the next language even when the
          // last stops were not on screen.
          if (_capture) {
            unawaited(_nextLanguage());
            return;
          }
          _finish();
          return;
        }
        // No `setState`: a skipped stop must not repaint anything. The bubble
        // on screen stays where it is until the next *shown* stop is measured.
        _index = to;
        _enter(to);
        return;
      }
      _lastIndex = i;
      if (_capture) _logStop(_chapters[i]);
      setState(() {
        _from = _spot;
        _spot = next;
        // The one place the visible stop changes — see [_shown].
        _shown = i;
      });
      _move
        ..reset()
        ..forward();
    });
  }

  /// Measures the target until it has stopped moving.
  ///
  /// «التوتوريال ساعات مش بيجيب الشاشة كاملة اللي بيشرحها زي القبلة». The
  /// target used to be measured once, one frame after switching tabs. A tab
  /// still building answered «no anchor», and the stop was SKIPPED; the
  /// Qibla compass card, which opens as a small «locating…» card and grows
  /// into the compass, was framed at its loading size. So it is measured
  /// frame after frame until the rectangle holds still for six frames, up
  /// to two seconds, and only a target still absent after that is treated
  /// as switched off.
  Future<Rect?> _settledTarget(TutorialChapter chapter) async {
    if (chapter.anchor == null) return null;
    Rect? last;
    var still = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final rect = _targetOf(chapter);
      final same =
          rect != null &&
          last != null &&
          (rect.topLeft - last.topLeft).distance < 1 &&
          (rect.bottomRight - last.bottomRight).distance < 1;
      still = same ? still + 1 : 0;
      if (still >= 6) return rect;
      last = rect;
      await _nextFrame();
    }
    return mounted ? _targetOf(chapter) : null;
  }

  Future<void> _nextFrame() {
    final done = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => done.complete());
    WidgetsBinding.instance.ensureVisualUpdate();
    return done.future;
  }

  /// The last stop entered, so a skipped feature is skipped in the direction
  /// the reader was moving.
  int _lastIndex = 0;

  /// The frame goes around the feature itself, with room for the ornament.
  /// Only the welcome has no target. There is deliberately no fallback to a
  /// navigation button (see `tutorial_chapters.dart`).
  Rect? _targetOf(TutorialChapter chapter) {
    final anchor = chapter.anchor;
    if (anchor == null) return null;
    final rect = anchorRect(anchor);
    if (rect == null) return null;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final framed = rect.inflate(10).intersect(screen.deflate(4));
    return framed.isEmpty ? null : framed;
  }

  /// One line per stop for `scripts/capture_tour.py`: the feature's
  /// rectangle and the screen, in logical pixels, plus the system bars the
  /// script crops away.
  void _logStop(TutorialChapter c) {
    final media = MediaQuery.of(context);
    final rect = c.whole
        ? Offset.zero & media.size
        : (c.anchor == null ? null : anchorRect(c.anchor!));
    final r = rect == null
        ? 'NONE'
        : [
            rect.left,
            rect.top,
            rect.right,
            rect.bottom,
          ].map((v) => v.toStringAsFixed(1)).join(',');
    // ignore: avoid_print
    print(
      'TOURCAP|${context.locale.languageCode}|${c.key}|$r|'
      '${media.size.width.toStringAsFixed(1)},'
      '${media.size.height.toStringAsFixed(1)}|'
      '${media.padding.top.toStringAsFixed(1)},'
      '${media.padding.bottom.toStringAsFixed(1)}|'
      '${media.devicePixelRatio}',
    );
  }

  /// Capture build: after the last stop, the same walk in the next language.
  Future<void> _nextLanguage() async {
    final codes = kLanguageNames.keys.toList();
    final at = codes.indexOf(context.locale.languageCode);
    if (at < 0 || at >= codes.length - 1) {
      // ignore: avoid_print
      print('TOURCAP|DONE');
      _finish();
      return;
    }
    await context.setLocale(Locale(codes[at + 1]));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _index = 0;
    _lastIndex = 0;
    _enter(0);
  }

  void _next() {
    if (_index >= _chapters.length - 1) {
      if (_capture) {
        unawaited(_nextLanguage());
        return;
      }
      _finish();
      return;
    }
    // No `setState`: the stop on screen changes when the new one is measured.
    _index++;
    _enter(_index);
  }

  void _prev() {
    if (_index == 0) return;
    _index--;
    _enter(_index);
  }

  /// The single exit. Every way out lands here — finishing, «تخطّي», and the
  /// back gesture `AppShell` routes in — so "seen" is recorded however the
  /// reader leaves, and the guard stops the paths racing.
  void _finish() {
    if (_closing) return;
    _closing = true;
    endTutorial(ref);
    widget.onGoToTab(AppTab.home);
  }

  @override
  Widget build(BuildContext context) {
    if (!_capture) {
      return Positioned.fill(
        child: TourSlides(chapters: _chapters, onFinish: _finish),
      );
    }
    // The capture build draws nothing over the screen it photographs; a tap
    // anywhere (the script's) moves on.
    return Positioned.fill(
      child: Stack(
        children: [
          if (_screen != null) Positioned.fill(child: _screen!(context)),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
            ),
          ),
        ],
      ),
    );
  }

  // The live overlay's own drawing, kept for reference by the capture walk's
  // history; not built any more.
  // ignore: unused_element
  Widget _liveBuild(BuildContext context) {
    final chapter = _chapters[_shown];
    final locale = context.locale.languageCode;
    final media = MediaQuery.of(context);

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_move, _pulse]),
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_move.value);
          final spot = _spot == null
              ? null
              : (_from == null ? _spot : Rect.lerp(_from, _spot, t));
          return Stack(
            children: [
              // The screen this stop is about, when it is not a tab. It is
              // a const widget, so the animation's rebuilds do not rebuild it.
              if (_screen != null) Positioned.fill(child: _screen!(context)),
              // The dim, with a hole in it. It ignores pointers: the tour
              // advances from its own buttons, so a stray finger cannot skip
              // a stop, and the lit control stays tappable underneath.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      spot: spot,
                      accent: chapter.accent,
                      pulse: _pulse.value,
                      // The border starts drawing as the frame settles.
                      draw: Curves.easeInOutCubic.transform(
                        ((t - 0.35) / 0.65).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              ),
              // «حوط عليها»: besides the ring, an animated hand taps the lit
              // part, so the stop says "this" even to a reader who has not
              // read the bubble yet.
              if (spot != null && t > 0.6)
                Positioned(
                  left: spot.center.dx - 20,
                  top: spot.center.dy - 8 + (1 - _pulse.value) * 10,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: ((t - 0.6) / 0.4).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.92 + _pulse.value * 0.12,
                        child: Icon(
                          Icons.touch_app_rounded,
                          size: 40,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: chapter.accent, blurRadius: 14),
                            const Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _bubble(context, chapter, spot, media, locale, _move.value),
            ],
          );
        },
      ),
    );
  }

  /// The bubble goes below the spotlight when the spotlight is in the upper
  /// part of the screen and above it otherwise, and its pointer follows — so
  /// it never covers the thing it is explaining.
  Widget _bubble(
    BuildContext context,
    TutorialChapter chapter,
    Rect? spot,
    MediaQueryData media,
    String locale,
    double entrance,
  ) {
    final h = media.size.height;
    final safeTop = media.padding.top + 8;
    final safeBottom = media.padding.bottom + 8;
    const gap = 14.0;

    final below = spot == null || spot.center.dy < h * 0.45;
    // Each stop's bubble arrives: it rises a little, grows into place and
    // fades in, keyed by the stop so it replays on every «التالي».
    // The entrance rides [_move] — the controller that is reset exactly once
    // per stop, in the same `setState` that plants the measured spotlight —
    // rather than a keyed `TweenAnimationBuilder`.
    //
    // «في فليكر في التوتوريال في كل شاشة». A `TweenAnimationBuilder` replays
    // from zero whenever its element is rebuilt from scratch, and every stop
    // calls `onGoToTab`, which rebuilds the shell this overlay sits in. So the
    // bubble faded in, snapped back to nothing and faded in again, twice per
    // stop. Logging `_enter` on the owner's Honor proved the tour itself was
    // innocent: it ran once per stop, measured once. Reading the animation out
    // of a controller makes a rebuild recompute the same value instead of
    // starting over.
    final v = Curves.easeOutBack.transform((entrance / 0.5).clamp(0.0, 1.0));
    // The bubble never reaches zero opacity. Swapping one stop's card for the
    // next takes a single frame, and a card that starts that frame invisible
    // reads as a blink — measured at 30 fps, mean frame brightness fell from
    // 98 to 59 for exactly one frame on every stop. Rising from 0.62 keeps the
    // movement (it still lifts and grows into place) without the gap.
    //
    // And not 0.62 either. «التوتوريال رجع تاني يعمل فليكر، مش كتير بس بيعمل»
    // (2026-09-18, after v3.36.1 on his Honor): a card that drops to 62% on
    // every «التالي» and climbs back is a smaller blink, but still a blink.
    // It stays fully opaque now; the lift and the growth carry the arrival.
    final card = RepaintBoundary(
      child: Transform.translate(
        offset: Offset(0, (1 - v) * (below ? 28 : -28)),
        child: Transform.scale(
          scale: 0.9 + 0.1 * v,
          child: _bubbleCard(chapter, spot, below, locale),
        ),
      ),
    );

    // ONE tree, whatever the stop. The welcome used to be `Center(Padding(…))`
    // and every other stop `Positioned(…)`, so the first measured stop moved
    // the card to a different parent — and a widget that changes parent is a
    // new element, which restarts the entrance animation however stable its
    // key is. That second entrance is half of the flicker; the insets change,
    // the shape does not.
    final double topInset = spot == null || !below
        ? 0
        : math.max(safeTop, spot.bottom + gap);
    final double bottomInset = spot == null || below
        ? 0
        : math.max(safeBottom, h - spot.top + gap);
    final double side = spot == null ? 18 : 12;
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, topInset, side, bottomInset),
        child: Align(
          alignment: spot == null
              ? Alignment.center
              : (below ? Alignment.topCenter : Alignment.bottomCenter),
          child: SizedBox(width: double.infinity, child: card),
        ),
      ),
    );
  }

  Widget _bubbleCard(
    TutorialChapter chapter,
    Rect? spot,
    bool below,
    String locale,
  ) {
    return _ChapterBubble(
      chapter: chapter,
      index: _shown,
      total: _chapters.length,
      locale: locale,
      isFirst: _shown == 0,
      isLast: _shown == _chapters.length - 1,
      onPrev: _shown == 0 ? null : _prev,
      onNext: _next,
      onSkip: _finish,
      pointerX: spot?.center.dx,
      pointerBelow: !below,
    );
  }
}
