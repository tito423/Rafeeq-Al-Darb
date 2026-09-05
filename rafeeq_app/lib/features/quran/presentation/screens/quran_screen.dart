import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../data/ayah_coords_repository.dart';
import '../../data/mushaf_data_provider.dart';
import '../../data/mushaf_edition.dart';
import '../../data/quran_fullscreen_provider.dart';
import '../../data/quran_jump_provider.dart';
import '../../data/quran_last_read.dart';
import '../widgets/ayah_sciences_sheet.dart';
import '../widgets/mushaf_edition_sheet.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/mushaf_nav_sheets.dart';
import '../widgets/mushaf_text_page.dart';

/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.
enum MushafMode { text, image }

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  static const _totalPages = 604;

  PageController? _pages;
  final Map<int, Future<List<Ayah>>> _pageFutures = {};
  final AyahCoordsRepository _coords = AyahCoordsRepository.instance;

  MushafMode _mode = MushafMode.text;
  int _current = 1;
  int _initialPage = 1;
  int? _highlightSurah;
  int? _highlightAyah;

  /// Text-mode font scale (1.0 = the page's own base size). Persisted like
  /// `book_text_reader_screen.dart`'s A+/A− — a plain `SharedPreferences`
  /// double, not a provider, since only this screen reads it.
  double _fontScale = 1.0;
  static const _kFontScale = 'quran_text_font_scale_v1';

  /// P3‑39: auto-scroll (the owner's own clarification of P3‑34's
  /// ambiguous "speed control" — "speed control for scrolling reading for
  /// quran text"). `_autoScroll` itself always starts off on a fresh open
  /// of the reader — silently resuming a hands-free scroll the moment the
  /// tab reopens would be a bad surprise — but the *speed* the reader
  /// picked last time is worth remembering, same as font scale.
  bool _autoScroll = false;
  double _autoScrollSpeed = 40; // pixels/second
  static const _kAutoScrollSpeed = 'quran_text_autoscroll_speed_v1';

  /// P3‑41: real-device feedback — the toolbar "is taking place from the
  /// screen"; tapping the page should hide it (and give the page the
  /// freed space) and tapping again should bring it back. Starts visible
  /// — hiding it by default on first open would make the reader's own
  /// controls undiscoverable.
  bool _toolbarVisible = true;

  /// P3‑41: "give option so I can change page from small to full fit of
  /// screen" — a persisted, explicit reader preference, independent of
  /// the toolbar-hide above (that just reclaims the toolbar's own strip;
  /// this changes how much of *that* remaining space the page itself
  /// fills).
  bool _pageFillScreen = false;
  static const _kPageFillScreen = 'quran_text_page_fill_v1';

  Future<void> _persistPage() async {
    // Goes through the reactive provider (P3‑4), not a raw prefs write —
    // see `quran_last_read.dart`'s doc for why: `ContinueReadingCard` on
    // Home needs to notice this change even though `AppShell` keeps every
    // tab mounted in an `IndexedStack` and never rebuilds Home just from
    // switching back to it.
    await ref.read(quranLastPageProvider.notifier).set(_current);
  }

  Future<void> _persistMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reader_mode', _mode.name);
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getInt(kQuranLastPageKey) ?? 1;
    final modeName = prefs.getString('quran_reader_mode');
    final fontScale = prefs.getDouble(_kFontScale);
    final autoScrollSpeed = prefs.getDouble(_kAutoScrollSpeed);
    final pageFillScreen = prefs.getBool(_kPageFillScreen);
    if (!mounted) return;
    setState(() {
      if (p >= 1 && p <= _totalPages) {
        _initialPage = p;
        _current = p;
      }
      _mode = MushafMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => MushafMode.text,
      );
      if (fontScale != null) _fontScale = fontScale;
      if (autoScrollSpeed != null) _autoScrollSpeed = autoScrollSpeed;
      if (pageFillScreen != null) _pageFillScreen = pageFillScreen;
    });
    ref.read(quranFullScreenProvider.notifier).state = _pageFillScreen;
  }

  void _changeFontScale(double delta) {
    setState(() => _fontScale = (_fontScale + delta).clamp(0.75, 1.8));
    SharedPreferences.getInstance().then(
      (p) => p.setDouble(_kFontScale, _fontScale),
    );
  }

  /// P3‑43 #6: while genuinely full-screen (AppBar and both bottom nav
  /// bars hidden), the fullscreen toggle button itself is off-screen too
  /// — a plain tap on the page is the only way back, so it exits
  /// full-screen first rather than just toggling the (currently invisible
  /// anyway) toolbar row underneath it.
  void _onBackgroundTap() {
    if (_pageFillScreen) {
      _togglePageFillScreen();
    } else {
      setState(() => _toolbarVisible = !_toolbarVisible);
    }
  }

  void _togglePageFillScreen() {
    setState(() => _pageFillScreen = !_pageFillScreen);
    ref.read(quranFullScreenProvider.notifier).state = _pageFillScreen;
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kPageFillScreen, _pageFillScreen),
    );
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
  }

  void _changeAutoScrollSpeed(double speed) {
    setState(() => _autoScrollSpeed = speed);
    SharedPreferences.getInstance().then(
      (p) => p.setDouble(_kAutoScrollSpeed, speed),
    );
  }

  /// Called once by the currently-active `MushafTextPage` when auto-scroll
  /// reaches the bottom of its content. Turns the page and keeps going —
  /// the whole point of "hands-free reading" is not stopping dead at every
  /// page boundary — unless this was already the mushaf's last page, where
  /// there's honestly nowhere further to go.
  void _onAutoScrollReachedEnd() {
    if (_current >= _totalPages) {
      setState(() => _autoScroll = false);
      return;
    }
    _goToPage(_current + 1);
  }

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  void _goToPage(int page, {bool animate = true}) {
    final pages = _pages;
    if (pages == null) return;
    final p = page.clamp(1, _totalPages);
    if (animate) {
      pages.animateToPage(
        p - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      pages.jumpToPage(p - 1);
    }
    setState(() => _current = p);
    _persistPage();
  }

  // P3‑41: real-device feedback — "use logic... if I use navigation
  // gesture or option for back just unselect the ayah". The highlight
  // used to just be set and never cleared; `AyahSciencesSheet.show`
  // already returns a future that resolves on *any* dismissal (the
  // system back gesture, tapping the scrim, or an explicit close — all
  // of them go through `Navigator.pop` under a `showModalBottomSheet`),
  // so awaiting it and clearing the highlight there covers all three the
  // same way, not just one specific close button.
  Future<void> _openSciences(
    Ayah ayah,
    MushafData data, {
    bool sciencesAvailable = true,
  }) async {
    setState(() {
      _highlightSurah = ayah.surahId;
      _highlightAyah = ayah.ayahNumber;
    });
    await AyahSciencesSheet.show(
      context,
      ayah: ayah,
      surahNameAr: data.surahNameAr(ayah.surahId),
      quranRepo: data.repo,
      sciencesAvailable: sciencesAvailable,
    );
    if (mounted) {
      setState(() {
        _highlightSurah = null;
        _highlightAyah = null;
      });
    }
  }

  Future<List<Ayah>> _ayahsOfPage(int page, MushafData data) =>
      _pageFutures.putIfAbsent(page, () => data.repo.ayahsOfPage(page));

  AyahRegion? _highlightRegion(String editionId, int page) {
    if (_highlightSurah == null || _current != page) return null;
    for (final r in _coords.regionsForPage(editionId, page)) {
      if (r.surah == _highlightSurah && r.ayah == _highlightAyah) return r;
    }
    return null;
  }

  /// P3‑43 #7: the real surah covering `_current` — "which surah's start
  /// page is the highest one at or before the current page", the same
  /// real-data rule `_SurahStrip` already uses, not a second guess at it.
  String _currentSurahName(MushafData data) {
    var name = data.surahs.isEmpty ? '' : data.surahs.first.nameAr;
    for (final s in data.surahs) {
      if ((data.surahStartPages[s.id] ?? 1) <= _current) {
        name = s.nameAr;
      } else {
        break;
      }
    }
    return name;
  }

  /// Same rule as [_currentSurahName], against `juzStartPages` instead.
  int _currentJuzNumber(MushafData data) {
    var juz = 1;
    final entries = data.juzStartPages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      if (e.value <= _current) {
        juz = e.key;
      } else {
        break;
      }
    }
    return juz;
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafDataProvider);
    // P2‑11: a khatma's "اقرأ اليوم" (or its card) asks for a page here,
    // then switches to this tab — consume it once and clear it so it
    // doesn't re-fire on every rebuild.
    ref.listen<int?>(quranJumpRequestProvider, (_, page) {
      if (page != null) {
        _goToPage(page, animate: false);
        Future.microtask(
          () => ref.read(quranJumpRequestProvider.notifier).state = null,
        );
      }
    });
    return Scaffold(
      // P3‑43 #6: "ملء الشاشة" now hides the AppBar entirely (not just its
      // own toolbar row) plus this screen's own bottom bar below, and
      // (via `quranFullScreenProvider`) `AppShell`'s bottom nav bar too —
      // a tap on the page (`_onBackgroundTap`) is the only way back once
      // the button that turned this on is itself off-screen.
      appBar: _pageFillScreen
          ? null
          : AppBar(
              title: Text('nav.quran'.tr()),
              // P3‑34 built this as a single horizontal-scroll row; P3‑41's
              // real-device feedback was that this "takes place from the
              // screen" — a long scrolling strip hides most actions until you
              // scroll to find them. Two changes: a `Wrap` instead of a
              // `SingleChildScrollView(Row)` so every action is visible at
              // once across as many rows as it naturally takes (no more
              // hidden-until-scrolled icons), and the whole thing collapses to
              // nothing when `_toolbarVisible` is false (tapping the page
              // itself toggles it — see `_buildViewer`), handing that space
              // back to the page.
              bottom: mushaf.hasValue && _toolbarVisible
                  ? PreferredSize(
                      // P3‑43 #6: image mode's toolbar gained the full-screen
                      // action too (moved out of the text-only block below), so
                      // it now wraps to two rows the same as text mode's own —
                      // this height was still the old single-row estimate and
                      // would have clipped/overflowed the extra row.
                      preferredSize: const Size.fromHeight(116),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 0,
                          children: [
                            if (_mode == MushafMode.text) ...[
                              ToolbarAction(
                                icon: Icons.text_decrease,
                                label: 'quran.font_smaller'.tr(),
                                onPressed: () => _changeFontScale(-0.1),
                              ),
                              ToolbarAction(
                                icon: Icons.text_increase,
                                label: 'quran.font_larger'.tr(),
                                onPressed: () => _changeFontScale(0.1),
                              ),
                              ToolbarAction(
                                icon: _autoScroll
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                label: _autoScroll
                                    ? 'quran.auto_scroll_stop'.tr()
                                    : 'quran.auto_scroll'.tr(),
                                onPressed: _toggleAutoScroll,
                              ),
                            ],
                            // P3‑43 #6: moved out of the text-only block above —
                            // full-screen reading is a real, useful mode for the
                            // image mushaf too, not just the text one.
                            ToolbarAction(
                              icon: _pageFillScreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              label: _pageFillScreen
                                  ? 'quran.page_fit_small'.tr()
                                  : 'quran.page_fit_full'.tr(),
                              onPressed: _togglePageFillScreen,
                            ),
                            ToolbarAction(
                              icon: Icons.travel_explore_outlined,
                              label: 'search.title'.tr(),
                              onPressed: () async {
                                final page = await Navigator.of(context)
                                    .push<int>(
                                      MaterialPageRoute<int>(
                                        builder: (_) => SearchScreen(
                                          repo: mushaf.value!.repo,
                                        ),
                                      ),
                                    );
                                if (page != null) _goToPage(page);
                              },
                            ),
                            ToolbarAction(
                              icon: Icons.format_list_numbered,
                              label: 'quran.surah_list'.tr(),
                              onPressed: () => showSurahSheet(
                                context,
                                surahs: mushaf.value!.surahs,
                                startPages: mushaf.value!.surahStartPages,
                                onSelect: _goToPage,
                              ),
                            ),
                            ToolbarAction(
                              icon: Icons.filter_9_plus,
                              label: 'quran.juz'.tr(),
                              onPressed: () => showJuzSheet(
                                context,
                                juzStartPages: mushaf.value!.juzStartPages,
                                onSelect: _goToPage,
                              ),
                            ),
                            ToolbarAction(
                              icon: Icons.pin_drop_outlined,
                              label: 'quran.jump_to'.tr(),
                              onPressed: () => showGotoPageSheet(
                                context,
                                current: _current,
                                onSelect: _goToPage,
                              ),
                            ),
                            ToolbarAction(
                              icon: Icons.auto_stories_outlined,
                              label: 'quran.editions'.tr(),
                              onPressed: () => MushafEditionSheet.show(context),
                            ),
                            ToolbarAction(
                              icon: _mode == MushafMode.text
                                  ? Icons.image_outlined
                                  : Icons.notes,
                              label: _mode == MushafMode.text
                                  ? 'quran.mushaf_mode'.tr()
                                  : 'quran.text_mode'.tr(),
                              onPressed: () {
                                setState(() {
                                  _mode = _mode == MushafMode.text
                                      ? MushafMode.image
                                      : MushafMode.text;
                                });
                                _persistMode();
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
      body: mushaf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
        data: (data) => Stack(
          children: [
            _buildViewer(
              data,
              ref.watch(currentMushafEditionProvider).valueOrNull,
            ),
            // P3‑43 #7: "always show the page number at the bottom, the
            // surah name at the top-right, and the juz name at the
            // top-left" — reading context, not an "option" toolbars can
            // hide, so this sits above everything (toolbar visibility,
            // full-screen mode) and never toggles off with them.
            _PersistentPageOverlay(
              pageNumber: _current,
              surahName: _currentSurahName(data),
              juzNumber: _currentJuzNumber(data),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _pageFillScreen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // P3‑8: a fast surah-jump strip — was completely missing,
                    // the only way to jump surahs before this was the toolbar's
                    // full-screen "السور" list sheet. Only shown once real data
                    // is loaded (needs `surahStartPages` to know where to jump).
                    if (mushaf.hasValue)
                      _SurahStrip(
                        surahs: mushaf.value!.surahs,
                        surahStartPages: mushaf.value!.surahStartPages,
                        currentPage: _current,
                        onSelect: _goToPage,
                      ),
                    // Only shown once auto-scroll is actually on — no point
                    // occupying screen space with a speed control for a feature
                    // that isn't running.
                    if (_autoScroll && _mode == MushafMode.text)
                      _AutoScrollSpeedBar(
                        speed: _autoScrollSpeed,
                        onChanged: _changeAutoScrollSpeed,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _current > 1
                              ? () => _goToPage(_current - 1)
                              : null,
                        ),
                        Text(
                          '${'quran.page'.tr()}  $_current / $_totalPages',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _current < _totalPages
                              ? () => _goToPage(_current + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildViewer(MushafData data, MushafEdition? edition) {
    _pages ??= PageController(initialPage: _initialPage - 1);
    return PageView.builder(
      controller: _pages,
      onPageChanged: (i) {
        setState(() => _current = i + 1);
        _persistPage();
      },
      itemCount: _totalPages,
      itemBuilder: (context, index) {
        final page = index + 1;
        return FutureBuilder<List<Ayah>>(
          future: _ayahsOfPage(page, data),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final ayahs = snap.data!;
            if (_mode == MushafMode.image) {
              if (edition == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return MushafPageView(
                edition: edition,
                page: page,
                highlight: _highlightRegion(edition.id, page),
                onAyahTap: (region) =>
                    _onImageAyahTap(region, ayahs, data, edition),
                onLoadFailed: () => setState(() => _mode = MushafMode.text),
                // Image mode never had a tap-to-hide-toolbar gesture (only
                // text mode does, since P3‑42) — deliberately not adding
                // one here. This only exists so a full-screen image-mode
                // reader can be exited the same way the text-mode one can.
                onBackgroundTap: _pageFillScreen ? _togglePageFillScreen : null,
              );
            }
            return MushafTextPage(
              ayahs: ayahs,
              surahNameOf: data.surahNameAr,
              onAyahTap: (a) => _openSciences(a, data),
              fontScale: _fontScale,
              autoScroll: _autoScroll,
              autoScrollSpeed: _autoScrollSpeed,
              isActive: page == _current,
              onAutoScrollReachedEnd: _onAutoScrollReachedEnd,
              onBackgroundTap: _onBackgroundTap,
              pageFillScreen: _pageFillScreen,
            );
          },
        );
      },
    );
  }

  void _onImageAyahTap(
    AyahRegion region,
    List<Ayah> ayahs,
    MushafData data,
    MushafEdition edition,
  ) {
    for (final ayah in ayahs) {
      if (ayah.surahId == region.surah && ayah.ayahNumber == region.ayah) {
        _openSciences(
          ayah,
          data,
          sciencesAvailable: edition.sciencesAvailableFor(region.surah),
        );
        return;
      }
    }
  }
}

/// P3‑43 #7: a real printed mushaf's running header — page number bottom
/// centre, surah name top-right, juz name top-left — kept on screen
/// regardless of toolbar visibility or full-screen mode (it's reading
/// context, not an "option"). Fixed physical corners, not RTL `start`/
/// `end`: a real mushaf page's own running headers don't mirror with the
/// *app's* locale, they're a property of the page itself. `IgnorePointer`
/// throughout so it never steals the background tap that toggles the
/// toolbar or exits full-screen.
class _PersistentPageOverlay extends StatelessWidget {
  final int pageNumber;
  final String surahName;
  final int juzNumber;

  const _PersistentPageOverlay({
    required this.pageNumber,
    required this.surahName,
    required this.juzNumber,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: _HeaderBadge(text: surahName),
              ),
              Positioned(
                top: 0,
                left: 0,
                // Same convention as the surah name above (and as
                // `mushaf_nav_sheets.dart`'s own juz list): a real
                // mushaf's own running header is always Arabic — it's
                // part of the page's own printed identity, not app UI
                // chrome that follows the interface locale.
                child: _HeaderBadge(text: 'الجزء ${_arabicNumber(juzNumber)}'),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _HeaderBadge(text: _arabicNumber(pageNumber)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _arabicNumber(int n) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}

class _HeaderBadge extends StatelessWidget {
  final String text;
  const _HeaderBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// P3‑39: the auto-scroll speed control — a plain labelled `Slider` over a
/// real pixels/second range (15–120) rather than an opaque "slow/medium/
/// fast" enum, so a reader can actually tune it to their own reading pace.
/// Only ever built while auto-scroll is on (see the call site).
class _AutoScrollSpeedBar extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  const _AutoScrollSpeedBar({required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 18),
          Expanded(
            child: Slider(
              value: speed.clamp(15, 120),
              min: 15,
              max: 120,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${speed.round()}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// P3‑8: a fast surah-jump strip — before this the only way to jump
/// between surahs was the toolbar's full-screen "السور" list sheet, a much
/// heavier interaction for what's often a quick "skip ahead a surah or
/// two" move. Auto-scrolls to keep the current surah's chip in view as
/// the reader pages through the mushaf, and tapping any chip jumps
/// straight there (reusing the exact same `surahStartPages` lookup the
/// full sheet already uses).
class _SurahStrip extends StatefulWidget {
  final List<Surah> surahs;
  final Map<int, int> surahStartPages;
  final int currentPage;
  final void Function(int page) onSelect;

  const _SurahStrip({
    required this.surahs,
    required this.surahStartPages,
    required this.currentPage,
    required this.onSelect,
  });

  @override
  State<_SurahStrip> createState() => _SurahStripState();
}

class _SurahStripState extends State<_SurahStrip> {
  static const _itemWidth = 96.0;
  final _scrollController = ScrollController();

  /// The surah whose own start page is the highest one at or before the
  /// current page — i.e. "which surah is this page actually inside".
  int get _currentIndex {
    var best = 0;
    for (var i = 0; i < widget.surahs.length; i++) {
      final start = widget.surahStartPages[widget.surahs[i].id] ?? 1;
      if (start <= widget.currentPage) {
        best = i;
      } else {
        break;
      }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant _SurahStrip old) {
    super.didUpdateWidget(old);
    if (old.currentPage != widget.currentPage) _scrollToCurrent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = (_currentIndex * _itemWidth - 140).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final curIdx = _currentIndex;
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.surahs.length,
        itemExtent: _itemWidth,
        itemBuilder: (context, i) {
          final s = widget.surahs[i];
          final active = i == curIdx;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: active
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onSelect(widget.surahStartPages[s.id] ?? 1),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? AppColors.gold.withValues(alpha: 0.7)
                          : scheme.outlineVariant,
                      width: active ? 1.4 : 1,
                    ),
                  ),
                  child: Text(
                    '${s.id}. ${s.nameAr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppColors.gold : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// P3‑34's `_ToolbarAction` moved to `core/widgets/toolbar_action.dart`
// (P3‑29) so `book_text_reader_screen.dart` can reuse the exact same
// widget instead of a second copy — see `ToolbarAction` there.
