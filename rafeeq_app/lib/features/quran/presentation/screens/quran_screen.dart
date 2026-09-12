import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/models.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/toolbar_action.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../data/ayah_coords_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../downloads/data/reciters_provider.dart';
import '../../data/mushaf_data_provider.dart';
import '../../data/mushaf_edition.dart';
import '../../data/page_surahs.dart';
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
import '../widgets/reciter_picker_sheet.dart';
import '../widgets/mushaf_theme_picker.dart';
import '../widgets/mushaf_text_page.dart';
import '../../../../app/shell/tab_request_provider.dart';

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

  /// The orientation the last frame was built for, so a rotation can be told
  /// apart from an ordinary rebuild.
  Orientation? _lastOrientation;

  /// What full-screen was set to before the phone was turned sideways.
  bool? _fillBeforePortrait;
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
  /// press. In landscape the page stays full screen — «الخيارات تظهر بس في
  /// الوضع العمودي» — so a tap there does nothing.
  ///
  /// This replaces three older meanings of the same tap: clear the selection,
  /// hide the toolbar, and in full screen pause the auto-scroll. The selection
  /// now stays until the page turns, so the continuous recitation can still
  /// start from it after going full screen.
  void _onPageTap() {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) return;
    _togglePageFillScreen();
  }

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
  /// The owner's call: «خلي الاورينتيشن بس على النص لو ده أفضل». It is. A
  /// scanned page has one fixed shape, and on a phone's side it can only be
  /// drawn full-width and scrolled — readable, but never the page the printer
  /// set. The text reflows, so landscape genuinely gives it longer lines.
  /// Reverting this is one list.
  void _applyOrientationLock() {
    SystemChrome.setPreferredOrientations(
      _mode == MushafMode.text
          ? const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
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

  void _setPageFillScreen(bool entering, {bool persist = true}) {
    if (entering == _pageFillScreen) return;
    setState(() {
      _pageFillScreen = entering;
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
    if (_isActiveTab) _applyImmersive(_pageFillScreen);
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
  void _applyImmersive(bool on) {
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  /// True while this tab is the one being shown.
  bool get _isActiveTab => ref.read(activeTabProvider) == AppTab.quran;

  /// Re-applies (or lifts) the immersive mode for the tab that is now on
  /// screen. Called from `build`'s `ref.listen`.
  void _syncImmersiveToTab(int tab) {
    _applyImmersive(tab == AppTab.quran && _pageFillScreen);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('quran.recite_failed'.tr()),
        duration: const Duration(seconds: 4),
      ),
    );
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

  /// The printings sheet. Picking a printing IS choosing the mushaf view:
  /// picking «مصحف المدينة — حفص» used to change the printing and leave the
  /// reader in the text mode he was in, so from his side the button did
  /// nothing — only the scanned printings, which have no text mode, ever
  /// opened as a mushaf.
  Future<void> _pickEdition() async {
    final id = await MushafEditionSheet.show(context);
    if (id == null || !mounted) return;
    _enterImageView();
  }

  /// A jump from the surah, juz or page index. While the reciter is reading,
  /// the recitation goes with it — to the surah's first verse when a surah was
  /// picked, otherwise to the page's first verse. Swiping pages by hand does
  /// not move it: that is looking around, not choosing.
  Future<void> _navigateFromIndex(
    int page,
    MushafData data, {
    bool surahStart = false,
  }) async {
    _goToPage(page, animate: false);
    if (!_recite.active) return;
    final ayahs = await _ayahsOfPage(page, data);
    if (ayahs.isEmpty || !mounted) return;
    final start = surahStart
        ? ayahs.firstWhere((a) => a.ayahNumber == 1, orElse: () => ayahs.first)
        : ayahs.first;
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

  /// Starts continuous recitation from the current page (or from the verse
  /// the reader has selected, if any), and reads on through the mushaf.
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
    AyahAudioService.instance.continuousError.removeListener(_onReciteError);
    _pages?.dispose();
    // Make sure the system bars are never left hidden if this screen goes
    // away while full-screen, and that the rest of the app is not left locked
    // to portrait by the image mushaf's lock.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
  // of them go through `Navigator.pop` under a `showModalBottomSheet`).
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
    // The verse STAYS selected after its card closes, so «التلاوة المستمرة»
    // starts from it: «لما أكون فاتح صفحة وأضغط على آية وأضغط تلاوة تلقائية
    // يبدأ من الآية اللي ضغطت عليها». A tap on the page, or turning it,
    // clears the selection.
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

  /// The surahs on the page being read — see `page_surahs.dart` for the rule
  /// and for the defect that made it necessary.
  String _currentSurahName(MushafData data) => surahNamesOnPage(
        surahs: data.surahs,
        startPages: data.surahStartPages,
        endPages: data.surahEndPages,
        page: _current,
      ).join(' · ');

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

  /// True when the toolbar has to earn its vertical space.
  ///
  /// `MediaQuery.orientationOf` rather than the body's `OrientationBuilder`:
  /// the bar is built in the `appBar` slot, above and outside that builder.
  bool _toolbarLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  @override
  Widget build(BuildContext context) {
    // The immersive mode is process-wide; it follows whichever tab is on
    // screen so it can never leak into the rest of the app. See
    // `_applyImmersive` for the flicker this was.
    ref.listen<int>(activeTabProvider, (_, tab) => _syncImmersiveToTab(tab));
    final mushaf = ref.watch(mushafDataProvider);
    // P3‑53: a raster (image-scan) edition — e.g. the coloured Tajweed mushaf —
    // has no reflowable text form, so it's always shown as page images. This
    // coerces the reader into image mode and hides the text/image toggle and
    // the text-only controls for those editions.
    final edition = ref.watch(currentMushafEditionProvider).valueOrNull;
    final textLayout = ref.watch(quranTextLayoutProvider);
    final isRaster = edition?.isRaster ?? false;
    // Three of the nine printings paginate their own way — Shamarly's 521
    // pages, the Indo-Pak 564, the Nastaliq 611 — and the app's surah->page
    // and juz->page tables are the Madinah 604-page layout's. On those three,
    // picking «سورة يوسف» jumps to Madinah page 235, which in that printing
    // is some other surah entirely. That is the owner's «عدم اتساق بين اسم
    // السورة اللي بختاره والسورة اللي بتطلع على الشاشة فعليا». The running header is
    // already hidden on them for the same reason; the two indexes that would
    // navigate wrong are withheld here rather than silently missing.
    final canIndexBySurah = edition?.hafsPagination ?? true;
    // A recitation does not carry on into an image page (see
    // `_toggleContinuousRecitation`): switching to the image mode, or to a
    // scanned printing, while it runs ends it.
    if (_recite.active && (_mode == MushafMode.image || isRaster)) {
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
              // In landscape the title row is 56 of the 393 logical pixels the
              // whole screen has, spent restating which tab you are on — the
              // nav bar below already shows Qur'an selected. Collapsing it
              // leaves only the toolbar in the app-bar slot.
              toolbarHeight: _toolbarLandscape(context) ? 0 : null,
              title: _toolbarLandscape(context)
                  ? null
                  : Text('nav.quran'.tr()),
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
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        _toolbarLandscape(context)
                            ? ToolbarAction.compactHeight + 8
                            : 116,
                      ),
                      // The bar is toggled by tapping the page, and it used
                      // to blink in and out between two frames. It fades and
                      // lifts now — the owner asked for it to be animated and
                      // to look like something.
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_toolbarLandscape(context)),
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * -8),
                            child: child,
                          ),
                        ),
                        child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: _ToolbarStrip(
                          compact: _toolbarLandscape(context),
                          children: [
                            if (_mode == MushafMode.text && !isRaster) ...[
                              // Three verse layouts now, all of them real
                              // reading preferences, so this cycles rather
                              // than flips — and it is labelled with the one
                              // it will GIVE you, not the one you are in.
                              ToolbarAction(
                                icon: switch (ref
                                    .read(quranTextLayoutProvider.notifier)
                                    .next) {
                                  QuranTextLayout.page =>
                                    Icons.article_rounded,
                                  QuranTextLayout.cards =>
                                    Icons.view_agenda_rounded,
                                  QuranTextLayout.reading =>
                                    Icons.chrome_reader_mode_rounded,
                                },
                                label: switch (ref
                                    .read(quranTextLayoutProvider.notifier)
                                    .next) {
                                  QuranTextLayout.page =>
                                    'quran.layout_page'.tr(),
                                  QuranTextLayout.cards =>
                                    'quran.layout_cards'.tr(),
                                  QuranTextLayout.reading =>
                                    'quran.layout_reading'.tr(),
                                },
                                onPressed: () => ref
                                    .read(quranTextLayoutProvider.notifier)
                                    .toggle(),
                              ),
                              ToolbarAction(
                                icon: Icons.text_decrease_rounded,
                                label: 'quran.font_smaller'.tr(),
                                onPressed: () => _changeFontScale(-0.1),
                              ),
                              ToolbarAction(
                                icon: Icons.text_increase_rounded,
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
                            // Continuous recitation lives in the text mushaf
                            // only, in every layout and theme — «شيل التلاوة
                            // المستمرة خالص من المصحف المصوّر». The Tajweed
                            // printing highlighted 4:3 on page 77 a line low,
                            // so the image page does not offer it at all.
                            if (_mode == MushafMode.text && !isRaster)
                            ToolbarAction(
                              icon: _recite.active
                                  ? Icons.stop_circle_rounded
                                  : Icons.headphones_rounded,
                              label: _recite.active
                                  ? 'quran.recite_stop'.tr()
                                  : 'quran.recite_continuous'.tr(),
                              onPressed: () =>
                                  _toggleContinuousRecitation(mushaf.value!),
                            ),
                            // The paper. It lived only in Settings, four taps
                            // and a different tab away from the page whose
                            // colour it changes — which is why the owner
                            // reported the app had no black reading page while
                            // shipping five of them. Khatmah puts it behind a
                            // gear on the reading screen itself; so do we.
                            // Text mushaf only: «شيل ثيمات المصحف النصي من
                            // المصحف المصوّر» — it recolours a page the image
                            // mode does not draw.
                            if (_mode == MushafMode.text && !isRaster)
                            Builder(
                              builder: (tileContext) => ToolbarAction(
                                icon: Icons.palette_outlined,
                                label: 'mushaf_theme.title'.tr(),
                                onPressed: () => MushafThemePicker.show(
                                  context,
                                  origin: tileContext,
                                ),
                              ),
                            ),
                            // P3‑43 #6: moved out of the text-only block above —
                            // full-screen reading is a real, useful mode for the
                            // image mushaf too, not just the text one.
                            ToolbarAction(
                              icon: _pageFillScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              label: _pageFillScreen
                                  ? 'quran.page_fit_small'.tr()
                                  : 'quran.page_fit_full'.tr(),
                              onPressed: _togglePageFillScreen,
                            ),
                            ToolbarAction(
                              icon: Icons.travel_explore_rounded,
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
                            if (canIndexBySurah)
                            ToolbarAction(
                              icon: Icons.format_list_bulleted_rounded,
                              label: 'quran.surah_list'.tr(),
                              onPressed: () => showSurahSheet(
                                context,
                                surahs: mushaf.value!.surahs,
                                startPages: mushaf.value!.surahStartPages,
                                onSelect: (page) => _navigateFromIndex(
                                  page,
                                  mushaf.value!,
                                  surahStart: true,
                                ),
                              ),
                            ),
                            if (canIndexBySurah)
                            ToolbarAction(
                              icon: Icons.layers_rounded,
                              label: 'quran.juz'.tr(),
                              onPressed: () => showJuzSheet(
                                context,
                                juzStartPages: mushaf.value!.juzStartPages,
                                onSelect: (page) => _navigateFromIndex(page, mushaf.value!),
                              ),
                            ),
                            ToolbarAction(
                              icon: Icons.numbers_rounded,
                              label: 'quran.jump_to'.tr(),
                              // «خلي زر الانتقال يديني خيارات إلى سورة أو
                              // صفحة أو جزء مباشرة».
                              onPressed: () => showJumpSheet(
                                context,
                                surahs: canIndexBySurah
                                    ? mushaf.value!.surahs
                                    : const [],
                                surahStartPages: mushaf.value!.surahStartPages,
                                juzStartPages: mushaf.value!.juzStartPages,
                                current: _current,
                                totalPages: _totalPages,
                                onSurahPage: (page) => _navigateFromIndex(
                                  page,
                                  mushaf.value!,
                                  surahStart: true,
                                ),
                                onPage: (page) =>
                                    _navigateFromIndex(page, mushaf.value!),
                              ),
                            ),
                            ToolbarAction(
                              icon: Icons.auto_stories_rounded,
                              label: 'quran.editions'.tr(),
                              onPressed: _pickEdition,
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
                                  ? Icons.image_rounded
                                  : Icons.notes_rounded,
                              label: (_mode == MushafMode.text && !isRaster)
                                  ? 'quran.mushaf_mode'.tr()
                                  : 'quran.text_mode'.tr(),
                              onPressed: () {
                                if (isRaster) {
                                  ref
                                      .read(selectedMushafEditionProvider
                                          .notifier)
                                      .select(AppConfig.defaultMushafEdition);
                                  _leaveImageView();
                                } else if (_mode == MushafMode.text) {
                                  _enterImageView();
                                } else {
                                  _leaveImageView();
                                }
                              },
                            ),
                          ],
                        ),
                        ),
                      ),
                    )
                  : null,
            ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          _syncOrientationFullScreen(orientation);
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
                    // Landscape floats the page badge over the page (the bar
                    // that used to carry it is gone, see below), so the text
                    // has to stop short of it or the last line runs underneath
                    // the number — which is what the first attempt at this
                    // shipped to the emulator.
                    bottom: _pageFillScreen
                        ? (isLandscape ? 36 : 56)
                        : (isLandscape ? 34 : 0),
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
                  // Image mode only. The text page already carries its own
                  // pinned header and a banner for every surah it opens, so a
                  // third copy in the corner was «متكرر سورة الرعد ٣ مرات».
                  // «في وضع المصحف شيل اسم السورة واسم الجزء واعتمد على اللي
                  // موجودين في صفحة المصحف المصوّر». A printing whose page
                  // prints them gets neither badge; one that does not (the
                  // vector Hafs pages) keeps both. The text page has its own
                  // header, so it keeps only the juz.
                  surahName: (edition?.hafsPagination ?? true) &&
                          (_mode == MushafMode.image || isRaster) &&
                          !(edition?.printedHeader ?? false)
                      ? _currentSurahName(data)
                      : null,
                  juzNumber: (edition?.hafsPagination ?? true) &&
                          !((_mode == MushafMode.image || isRaster) &&
                              (edition?.printedHeader ?? false))
                      ? _currentJuzNumber(data)
                      : null,
                  // Landscape drops the page-number bar under the text, so
                  // the number has to live here instead of nowhere.
                  pageNumber: (_pageFillScreen || isLandscape) ? _current : null,
                ),
                // P3‑54: a translucent floating "exit immersive" button — the
                // always-visible, discoverable way back out (alongside the
                // double-tap gesture), since in full-screen the toolbar that
                // toggled the mode is itself off-screen. Only present while
                // full-screen; a plain SafeArea-aligned button, not an
                // `IgnorePointer` overlay, so it actually receives its own taps.
                // Not in landscape: the options live in portrait only.
                if (_pageFillScreen && !isLandscape)
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
                    if (_recite.active)
                      _ReciteBar(
                        state: _recite,
                        reciterName: _reciterName(),
                        onPickReciter: _pickReciter,
                      ),
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
                    //
                    // Not in landscape: it costs about 60 logical pixels of a
                    // 393-pixel screen to show a number the running header
                    // already carries, and those pixels are the difference
                    // between a page of Qur'an and none.
                    if (!_toolbarLandscape(context)) ...[
                      Center(child: _PageNumberBadge(page: _current)),
                      const SizedBox(height: 6),
                    ],
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
              // The selected verse stays marked after its card closes, as it
              // does on the image page, so the owner can see where the
              // continuous recitation will start from.
              playingSurah: _recite.active ? _recite.surahId : _highlightSurah,
              playingAyah: _recite.active ? _recite.ayahNumber : _highlightAyah,
              onAyahLongPress: (a) => _openSciences(a, data),
              // `edition:` here is the RECITER, not the mushaf. It used to
              // be handed `edition?.id ?? 'hafs_kfqc'` — a *mushaf* printing
              // id — so every verse resolved to
              // `cdn.islamic.network/quran/audio/128/hafs_kfqc/<n>.mp3`,
              // which 404s; `setAudioSource` threw, the catch called
              // `stopContinuous()`, and picking a verse stopped the
              // recitation instead of moving it. That is the owner's
              // «واجي اختار آية … بتقف التلاوة مش بتشتغل».
              // The verse's own marker plays that one verse — separate from the
              // continuous recitation, which only the toolbar starts.
              onPlayTap: (a) => AyahAudioService.instance.play(
                a,
                data.repo,
                edition: ref.read(selectedReciterProvider),
              ),
              fontScale: _fontScale,
              autoScroll: _autoScroll,
              autoScrollSpeed: _autoScrollSpeed,
              isActive: page == _current,
              onAutoScrollReachedEnd: _onAutoScrollReachedEnd,
              onBackgroundTap: _onPageTap,
              onReadingScroll: _onReadingScroll,
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

/// The compact transport shown under the page while continuous recitation is
/// running: which verse is sounding, and the three controls a listener
/// actually reaches for.
class _ReciteBar extends StatelessWidget {
  final ContinuousRecitation state;
  final String reciterName;
  final VoidCallback onPickReciter;
  const _ReciteBar({
    required this.state,
    required this.reciterName,
    required this.onPickReciter,
  });

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
                state.stalled
                    ? Icons.play_circle_outline_rounded
                    : state.buffering
                        ? Icons.hourglass_top_rounded
                        : Icons.graphic_eq_rounded,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.stalled
                      ? 'quran.recite_stalled'.tr()
                      : state.buffering
                      ? 'quran.recite_loading'.tr()
                      : 'quran.recite_now'.tr(
                          args: [
                            '${state.surahId ?? ''}',
                            '${state.ayahNumber ?? ''}',
                          ],
                        ) + (reciterName.isEmpty ? '' : '  ·  $reciterName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_choose_reciter'.tr(),
                icon: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.gold),
                onPressed: onPickReciter,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'quran.recite_previous'.tr(),
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: audio.continuousPrevious,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: (state.stalled
                        ? 'quran.recite_resume'
                        : 'quran.recite_pause')
                    .tr(),
                icon: Icon(state.stalled
                    ? Icons.play_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded),
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
                      _HeaderBadge(
                          text: '${'quran.juz'.tr()} ${_arabicNumber(juzNumber!)}'),
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

/// A mushaf page number, always in Arabic-Indic digits — every printing sets
/// them that way, whatever language the app is in. The conversion itself
/// comes from `core/utils/digits.dart`; this was the fifth copy of it.
String _arabicNumber(int n) => localizeDigits('$n', 'ar');

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


/// The Qur'an toolbar's two shapes.
///
/// Portrait keeps the captioned `Wrap` — every action visible at once, which
/// is what P3‑41's device feedback asked for. Landscape cannot afford it (see
/// the `bottom:` comment above), so the same actions become one compact,
/// horizontally-scrolling row.
///
/// The children arrive as ordinary [ToolbarAction]s and are rebuilt compact
/// here rather than each of the thirteen call sites having to pass a flag —
/// a flag that would then be possible to forget on the fourteenth.
class _ToolbarStrip extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const _ToolbarStrip({required this.compact, required this.children});

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 0,
        children: children,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in children)
            if (child is ToolbarAction)
              ToolbarAction(
                icon: child.icon,
                label: child.label,
                onPressed: child.onPressed,
                active: child.active,
                compact: true,
              )
            else
              child,
        ],
      ),
    );
  }
}
