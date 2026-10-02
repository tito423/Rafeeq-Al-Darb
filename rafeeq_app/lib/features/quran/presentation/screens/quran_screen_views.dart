part of 'quran_screen.dart';

/// What the Qur'an tab draws for a page, kept apart from the screen's state
/// handling: a text page, the reading layout's continuous scroll, the
/// running surah/juz labels and the image page's long press. Moved here on
/// 2026-10-02 when the continuous view was added, so `quran_screen.dart`
/// shrinks instead of growing past its ceiling (`code_layout_test.dart`).
extension _QuranViews on _QuranScreenState {
  /// A surah picked by name in the continuous view lands on its own banner,
  /// not on the top of the page it shares with the surah before it. False
  /// when this is not the continuous view; the caller turns the page.
  /// (The page reached is saved by `_onScrolledToPage`.)
  bool _continuousToSurah(int page, int? surahId) {
    final continuous = _continuous.currentState;
    if (!_isContinuous || continuous == null || surahId == null) return false;
    continuous.jumpToPage(page, mark: continuousSurahMark(surahId));
    return true;
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

  /// One text page — on its own in the `PageView`, or [embedded] in the
  /// reading layout's continuous scroll.
  Widget _textPage(
    int page,
    List<Ayah> ayahs,
    MushafData data,
    QuranTextLayout textLayout, {
    bool embedded = false,
  }) {
    final mushafTheme = resolveMushafTheme(
      ref.watch(mushafThemeProvider),
      Theme.of(context).brightness,
    );
    final frame = ref.watch(mushafFrameProvider);
    return MushafTextPage(
      embedded: embedded,
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
      playingBasmalaSurah: _recite.basmala ? _recite.surahId : null,
      onAyahLongPress: (a) => _openSciences(a, data),
      // `edition:` is the RECITER, not the mushaf. Handed a printing
      // id (`hafs_kfqc`) every verse URL 404'd, `setAudioSource`
      // threw and the recitation stopped: «بتقف التلاوة مش بتشتغل».
      // The verse's own marker plays that one verse — separate from the
      // continuous recitation, which only the toolbar starts.
      onPlayTap: (a) => AyahAudioService.instance.play(
        a,
        data.repo,
        edition: ref.read(selectedReciterProvider),
      ),
      fontScale: _fontScale,
      // Embedded pages do not scroll; the continuous view does.
      autoScroll: !embedded &&
          _autoScroll &&
          !(_recite.active && !_recite.stalled),
      autoScrollSpeed: _autoScrollSpeed,
      isActive: embedded || page == _current,
      onAutoScrollReachedEnd: _onAutoScrollReachedEnd,
      onBackgroundTap: _onPageTap,
      onReadingScroll: _onReadingScroll,
      pageFillScreen: _pageFillScreen,
    );
  }

  /// The reading layout: the whole mushaf as one scroll, no page turns.
  Widget _buildContinuous(MushafData data, QuranTextLayout textLayout) {
    // The `PageView` and its controller are gone while this shows; a fresh
    // one starts at the page the reader scrolled to when they come back.
    final old = _pages;
    if (old != null) {
      _pages = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final mt = resolveMushafTheme(
      ref.watch(mushafThemeProvider),
      Theme.of(context).brightness,
    );
    return MushafRemoteKeys(
      onTurn: (d) => _goToPage(_current + d),
      onSelect: _onPageTap,
      child: ContinuousMushafView(
        key: _continuous,
        firstPage: 1,
        lastPage: _totalPages,
        initialPage: _current,
        ayahsOf: (page) => _ayahsOfPage(page, data),
        ayahsIfLoaded: data.repo.pageIfLoaded,
        background: mt.paper,
        ruleColor: mt.gold,
        autoScroll: _autoScroll && !(_recite.active && !_recite.stalled),
        autoScrollSpeed: _autoScrollSpeed,
        onAutoScrollReachedEnd: _stopAutoScroll,
        onReadingScroll: _onReadingScroll,
        onBackgroundTap: _onPageTap,
        onPageChanged: _onScrolledToPage,
        pageBuilder: (context, page, ayahs) =>
            _textPage(page, ayahs, data, textLayout, embedded: true),
      ),
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
