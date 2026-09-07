import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';

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

  /// In full-screen mode, a double-tap exits — non-null only when
  /// `pageFillScreen` is true.
  final VoidCallback? onExitFullScreen;

  /// The verse continuous recitation is sounding right now, if any.
  final int? playingSurah;
  final int? playingAyah;

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
    this.onExitFullScreen,
    this.playingSurah,
    this.playingAyah,
  });

  @override
  State<MushafTextPage> createState() => _MushafTextPageState();
}

class _MushafTextPageState extends State<MushafTextPage> {
  final ScrollController _scroll = ScrollController();

  /// One key per ayah — used as scroll anchors for playing-verse tracking
  /// and auto-scroll end detection.
  List<GlobalKey> _ayahKeys = const [];

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
    _buildKeys();
    _syncAutoScroll();
  }

  @override
  void didUpdateWidget(covariant MushafTextPage old) {
    super.didUpdateWidget(old);
    if (old.ayahs != widget.ayahs) _buildKeys();
    _syncAutoScroll();
    if (old.playingSurah != widget.playingSurah ||
        old.playingAyah != widget.playingAyah) {
      _scrollToPlayingAyah();
    }
  }

  void _buildKeys() {
    _ayahKeys = List.generate(widget.ayahs.length, (_) => GlobalKey());
  }

  /// Brings the verse being recited into view.
  void _scrollToPlayingAyah() {
    if (!widget.isActive) return;
    final index = _playingIndex;
    if (index < 0 || index >= _ayahKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _ayahKeys[index].currentContext;
      if (ctx == null || !mounted || !_scroll.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
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
    final isDark = theme.brightness == Brightness.dark;
    if (widget.ayahs.isEmpty) {
      return const Center(child: Text('—'));
    }

    final paper = isDark ? AppColors.nightSurface : AppColors.paper;
    final ink = isDark ? AppColors.paperDark : AppColors.ink;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final baseFont = (isLandscape ? 20.0 : 24.0) * widget.fontScale;
    final fill = widget.pageFillScreen;
    final playingIndex = _playingIndex;

    final textStyle = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: baseFont,
      height: 2.1,
      color: ink,
    );

    // ── Build a flat list of item descriptors (surah banners + ayahs) ──
    // Several short surahs may share one physical page, so every surah
    // break gets its own banner row in the list.
    final items = <_ListItem>[];
    for (var i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final isNewSurah = i == 0
          ? ayah.ayahNumber == 1
          : ayah.surahId != widget.ayahs[i - 1].surahId;
      if (isNewSurah) {
        items.add(_ListItem.banner(ayah.surahId));
      }
      items.add(_ListItem.ayah(i));
    }

    final body = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ── Pinned surah header ──
          SliverAppBar(
            pinned: true,
            floating: false,
            automaticallyImplyLeading: false,
            backgroundColor: paper,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 52,
            title: Text(
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
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 22,
                height: 1.0,
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
          ),

          // ── Ayah list ──
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: fill ? 8.0 : (isLandscape ? 32.0 : 16.0),
              vertical: 12.0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];

                  // ── Surah banner ──
                  if (item.isBanner) {
                    return _SurahBanner(
                      name: widget.surahNameOf(item.surahId!),
                    );
                  }

                  // ── Ayah row ──
                  final ayahIndex = item.ayahIndex!;
                  final ayah = widget.ayahs[ayahIndex];
                  final isPlaying = ayahIndex == playingIndex;

                  return _AyahRow(
                    key: _ayahKeys[ayahIndex],
                    ayah: ayah,
                    isPlaying: isPlaying,
                    textStyle: textStyle,
                    onLongPress: () => widget.onAyahTap(ayah),
                    onTap: widget.onBackgroundTap,
                    onPlayTap: widget.onPlayTap != null
                        ? () => widget.onPlayTap!(ayah)
                        : null,
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

    return Container(color: paper, child: content);
  }
}

// ─── Helper models ─────────────────────────────────────────────────────────

/// Describes one row in the flat list: either a surah banner or an ayah.
class _ListItem {
  final bool isBanner;
  final int? surahId; // only for banners
  final int? ayahIndex; // only for ayahs (index into widget.ayahs)

  const _ListItem._({required this.isBanner, this.surahId, this.ayahIndex});

  factory _ListItem.banner(int surahId) =>
      _ListItem._(isBanner: true, surahId: surahId);
  factory _ListItem.ayah(int ayahIndex) =>
      _ListItem._(isBanner: false, ayahIndex: ayahIndex);
}

// ─── Ayah row widget ───────────────────────────────────────────────────────

/// One ayah rendered as a card-like row: Uthmani text (right-aligned, RTL) with
/// a rosette marker on the side, an `InkWell` for long-press → sciences sheet,
/// and an optional highlight when this is the verse being recited.
class _AyahRow extends StatelessWidget {
  final Ayah ayah;
  final bool isPlaying;
  final TextStyle textStyle;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;

  const _AyahRow({
    super.key,
    required this.ayah,
    required this.isPlaying,
    required this.textStyle,
    required this.onLongPress,
    this.onTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.ayahHighlightPlaying.withValues(alpha: 0.18)
            : (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.015)),
        borderRadius: BorderRadius.circular(14),
        border: isPlaying
            ? Border.all(
                color: AppColors.gold.withValues(alpha: 0.5),
                width: 1.2,
              )
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
  const _SurahBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return Container(
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

  const _AyahMarker({
    required this.number,
    this.playing = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = playing ? AppColors.goldSoft : AppColors.gold;
    const size = 32.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _RosettePainter(
              color: gold.withValues(alpha: playing ? 1.0 : 0.85),
            ),
          ),
          Text(
            _arabicNumber(number),
            style: TextStyle(
              fontSize: size * 0.38,
              color: gold,
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
