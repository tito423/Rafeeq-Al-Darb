import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/services/ayah_audio_service.dart';
import '../../../core/widgets/error_retry.dart';
import '../../downloads/data/reciters_provider.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/mushaf_edition.dart';
import '../../quran/data/mushaf_frame.dart';
import '../../quran/data/mushaf_theme.dart';
import '../../quran/data/text_layout_provider.dart';
import '../../quran/presentation/widgets/ayah_sciences_sheet.dart';
import '../../quran/presentation/widgets/mushaf_page_view.dart';
import '../../quran/presentation/widgets/mushaf_text_page.dart';
import '../../quran/presentation/widgets/mushaf_theme_picker.dart';

enum _Mode { text, image }

/// P2‑12's "locked reader" — the same page rendering as `QuranScreen`
/// (`MushafTextPage`/`MushafPageView`), but bounded to a single surah's real
/// page range (resolved from `mushafDataProvider.surahStartPages`, never
/// hardcoded) with every whole-mushaf navigation affordance removed:
/// no surah/juz list, no goto-page, no edition picker, and the `PageView`
/// itself cannot page past the surah's own first/last page.
///
/// **It now carries the full set of text-mushaf options**, which the owner
/// asked for twice: full-screen, auto-scroll, recitation with verse
/// highlighting, the cards/flowing layout switch, font size, and the theme +
/// frame picker. Before this it had only the font buttons and the text/image
/// toggle, so choosing the text mushaf here dropped the reader into a much
/// poorer reader than the one on the Qur'an tab.
///
/// Everything stays **locked to the surah**. In particular the recitation is
/// started with `wholeMushaf: false`, so the voice stops at the surah's last
/// verse instead of reading on into the next one — the same boundary the
/// `PageView` enforces visually.
class SingleSurahScreen extends ConsumerStatefulWidget {
  final int surahId;
  const SingleSurahScreen({super.key, required this.surahId});

  @override
  ConsumerState<SingleSurahScreen> createState() => _SingleSurahScreenState();
}

class _SingleSurahScreenState extends ConsumerState<SingleSurahScreen> {
  _Mode _mode = _Mode.text;
  double _fontScale = 1.0;
  PageController? _pages;
  int _current = 0;
  final Map<int, Future<List<Ayah>>> _pageFutures = {};

  bool _fullScreen = false;
  bool _autoScroll = false;
  double _autoScrollSpeed = 40;
  bool _toolbarVisible = true;

  ContinuousRecitation _recite = ContinuousRecitation.stopped;

  /// The surah's own page bounds, filled in on the first build. Held as state
  /// so the recitation follower can turn pages without re-deriving them.
  int _startPage = 1;
  int _endPage = 1;

  @override
  void initState() {
    super.initState();
    AyahAudioService.instance.continuous.addListener(_onReciteChanged);
  }

  @override
  void dispose() {
    AyahAudioService.instance.continuous.removeListener(_onReciteChanged);
    // Leaving must never leave a recitation sounding, nor the system bars
    // hidden, behind this screen.
    if (_recite.active) unawaited(AyahAudioService.instance.stopContinuous());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pages?.dispose();
    super.dispose();
  }

  void _onReciteChanged() {
    if (!mounted) return;
    final state = AyahAudioService.instance.continuous.value;
    setState(() => _recite = state);
    if (!state.active) return;
    final surah = state.surahId;
    final ayah = state.ayahNumber;
    if (surah == null || ayah == null) return;
    unawaited(_followRecitationTo(surah, ayah));
  }

  /// Turns the page to keep up with the voice — but never outside this
  /// surah's own range.
  Future<void> _followRecitationTo(int surah, int ayah) async {
    final repo = ref.read(mushafDataProvider).valueOrNull?.repo;
    if (repo == null) return;
    final row = await repo.ayah(surah, ayah);
    if (!mounted || row == null) return;
    final page = row.pageNumber;
    if (page < _startPage || page > _endPage || page == _current) return;
    _pages?.animateToPage(
      page - _startPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _toggleFullScreen() {
    final entering = !_fullScreen;
    setState(() {
      _fullScreen = entering;
      // Same rule the Qur'an reader follows: leaving full-screen also stops
      // the hands-free scroll, so no exit path can leave one running behind
      // the normal reader.
      if (!entering) _autoScroll = false;
      _toolbarVisible = true;
    });
    SystemChrome.setEnabledSystemUIMode(
      entering ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _onBackgroundTap() {
    if (_fullScreen) {
      _setAutoScroll(!_autoScroll);
    } else {
      setState(() => _toolbarVisible = !_toolbarVisible);
    }
  }

  void _setAutoScroll(bool on) => setState(() => _autoScroll = on);

  /// Auto-scroll reached the bottom of a page: turn to the next one, unless
  /// this was the surah's last page — where there is honestly nowhere to go.
  void _onAutoScrollReachedEnd() {
    if (_current >= _endPage) {
      setState(() => _autoScroll = false);
      return;
    }
    _pages?.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleRecitation(MushafData data) async {
    final audio = AyahAudioService.instance;
    if (_recite.active) {
      await audio.stopContinuous();
      return;
    }
    final ayahs = await _pageFutures[_current];
    if (ayahs == null || ayahs.isEmpty || !mounted) return;
    // Start at the first verse of this page that belongs to *this* surah, so
    // a page shared with the previous surah does not start the reader off in
    // the wrong one.
    final start = ayahs.firstWhere(
      (a) => a.surahId == widget.surahId,
      orElse: () => ayahs.first,
    );
    await audio.startContinuous(
      from: start,
      repo: data.repo,
      edition: ref.read(selectedReciterProvider),
      // The whole point of this screen: stop at the surah's end.
      wholeMushaf: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafDataProvider);
    final edition = ref.watch(currentMushafEditionProvider).valueOrNull;
    final textLayout = ref.watch(quranTextLayoutProvider);

    return mushaf.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
      ),
      data: (data) {
        final startPage = data.surahStartPages[widget.surahId];
        if (startPage == null) {
          return Scaffold(body: Center(child: Text('errors.generic'.tr())));
        }
        final nextStart = data.surahStartPages[widget.surahId + 1];
        final endPage = (nextStart ?? 605) - 1;
        final pageCount = endPage - startPage + 1;
        _startPage = startPage;
        _endPage = endPage;
        _current = _current == 0 ? startPage : _current;
        _pages ??= PageController(initialPage: _current - startPage);

        final isText = _mode == _Mode.text;
        final showChrome = !_fullScreen && _toolbarVisible;

        return Scaffold(
          appBar: showChrome
              ? AppBar(
                  title: Text(data.surahNameAr(widget.surahId)),
                  actions: [
                    if (isText) ...[
                      IconButton(
                        tooltip: 'quran.font_smaller'.tr(),
                        icon: const Icon(Icons.text_decrease),
                        onPressed: () => setState(
                          () => _fontScale =
                              (_fontScale - 0.1).clamp(0.75, 1.8),
                        ),
                      ),
                      IconButton(
                        tooltip: 'quran.font_larger'.tr(),
                        icon: const Icon(Icons.text_increase),
                        onPressed: () => setState(
                          () => _fontScale =
                              (_fontScale + 0.1).clamp(0.75, 1.8),
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: isText
                          ? 'quran.mushaf_mode'.tr()
                          : 'quran.text_mode'.tr(),
                      icon: Icon(
                        isText ? Icons.image_outlined : Icons.notes,
                      ),
                      onPressed: () => setState(
                        () => _mode = isText ? _Mode.image : _Mode.text,
                      ),
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            top: !_fullScreen,
            bottom: !_fullScreen,
            child: PageView.builder(
              controller: _pages,
              onPageChanged: (i) => setState(() => _current = startPage + i),
              itemCount: pageCount,
              itemBuilder: (context, i) {
                final page = startPage + i;
                return FutureBuilder<List<Ayah>>(
                  future: _pageFutures.putIfAbsent(
                    page,
                    () => data.repo.ayahsOfPage(page),
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final ayahs = snap.data!;
                    if (!isText) {
                      if (edition == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return MushafPageView(
                        edition: edition,
                        page: page,
                        highlight: null,
                        onBackgroundTap: _onBackgroundTap,
                        onAyahTap: (region) {
                          for (final a in ayahs) {
                            if (a.surahId == region.surah &&
                                a.ayahNumber == region.ayah) {
                              _openSciences(a, data, edition);
                              return;
                            }
                          }
                        },
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
                      onAyahTap: (a) => _openSciences(a, data, edition),
                      onPlayTap: (a) => AyahAudioService.instance
                          .startContinuous(
                        from: a,
                        repo: data.repo,
                        edition: ref.read(selectedReciterProvider),
                        wholeMushaf: false,
                      ),
                      playingSurah: _recite.active ? _recite.surahId : null,
                      playingAyah: _recite.active ? _recite.ayahNumber : null,
                      fontScale: _fontScale,
                      autoScroll: _autoScroll,
                      autoScrollSpeed: _autoScrollSpeed,
                      isActive: page == _current,
                      onAutoScrollReachedEnd: _onAutoScrollReachedEnd,
                      onBackgroundTap: _onBackgroundTap,
                      pageFillScreen: _fullScreen,
                      onExitFullScreen:
                          _fullScreen ? _toggleFullScreen : null,
                    );
                  },
                );
              },
            ),
          ),
          floatingActionButton: _fullScreen
              ? FloatingActionButton.small(
                  tooltip: 'quran.page_fit_small'.tr(),
                  onPressed: _toggleFullScreen,
                  child: const Icon(Icons.fullscreen_exit),
                )
              : null,
          bottomNavigationBar: showChrome
              ? _ReaderBar(
                  isText: isText,
                  current: _current,
                  startPage: startPage,
                  endPage: endPage,
                  pageCount: pageCount,
                  reciting: _recite.active,
                  autoScroll: _autoScroll,
                  autoScrollSpeed: _autoScrollSpeed,
                  layout: textLayout,
                  onPrev: _current > startPage
                      ? () => _pages!.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  onNext: _current < endPage
                      ? () => _pages!.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  onToggleRecite: () => _toggleRecitation(data),
                  onToggleAutoScroll: () => _setAutoScroll(!_autoScroll),
                  onSpeed: (v) => setState(() => _autoScrollSpeed = v),
                  onFullScreen: _toggleFullScreen,
                  onLayout: () => ref
                      .read(quranTextLayoutProvider.notifier)
                      .toggle(),
                  onThemes: (origin) =>
                      MushafThemePicker.show(context, origin: origin),
                )
              : null,
        );
      },
    );
  }

  void _openSciences(Ayah ayah, MushafData data, MushafEdition? edition) {
    AyahSciencesSheet.show(
      context,
      ayah: ayah,
      surahNameAr: data.surahNameAr(ayah.surahId),
      quranRepo: data.repo,
      sciencesAvailable: edition?.sciencesAvailableFor(ayah.surahId) ?? true,
    );
  }
}

/// The reading controls, in the same order the Qur'an tab puts them so moving
/// between the two readers does not mean relearning the bar.
class _ReaderBar extends StatelessWidget {
  final bool isText;
  final int current;
  final int startPage;
  final int endPage;
  final int pageCount;
  final bool reciting;
  final bool autoScroll;
  final double autoScrollSpeed;
  final QuranTextLayout layout;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onToggleRecite;
  final VoidCallback onToggleAutoScroll;
  final ValueChanged<double> onSpeed;
  final VoidCallback onFullScreen;
  final VoidCallback onLayout;
  final void Function(BuildContext origin) onThemes;

  const _ReaderBar({
    required this.isText,
    required this.current,
    required this.startPage,
    required this.endPage,
    required this.pageCount,
    required this.reciting,
    required this.autoScroll,
    required this.autoScrollSpeed,
    required this.layout,
    required this.onPrev,
    required this.onNext,
    required this.onToggleRecite,
    required this.onToggleAutoScroll,
    required this.onSpeed,
    required this.onFullScreen,
    required this.onLayout,
    required this.onThemes,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The speed slider only exists while auto-scroll is actually on —
          // a disabled slider sitting there permanently is just clutter.
          if (isText && autoScroll)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 18),
                  Expanded(
                    child: Slider(
                      value: autoScrollSpeed,
                      min: 10,
                      max: 120,
                      onChanged: onSpeed,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrev,
                ),
                if (isText) ...[
                  IconButton(
                    tooltip: 'quran.play'.tr(),
                    icon: Icon(
                      reciting
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color: reciting ? scheme.primary : null,
                    ),
                    onPressed: onToggleRecite,
                  ),
                  IconButton(
                    tooltip: 'quran.auto_scroll'.tr(),
                    icon: Icon(
                      autoScroll
                          ? Icons.pause_circle_outline
                          : Icons.swipe_vertical,
                      color: autoScroll ? scheme.primary : null,
                    ),
                    onPressed: onToggleAutoScroll,
                  ),
                  IconButton(
                    tooltip: 'quran.layout_toggle'.tr(),
                    icon: Icon(
                      layout == QuranTextLayout.page
                          ? Icons.view_agenda_outlined
                          : Icons.article_outlined,
                    ),
                    onPressed: onLayout,
                  ),
                  Builder(
                    builder: (origin) => IconButton(
                      tooltip: 'mushaf_theme.title'.tr(),
                      icon: const Icon(Icons.palette_outlined),
                      onPressed: () => onThemes(origin),
                    ),
                  ),
                ],
                IconButton(
                  tooltip: 'quran.page_fit_full'.tr(),
                  icon: const Icon(Icons.fullscreen),
                  onPressed: onFullScreen,
                ),
                Text(
                  '${'quran.page'.tr()}  ${current - startPage + 1} / $pageCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
