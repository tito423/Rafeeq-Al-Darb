import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/models.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../data/ayah_coords_repository.dart';
import '../../data/mushaf_data_provider.dart';
import '../../data/mushaf_edition.dart';
import '../../data/quran_jump_provider.dart';
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

  Future<void> _persistPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_page', _current);
  }

  Future<void> _persistMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reader_mode', _mode.name);
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getInt('quran_last_page') ?? 1;
    final modeName = prefs.getString('quran_reader_mode');
    final fontScale = prefs.getDouble(_kFontScale);
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
    });
  }

  void _changeFontScale(double delta) {
    setState(() => _fontScale = (_fontScale + delta).clamp(0.75, 1.8));
    SharedPreferences.getInstance()
        .then((p) => p.setDouble(_kFontScale, _fontScale));
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

  void _openSciences(Ayah ayah, MushafData data,
      {bool sciencesAvailable = true}) {
    setState(() {
      _highlightSurah = ayah.surahId;
      _highlightAyah = ayah.ayahNumber;
    });
    AyahSciencesSheet.show(
      context,
      ayah: ayah,
      surahNameAr: data.surahNameAr(ayah.surahId),
      quranRepo: data.repo,
      sciencesAvailable: sciencesAvailable,
    );
  }

  Future<List<Ayah>> _ayahsOfPage(int page, MushafData data) =>
      _pageFutures.putIfAbsent(page, () => data.repo.ayahsOfPage(page));

  String? _surahHeaderIdForPage(int page, Map<int, int> startPages) {
    for (final e in startPages.entries) {
      if (e.value == page) return e.key.toString();
    }
    return null;
  }

  AyahRegion? _highlightRegion(String editionId, int page) {
    if (_highlightSurah == null || _current != page) return null;
    for (final r in _coords.regionsForPage(editionId, page)) {
      if (r.surah == _highlightSurah && r.ayah == _highlightAyah) return r;
    }
    return null;
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
            () => ref.read(quranJumpRequestProvider.notifier).state = null);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('nav.quran'.tr()),
        actions: [
          if (mushaf.hasValue) ...[
            if (_mode == MushafMode.text) ...[
              IconButton(
                tooltip: 'quran.font_smaller'.tr(),
                icon: const Icon(Icons.text_decrease),
                onPressed: () => _changeFontScale(-0.1),
              ),
              IconButton(
                tooltip: 'quran.font_larger'.tr(),
                icon: const Icon(Icons.text_increase),
                onPressed: () => _changeFontScale(0.1),
              ),
            ],
            IconButton(
              tooltip: 'search.title'.tr(),
              icon: const Icon(Icons.travel_explore_outlined),
              onPressed: () async {
                final page = await Navigator.of(context).push<int>(
                  MaterialPageRoute<int>(
                    builder: (_) => SearchScreen(repo: mushaf.value!.repo),
                  ),
                );
                if (page != null) _goToPage(page);
              },
            ),
            IconButton(
              tooltip: 'quran.surah_list'.tr(),
              icon: const Icon(Icons.format_list_numbered),
              onPressed: () => showSurahSheet(
                context,
                surahs: mushaf.value!.surahs,
                startPages: mushaf.value!.surahStartPages,
                onSelect: _goToPage,
              ),
            ),
            IconButton(
              tooltip: 'quran.juz'.tr(),
              icon: const Icon(Icons.filter_9_plus),
              onPressed: () => showJuzSheet(
                context,
                juzStartPages: mushaf.value!.juzStartPages,
                onSelect: _goToPage,
              ),
            ),
            IconButton(
              tooltip: 'quran.jump_to'.tr(),
              icon: const Icon(Icons.pin_drop_outlined),
              onPressed: () => showGotoPageSheet(
                context,
                current: _current,
                onSelect: _goToPage,
              ),
            ),
            IconButton(
              tooltip: 'quran.editions'.tr(),
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: () => MushafEditionSheet.show(context),
            ),
            IconButton(
              tooltip: _mode == MushafMode.text
                  ? 'quran.mushaf_mode'.tr()
                  : 'quran.text_mode'.tr(),
              icon: Icon(_mode == MushafMode.text
                  ? Icons.image_outlined
                  : Icons.notes),
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
          const SizedBox(width: 4),
        ],
      ),
      body: mushaf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('errors.generic'.tr())),
        data: (data) => _buildViewer(data, ref.watch(
            currentMushafEditionProvider).valueOrNull),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _current > 1 ? () => _goToPage(_current - 1) : null,
              ),
              Text(
                '${'quran.page'.tr()}  $_current / $_totalPages',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
            final headerId = _surahHeaderIdForPage(page, data.surahStartPages);
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
                onLoadFailed: () =>
                    setState(() => _mode = MushafMode.text),
              );
            }
            return MushafTextPage(
              ayahs: ayahs,
              surahHeader: headerId == null
                  ? null
                  : (int.parse(headerId),
                      data.surahNameAr(int.parse(headerId))),
              onAyahTap: (a) => _openSciences(a, data),
              fontScale: _fontScale,
            );
          },
        );
      },
    );
  }

  void _onImageAyahTap(AyahRegion region, List<Ayah> ayahs, MushafData data,
      MushafEdition edition) {
    for (final ayah in ayahs) {
      if (ayah.surahId == region.surah && ayah.ayahNumber == region.ayah) {
        _openSciences(ayah, data,
            sciencesAvailable: edition.sciencesAvailableFor(region.surah));
        return;
      }
    }
  }
}
