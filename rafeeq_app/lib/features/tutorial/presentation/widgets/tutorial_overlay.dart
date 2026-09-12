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
  bool _closing = false;

  /// Where the spotlight is now. Null on stops that have nothing to point at.
  Rect? _spot;

  /// Slides the spotlight from the previous target to the next, so the eye is
  /// led rather than teleported.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
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
    widget.onGoToTab(tutorialChapters[i].tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _targetOf(tutorialChapters[i]);
      setState(() {
        _from = _spot;
        _spot = next;
      });
      _move
        ..reset()
        ..forward();
    });
  }

  /// A chapter points at its own card when that card is on screen, and
  /// otherwise at the navigation button that leads to it. The welcome stop
  /// points at nothing, on purpose.
  Rect? _targetOf(TutorialChapter chapter) {
    if (chapter.key == 'welcome') return null;
    final anchor = chapter.anchor;
    if (anchor != null) {
      final rect = anchorRect(anchor);
      if (rect != null) return rect.inflate(6);
    }
    return _navItemRect(chapter.tab);
  }

  /// The navigation bar is seven equal cells across the bottom of the window.
  /// Measuring it through a key would mean reaching into `AppShell`'s private
  /// tree; its geometry is fixed and known, so it is computed.
  Rect? _navItemRect(int tab) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final bottomInset = media.padding.bottom;
    const barHeight = 68.0;
    final cell = width / 7;
    // The bar lays its destinations out in reading order, so under RTL the
    // first tab sits on the RIGHT. Getting this wrong points confidently at
    // the wrong button, which is worse than not pointing at all.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final slot = rtl ? 6 - tab : tab;
    final top = media.size.height - bottomInset - barHeight;
    return Rect.fromLTWH(slot * cell + 6, top + 2, cell - 12, barHeight - 4);
  }

  void _next() {
    if (_index >= tutorialChapters.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _enter(_index);
  }

  void _prev() {
    if (_index == 0) return;
    setState(() => _index--);
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
    final chapter = tutorialChapters[_index];
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
                    ),
                  ),
                ),
              ),
              _bubble(context, chapter, spot, media, locale),
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
      MediaQueryData media, String locale) {
    final h = media.size.height;
    final safeTop = media.padding.top + 8;
    final safeBottom = media.padding.bottom + 8;
    const gap = 14.0;

    final below = spot == null || spot.center.dy < h * 0.45;
    final card = _ChapterBubble(
      chapter: chapter,
      index: _index,
      total: tutorialChapters.length,
      locale: locale,
      isFirst: _index == 0,
      isLast: _index == tutorialChapters.length - 1,
      onPrev: _index == 0 ? null : _prev,
      onNext: _next,
      onSkip: _finish,
      pointerX: spot?.center.dx,
      pointerBelow: !below,
    );

    if (spot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: card,
        ),
      );
    }
    return Positioned(
      left: 12,
      right: 12,
      top: below ? math.max(safeTop, spot.bottom + gap) : null,
      bottom: below ? null : math.max(safeBottom, h - spot.top + gap),
      child: card,
    );
  }
}

/// The dim with a rounded hole cut in it, plus a breathing ring on the rim.
class _SpotlightPainter extends CustomPainter {
  final Rect? spot;
  final Color accent;
  final double pulse;

  const _SpotlightPainter({
    required this.spot,
    required this.accent,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.72);
    if (spot == null) {
      canvas.drawRect(full, dim);
      return;
    }
    final hole = RRect.fromRectAndRadius(spot!, const Radius.circular(16));
    // saveLayer + BlendMode.clear is the only way to punch a real hole: a
    // second rectangle in "the background colour" would be wrong on every
    // theme, and there are four.
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dim);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = accent.withValues(alpha: 0.95),
    );
    // The breath: a second ring stepping outwards and fading as it goes.
    final grow = 4 + pulse * 10;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          spot!.inflate(grow), Radius.circular(16 + grow * 0.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.45 * (1 - pulse)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spot != spot || old.pulse != pulse || old.accent != accent;
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
