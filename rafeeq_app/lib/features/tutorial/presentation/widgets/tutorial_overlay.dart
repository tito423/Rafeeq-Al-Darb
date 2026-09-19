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

import 'dart:math' as math;

// easy_localization re-exports package:intl, whose `TextDirection`
// (LTR/RTL) collides with the `dart:ui` enum (ltr/rtl) this file needs to
// decide which end of the navigation bar a tab sits at.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/utils/digits.dart';
import '../../data/tutorial_anchors.dart';
import '../../data/tutorial_chapters.dart';
import '../../data/tutorial_state.dart';

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

  /// The tour being played, fixed when it starts.
  late final List<TutorialChapter> _chapters =
      ref.read(tutorialModeProvider) == TutorialMode.quick
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter(0));
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // A part further down a scrolling screen is brought into view first,
      // then measured where it has come to rest.
      final anchor = _chapters[i].anchor;
      if (anchor != null) await revealAnchor(anchor);
      if (!mounted || _index != i) return;
      final next = _targetOf(_chapters[i]);
      // A feature that is not on screen — a Home card switched off in
      // Settings — is skipped in the direction the reader was going, never
      // stood in for by a navigation button.
      if (anchor != null && next == null) {
        final step = i >= _lastIndex ? 1 : -1;
        _lastIndex = i;
        final to = i + step;
        if (to < 0) return;
        if (to >= _chapters.length) {
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

  void _next() {
    if (_index >= _chapters.length - 1) {
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
                      draw: Curves.easeInOutCubic
                          .transform(((t - 0.35) / 0.65).clamp(0.0, 1.0)),
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
                            Shadow(
                              color: chapter.accent,
                              blurRadius: 14,
                            ),
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
  Widget _bubble(BuildContext context, TutorialChapter chapter, Rect? spot,
      MediaQueryData media, String locale, double entrance) {
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
    final double topInset =
        spot == null || !below ? 0 : math.max(safeTop, spot.bottom + gap);
    final double bottomInset =
        spot == null || below ? 0 : math.max(safeBottom, h - spot.top + gap);
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
      TutorialChapter chapter, Rect? spot, bool below, String locale) {
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

/// The dim with a rounded hole cut in it, plus a breathing ring on the rim.
class _SpotlightPainter extends CustomPainter {
  final Rect? spot;
  final Color accent;
  final double pulse;

  /// 0 → 1 as the frame's border draws itself around the feature.
  final double draw;

  const _SpotlightPainter({
    required this.spot,
    required this.accent,
    required this.pulse,
    required this.draw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    // «خفي اللي وراها»: dark enough that the lit part is the only thing the
    // eye lands on.
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.84);
    if (spot == null) {
      canvas.drawRect(full, dim);
      return;
    }
    final r = spot!;
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(18));
    // saveLayer + BlendMode.clear is the only way to punch a real hole: a
    // second rectangle in "the background colour" would be wrong on every
    // theme, and there are four.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dim);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // THE FRAME. «يحاوط … بفريم شكله جميل». A soft halo of the stop's own
    // colour, then a gold-to-accent border that DRAWS ITSELF around the
    // feature as the spotlight arrives, then a diamond ornament at each
    // corner once the border has closed.
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = accent.withValues(alpha: 0.18 + 0.12 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(hole.inflate(3), halo);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [AppColors.gold, accent, AppColors.gold],
      ).createShader(r);
    final outline = Path()..addRRect(hole);
    for (final metric in outline.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw.clamp(0.0, 1.0)),
        border,
      );
    }
    // A thin inner line a few pixels in, for the double-rule look of an
    // illuminated frame.
    if (draw >= 1) {
      canvas.drawRRect(
        hole.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.gold.withValues(alpha: 0.55),
      );
    }

    final ornament = ((draw - 0.75) / 0.25).clamp(0.0, 1.0);
    if (ornament > 0) {
      final s = 7.0 * ornament * (1 + 0.12 * pulse);
      final fill = Paint()..color = AppColors.gold;
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent;
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final diamond = Path()
          ..moveTo(c.dx, c.dy - s)
          ..lineTo(c.dx + s, c.dy)
          ..lineTo(c.dx, c.dy + s)
          ..lineTo(c.dx - s, c.dy)
          ..close();
        canvas.drawPath(diamond, fill);
        canvas.drawPath(diamond, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spot != spot ||
      old.pulse != pulse ||
      old.accent != accent ||
      old.draw != draw;
}

/// The explanation itself: a small card with a pointer on the edge facing
/// whatever is lit.
class _ChapterBubble extends StatelessWidget {
  final TutorialChapter chapter;
  final int index;
  final int total;
  final String locale;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Horizontal position of the thing being pointed at, in global pixels.
  /// Null hides the pointer.
  final double? pointerX;

  /// True when the target is BELOW the bubble, so the pointer sits on the
  /// bottom edge.
  final bool pointerBelow;

  const _ChapterBubble({
    required this.chapter,
    required this.index,
    required this.total,
    required this.locale,
    required this.isFirst,
    required this.isLast,
    required this.onPrev,
    required this.onNext,
    required this.onSkip,
    required this.pointerX,
    required this.pointerBelow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: chapter.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(chapter.icon, color: chapter.accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'tutorial.${chapter.key}_title'.tr(),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${localizeDigits('${index + 1}', locale)}'
                  ' / ${localizeDigits('$total', locale)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress, animated from the previous stop's width to this one.
            TweenAnimationBuilder<double>(
              tween: Tween(end: (index + 1) / total),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: chapter.accent,
                  backgroundColor: chapter.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'tutorial.${chapter.key}_body'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(height: 1.5, color: scheme.onSurfaceVariant),
            ),
            if (isFirst) ...[
              const SizedBox(height: 12),
              const _LanguageRow(),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant),
                  child: Text('tutorial.skip'.tr()),
                ),
                const Spacer(),
                if (onPrev != null)
                  TextButton(
                    onPressed: onPrev,
                    child: Text('tutorial.back'.tr()),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: chapter.accent,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  child:
                      Text(isLast ? 'tutorial.done'.tr() : 'tutorial.next'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (pointerX == null) return body;
    final pointer = CustomPaint(
      painter: _PointerPainter(
        x: pointerX!,
        color: scheme.surface,
        up: !pointerBelow,
      ),
      size: const Size(double.infinity, 10),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: pointerBelow ? [body, pointer] : [pointer, body],
    );
  }
}

/// The little triangle on the bubble's edge. Drawn rather than rotated from a
/// glyph so its tip lands under the spotlight's centre whatever the bubble's
/// own left edge is.
class _PointerPainter extends CustomPainter {
  /// Global x of the thing being pointed at.
  final double x;
  final Color color;

  /// True when the triangle sits on the TOP edge (target above the bubble).
  final bool up;

  const _PointerPainter({
    required this.x,
    required this.color,
    required this.up,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The bubble is inset 12 px from the window, and 20 px of margin keeps
    // the tip off a rounded corner.
    final cx =
        x.clamp(20.0, math.max(20.0, size.width + 12 - 20.0)).toDouble() - 12;
    final path = Path();
    if (up) {
      path
        ..moveTo(cx, 0)
        ..lineTo(cx - 10, size.height)
        ..lineTo(cx + 10, size.height);
    } else {
      path
        ..moveTo(cx, size.height)
        ..lineTo(cx - 10, 0)
        ..lineTo(cx + 10, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.x != x || old.up != up || old.color != color;
}

/// The language picker, offered where a reader who cannot read the tour will
/// actually meet it. Changing it here changes the app — the same
/// `context.setLocale` every other language control calls — so the rest of the
/// tour continues in the language just chosen.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('tutorial.language'.tr(),
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in kLanguageNames.entries)
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: e.key == current,
                onSelected: (_) {
                  if (e.key != current) context.setLocale(Locale(e.key));
                },
              ),
          ],
        ),
      ],
    );
  }
}
