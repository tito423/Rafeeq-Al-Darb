import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/db/models.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/utils/stable_insets.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/recitation_failure_snackbar.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../data/ayah_coords_repository.dart';
import '../../data/continuous_start.dart';
import '../../data/mushaf_data_provider.dart';
import '../../data/mushaf_edition.dart';
import '../../data/mushaf_frame.dart';
import '../../data/mushaf_paper_provider.dart';
import '../../data/mushaf_theme.dart';
import '../../data/page_surahs.dart';
import '../../data/quran_fullscreen_provider.dart';
import '../../data/quran_jump_provider.dart';
import '../../data/quran_last_read.dart';
import '../../data/quran_zoom_provider.dart';
import '../../data/text_layout_provider.dart';
import '../widgets/ayah_sciences_sheet.dart';
/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.
import '../widgets/mushaf/auto_scroll_speed_bar.dart';
import '../widgets/mushaf/continuous_mushaf_view.dart';
import '../widgets/mushaf/fast_page_scroll_bar.dart';
import '../widgets/mushaf/follows_recitation_note.dart';
import '../widgets/mushaf/mushaf_chrome.dart';
import '../widgets/mushaf/mushaf_remote_keys.dart';
import '../widgets/mushaf/mushaf_toolbar.dart';
import '../widgets/mushaf/page_overlay.dart';
import '../widgets/mushaf/page_turn.dart';
import '../widgets/mushaf/recite_bar.dart';
import '../widgets/mushaf/toolbar_bar.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/mushaf_text_page.dart';
import '../widgets/reciter_picker_sheet.dart';

part 'quran_screen_views.dart';

enum MushafMode { text, image }

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  /// Pages in the open edition. Raster printings genuinely differ (Shamarly
  /// 521, Indo-Pak 564) and paging past the real end renders 404s, so this
  /// follows the edition rather than assuming Hafs's 604.
  int _totalPages = 604;

  PageController? _pages;

  /// The reading layout's endless scroll, while it is the one on screen.
  final GlobalKey<ContinuousMushafViewState> _continuous = GlobalKey();

  /// True while the text mushaf is in the reading layout, which is one
  /// continuous scroll instead of pages (owner, 2026-10-02).
  bool get _isContinuous =>
      _mode == MushafMode.text &&
      ref.read(quranTextLayoutProvider) == QuranTextLayout.reading;
  final Map<int, Future<List<Ayah>>> _pageFutures = {};
  final AyahCoordsRepository _coords = AyahCoordsRepository.instance;

  MushafMode _mode = MushafMode.text;

  /// The orientation the last frame was built for, so a rotation can be told
  /// apart from an ordinary rebuild.
  Orientation? _lastOrientation;

  /// What full-screen was set to before the phone was turned sideways.
  bool? _fillBeforePortrait;
  int _current = 1;
  int? _highlightSurah;
  int? _highlightAyah;

  /// Text-mode font scale (1.0 = the page's own base size). Persisted like
  /// `book_text_reader_screen.dart`'s A+/A− — a plain `SharedPreferences`
  /// double, not a provider, since only this screen reads it.
  double _fontScale = 1.0;
  static const _kFontScale = 'quran_text_font_scale_v1';

  /// P3‑39 auto-scroll. Always starts OFF on a fresh open — resuming a
  /// hands-free scroll unasked would be a bad surprise — but the speed the
  /// reader picked is remembered, same as font scale.
  bool _autoScroll = false;
  double _autoScrollSpeed = 40; // pixels/second
  static const _kAutoScrollSpeed = 'quran_text_autoscroll_speed_v1';

  /// P3‑41: the toolbar hides on a downward read and returns on a pull up.
  /// Normal mode only — full screen has no bar to move.
  bool _toolbarVisible = true;

  /// First-frame estimate only; the bar reports its real height on layout.
  double _toolbarHeight = 116;

  /// The floating controls (`MushafChrome`), toggled by the page tap.
  bool _chromeVisible = false;

  /// P3‑41: "give option so I can change page from small to full fit of
  /// screen" — a persisted, explicit reader preference, independent of
  /// the toolbar-hide above (that just reclaims the toolbar's own strip;
  /// this changes how much of *that* remaining space the page itself
  /// fills).
  /// Default since 2026-09-17 («تفتح بملئ الشاشة»); `_restoreState`
  /// overwrites it, so a reader who turned it off keeps it off.
  bool _pageFillScreen = true;
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
    // The continuous view may have been built before the stored page was
    // read; send it there too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isContinuous) _continuous.currentState?.jumpToPage(_current);
    });
    ref.read(quranFullScreenProvider.notifier).state = _pageFillScreen;
    // Only if this tab is the one on screen. On a cold start it is not —
    // `IndexedStack` builds every tab, Home is showing, and applying the mode
    // here is what put the whole app into `immersiveSticky` before the reader
    // had even opened the mushaf.
    if (_pageFillScreen && _isActiveTab) _applyImmersive(true);
    // The stored mode decides whether this screen may rotate at all.
    _applyOrientationLock();
  }

  void _changeFontScale(double delta) {
    setState(() => _fontScale = (_fontScale + delta).clamp(0.75, 1.8));
    SharedPreferences.getInstance().then(
      (p) => p.setDouble(_kFontScale, _fontScale),
    );
  }

  /// «من الآن فصاعدًا ضغطة واحدة خفيفة على الصفحة في أي مكان أو آية ملء
  /// الشاشة أو خروج منه، نصي أو مصوّر، وضغطة تانية تظهر الأيقونات».
  ///
  /// One tap, anywhere on the page, in either mode. The verse card is a long
  /// press. Sideways too since 2026-09-26 («اظهرهم لما اضغط»): the page stays
  /// full screen and the tap shows or hides the floating controls.
  ///
  /// A selected ayah is cleared first; otherwise the tap toggles full screen.
  void _onPageTap() {
    // Recitation highlights belong to the audio and clear when it stops.
    if (!_recite.active && _highlightSurah != null) {
      setState(() { _highlightSurah = null; _highlightAyah = null; });
      return;
    }
    // In full screen the tap shows/hides the floating controls instead of
    // leaving the mode — the same gesture, deliberately; see MushafChrome.
    if (_pageFillScreen) {
      _setChromeVisible(!_chromeVisible);
      return;
    }
    _togglePageFillScreen();
  }

  /// One toolbar for both the app bar and [MushafChrome] — a second copy
  /// is a second copy to forget to update.
  Widget _toolbarFor(MushafData d, bool isRaster, bool canIndexBySurah) =>
      MushafToolbar(
        compact: _toolbarLandscape(context),
        textMode: _mode == MushafMode.text,
        isRaster: isRaster,
        canIndexBySurah: canIndexBySurah,
        autoScroll: _autoScroll,
        autoScrollSpeed: _autoScrollSpeed,
        reciteActive: _recite.active,
        pageFillScreen: _pageFillScreen,
        fontScale: _fontScale,
        data: d,
        current: _current,
        totalPages: _totalPages,
        onFontScale: _changeFontScale,
        onToggleAutoScroll: _toggleAutoScroll,
        onAutoScrollSpeedChanged: _changeAutoScrollSpeed,
        onToggleRecite: () => _toggleContinuousRecitation(d),
        onTogglePageFill: _togglePageFillScreen,
        onGoToPage: _goToPage,
        onNavigateFromIndex: (page, {surahId}) =>
            _navigateFromIndex(page, d, surahId: surahId),
        onEnterImageView: _enterImageView,
        onLeaveImageView: _leaveImageView,
      );

  /// The toolbar gets out of the way while the reader is reading.
  ///
  /// Measured on emulator-5554 before this existed: the text mode gave the
  /// Qur'an 51% of a 2400-pixel screen, and the reference app the owner sent
  /// gives it about 80% — the difference is three rows of toolbar plus its
  /// title. Nothing is hidden behind a preference: a pull back up returns it.
  void _onReadingScroll(bool forward) {
    // In full-screen there is no toolbar to move, and the recitation bar is
    // the reader's transport — leave both alone.
    if (_pageFillScreen) return;
    if (_toolbarVisible == !forward) return;
    setState(() => _toolbarVisible = !forward);
  }

  /// Rotation belongs to the text mode.
  ///
  /// BOTH MODES ROTATE, since 2026-09-17.
  ///
  /// It used to be text-only, on the owner's own call — «خلي الاورينتيشن بس
  /// على النص لو ده أفضل» — because a scanned page has one fixed shape and
  /// on a phone's side it can only be drawn full-width and scrolled, never
  /// the page the printer set. He asked for it back: «هو مينفعش المصحف
  /// الورقي يتعمله اورينتيشن».
  ///
  /// The image page has been ready for this the whole time: `_stage()` in
  /// `mushaf_page_view.dart` carries a landscape branch that lays the scan
  /// out at the full width of the screen and scrolls it vertically, written
  /// and then left unreachable by this lock. Nothing else had to change.
  ///
  /// The trade it makes, stated rather than hidden: sideways you see a band
  /// of the page at a time and scroll, instead of the whole leaf at once.
  /// That is the honest best a fixed-shape scan can do on a phone's side,
  /// and it is why the lock existed.
  void _applyOrientationLock() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Turning the phone sideways opens the page up, «زي ختمة».
  ///
  /// Called from `build` with the orientation it is building for, and does
  /// its work in a post-frame callback because this changes state.
  ///
  /// The automatic full-screen is deliberately NOT persisted: it is a
  /// consequence of how the phone is being held, not a preference, and
  /// writing it would mean a reader who rotated once came back to portrait
  /// permanently immersed. What he chose in portrait is remembered and put
  /// back when he rotates back.
  void _syncOrientationFullScreen(Orientation orientation) {
    if (orientation == _lastOrientation) return;
    final previous = _lastOrientation;
    _lastOrientation = orientation;
    // First build: leave his stored choice — unless the phone is already on
    // its side, where the text is always full screen.
    if (previous == null && orientation != Orientation.landscape) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (orientation == Orientation.landscape) {
        if (_chromeVisible) _setChromeVisible(false); // start clean
        _fillBeforePortrait = _pageFillScreen;
        if (!_pageFillScreen) _setPageFillScreen(true, persist: false);
      } else {
        final back = _fillBeforePortrait;
        _fillBeforePortrait = null;
        if (back != null && back != _pageFillScreen) {
          _setPageFillScreen(back, persist: false);
        }
      }
    });
  }

  void _togglePageFillScreen() => _setPageFillScreen(!_pageFillScreen);

  /// The floating controls and the phone's own bars come and go together:
  /// «لما أضغط على الشاشة يظهر تحت البوتوم نافيجيشن ويظهر النوتش والحاجات
  /// اللي في الستيتس بار» (owner, 2026-10-02). The page already stops short
  /// of where the bars sit (`stableSystemInsets`), so they appear in empty
  /// space and nothing moves.
  void _setChromeVisible(bool visible) {
    if (visible == _chromeVisible) return;
    setState(() => _chromeVisible = visible);
    if (_isActiveTab) _applyImmersive(_pageFillScreen && !visible);
  }

  void _setPageFillScreen(bool entering, {bool persist = true}) {
    if (entering == _pageFillScreen) return;
    setState(() {
      _pageFillScreen = entering;
      _chromeVisible = false;
      // P3‑54: exiting immersive mode also stops the auto-scroll — the owner's
      // spec ("العودة للوضع الطبيعي وإيقاف التمرير"). Every exit path (the
      // toolbar button, a double-tap, and the floating button) funnels through
      // here, so none of them can leave a hands-free scroll running behind the
      // normal reader.
      if (!entering) {
        _autoScroll = false;
        // Leaving full screen is how the options come back — they must not
        // stay hidden behind a scroll that tucked them away earlier.
        _toolbarVisible = true;
      }
    });
    ref.read(quranFullScreenProvider.notifier).state = _pageFillScreen;
    // Same rule as `_restoreState`: the mode is global, so it is only ever
    // set while this tab is the one being looked at.
    if (_isActiveTab) _applyImmersive(_pageFillScreen && !_chromeVisible);
    if (!persist) return;
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kPageFillScreen, _pageFillScreen),
    );
  }

  /// P3‑47: real-device feedback — in full-screen the surah-header badges
  /// collided with the system status bar (clock/battery). Truly "cover
  /// everything" by hiding the system bars while full-screen, and restore
  /// them on exit. `immersiveSticky` lets a swipe from the edge peek them
  /// back temporarily without leaving the mode.
  ///
  /// THE APP-WIDE FLICKER THIS CAUSED, MEASURED ON emulator-5554.
  /// «فيه مأثرة للوحة المفاتيح، لما بتظهر الشاشة بتعمل فليكر، حاصل في أي حتة
  /// في التطبيق». `setEnabledSystemUIMode` is a **process-wide** setting, not
  /// a per-screen one, and this screen is a kept-alive tab inside `AppShell`'s
  /// `IndexedStack` — so it is built on the app's first frame and never
  /// disposed. The moment `_restoreState` read a stored «ملء الشاشة» of true,
  /// the whole app was in `immersiveSticky` for the rest of its life, and
  /// `dispose`'s restore never ran.
  ///
  /// `immersiveSticky` is the worst mode to leave on: it hides the bars and
  /// then *peeks them back* on any interaction before hiding them again, so
  /// opening a keyboard resized the window twice in quick succession. Caught
  /// by recording the library's search screen opening its keyboard —
  /// `screenrecord` at 15 fps shows the keyboard bouncing up, part-way down
  /// and up again, with the status bar appearing and vanishing with it — and
  /// confirmed in `dumpsys window`, which on a screen that never asks for
  /// anything of the sort reported `type=statusBars … visible=false`.
  ///
  /// So the mode now follows the tab: applied only while the Quran tab is the
  /// one on screen, and lifted the moment the reader leaves it — the same
  /// rule `activeTabProvider` already exists for (see its own comment, and
  /// the Qibla compass that pauses its sensor by it).
  /// The mode currently applied, so the same one is never applied twice.
  ///
  /// THE SECOND FLICKER. Re-applying `immersiveSticky` does not no-op: it
  /// re-hides the bars, the window's metrics change, Flutter rebuilds,
  /// `build` runs its `ref.listen` and asks for the mode again — a loop.
  /// Thirty frames pulled at 3 fps from the owner's recording show the
  /// navigation and status bars alternating frame by frame with the page
  /// sliding as the window resizes. Three call sites reach here, so the
  /// guard belongs here rather than at any one of them.
  SystemUiMode? _appliedUiMode;

  void _applyImmersive(bool on) {
    final mode = on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge;
    if (_appliedUiMode == mode) return;
    _appliedUiMode = mode;
    SystemChrome.setEnabledSystemUIMode(mode);
  }

  /// True while this tab is the one being shown.
  bool get _isActiveTab => ref.read(activeTabProvider) == AppTab.quran;

  /// Re-applies (or lifts) the immersive mode for the tab that is now on
  /// screen. Called from `build`'s `ref.listen`.
  void _syncImmersiveToTab(int tab) {
    _applyImmersive(tab == AppTab.quran && _pageFillScreen && !_chromeVisible);
  }

  /// Auto-scroll belongs to the reading layout only, and turning it on
  /// takes the reader there: «أول ما أضغط على السكرول التلقائي يقلب
  /// أوتوماتيك على الوضع الثالث» (owner, 2026-10-02). That layout is one
  /// continuous scroll, so the text runs on through the page ends instead of
  /// stopping to turn a page.
  void _toggleAutoScroll() {
    final on = !_autoScroll;
    if (on) {
      if (_mode != MushafMode.text) _leaveImageView();
      ref.read(quranTextLayoutProvider.notifier).set(QuranTextLayout.reading);
    }
    setState(() => _autoScroll = on);
  }

  void _stopAutoScroll() => setState(() => _autoScroll = false);

  /// The continuous view scrolled a new page up to the reading line.
  void _onScrolledToPage(int page) {
    setState(() => _current = page);
    _persistPage();
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
    _applyOrientationLock();
    AyahAudioService.instance.continuous.addListener(_onReciteChanged);
    AyahAudioService.instance.continuousError.addListener(_onReciteError);
  }

  /// A recitation that could not be loaded now SAYS so. It used to end in
  /// silence with the play button still there, which is indistinguishable
  /// from the app ignoring the press.
  void _onReciteError() {
    final err = AyahAudioService.instance.continuousError.value;
    if (err == null || !mounted) return;
    AyahAudioService.instance.continuousError.value = null;
    // WITH THE HOST AND THE REASON — see `showRecitationFailure`.
    showRecitationFailure(context);
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
    // The continuous scroll brings the verse on screen by itself when its
    // page is already there; only a page out of sight needs the jump.
    if (_isContinuous &&
        (_continuous.currentState?.isOnScreen(page) ?? false)) {
      return;
    }
    _goToPage(page);
  }

  /// What full screen was before the image mushaf took it, so going back to
  /// the text mushaf gives the reader the screen he had.
  bool _fillBeforeImage = false;

  /// «دايمًا أول لما أختار المصحف المصوّر خلّيه ملء الشاشة أوتوماتيك، إلا لو
  /// ضغطت تاني اعرض خياراته». Called on every path that CHOOSES the image
  /// mushaf — the mode button and the printings sheet — not on a restore, so
  /// opening the app does not hide the toolbar by itself.
  void _enterImageView() {
    _fillBeforeImage = _pageFillScreen;
    setState(() => _mode = MushafMode.image);
    _applyOrientationLock();
    _persistMode();
    _setPageFillScreen(true, persist: false);
    // On the dark theme the vector Hafs page and the text page look alike,
    // and full screen hides the toolbar that was just pressed — so say what
    // happened, and how to get the options back.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('quran.image_view_hint'.tr()),
        duration: const Duration(seconds: 3),
      ));
  }

  void _leaveImageView() {
    setState(() => _mode = MushafMode.text);
    _applyOrientationLock();
    _persistMode();
    _setPageFillScreen(_fillBeforeImage, persist: false);
  }

  /// A jump from the surah, juz or page index. While the reciter is reading,
  /// the recitation goes with it — to the surah's first verse when a surah was
  /// picked (remembered for a later press of play too), otherwise to the
  /// page's first verse. Swiping pages by hand does not move it.
  Future<void> _navigateFromIndex(int page, MushafData data,
      {int? surahId}) async {
    final opened = ref.read(quranOpenedAyahProvider.notifier).state = surahId ==
            null
        ? null
        : (surah: surahId, ayah: 1, page: page, mark: false, card: null);
    if (!_continuousToSurah(page, surahId)) _goToPage(page, animate: false);
    if (!_recite.active) return;
    final ayahs = await _ayahsOfPage(page, data);
    if (ayahs.isEmpty || !mounted) return;
    final start = continuousStartOnPage(ayahs, page: page, opened: opened);
    _followedPage = page;
    await AyahAudioService.instance.startContinuous(
      from: start,
      repo: data.repo,
      edition: ref.read(selectedReciterProvider),
    );
  }

  Future<void> _pickReciter() async {
    final id = await showReciterPickerSheet(context);
    if (id == null || !mounted) return;
    await ref.read(selectedReciterProvider.notifier).select(id);
    await AyahAudioService.instance.switchReciter(id);
  }

  String _reciterName() {
    final id = ref.watch(selectedReciterProvider);
    final list = ref.watch(recitersProvider).valueOrNull;
    final r = list?.where((x) => x.identifier == id).firstOrNull;
    return r?.displayName(context.locale.languageCode) ?? '';
  }

  /// Starts continuous recitation where `continuousStartOnPage` says, and
  /// reads on through the mushaf.
  Future<void> _toggleContinuousRecitation(MushafData data) async {
    final audio = AyahAudioService.instance;
    if (_recite.active) {
      // A run Android has already torn down (see `ContinuousRecitation
      // .stalled`) must RESUME on this press, not stop. Treating it as
      // "running" meant the owner's press silently cleared a recitation that
      // was not playing anyway, which read as the button doing nothing.
      if (_recite.stalled) {
        await audio.continuousPauseResume();
        return;
      }
      await audio.stopContinuous();
      return;
    }
    // «لما تضغط على التلاوة المستمرة يديني اختيار قارئ» (2026-09-23), with
    // «أكمل مع …» on top (2026-09-27); downloaded reciters first.
    final pick = await pickReciterOrResume(context);
    if (pick == null || !mounted) return;
    await ref.read(selectedReciterProvider.notifier).select(pick.id);
    if (await resumeContinuousIfPicked(pick, data.repo)) return;
    final ayahs = await _ayahsOfPage(_current, data);
    if (ayahs.isEmpty || !mounted) return;
    final start = continuousStartOnPage(ayahs,
        page: _current,
        selectedSurah: _highlightSurah,
        selectedAyah: _highlightAyah,
        opened: ref.read(quranOpenedAyahProvider));
    await audio.startContinuous(from: start, repo: data.repo, edition: pick.id);
  }

  @override
  void dispose() {
    AyahAudioService.instance.continuous.removeListener(_onReciteChanged);
    AyahAudioService.instance.continuousError.removeListener(_onReciteError);
    _pages?.dispose();
    // Make sure the system bars are never left hidden if this screen goes
    // away while full-screen, and that the rest of the app is not left locked
    // to portrait by the image mushaf's lock.
    _appliedUiMode = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _goToPage(int page, {bool animate = true}) {
    final p = page.clamp(1, _totalPages);
    final continuous = _continuous.currentState;
    if (_isContinuous && continuous != null) {
      continuous.jumpToPage(p);
      _persistPage();
      return;
    }
    final pages = _pages;
    if (pages == null) return;
    if (animate) {
      pages.animateToPage(
        p - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      pages.jumpToPage(p - 1);
    }
    // `_current` comes from onPageChanged only (a cut-off turn desynced it).
    _persistPage();
  }

  // P3‑41: «if I use navigation gesture or option for back just unselect the
  // ayah» - `AyahSciencesSheet.show` resolves on ANY dismissal of the sheet.
  Future<void> _openSciences(
    Ayah ayah,
    MushafData data, {
    bool sciencesAvailable = true,
    int tab = 0,
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
      initialTab: tab,
    );
    // The verse STAYS selected after its card closes, so «التلاوة المستمرة»
    // starts from it: «لما أكون فاتح صفحة وأضغط على آية وأضغط تلاوة تلقائية
    // يبدأ من الآية اللي ضغطت عليها». A tap on the page, or turning it,
    // clears the selection.
  }

  /// «افتح سورة X آية Y»: the verse marked - and so scrolled to, as a recited
  /// one is - and, when asked for, its card opened on that tab.
  Future<void> _markOpened(int page, MushafData? data) async {
    final o = ref.read(quranOpenedAyahProvider);
    if (o == null || o.page != page || !o.mark) return;
    setState(() {
      _highlightSurah = o.surah;
      _highlightAyah = o.ayah;
    });
    final tab = o.card;
    if (tab == null || data == null) return;
    final a = (await _ayahsOfPage(page, data))
        .where((x) => x.surahId == o.surah && x.ayahNumber == o.ayah)
        .firstOrNull;
    if (a != null && mounted) await _openSciences(a, data, tab: tab);
  }

  Future<List<Ayah>> _ayahsOfPage(int page, MushafData data) =>
      _pageFutures.putIfAbsent(page, () => data.repo.ayahsOfPage(page));

  /// True in landscape or under 700 logical pixels tall, where the captioned
  /// bar took five rows at `wm density 600` and left the text ~60 pixels.
  bool _toolbarLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape ||
      MediaQuery.sizeOf(context).height < 700;

  @override
  Widget build(BuildContext context) {
    // The immersive mode is process-wide and follows the tab on screen. See
    // `_applyImmersive` for the flicker this was.
    ref.listen<int>(activeTabProvider, (_, tab) => _syncImmersiveToTab(tab));
    // Auto-scroll is the reading layout's alone; choosing another layout
    // ends it.
    ref.listen<QuranTextLayout>(quranTextLayoutProvider, (_, layout) {
      if (layout != QuranTextLayout.reading && _autoScroll) {
        setState(() => _autoScroll = false);
      }
    });
    final mushaf = ref.watch(mushafDataProvider);
    // `isRaster` means "this printing ships page images", nothing more (until
    // 3.44.0 it forced image mode, and the text mushaf became unreachable).
    final edition = ref.watch(currentMushafEditionProvider).valueOrNull;
    final textLayout = ref.watch(quranTextLayoutProvider);
    final isRaster = edition?.isRaster ?? false;
    // Printings that paginate their own way (Shamarly 521, Indo-Pak 564,
    // Nastaliq 611) would land a surah picked by name on Madinah's page -
    // «عدم اتساق بين اسم السورة … والسورة اللي بتطلع» - so those indexes are
    // withheld there, as the running header is.
    final canIndexBySurah = edition?.hafsPagination ?? true;
    // Recitation stops only on a printing that is not the Madinah layout;
    // madinah_qc recites (owner 2026-09-26; this used to stop ALL image mode).
    if (_recite.active && _mode == MushafMode.image && !canIndexBySurah) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AyahAudioService.instance.stopContinuous(),
      );
    }
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
        _markOpened(page, mushaf.valueOrNull);
        Future.microtask(
          () => ref.read(quranJumpRequestProvider.notifier).state = null,
        );
      }
    });
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // Never transparent over a printed page - see `opaqueMushafGround`.
      backgroundColor: mushafGround(ref.watch(mushafPaperProvider),
              imageMode: _mode == MushafMode.image,
              darkPage: edition?.darkPage ?? false) ??
          (_mode == MushafMode.image
              ? opaqueMushafGround(Theme.of(context).colorScheme.surface,
                  Theme.of(context).brightness)
              : null),
      // P3‑43 #6: "ملء الشاشة" hides the AppBar, this screen's bottom bar and
      // (`quranFullScreenProvider`) the nav bar; a page tap brings them back.
      appBar: _pageFillScreen
          ? null
          : AppBar(
              // In landscape the title row is 56 of the 393 logical pixels the
              // whole screen has, spent restating which tab you are on — the
              // nav bar below already shows Qur'an selected. Collapsing it
              // leaves only the toolbar in the app-bar slot.
              toolbarHeight: _toolbarLandscape(context) ? 0 : null,
              title: _toolbarLandscape(context)
                  ? null
                  : Text('nav.quran'.tr()),
              // P3‑34 made this one scrolling row; P3‑41 made it a `Wrap` so
              // nothing hid until you scrolled. With thirteen actions that
              // was two rows and ~116 logical pixels, permanently, on the tab
              // whose job is to show the Qur'an — «شكلهم بدائي اوي»
              // (2026-09-17), and right about more than the look: three of
              // them opened the SAME sheet and none said what it was set to.
              // It now carries the four things done WHILE reading and every
              // setting moved to `showQuranDisplaySheet`. See
              // `mushaf_toolbar.dart`. It still collapses to nothing when
              // `_toolbarVisible` is false (tapping the page toggles it).
              // LANDSCAPE. A phone in landscape is about 393 logical pixels
              // tall in total. This bar was a fixed 116 of them — two wrapped
              // rows of captioned actions — which, with the 56pt title above
              // it, the page-number bar and the app's own nav below, left the
              // Qur'an text roughly 80 pixels. Measured on emulator-5554: the
              // surah and juz badges were sliced in half and not one line of
              // text fitted. That is the whole of «في الأورينتيشن المصاحف
              // النصية مش بتشتغل».
              //
              // So in landscape the bar drops its captions, becomes one
              // horizontally-scrolling row, and costs 44 instead of 116 —
              // giving the page back 72 pixels, nearly doubling the text area.
              // The height comes from `ToolbarAction`'s own constants rather
              // than from another guessed number.
              bottom: mushaf.hasValue && _toolbarVisible
                  ? mushafToolbarBar(
                      compact: _toolbarLandscape(context),
                      height: _toolbarHeight,
                      onMeasured: (size) {
                        if (!mounted) return;
                        if ((size.height - _toolbarHeight).abs() < 0.5) return;
                        setState(() => _toolbarHeight = size.height);
                      },
                      child: _toolbarFor(
                          mushaf.value!, isRaster, canIndexBySurah),
                    )
                  : null,
            ),
      body: Builder(
        builder: (context) {
          // The WINDOW's orientation, never the body's (`OrientationBuilder`):
          // leaving full screen shrinks the body, a short body read as
          // landscape and re-entered full screen — the flicker on five
          // phones. Reproduced on emulator-5554 at `wm density 600`.
          final orientation = MediaQuery.orientationOf(context);
          final isLandscape = orientation == Orientation.landscape;
          _syncOrientationFullScreen(orientation);
          // Full screen stops where the system bars would be, so a tap can
          // bring them back over empty space - see `stableSystemInsets`.
          final bars = stableSystemInsets(context);
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
                    // Full screen: up to the notch and the status bar, and no
                    // further (owner, 2026-10-02).
                    top: _pageFillScreen
                        ? bars.top + 6
                        : (isLandscape ? 28 : 40),
                    left: _pageFillScreen ? bars.left : 0,
                    right: _pageFillScreen ? bars.right : 0,
                    // Down to the phone's navigation bar. Landscape floats the
                    // page badge over the page (the bar that used to carry it
                    // is gone, see below), so there the text also stops short
                    // of it or the last line runs underneath the number.
                    bottom: _pageFillScreen
                        ? (isLandscape
                            ? (bars.bottom + 6).clamp(36.0, double.infinity)
                            : bars.bottom + 6)
                        : (isLandscape ? 34 : 0),
                  ),
                  child: _buildViewer(data, edition, textLayout),
                ),
                // NORMAL MODE ONLY: in full screen `MushafChrome` carries
                // surah + juz + page with the controls, and leaving these
                // here too would show the juz twice when the panel opened.
                // Only label the page with a surah/juz when this printing
                // actually shares the Hafs pagination those labels come from
                // — otherwise they would name a surah this page doesn't hold.
                if (!_pageFillScreen || (isLandscape && !_chromeVisible)) // chrome carries it
                  PersistentPageOverlay(
                  // Image mode only. The text page already carries its own
                  // pinned header and a banner for every surah it opens, so a
                  // third copy in the corner was «متكرر سورة الرعد ٣ مرات».
                  // «في وضع المصحف شيل اسم السورة واسم الجزء واعتمد على اللي
                  // موجودين في صفحة المصحف المصوّر». A printing whose page
                  // prints them gets neither badge; one that does not (the
                  // vector Hafs pages) keeps both. The text page has its own
                  // header, so it keeps only the juz.
                  surahName: (edition?.hafsPagination ?? true) &&
                          _mode == MushafMode.image &&
                          !(edition?.printedHeader ?? false)
                      ? _currentSurahName(data)
                      : null,
                  juzNumber: (edition?.hafsPagination ?? true) &&
                          !(_mode == MushafMode.image &&
                              (edition?.printedHeader ?? false))
                      ? _currentJuzNumber(data)
                      : null,
                  // Landscape drops the page-number bar under the text, so
                  // the number has to live here instead of nowhere.
                  pageNumber: (_pageFillScreen || isLandscape) ? _current : null,
                ),
                // THE FLOATING CONTROLS, replacing a black-and-white «exit
                // immersive» circle. They take no layout space, so the
                // mushaf keeps the whole screen — «مش تاكل اي حاجة من الشاشة».
                if (_pageFillScreen)
                  MushafChrome(
                    visible: _chromeVisible || ref.watch(tutorialRunningProvider),
                    onAutoHide: () => _setChromeVisible(false),
                    mt: resolveMushafTheme(ref.watch(mushafThemeProvider),
                        Theme.of(context).brightness),
                    surahName: (edition?.hafsPagination ?? true)
                        ? _currentSurahName(data)
                        : null,
                    juzNumber: (edition?.hafsPagination ?? true)
                        ? _currentJuzNumber(data)
                        : null,
                    pageNumber: _current, totalPages: _totalPages,
                    actions: _toolbarFor(data, isRaster, canIndexBySurah),
                    pageBadges: !(edition?.printedHeader ?? false),
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
                    if (_recite.active)
                      ReciteBar(
                        state: _recite,
                        reciterName: _reciterName(),
                        onPickReciter: _pickReciter,
                      ),
                    // Only shown once auto-scroll is actually on — no point
                    // occupying screen space with a speed control for a feature
                    // that isn't running.
                    if (_autoScroll && _mode == MushafMode.text && _recite.active)
                      const FollowsRecitationNote()
                    else if (_autoScroll && _mode == MushafMode.text)
                      AutoScrollSpeedBar(
                        speed: _autoScrollSpeed,
                        onChanged: _changeAutoScrollSpeed,
                      ),
                    // (b) The page-number info bar — its own row, centred, so
                    // it sits cleanly below the text instead of over it.
                    //
                    // Not in landscape: it costs about 60 logical pixels of a
                    // 393-pixel screen to show a number the running header
                    // already carries, and those pixels are the difference
                    // between a page of Qur'an and none.
                    if (!_toolbarLandscape(context)) ...[
                      Center(child: PageNumberBadge(page: _current)),
                      const SizedBox(height: 6),
                    ],
                    // (c) One real drag-to-scrub scrollbar (P3‑43 #4/#5: the
                    // old surah strip + ‹ › arrows were removed per the
                    // owner's repeated ask).
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FastPageScrollBar(
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
    if (_mode == MushafMode.text && textLayout == QuranTextLayout.reading) {
      return _buildContinuous(data, textLayout);
    }
    _pages ??= PageController(initialPage: _current - 1);
    // «دايمًا خلّي تقليب الصفحات من اليمين للشمال»: a mushaf turns right to
    // left in every UI language; each page keeps the UI's own direction.
    final ambient = Directionality.of(context);
    return Directionality(textDirection: TextDirection.rtl, child: MushafRemoteKeys(onTurn: (d) => _goToPage(_current + d), onSelect: _onPageTap, child: PageView.builder(
      controller: _pages,
      // Frozen while the page is pinched in, so a pan moves the page instead
      // of turning it — see `quran_zoom_provider.dart`.
      physics: ref.watch(quranPageZoomedProvider)
          ? const NeverScrollableScrollPhysics()
          : null,
      onPageChanged: (i) {
        setState(() {
          _current = i + 1;
          if (!_recite.active) {
            _highlightSurah = null;
            _highlightAyah = null;
          }
        });
        _persistPage();
      },
      itemCount: _totalPages,
      itemBuilder: (context, index) {
        final page = index + 1;
        return TurningPage(
          controller: _pages!,
          index: index,
          child: Directionality(textDirection: ambient, child: FutureBuilder<List<Ayah>>(
          future: _ayahsOfPage(page, data), initialData: data.repo.pageIfLoaded(page),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final ayahs = snap.data!;
            // The reader's own mode decides; the `|| edition.isRaster` that
            // stood here was always true after 3.43.0, so `MushafTextPage`
            // below was dead code. See the note on `isRaster` above.
            if (_mode == MushafMode.image) {
              if (edition == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return MushafPageView(
                edition: edition,
                page: page,
                // While reciting, the verse being read wins over a tap
                // selection — it is the one the reader is following.
                highlight: _current != page
                    ? null
                    : _coords.regionOf(edition.polygonsAsset, page,
                        _recite.active ? _recite.surahId : _highlightSurah,
                        _recite.active ? _recite.ayahNumber : _highlightAyah),
                onAyahLongPress: (region) =>
                    _onImageAyahTap(region, ayahs, data, edition),
                onLoadFailed: edition.isRaster
                    ? null
                    : () {
                        setState(() => _mode = MushafMode.text);
                        _applyOrientationLock();
                      },
                onBackgroundTap: _onPageTap,
              );
            }
            return _textPage(page, ayahs, data, textLayout);
          },
        )));
      },
    )));
  }

}

/// The compact transport shown under the page while continuous recitation is
/// running: which verse is sounding, and the three controls a listener
/// actually reaches for.
