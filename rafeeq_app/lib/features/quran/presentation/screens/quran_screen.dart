import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
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
        // P3‑34: the toolbar used to be plain unlabelled IconButtons —
        // moved into a captioned, animated row of its own (`bottom:`,
        // not `actions:`, so it spans the full screen width and can
        // never overflow regardless of how many actions there are or how
        // narrow the device is — it scrolls horizontally instead).
        bottom: mushaf.hasValue
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
                  child: Row(
                    children: [
                      if (_mode == MushafMode.text) ...[
                        _ToolbarAction(
                          icon: Icons.text_decrease,
                          label: 'quran.font_smaller'.tr(),
                          onPressed: () => _changeFontScale(-0.1),
                        ),
                        _ToolbarAction(
                          icon: Icons.text_increase,
                          label: 'quran.font_larger'.tr(),
                          onPressed: () => _changeFontScale(0.1),
                        ),
                      ],
                      _ToolbarAction(
                        icon: Icons.travel_explore_outlined,
                        label: 'search.title'.tr(),
                        onPressed: () async {
                          final page = await Navigator.of(context).push<int>(
                            MaterialPageRoute<int>(
                              builder: (_) =>
                                  SearchScreen(repo: mushaf.value!.repo),
                            ),
                          );
                          if (page != null) _goToPage(page);
                        },
                      ),
                      _ToolbarAction(
                        icon: Icons.format_list_numbered,
                        label: 'quran.surah_list'.tr(),
                        onPressed: () => showSurahSheet(
                          context,
                          surahs: mushaf.value!.surahs,
                          startPages: mushaf.value!.surahStartPages,
                          onSelect: _goToPage,
                        ),
                      ),
                      _ToolbarAction(
                        icon: Icons.filter_9_plus,
                        label: 'quran.juz'.tr(),
                        onPressed: () => showJuzSheet(
                          context,
                          juzStartPages: mushaf.value!.juzStartPages,
                          onSelect: _goToPage,
                        ),
                      ),
                      _ToolbarAction(
                        icon: Icons.pin_drop_outlined,
                        label: 'quran.jump_to'.tr(),
                        onPressed: () => showGotoPageSheet(
                          context,
                          current: _current,
                          onSelect: _goToPage,
                        ),
                      ),
                      _ToolbarAction(
                        icon: Icons.auto_stories_outlined,
                        label: 'quran.editions'.tr(),
                        onPressed: () => MushafEditionSheet.show(context),
                      ),
                      _ToolbarAction(
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
        error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
        data: (data) => _buildViewer(data, ref.watch(
            currentMushafEditionProvider).valueOrNull),
      ),
      bottomNavigationBar: SafeArea(
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
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _current > 1 ? () => _goToPage(_current - 1) : null,
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToCurrent(animate: false));
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
    final target = (_currentIndex * _itemWidth - 140)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
                onTap: () =>
                    widget.onSelect(widget.surahStartPages[s.id] ?? 1),
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

/// P3‑34: one toolbar action — icon + a short caption underneath, with a
/// small scale-down "press" animation instead of a plain flat `IconButton`.
/// Each label reuses the exact same string already used as that action's
/// tooltip, so nothing new was translated — just made visible instead of
/// hover/long-press-only.
class _ToolbarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<_ToolbarAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 22, color: scheme.onSurface),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
