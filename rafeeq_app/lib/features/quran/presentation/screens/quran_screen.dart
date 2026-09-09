import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../data/ayah_coords_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../data/mushaf_data_provider.dart';
import '../../data/mushaf_edition.dart';
import '../../data/quran_fullscreen_provider.dart';
import '../../data/quran_jump_provider.dart';
import '../../data/mushaf_frame.dart';
import '../../data/mushaf_theme.dart';
import '../../data/text_layout_provider.dart';
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
  /// Pages in the edition currently open. Hafs and most printings are 604,
  /// but the raster printings genuinely differ (Shamarly 521, Indo-Pak 564),
  /// and paging past a printing's real end would just render 404s — so this
  /// tracks the selected edition instead of assuming the Hafs count.
  int _totalPages = 604;

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

  /// Live state of continuous (ayah-by-ayah, auto-advancing) recitation.
  /// Mirrored into local state from `AyahAudioService.continuous` so the page
  /// can highlight the verse being recited and follow it across page breaks.
  ContinuousRecitation _recite = ContinuousRecitation.stopped;

  /// Guards the page-following below: without it, every position update for a
  /// verse already on screen would re-issue the same page jump.
  int? _followedPage;

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
    if (_pageFillScreen) _applyImmersive(true);
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
      // P3‑54: leaving immersive mode is now a double-tap or the translucent
      // floating button (see `_togglePageFillScreen` / the exit FAB), so a
      // single tap here instead toggles the hands-free auto-scroll — a
      // tap-to-pause/resume, like a video, without dropping out of immersive
      // reading.
      _toggleAutoScroll();
    } else {
      setState(() => _toolbarVisible = !_toolbarVisible);
    }
  }

  void _togglePageFillScreen() {
    final entering = !_pageFillScreen;
    setState(() {
      _pageFillScreen = entering;
      // P3‑54: exiting immersive mode also stops the auto-scroll — the owner's
      // spec ("العودة للوضع الطبيعي وإيقاف التمرير"). Every exit path (the
      // toolbar button, a double-tap, and the floating button) funnels through
      // here, so none of them can leave a hands-free scroll running behind the
      // normal reader.
      if (!entering) _autoScroll = false;
    });
    ref.read(quranFullScreenProvider.notifier).state = _pageFillScreen;
    _applyImmersive(_pageFillScreen);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kPageFillScreen, _pageFillScreen),
    );
  }

  /// P3‑47: real-device feedback — in full-screen the surah-header badges
  /// collided with the system status bar (clock/battery). Truly "cover
  /// everything" by hiding the system bars while full-screen, and restore
  /// them on exit. `immersiveSticky` lets a swipe from the edge peek them
  /// back temporarily without leaving the mode.
  void _applyImmersive(bool on) {
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
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
    AyahAudioService.instance.continuous.addListener(_onReciteChanged);
  }

  /// The recitation moved to another verse. Two things follow: the highlight
  /// (a plain rebuild), and turning the page when the reciter crosses onto
  /// the next one — the reader should never have to swipe to keep up.
  void _onReciteChanged() {
    if (!mounted) return;
    final state = AyahAudioService.instance.continuous.value;
    setState(() => _recite = state);
    if (!state.active) {
      _followedPage = null;
      return;
    }
    final surah = state.surahId;
    final ayah = state.ayahNumber;
    if (surah == null || ayah == null) return;
    unawaited(_followRecitationTo(surah, ayah));
  }

  Future<void> _followRecitationTo(int surah, int ayah) async {
    final repo = ref.read(mushafDataProvider).valueOrNull?.repo;
    if (repo == null) return;
    final row = await repo.ayah(surah, ayah);
    if (!mounted || row == null) return;
    final page = row.pageNumber;
    if (page == _current || page == _followedPage) return;
    _followedPage = page;
    _goToPage(page);
  }

  /// Starts continuous recitation from the current page (or from the verse
  /// the reader has selected, if any), and reads on through the mushaf.
  Future<void> _toggleContinuousRecitation(MushafData data) async {
    final audio = AyahAudioService.instance;
    if (_recite.active) {
      await audio.stopContinuous();
      return;
    }
    final ayahs = await _ayahsOfPage(_current, data);
    if (ayahs.isEmpty || !mounted) return;
    final start = ayahs.firstWhere(
      (a) => a.surahId == _highlightSurah && a.ayahNumber == _highlightAyah,
      orElse: () => ayahs.first,
    );
    await audio.startContinuous(
      from: start,
      repo: data.repo,
      edition: ref.read(selectedReciterProvider),
    );
  }

  @override
  void dispose() {
    AyahAudioService.instance.continuous.removeListener(_onReciteChanged);
    _pages?.dispose();
    // Make sure the system bars are never left hidden if this screen goes
    // away while full-screen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  AyahRegion? _highlightRegion(MushafEdition edition, int page) {
    if (_current != page) return null;
    // While reciting, the verse being read wins over a tap selection — it is
    // the one the reader is actually following.
    final surah = _recite.active ? _recite.surahId : _highlightSurah;
    final ayah = _recite.active ? _recite.ayahNumber : _highlightAyah;
    if (surah == null || ayah == null) return null;
    // The regions are in the polygon layer's own space; `MushafPageView`
    // applies the printing's fit when it paints them.
    for (final r in _coords.regionsForPage(edition.polygonsAsset, page)) {
      if (r.surah == surah && r.ayah == ayah) return r;
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
    // P3‑53: a raster (image-scan) edition — e.g. the coloured Tajweed mushaf —
    // has no reflowable text form, so it's always shown as page images. This
    // coerces the reader into image mode and hides the text/image toggle and
    // the text-only controls for those editions.
    final edition = ref.watch(currentMushafEditionProvider).valueOrNull;
    final textLayout = ref.watch(quranTextLayoutProvider);
    final isRaster = edition?.isRaster ?? false;
    // Adopt the open edition's real page count. Plain assignment rather than
    // setState: we are already inside build and the new value is used by this
    // very frame. If the reader was deeper into a longer printing than the
    // newly-picked one has pages, pull them back to its last page after the
    // frame — paging past the end would only ever render 404s.
    if (edition != null && edition.pages != _totalPages) {
      _totalPages = edition.pages;
      if (_current > _totalPages) {
        final clamped = _totalPages;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _goToPage(clamped, animate: false);
        });
      }
    }
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
                            if (_mode == MushafMode.text && !isRaster) ...[
                              // Both verse layouts are real reading
                              // preferences, so this switches between them
                              // rather than one replacing the other.
                              ToolbarAction(
                                icon: textLayout == QuranTextLayout.page
                                    ? Icons.view_agenda_outlined
                                    : Icons.article_outlined,
                                label: textLayout == QuranTextLayout.page
                                    ? 'quran.layout_cards'.tr()
                                    : 'quran.layout_page'.tr(),
                                onPressed: () => ref
                                    .read(quranTextLayoutProvider.notifier)
                                    .toggle(),
                              ),
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
                            // Continuous recitation works in both modes: the
                            // text page tints the verse, the image page
                            // highlights its polygon, and either way the reader
                            // turns its own pages to follow the reciter.
                            ToolbarAction(
                              icon: _recite.active
                                  ? Icons.stop_circle_outlined
                                  : Icons.headphones_rounded,
                              label: _recite.active
                                  ? 'quran.recite_stop'.tr()
                                  : 'quran.recite_continuous'.tr(),
                              onPressed: () =>
                                  _toggleContinuousRecitation(mushaf.value!),
                            ),
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
                            // A raster printing is a finished scan with no
                            // reflowable text of its own — but the button is
                            // still shown, because hiding it left a reader who
                            // had picked one of those printings with no way
                            // back to the text reader at all. On a raster
                            // edition it switches back to the default text
                            // edition as well as the mode.
                            ToolbarAction(
                              icon: (_mode == MushafMode.text && !isRaster)
                                  ? Icons.image_outlined
                                  : Icons.notes,
                              label: (_mode == MushafMode.text && !isRaster)
                                  ? 'quran.mushaf_mode'.tr()
                                  : 'quran.text_mode'.tr(),
                              onPressed: () {
                                if (isRaster) {
                                  ref
                                      .read(selectedMushafEditionProvider
                                          .notifier)
                                      .select(AppConfig.defaultMushafEdition);
                                  setState(() => _mode = MushafMode.text);
                                } else {
                                  setState(() {
                                    _mode = _mode == MushafMode.text
                                        ? MushafMode.image
                                        : MushafMode.text;
                                  });
                                }
                                _persistMode();
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return mushaf.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
            data: (data) => Stack(
              children: [
                // P3‑44 / P3-Landscape: adjust viewer padding dynamically based on
                // screen orientation and full-screen state.
                Padding(
                  padding: EdgeInsets.only(
                    top: _pageFillScreen
                        ? (isLandscape ? 32 : 44)
                        : (isLandscape ? 28 : 40),
                    bottom: _pageFillScreen
                        ? (isLandscape ? 36 : 56)
                        : 0,
                  ),
                  child: _buildViewer(data, edition, textLayout),
                ),
                // P3‑43 #7 / P3‑51: the surah name (top-right) and juz (top-left)
                // running header stays on screen regardless of toolbar/full-screen
                // — reading context, not an "option". The page number is only
                // floated here in full-screen mode (where there's no bottom bar);
                // in normal mode it lives in its own bar under the text so it can
                // never overlap the last line.
                // Only label the page with a surah/juz when this printing
                // actually shares the Hafs pagination those labels come from
                // — otherwise they would name a surah this page doesn't hold.
                _PersistentPageOverlay(
                  surahName: (edition?.hafsPagination ?? true)
                      ? _currentSurahName(data)
                      : null,
                  juzNumber: (edition?.hafsPagination ?? true)
                      ? _currentJuzNumber(data)
                      : null,
                  pageNumber: _pageFillScreen ? _current : null,
                ),
                // P3‑54: a translucent floating "exit immersive" button — the
                // always-visible, discoverable way back out (alongside the
                // double-tap gesture), since in full-screen the toolbar that
                // toggled the mode is itself off-screen. Only present while
                // full-screen; a plain SafeArea-aligned button, not an
                // `IgnorePointer` overlay, so it actually receives its own taps.
                if (_pageFillScreen)
                  SafeArea(
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      // Sits below the running-header badges (surah/juz occupy the
                      // top corners) so it never overlaps them.
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: 8,
                          top: isLandscape ? 40 : 56,
                        ),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'quran.page_fit_small'.tr(),
                            icon: const Icon(Icons.fullscreen_exit,
                                color: Colors.white),
                            onPressed: _togglePageFillScreen,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      // P3‑51: the owner asked for a clean vertical stack with nothing
      // floating over the ayah text — (a) the text area (the Scaffold body,
      // Expanded by nature), (b) a dedicated info bar with the page number
      // centred, (c) the scrollbar, (d) the app's own bottom nav. This
      // bottomNavigationBar holds (b) + (c); (d) is AppShell's NavigationBar
      // below it. Built with min-size flex so it never overflows or overlaps
      // regardless of screen size/density.
      bottomNavigationBar: _pageFillScreen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The reciter's transport, only while it is actually
                    // running — skip back/forward a verse, pause, or stop
                    // without digging back into the toolbar.
                    if (_recite.active) _ReciteBar(state: _recite),
                    // Only shown once auto-scroll is actually on — no point
                    // occupying screen space with a speed control for a feature
                    // that isn't running.
                    if (_autoScroll && _mode == MushafMode.text)
                      _AutoScrollSpeedBar(
                        speed: _autoScrollSpeed,
                        onChanged: _changeAutoScrollSpeed,
                      ),
                    // (b) The page-number info bar — its own row, centred, so
                    // it sits cleanly below the text instead of over it.
                    Center(child: _PageNumberBadge(page: _current)),
                    const SizedBox(height: 6),
                    // (c) One real drag-to-scrub scrollbar (P3‑43 #4/#5: the
                    // old surah strip + ‹ › arrows were removed per the
                    // owner's repeated ask).
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _FastPageScrollBar(
                        currentPage: _current,
                        totalPages: _totalPages,
                        onChanged: (p) => _goToPage(p, animate: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildViewer(
    MushafData data,
    MushafEdition? edition,
    QuranTextLayout textLayout,
  ) {
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
            // A raster edition is always shown as page images, regardless of
            // the persisted text/image mode (it has no reflowable text form).
            if (_mode == MushafMode.image || (edition?.isRaster ?? false)) {
              if (edition == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return MushafPageView(
                edition: edition,
                page: page,
                highlight: _highlightRegion(edition, page),
                onAyahTap: (region) =>
                    _onImageAyahTap(region, ayahs, data, edition),
                onLoadFailed: edition.isRaster
                    ? null
                    : () => setState(() => _mode = MushafMode.text),
                // Image mode never had a tap-to-hide-toolbar gesture (only
                // text mode does, since P3‑42) — deliberately not adding
                // one here. This only exists so a full-screen image-mode
                // reader can be exited the same way the text-mode one can.
                onBackgroundTap: _pageFillScreen ? _togglePageFillScreen : null,
              );
            }
            final mushafTheme = resolveMushafTheme(
              ref.watch(mushafThemeProvider),
              Theme.of(context).brightness,
            );
            final frame = ref.watch(mushafFrameProvider);
            return MushafTextPage(
              layout: textLayout,
              mushafTheme: mushafTheme,
              frameStyle: frame.style,
              frameColor: frame.accent.color ?? mushafTheme.gold,
              ayahs: ayahs,
              surahNameOf: data.surahNameAr,
              playingSurah: _recite.active ? _recite.surahId : null,
              playingAyah: _recite.active ? _recite.ayahNumber : null,
              onAyahTap: (a) => _openSciences(a, data),
              // `edition:` here is the RECITER, not the mushaf. It used to
              // be handed `edition?.id ?? 'hafs_kfqc'` — a *mushaf* printing
              // id — so every verse resolved to
              // `cdn.islamic.network/quran/audio/128/hafs_kfqc/<n>.mp3`,
              // which 404s; `setAudioSource` threw, the catch called
              // `stopContinuous()`, and picking a verse stopped the
              // recitation instead of moving it. That is the owner's
              // «واجي اختار آية … بتقف التلاوة مش بتشتغل».
              onPlayTap: (a) {
                AyahAudioService.instance.startContinuous(
                  from: a,
                  repo: data.repo,
                  edition: ref.read(selectedReciterProvider),
                  wholeMushaf: true,
                );
              },
              fontScale: _fontScale,
              autoScroll: _autoScroll,
              autoScrollSpeed: _autoScrollSpeed,
              isActive: page == _current,
              onAutoScrollReachedEnd: _onAutoScrollReachedEnd,
              onBackgroundTap: _onBackgroundTap,
              pageFillScreen: _pageFillScreen,
              // Only wired in full-screen, so a stray double-tap never exits a
              // mode the reader isn't in.
              onExitFullScreen: _pageFillScreen ? _togglePageFillScreen : null,
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

/// The compact transport shown under the page while continuous recitation is
/// running: which verse is sounding, and the three controls a listener
/// actually reaches for.
class _ReciteBar extends StatelessWidget {
  final ContinuousRecitation state;
  const _ReciteBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final audio = AyahAudioService.instance;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
          child: Row(
            children: [
              Icon(
                state.buffering ? Icons.hourglass_top_rounded : Icons.graphic_eq_rounded,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.buffering
                      ? 'quran.recite_loading'.tr()
                      : 'quran.recite_now'.tr(
                          args: [
                            '${state.surahId ?? ''}',
                            '${state.ayahNumber ?? ''}',
                          ],
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_previous'.tr(),
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: audio.continuousPrevious,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_pause'.tr(),
                icon: const Icon(Icons.pause_circle_outline_rounded),
                onPressed: audio.continuousPauseResume,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_next'.tr(),
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: audio.continuousNext,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_stop'.tr(),
                icon: Icon(Icons.stop_circle_outlined, color: scheme.error),
                onPressed: audio.stopContinuous,
              ),
            ],
          ),
        ),
      ),
    );
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
  /// Null when the open printing doesn't share the Hafs pagination these
  /// labels are derived from — the header is simply omitted rather than
  /// asserting a surah/juz that isn't on the page.
  final String? surahName;
  final int? juzNumber;

  /// P3‑51: the page number itself no longer lives here. In normal mode it's
  /// a real bar under the text (see the Scaffold's bottomNavigationBar), so
  /// this overlay only paints the top running header (surah + juz). In
  /// full-screen mode there's no bottom bar, so the page badge is shown here
  /// at the bottom instead — the viewer already reserves 56px there, so it
  /// never overlaps the last line.
  final int? pageNumber;

  const _PersistentPageOverlay({
    this.surahName,
    this.juzNumber,
    this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              if (surahName != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _HeaderBadge(text: surahName!),
                ),
              if (juzNumber != null)
                Positioned(
                  top: 0,
                  left: 0,
                // Same convention as the surah name above (and as
                // `mushaf_nav_sheets.dart`'s own juz list): a real
                // mushaf's own running header is always Arabic — it's
                // part of the page's own printed identity, not app UI
                // chrome that follows the interface locale.
                  child:
                      _HeaderBadge(text: 'الجزء ${_arabicNumber(juzNumber!)}'),
                ),
              if (pageNumber != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _PageNumberBadge(page: pageNumber!),
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

/// P3‑51: a uniform, perfectly-centred badge for the running header.
///
/// Arabic (esp. the AmiriQuran calligraphy face, with its large internal
/// metrics and tashkeel marks that sit above/below the glyph body) does not
/// vertically centre inside a box by default — the baseline drifts. The fix,
/// applied here and in [_PageNumberBadge], is: `alignment: center` on the box,
/// plus `StrutStyle(forceStrutHeight, height:1.0, leading:0)` and a
/// `TextHeightBehavior` that trims the first-ascent/last-descent, so the line
/// box collapses to the font size and the glyph lands in the geometric centre.
class _HeaderBadge extends StatelessWidget {
  final String text;
  const _HeaderBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const fontSize = 13.0;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
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
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// P3‑51: the page-number badge — a real circle with the Arabic-Indic page
/// number geometrically centred (same centring recipe as [_HeaderBadge]).
/// Used both in the normal-mode bottom info bar and, in full-screen, floated
/// at the bottom of the reserved strip.
class _PageNumberBadge extends StatelessWidget {
  final int page;
  const _PageNumberBadge({required this.page});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        _arabicNumber(page),
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(
          fontFamily: 'AmiriQuran',
          fontSize: 14,
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
          fontSize: 14,
          height: 1.0,
          fontWeight: FontWeight.w700,
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

/// P3‑43 #4/#5: replaces the old surah-name strip (P3‑8) *and* the ‹ ›
/// page-arrow buttons with one real drag-to-scrub scrollbar — the owner's
/// actual, twice-repeated ask ("my request was only fast scroll bar not
/// putting suras names", P3‑41; "delete the arrows, make scroll bar, when
/// I move it scroll quickly", this round). Dragging anywhere jumps
/// immediately (no animation — a scrub should feel instant, not
/// throttled by a 320ms page-turn tween), and the thumb tracks the real
/// current page live while dragging, not just on release.
///
/// **Direction: follows the app's own text direction.** P3‑43 originally
/// shipped this as a plain always-left-to-right value (matching every
/// other slider in the app) since there was no confirmed signal either
/// way. P3‑44's real-device round gave a direct one: real feedback asked
/// for RTL specifically "in arabic locale selection state" — so in an
/// RTL locale, page 1 now sits at the physical right (like a printed
/// Arabic mushaf's spine) and dragging left increases the page number;
/// in an LTR locale it stays the original plain left-to-right mapping.
class _FastPageScrollBar extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const _FastPageScrollBar({
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  State<_FastPageScrollBar> createState() => _FastPageScrollBarState();
}

class _FastPageScrollBarState extends State<_FastPageScrollBar> {
  /// 0 = page 1 (physical left), 1 = page [totalPages] (physical right).
  /// Non-null only while a drag is actively in progress, so the thumb
  /// reflects the real `currentPage` (from the parent, once it's actually
  /// jumped) the rest of the time rather than a stale local guess.
  double? _dragFraction;

  /// `fraction` is always plain screen-space left(0)-to-right(1) — the RTL
  /// flip lives entirely in these two conversions, so `thumbX`/`Positioned`
  /// below never has to think about direction itself. Each must stay the
  /// exact inverse of the other for a given `isRtl`.
  double _fractionOf(int page, bool isRtl) {
    if (widget.totalPages <= 1) return isRtl ? 1.0 : 0.0;
    final t = (page - 1) / (widget.totalPages - 1);
    return isRtl ? 1 - t : t;
  }

  int _pageOf(double fraction, bool isRtl) {
    final t = isRtl ? 1 - fraction : fraction;
    return 1 + (t * (widget.totalPages - 1)).round();
  }

  void _handleDragAt(double dx, double width, bool isRtl) {
    final fraction = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
    widget.onChanged(_pageOf(fraction, isRtl));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = context.locale.languageCode == 'ar';
    final fraction = _dragFraction ?? _fractionOf(widget.currentPage, isRtl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbSize = 26.0;
        final thumbX = (fraction * width).clamp(
          thumbSize / 2,
          width - thumbSize / 2,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handleDragAt(d.localPosition.dx, width, isRtl),
          onHorizontalDragUpdate: (d) =>
              _handleDragAt(d.localPosition.dx, width, isRtl),
          onHorizontalDragEnd: (_) => setState(() => _dragFraction = null),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: thumbX - thumbSize / 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// P3‑34's `_ToolbarAction` moved to `core/widgets/toolbar_action.dart`
// (P3‑29) so `book_text_reader_screen.dart` can reuse the exact same
// widget instead of a second copy — see `ToolbarAction` there.
