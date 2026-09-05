import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';

/// Renders one mushaf page as real Uthmani text laid out per the real
/// Madani page boundaries (from the bundled database), as one continuous
/// justified paragraph — the way a printed mushaf actually reads — rather
/// than a separate row per ayah.
///
/// Three reading affordances, matching the image-mode page:
///  - **scrolls** vertically when a page's text is taller than the screen
///    (`SingleChildScrollView`) — text no longer gets silently shrunk to fit;
///  - **font size** is controlled from `QuranScreen`'s app bar and just
///    reflows this paragraph, so it always stays crisp (real text, never a
///    scaled bitmap);
///  - **pinch-to-zoom** (`InteractiveViewer`, same `minScale`/`maxScale` as
///    `MushafPageView`) for an optical zoom on top of that, high-quality for
///    the same reason — Flutter renders text as vector glyphs, so scaling it
///    up never blurs.
///
/// P3‑39 (the owner's own clarification of P3‑34's ambiguous "speed
/// control"): an optional **auto-scroll** — the page scrolls itself at a
/// steady, adjustable pace instead of needing a manual swipe, for
/// hands-free continuous reading (a phone propped on a stand, say). Only
/// runs while [isActive] is true, so the `PageView` that hosts this widget
/// never has more than one page silently auto-scrolling in the background
/// at once — every neighbouring page `PageView.builder` keeps pre-built
/// for smooth swiping stays motionless until it actually becomes current.
class MushafTextPage extends StatefulWidget {
  final List<Ayah> ayahs;

  /// Real surah-name lookup, used to render a banner before every surah
  /// that actually starts on this page — see [_MushafTextPageState.build]'s
  /// doc for why this replaced a single `surahHeader` (P3‑43 #3): several
  /// short surahs near the end of the mushaf share one physical page (e.g.
  /// page 603 holds the starts of both سورة الكافرون and سورة المسد), and
  /// a single fixed header picked the lowest surah id every time —
  /// jumping to المسد's own start page then showed "سورة الكافرون" at the
  /// top, reading as "jumped to the wrong surah" even though the page
  /// itself, and المسد's own text on it, were always correct.
  final String Function(int surahId) surahNameOf;

  /// P3‑41: fires on a **long press** of an ayah, not a plain tap any
  /// more — real-device feedback: "if I press the page directly it shows
  /// an ayah and directly shows the ayah card, no, I want if press the
  /// page options icons show and if I press again it disappear". A plain
  /// tap anywhere on the page (including on the text itself) now toggles
  /// the toolbar via [onBackgroundTap] instead; opening the sciences
  /// sheet needs a deliberate hold.
  final void Function(Ayah ayah) onAyahTap;
  final double fontScale;

  /// A plain tap anywhere on this page that wasn't a long-press on an
  /// ayah — the toolbar-visibility toggle lives one level up in
  /// `QuranScreen`, this just reports "the page itself was tapped".
  final VoidCallback? onBackgroundTap;

  /// P3‑41: "give option so I can change page from small to full fit of
  /// screen" — when true, the page's own card padding/border shrink
  /// toward the edges so its real content claims as much of the screen
  /// as it can, instead of sitting in a smaller bordered card.
  final bool pageFillScreen;

  /// Whether auto-scroll should be running at all right now.
  final bool autoScroll;

  /// Pixels per second — a plain speed, not an opaque 1–5 level, so the
  /// caller's slider maps directly to something a reader can actually feel
  /// the difference of.
  final double autoScrollSpeed;

  /// True only for the page the `PageView` is actually showing — see the
  /// class doc above for why this gates the timer, not just [autoScroll].
  final bool isActive;

  /// Fires once when auto-scroll reaches the bottom of this page's own
  /// content, so the parent can turn the page and keep the reading flow
  /// going rather than just stopping dead at the page boundary.
  final VoidCallback? onAutoScrollReachedEnd;

  const MushafTextPage({
    super.key,
    required this.ayahs,
    required this.surahNameOf,
    required this.onAyahTap,
    this.fontScale = 1.0,
    this.onBackgroundTap,
    this.pageFillScreen = false,
    this.autoScroll = false,
    this.autoScrollSpeed = 40,
    this.isActive = true,
    this.onAutoScrollReachedEnd,
  });

  @override
  State<MushafTextPage> createState() => _MushafTextPageState();
}

class _MushafTextPageState extends State<MushafTextPage> {
  final TransformationController _transform = TransformationController();
  final List<_SoloPointerLongPressRecognizer> _recognizers = [];
  final ScrollController _scroll = ScrollController();
  Timer? _autoTimer;
  bool _reachedEndFired = false;

  /// P3‑43 #1: a real pinch-to-zoom regression traced to this same
  /// session's own P3‑42 change. Two things compete with
  /// `InteractiveViewer`'s two-finger scale recognizer for the same
  /// pointers: the per-ayah tap became a `LongPressGestureRecognizer`
  /// (holds the gesture arena open for its ~500ms deadline instead of
  /// resolving immediately), and the background-tap `GestureDetector` was
  /// added as an *ancestor* of `InteractiveViewer` (the image-mode page,
  /// `MushafPageView`, keeps its own tap detector as InteractiveViewer's
  /// *child* instead — the pattern that was never broken). Tracking real
  /// pointer count here (via a plain `Listener`, which observes the raw
  /// pointer stream without joining the gesture arena at all) lets every
  /// custom recognizer below refuse to enter the arena the moment a
  /// second finger is already down, so a two-finger pinch is never
  /// contested by a single-pointer tap/long-press recognizer.
  int _activePointers = 0;
  bool get _otherPointerActive => _activePointers >= 1;

  static const _tickInterval = Duration(milliseconds: 50);

  /// Panning only makes sense once the user has actually pinched past 1×
  /// zoom — before that there's nothing to pan, so it stays off until then.
  /// (An earlier version of this comment claimed a plain swipe never reaches
  /// the reader's page-turning `PageView` past `InteractiveViewer` — that
  /// was wrong: it was this slow emulator's animation/frame lag being
  /// mistaken for a dropped gesture from screenshotting too soon after the
  /// swipe. Re-tested with a longer wait: swiping through the zoomed
  /// `InteractiveViewer` genuinely turns the page, same as the ‹ › buttons.)
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
    _transform.addListener(_onTransformChanged);
    _syncAutoScroll();
  }

  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _panEnabled) setState(() => _panEnabled = zoomed);
  }

  @override
  void didUpdateWidget(covariant MushafTextPage old) {
    super.didUpdateWidget(old);
    if (old.ayahs != widget.ayahs) _buildRecognizers();
    _syncAutoScroll();
  }

  /// Starts/stops the auto-scroll timer to match the widget's current
  /// `autoScroll`/`isActive` — called from both `initState` (a page can be
  /// built already-active, e.g. after an auto-scroll page turn) and
  /// `didUpdateWidget` (the parent toggles the feature, changes speed, or
  /// this page stops being the active one).
  void _syncAutoScroll() {
    final shouldRun = widget.autoScroll && widget.isActive;
    if (shouldRun && _autoTimer == null) {
      _reachedEndFired = false;
      _autoTimer = Timer.periodic(_tickInterval, (_) => _tickAutoScroll());
    } else if (!shouldRun && _autoTimer != null) {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
  }

  void _tickAutoScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next =
        (_scroll.offset +
                widget.autoScrollSpeed * _tickInterval.inMilliseconds / 1000)
            .clamp(0.0, max);
    _scroll.jumpTo(next);
    if (next >= max && !_reachedEndFired) {
      // Fire once, then stop this page's own timer — the parent decides
      // what happens next (turn the page, or stop altogether at the end
      // of the mushaf); this widget's job ends at "I've scrolled as far
      // as I can".
      _reachedEndFired = true;
      _autoTimer?.cancel();
      _autoTimer = null;
      widget.onAutoScrollReachedEnd?.call();
    }
  }

  void _buildRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers
      ..clear()
      ..addAll(
        widget.ayahs.map(
          (a) => _SoloPointerLongPressRecognizer(
            otherPointerActive: () => _otherPointerActive,
          )..onLongPress = () => widget.onAyahTap(a),
        ),
      );
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _autoTimer?.cancel();
    _scroll.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (widget.ayahs.isEmpty) {
      return const Center(child: Text('—'));
    }

    final paper = isDark ? AppColors.nightSurface : AppColors.paper;
    final ink = isDark ? AppColors.paperDark : AppColors.ink;
    final baseFont = 23.0 * widget.fontScale;
    // P3‑41: "full fit" shrinks the card's own margins/border toward the
    // edges instead of changing the text's own font scale (that's what
    // the A+/A- actions already own) — the real content gets more of the
    // screen without becoming a second, competing "zoom" control.
    final fill = widget.pageFillScreen;

    final textStyle = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: baseFont,
      height: 2.05,
      color: ink,
    );

    // P3‑43 #3: several short surahs near the end of the mushaf share one
    // physical page — this loop renders a real banner before EVERY surah
    // that actually starts here (not just one fixed pick for the whole
    // page), grouping consecutive same-surah ayahs into their own
    // Text.rich so a banner can sit between groups, matching how a real
    // printed mushaf stacks multiple surah headers on such a page.
    final blocks = <Widget>[];
    var groupStart = 0;
    void flushGroup(int end) {
      if (end <= groupStart) return;
      blocks.add(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text.rich(
            TextSpan(
              children: [
                for (var i = groupStart; i < end; i++) ...[
                  TextSpan(
                    text: widget.ayahs[i].textUthmani,
                    recognizer: _recognizers[i],
                  ),
                  // P3‑32: `PlaceholderAlignment.middle` centers the
                  // marker within the *line's* full ascent+descent
                  // box — for `AmiriQuran`, whose metrics reserve a
                  // lot of extra room above the baseline for
                  // tashkeel, that box is taller and sits higher
                  // than the visible base letters, so the marker
                  // read as sitting low relative to the actual
                  // Arabic glyphs next to it. `baseline` pins it to
                  // the alphabetic baseline instead — a stable
                  // reference line the base letters actually sit
                  // on, independent of how much tashkeel headroom
                  // the font reserves.
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: _AyahMarker(
                      number: widget.ayahs[i].ayahNumber,
                      fontScale: widget.fontScale,
                    ),
                  ),
                  const TextSpan(text: ' '),
                ],
              ],
            ),
            textAlign: TextAlign.justify,
            style: textStyle,
          ),
        ),
      );
    }

    for (var i = 0; i < widget.ayahs.length; i++) {
      final isNewSurah = i == 0
          ? widget.ayahs[i].ayahNumber == 1
          : widget.ayahs[i].surahId != widget.ayahs[i - 1].surahId;
      if (isNewSurah) {
        flushGroup(i);
        groupStart = i;
        blocks.add(
          _SurahBanner(name: widget.surahNameOf(widget.ayahs[i].surahId)),
        );
      }
    }
    flushGroup(widget.ayahs.length);

    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );

    final card = Container(
      padding: fill
          ? const EdgeInsets.fromLTRB(10, 14, 10, 14)
          : const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(fill ? 8 : 20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: fill ? 0.18 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: page,
    );

    // The background-tap detector is a *child* of `InteractiveViewer`
    // here, matching `MushafPageView` (image mode)'s own, never-broken
    // structure — not an ancestor wrapping it, which is what P3‑42
    // originally shipped and what made the tap recognizer a competitor
    // for the same pointers as the scale gesture (P3‑43 #1).
    final tappableScroll = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _SoloPointerTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_SoloPointerTapRecognizer>(
              () => _SoloPointerTapRecognizer(
                otherPointerActive: () => _otherPointerActive,
              ),
              (instance) => instance.onTap = widget.onBackgroundTap,
            ),
      },
      child: SingleChildScrollView(
        controller: _scroll,
        padding: fill
            ? const EdgeInsets.fromLTRB(4, 8, 4, 16)
            : const EdgeInsets.fromLTRB(14, 18, 14, 28),
        child: card,
      ),
    );

    return Listener(
      // Raw pointer observation only — a `Listener` never joins the
      // gesture arena, so counting pointers here can never itself compete
      // with `InteractiveViewer`'s scale recognizer or the recognizers
      // above; it only tells them whether a second finger is already down.
      onPointerDown: (_) => _activePointers++,
      onPointerUp: (_) => _activePointers = math.max(0, _activePointers - 1),
      onPointerCancel: (_) =>
          _activePointers = math.max(0, _activePointers - 1),
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 3,
          child: tappableScroll,
        ),
      ),
    );
  }
}

/// A `LongPressGestureRecognizer` that refuses to ever join the gesture
/// arena while another finger is already down. Without this, a genuine
/// two-finger pinch that happens to land its first finger on ayah text (the
/// text fills almost the whole page, so this is the common case) lets that
/// ayah's own long-press recognizer hold the arena open for its full ~500ms
/// deadline, delaying — and on a fast pinch, sometimes outright starving —
/// `InteractiveViewer`'s own scale recognizer. See P3‑43 #1.
class _SoloPointerLongPressRecognizer extends LongPressGestureRecognizer {
  _SoloPointerLongPressRecognizer({required this.otherPointerActive});
  final bool Function() otherPointerActive;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (otherPointerActive()) return false;
    return super.isPointerAllowed(event);
  }
}

/// Same guard as [_SoloPointerLongPressRecognizer], for the plain
/// background-tap-to-toggle-toolbar gesture.
class _SoloPointerTapRecognizer extends TapGestureRecognizer {
  _SoloPointerTapRecognizer({required this.otherPointerActive});
  final bool Function() otherPointerActive;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (otherPointerActive()) return false;
    return super.isPointerAllowed(event);
  }
}

/// An ornamental surah-name banner, styled like a mushaf's own section
/// headers — a bordered cartouche rather than a plain pill.
class _SurahBanner extends StatelessWidget {
  final String name;
  const _SurahBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return Container(
      // P3‑43 #3: this banner can now appear between two ayah groups on
      // the same page (several short surahs sharing a page), not only at
      // the very top of the page — a little breathing room above it
      // keeps it from crowding the previous surah's last line.
      margin: const EdgeInsets.only(top: 10, bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.4),
        gradient: LinearGradient(
          colors: [
            gold.withValues(alpha: 0.16),
            gold.withValues(alpha: 0.05),
            gold.withValues(alpha: 0.16),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        // The DB `name_ar` already reads "سُورَةُ ٱلْفَاتِحَةِ" — prefixing
        // another "سورة" produced the doubled header (P2‑1.1).
        name,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 22,
          color: gold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The end-of-ayah ornament: a small rosette carrying the Arabic-Indic ayah
/// number, inline with the text flow instead of on its own row.
class _AyahMarker extends StatelessWidget {
  final int number;
  final double fontScale;
  const _AyahMarker({required this.number, required this.fontScale});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    final size = 25.0 * fontScale;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RosettePainter(color: gold.withValues(alpha: 0.85)),
            ),
            // P3‑41: a real-device screenshot showed the digit still
            // reading off-center inside the rosette even after P3‑32's
            // fix — that earlier fix was the marker's position relative
            // to the *text line* (`PlaceholderAlignment.baseline` on the
            // `WidgetSpan` wrapping this whole widget); this is a
            // different axis entirely: the digit's position *within its
            // own marker*. Root cause: `AmiriQuran` is a Quranic display
            // face tuned for tashkeel headroom on Arabic letters — its
            // Arabic-Indic digit glyphs carry that same generous
            // ascent/descent, so a `Stack`-centered `Text` centers the
            // glyph's oversized *logical* box, not its actual ink, and
            // the visible numeral sits low. `height: 1.0` with no
            // explicit font (falling back to the theme's own UI font,
            // whose digits have ordinary, predictable metrics) centers
            // the real ink instead.
            Text(
              _arabicNumber(number),
              style: TextStyle(
                fontSize: size * 0.42,
                color: gold,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _arabicNumber(int n) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}

/// An 8-point rosette (two overlapped squares, the classic ayah-end motif
/// used across mushaf typography) instead of a plain circle.
class _RosettePainter extends CustomPainter {
  final Color color;
  const _RosettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..color = color;
    final c = size.center(Offset.zero);
    final r = size.width * 0.46;
    canvas.drawPath(_star(c, r, 0), paint);
    canvas.drawPath(_star(c, r, 45), paint);
  }

  Path _star(Offset c, double r, double rotationDeg) {
    final path = Path();
    final rad = rotationDeg * math.pi / 180;
    for (var i = 0; i < 4; i++) {
      final a = rad + i * math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _RosettePainter old) => old.color != color;
}
