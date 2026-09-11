import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../../../../core/db/models.dart';
import '../../data/mushaf_frame.dart';
import '../../data/mushaf_theme.dart';
import 'mushaf_frame_painter.dart';
import '../../data/text_layout_provider.dart';

/// Renders one mushaf page (or a surah's ayahs) as a **vertical list** of
/// individually-tappable ayah items, with the surah name pinned at the top
/// via a `SliverAppBar`.
///
/// This replaces the old justified-paragraph view. Each ayah is its own row
/// with the Uthmani text on the right and a rosette marker on the left,
/// giving readers a clear per-ayah reference point and enabling long-press
/// interactions (sciences sheet) on individual verses.
///
/// All existing callback contracts (`onAyahTap`, `onBackgroundTap`,
/// `onAutoScrollReachedEnd`, `onExitFullScreen`, playing-verse highlighting)
/// are preserved — the parent `QuranScreen` does not need to change.
class MushafTextPage extends StatefulWidget {
  final List<Ayah> ayahs;

  /// Real surah-name lookup — the pinned header calls this with the first
  /// ayah's `surahId`, and in-between surah banners call it for any surah
  /// that starts mid-page (several short surahs near the end of the mushaf
  /// share one physical page).
  final String Function(int surahId) surahNameOf;

  /// Fires on a **long press** of an ayah — opens the sciences sheet.
  final void Function(Ayah ayah) onAyahTap;

  /// Fires on a **short tap** of the ayah text or number — starts recitation.
  final void Function(Ayah ayah)? onPlayTap;

  final double fontScale;

  /// A plain tap anywhere on the page (including on the ayah text itself)
  /// — the toolbar-visibility toggle lives one level up in `QuranScreen`.
  final VoidCallback? onBackgroundTap;

  /// When true, margins shrink so the real content claims more screen space.
  final bool pageFillScreen;

  /// Whether auto-scroll should be running right now.
  final bool autoScroll;

  /// Pixels per second for auto-scroll.
  final double autoScrollSpeed;

  /// True only for the page the `PageView` is actually showing.
  final bool isActive;

  /// Fires once when auto-scroll reaches the bottom of this page's content.
  final VoidCallback? onAutoScrollReachedEnd;

  /// Fires while the reader drags the page: true when they are moving
  /// FORWARD through the text (content going up), false when they pull back.
  ///
  /// The screen uses it to get out of the way — twelve toolbar actions in
  /// three rows take about 16% of a 2400-pixel screen, and the owner's
  /// reference app spends 8% on one bar. Reading hides it; pulling back
  /// brings it straight down again, so nothing is buried behind a setting.
  final void Function(bool forward)? onReadingScroll;

  /// In full-screen mode, a double-tap exits — non-null only when
  /// `pageFillScreen` is true.
  final VoidCallback? onExitFullScreen;

  /// The verse continuous recitation is sounding right now, if any.
  final int? playingSurah;
  final int? playingAyah;

  /// Whether verses are set as boxed cards or as one flowing justified page.
  final QuranTextLayout layout;

  /// The decorative border, if the reader has turned one on.
  final MushafFrameStyle frameStyle;

  /// The border's colour. Null takes the theme's own accent, which is what
  /// keeps every frame/theme pairing coherent by default.
  final Color? frameColor;

  /// The page's colour scheme. Null follows the app's light/dark theme, which
  /// is what a reader who has never opened the theme picker gets.
  ///
  /// Passed in rather than watched here: this widget is deliberately
  /// presentational, and both callers are already Riverpod consumers.
  final MushafTheme? mushafTheme;

  const MushafTextPage({
    super.key,
    required this.ayahs,
    required this.surahNameOf,
    required this.onAyahTap,
    this.onPlayTap,
    this.fontScale = 1.0,
    this.onBackgroundTap,
    this.pageFillScreen = false,
    this.autoScroll = false,
    this.autoScrollSpeed = 40,
    this.isActive = true,
    this.onAutoScrollReachedEnd,
    this.onReadingScroll,
    this.onExitFullScreen,
    this.playingSurah,
    this.playingAyah,
    this.layout = QuranTextLayout.page,
    this.mushafTheme,
    this.frameStyle = MushafFrameStyle.none,
    this.frameColor,
  });

  @override
  State<MushafTextPage> createState() => _MushafTextPageState();
}

class _MushafTextPageState extends State<MushafTextPage> {
  final ScrollController _scroll = ScrollController();

  /// One key per ayah — used as scroll anchors for playing-verse tracking
  /// and auto-scroll end detection.

  Timer? _autoTimer;
  bool _reachedEndFired = false;

  /// Hybrid auto-scroll: while auto-scroll is on, a manual drag pauses it
  /// and lifting the finger resumes it from the new position.
  bool _pausedForUser = false;
  Timer? _resumeTimer;

  static const _tickInterval = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _syncAutoScroll();
  }

  @override
  void didUpdateWidget(covariant MushafTextPage old) {
    super.didUpdateWidget(old);
    _syncAutoScroll();
    if (old.playingSurah != widget.playingSurah ||
        old.playingAyah != widget.playingAyah) {
      _scrollToPlayingAyah();
    }
  }

  /// One key per flowing run, so the playing verse can be located inside
  /// the paragraph that actually contains it.
  List<GlobalKey> _runKeys = [];

  /// One key per verse — only the card layout has a widget per verse to
  /// attach them to; the flowing layout scrolls by glyph box instead.
  List<GlobalKey> _ayahKeys = [];

  /// (firstAyahIndex, lastAyahIndex) for each run, rebuilt every layout.
  List<(int, int)> _runs = [];

  /// Brings the verse being recited into view.
  ///
  /// A verse no longer has a widget of its own — it is a span inside a
  /// paragraph — so this asks the run's `_FlowingAyahs` where that span sits
  /// and scrolls the viewport to it directly.
  void _scrollToPlayingAyah() {
    if (!widget.isActive) return;
    final index = _playingIndex;
    if (index < 0) return;
    if (widget.layout == QuranTextLayout.cards) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || index >= _ayahKeys.length) return;
        final ctx = _ayahKeys[index].currentContext;
        if (ctx == null || !_scroll.hasClients) return;
        // Centring a card is right only while the whole card fits. A long
        // verse — al-Baqarah 282 is a card several screens tall — gets its
        // middle centred, which cuts off both its beginning AND its end:
        // «فيه جزء منها مش باين في الصفحة». When it cannot fit, show it from
        // the top instead, so the reader is at the start of the verse and the
        // rest is below them where reading goes.
        final box = ctx.findRenderObject();
        final fits = box is! RenderBox ||
            box.size.height <= _scroll.position.viewportDimension;
        Scrollable.ensureVisible(
          ctx,
          alignment: fits ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      });
      return;
    }
    final runIndex = _runs.indexWhere((r) => index >= r.$1 && index <= r.$2);
    if (runIndex < 0 || runIndex >= _runKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final ctx = _runKeys[runIndex].currentContext;
      if (ctx == null) return;
      final state = ctx.findAncestorStateOfType<_FlowingAyahsState>() ??
          (ctx is StatefulElement && ctx.state is _FlowingAyahsState
              ? ctx.state as _FlowingAyahsState
              : null);
      final dy = state?.offsetOfAyah(index);
      final box = ctx.findRenderObject();
      if (dy == null || box is! RenderBox) return;
      // The paragraph's own top in scroll coordinates, plus the verse's
      // offset inside it. Placed a third of the way down rather than centred:
      // this layout knows where the verse STARTS and not how tall it is, and
      // a centred start puts half the viewport above the verse and only half
      // below it — so a long verse runs off the bottom. A third leaves twice
      // as much room in the direction the verse actually continues.
      final top = box.localToGlobal(Offset.zero).dy;
      final viewport = _scroll.position.viewportDimension;
      final target = _scroll.offset + top + dy - viewport / 3;
      _scroll.animateTo(
        target.clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Index into `widget.ayahs` of the verse being recited, or -1.
  int get _playingIndex {
    final surah = widget.playingSurah;
    final ayah = widget.playingAyah;
    if (surah == null || ayah == null) return -1;
    for (var i = 0; i < widget.ayahs.length; i++) {
      final a = widget.ayahs[i];
      if (a.surahId == surah && a.ayahNumber == ayah) return i;
    }
    return -1;
  }

  // ─── Auto-scroll machinery ───────────────────────────────────────────

  void _syncAutoScroll() {
    final shouldRun = widget.autoScroll && widget.isActive && !_pausedForUser;
    if (shouldRun && _autoTimer == null) {
      _reachedEndFired = false;
      _autoTimer = Timer.periodic(_tickInterval, (_) => _tickAutoScroll());
    } else if (!shouldRun && _autoTimer != null) {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
    if (!widget.autoScroll || !widget.isActive) {
      _resumeTimer?.cancel();
      _resumeTimer = null;
      _pausedForUser = false;
    }
  }

  void _pauseForUserScroll() {
    _resumeTimer?.cancel();
    _resumeTimer = null;
    if (_pausedForUser) return;
    _pausedForUser = true;
    _syncAutoScroll();
  }

  void _resumeAfterUserScroll() {
    if (!_pausedForUser) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(milliseconds: 700), () {
      _pausedForUser = false;
      _syncAutoScroll();
    });
  }

  bool _onScrollNotification(ScrollNotification n) {
    // The reader's own drag, before the auto-scroll bookkeeping: a
    // programmatic scroll carries no drag details, so the toolbar is never
    // moved by the app scrolling itself.
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        widget.isActive) {
      final d = n.scrollDelta ?? 0;
      // A couple of pixels is a finger resting, not a decision.
      if (d > 2) {
        widget.onReadingScroll?.call(true);
      } else if (d < -2) {
        widget.onReadingScroll?.call(false);
      }
    }
    if (!(widget.autoScroll && widget.isActive)) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _pauseForUserScroll();
    } else if (n is ScrollEndNotification && _pausedForUser) {
      _resumeAfterUserScroll();
    }
    return false;
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
      _reachedEndFired = true;
      _autoTimer?.cancel();
      _autoTimer = null;
      widget.onAutoScrollReachedEnd?.call();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.ayahs.isEmpty) {
      return const Center(child: Text('—'));
    }

    final mt = widget.mushafTheme ??
        resolveMushafTheme(null, theme.brightness);
    final paper = mt.paper;
    final ink = mt.ink;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // The stripped reading layout: same justified block as `page`, with the
    // ornament taken out. Everything it changes is gathered here so the two
    // flowing layouts cannot drift apart by accident.
    final bare = widget.layout == QuranTextLayout.reading;
    final baseFont = (isLandscape ? 20.0 : 24.0) * widget.fontScale;
    final fill = widget.pageFillScreen;
    final playingIndex = _playingIndex;

    final textStyle = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: baseFont,
      // Tighter leading in the reading layout, which is most of why the
      // reference page fits noticeably more of the surah on one screen.
      height: bare ? 1.85 : 2.1,
      color: ink,
    );

    // ── Build the page's rows: a banner wherever a surah starts, and one
    // flowing run per contiguous stretch of the same surah's verses. ──
    final items = <_ListItem>[];
    final runs = <(int, int)>[];
    var runStart = 0;
    for (var i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final isNewSurah =
          i == 0 ? ayah.ayahNumber == 1 : ayah.surahId != widget.ayahs[i - 1].surahId;
      if (isNewSurah && i > 0) {
        items.add(_ListItem.run(runs.length, runStart, i - 1));
        runs.add((runStart, i - 1));
        runStart = i;
      }
      if (isNewSurah) items.add(_ListItem.banner(ayah.surahId));
    }
    items.add(_ListItem.run(runs.length, runStart, widget.ayahs.length - 1));
    runs.add((runStart, widget.ayahs.length - 1));
    _runs = runs;
    if (_runKeys.length != runs.length) {
      _runKeys = List.generate(runs.length, (_) => GlobalKey());
    }
    if (_ayahKeys.length != widget.ayahs.length) {
      _ayahKeys = List.generate(widget.ayahs.length, (_) => GlobalKey());
    }

    final opensWithBanner = items.isNotEmpty && items.first.isBanner;
    final body = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── Pinned surah header ──
          SliverAppBar(
            // Pinned in portrait, where 52 pixels is cheap and a running
            // header earns them. NOT in landscape: the whole text area is
            // about 200 logical pixels there, so pinning spends a quarter of
            // the page repeating a surah name the corner badge is already
            // showing — which is the two «سُورَةُ البَقَرَة» in the owner's
            // landscape screenshot, one of them sitting on the first line.
            pinned: !isLandscape,
            floating: false,
            automaticallyImplyLeading: false,
            backgroundColor: paper,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: isLandscape ? 40 : 52,
            // Blank when the page opens on a surah banner: the banner is the
            // name, right below, and printing it twice in a row was one of
            // the three «سورة الرعد» on his page.
            title: opensWithBanner
                ? null
                : Text(
              widget.surahNameOf(widget.ayahs.first.surahId),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              strutStyle: const StrutStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 22,
                height: 1.0,
                leading: 0,
                forceStrutHeight: true,
              ),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 22,
                height: 1.0,
                color: mt.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: mt.gold.withValues(alpha: 0.3),
              ),
            ),
          ),

          // ── The page itself ──
          //
          // A real mushaf sets its verses as one continuous justified block,
          // not as a stack of separate cards — that was the owner's ask, and
          // it is also what makes the page look like the printed page it is
          // meant to mirror. Each contiguous run of one surah's verses is a
          // single justified paragraph; a surah change breaks the run so its
          // banner can sit between them.
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: bare
                  ? (isLandscape ? 18.0 : 8.0)
                  : (fill ? 10.0 : (isLandscape ? 40.0 : 18.0)),
              vertical: bare ? 6.0 : 12.0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  if (item.isBanner) {
                    return _SurahBanner(
                      name: widget.surahNameOf(item.surahId!),
                      mt: mt,
                      bare: bare,
                    );
                  }
                  if (widget.layout == QuranTextLayout.cards) {
                    return Column(
                      children: [
                        for (var i = item.runFrom!; i <= item.runTo!; i++)
                          _AyahRow(
                            key: _ayahKeys.length > i ? _ayahKeys[i] : null,
                            ayah: widget.ayahs[i],
                            isPlaying: i == playingIndex,
                            textStyle: textStyle,
                            mt: mt,
                            onLongPress: () =>
                                widget.onAyahTap(widget.ayahs[i]),
                            onTap: widget.onBackgroundTap,
                            onPlayTap: widget.onPlayTap != null
                                ? () => widget.onPlayTap!(widget.ayahs[i])
                                : null,
                          ),
                      ],
                    );
                  }
                  return _FlowingAyahs(
                    key: _runKeys[item.runIndex!],
                    mt: mt,
                    ayahs: widget.ayahs,
                    from: item.runFrom!,
                    to: item.runTo!,
                    playingIndex: playingIndex,
                    textStyle: textStyle,
                    onAyahTap: widget.onPlayTap,
                    onAyahLongPress: widget.onAyahTap,
                    onBackgroundTap: widget.onBackgroundTap,
                    bare: bare,
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );

    // Wrap in double-tap exit gesture for full-screen mode.
    final Widget content;
    if (widget.onExitFullScreen != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onDoubleTap: widget.onExitFullScreen,
        child: body,
      );
    } else {
      content = body;
    }

    return Container(
      color: paper,
      child: MushafFrame(
        style: widget.frameStyle,
        color: widget.frameColor ?? mt.gold,
        child: content,
      ),
    );
  }
}

// ─── Helper models ─────────────────────────────────────────────────────────

/// One row of the page: either a surah banner, or a run of verses belonging to
/// the same surah that are set as a single flowing paragraph.
class _ListItem {
  final bool isBanner;
  final int? surahId; // banners only
  final int? runIndex; // runs only — index into the page's run list
  final int? runFrom; // runs only — first index into widget.ayahs
  final int? runTo; // runs only — last index, inclusive

  const _ListItem._({
    required this.isBanner,
    this.surahId,
    this.runIndex,
    this.runFrom,
    this.runTo,
  });

  factory _ListItem.banner(int surahId) =>
      _ListItem._(isBanner: true, surahId: surahId);

  factory _ListItem.run(int runIndex, int from, int to) => _ListItem._(
        isBanner: false,
        runIndex: runIndex,
        runFrom: from,
        runTo: to,
      );
}

// ─── Ayah row widget ───────────────────────────────────────────────────────

/// One ayah rendered as a card-like row: Uthmani text (right-aligned, RTL) with
/// a rosette marker on the side, an `InkWell` for long-press → sciences sheet,
/// and an optional highlight when this is the verse being recited.
class _AyahRow extends StatelessWidget {
  final Ayah ayah;
  final bool isPlaying;
  final TextStyle textStyle;
  final MushafTheme mt;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;

  const _AyahRow({
    super.key,
    required this.ayah,
    required this.isPlaying,
    required this.textStyle,
    required this.mt,
    required this.onLongPress,
    this.onTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    // The row's resting tint comes from the *theme's* own lightness, not the
    // app's: a light mushaf theme can be selected while the app is in dark
    // mode, and a white wash on cream paper is invisible.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying
            ? mt.highlightPlaying
            : (mt.isLight
                ? Colors.black.withValues(alpha: 0.015)
                : Colors.white.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(14),
        border: isPlaying
            ? Border.all(color: mt.gold.withValues(alpha: 0.5), width: 1.2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onLongPress: onLongPress,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                // ── Ayah text ──
                Expanded(
                  child: InkWell(
                    onTap: onPlayTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        ayah.textUthmani,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Rosette marker ──
                InkWell(
                  onTap: onPlayTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4, right: 4, bottom: 4),
                    child: _AyahMarker(
                      number: ayah.ayahNumber,
                      playing: isPlaying,
                      mt: mt,
                    ),
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

// ─── Surah banner ──────────────────────────────────────────────────────────

/// An ornamental surah-name banner, styled like a mushaf's own section
/// headers — a bordered cartouche.
class _SurahBanner extends StatelessWidget {
  final String name;
  final MushafTheme mt;

  /// The reading layout keeps the surah's name — you have to know which surah
  /// you are in — but not its illuminated frame, which is the single biggest
  /// block of ornament on the page.
  final bool bare;

  const _SurahBanner({
    required this.name,
    required this.mt,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = mt.gold;
    return Container(
      margin: bare
          ? const EdgeInsets.only(top: 6, bottom: 8)
          : const EdgeInsets.only(top: 10, bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: bare
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: gold.withValues(alpha: 0.55), width: 1.4),
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
        name,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 22,
          height: 1.0,
          leading: 0,
          forceStrutHeight: true,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 22,
          height: 1.0,
          color: gold,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Ayah marker (rosette) ─────────────────────────────────────────────────

/// The end-of-ayah ornament: a small rosette carrying the Arabic-Indic ayah
/// number.
class _AyahMarker extends StatelessWidget {
  final int number;
  final bool playing;
  final MushafTheme mt;

  /// Draw the marker as a filled disc instead of the open rosette — the
  /// reading layout's one piece of ornament, kept because a verse still has
  /// to end somewhere visible.
  final bool bare;

  const _AyahMarker({
    required this.number,
    required this.mt,
    this.playing = false,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = mt.gold;
    final size = bare ? 26.0 : 32.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (bare)
            // A filled disc rather than the open rosette: it reads as a full
            // stop at a glance and takes less of the line, which is the
            // difference the owner pointed at in the app he reads in.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: playing ? 1.0 : 0.88),
              ),
              child: SizedBox(width: size, height: size),
            )
          else
            CustomPaint(
              size: Size(size, size),
              painter: _RosettePainter(
                color: gold.withValues(alpha: playing ? 1.0 : 0.85),
              ),
            ),
          Text(
            _arabicNumber(number),
            style: TextStyle(
              fontSize: size * (bare ? 0.42 : 0.38),
              // On the disc the number sits ON the gold, so it takes the
              // paper's colour; the rosette is an outline and the number
              // stays gold inside it.
              color: bare ? mt.paper : gold,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  static String _arabicNumber(int n) {
    const digits = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}

/// An 8-point rosette (two overlapped squares).
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

// ─── Flowing verses ────────────────────────────────────────────────────────

/// One contiguous run of a surah's verses, set as a single justified paragraph
/// the way a printed mushaf sets them.
///
/// Verses are spans, not widgets, so hit-testing is done against the laid-out
/// paragraph: a tap is mapped to a text offset and then to the verse whose
/// span covers it. That gives per-verse tap and long-press without breaking
/// the text flow — which putting each verse in its own `InkWell` necessarily
/// would.
class _FlowingAyahs extends StatefulWidget {
  final List<Ayah> ayahs;

  /// Inclusive range into [ayahs] that this paragraph covers.
  final int from;
  final int to;

  /// Index into [ayahs] of the verse being recited, or -1.
  final int playingIndex;

  final TextStyle textStyle;

  /// The page's colour scheme, for the recited-verse wash and the markers.
  final MushafTheme mt;

  /// Tap a verse: start (or jump) the recitation there.
  final void Function(Ayah ayah)? onAyahTap;

  /// Long-press a verse: open its sciences sheet.
  final void Function(Ayah ayah) onAyahLongPress;

  /// Tap outside any verse: toggle the reader's chrome.
  final VoidCallback? onBackgroundTap;

  /// The stripped reading layout — see `QuranTextLayout.reading`.
  final bool bare;

  const _FlowingAyahs({
    super.key,
    required this.ayahs,
    required this.from,
    required this.to,
    required this.playingIndex,
    required this.textStyle,
    required this.mt,
    required this.onAyahLongPress,
    this.onAyahTap,
    this.onBackgroundTap,
    this.bare = false,
  });

  @override
  State<_FlowingAyahs> createState() => _FlowingAyahsState();
}

class _FlowingAyahsState extends State<_FlowingAyahs> {
  final GlobalKey _textKey = GlobalKey();

  /// (startOffset, endOffset, ayahIndex) for every verse in this paragraph,
  /// in the same character space the laid-out paragraph uses.
  List<(int, int, int)> _ranges = const [];

  RenderParagraph? get _paragraph {
    final ro = _textKey.currentContext?.findRenderObject();
    return ro is RenderParagraph ? ro : null;
  }

  /// Vertical offset of a verse's first glyph inside this paragraph, or null.
  double? offsetOfAyah(int ayahIndex) {
    final p = _paragraph;
    if (p == null) return null;
    for (final r in _ranges) {
      if (r.$3 != ayahIndex) continue;
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: r.$1, extentOffset: r.$2),
      );
      if (boxes.isEmpty) return null;
      return boxes.first.top;
    }
    return null;
  }

  /// The verse under [local], or null when the tap landed on empty space.
  Ayah? _ayahAt(Offset local) {
    final p = _paragraph;
    if (p == null) return null;
    final pos = p.getPositionForOffset(local);
    for (final r in _ranges) {
      if (pos.offset >= r.$1 && pos.offset < r.$2) return widget.ayahs[r.$3];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final ranges = <(int, int, int)>[];
    var offset = 0;

    for (var i = widget.from; i <= widget.to; i++) {
      final ayah = widget.ayahs[i];
      final isPlaying = i == widget.playingIndex;
      final text = '${ayah.textUthmani} ';

      spans.add(
        TextSpan(
          text: text,
          style: isPlaying
              ? widget.textStyle.copyWith(
                  // A wash behind the glyphs rather than a bordered box, so
                  // the highlight rides the text as it wraps across lines.
                  // Both colours come from the theme: on the black
                  // high-contrast page a gold wash under gold text would be
                  // unreadable, so that theme flips the ink instead.
                  backgroundColor: widget.mt.highlightPlaying,
                  color: widget.mt.inkOnHighlight,
                )
              : widget.textStyle,
        ),
      );
      ranges.add((offset, offset + text.length, i));
      offset += text.length;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _AyahMarker(
              number: ayah.ayahNumber,
              playing: isPlaying,
              mt: widget.mt,
              bare: widget.bare,
            ),
          ),
        ),
      );
      offset += 1; // a WidgetSpan occupies one placeholder character
    }
    _ranges = ranges;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final ayah = _ayahAt(d.localPosition);
        if (ayah != null && widget.onAyahTap != null) {
          widget.onAyahTap!(ayah);
        } else {
          widget.onBackgroundTap?.call();
        }
      },
      onLongPressStart: (d) {
        final ayah = _ayahAt(d.localPosition);
        if (ayah != null) widget.onAyahLongPress(ayah);
      },
      child: Text.rich(
        TextSpan(children: spans),
        key: _textKey,
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
