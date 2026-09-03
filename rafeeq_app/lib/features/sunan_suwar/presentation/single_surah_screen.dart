import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../../../core/widgets/error_retry.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/mushaf_edition.dart';
import '../../quran/presentation/widgets/ayah_sciences_sheet.dart';
import '../../quran/presentation/widgets/mushaf_page_view.dart';
import '../../quran/presentation/widgets/mushaf_text_page.dart';

enum _Mode { text, image }

/// P2‑12's "locked reader" — the same page rendering as `QuranScreen`
/// (`MushafTextPage`/`MushafPageView`), but bounded to a single surah's real
/// page range (resolved from `mushafDataProvider.surahStartPages`, never
/// hardcoded) with every whole-mushaf navigation affordance removed:
/// no surah/juz list, no goto-page, no edition picker, and the `PageView`
/// itself cannot page past the surah's own first/last page.
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

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = ref.watch(mushafDataProvider);
    final edition = ref.watch(currentMushafEditionProvider).valueOrNull;

    return mushaf.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
        _current = _current == 0 ? startPage : _current;
        _pages ??= PageController(initialPage: _current - startPage);

        return Scaffold(
          appBar: AppBar(
            title: Text(data.surahNameAr(widget.surahId)),
            actions: [
              if (_mode == _Mode.text) ...[
                IconButton(
                  tooltip: 'quran.font_smaller'.tr(),
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () =>
                      setState(() => _fontScale = (_fontScale - 0.1).clamp(0.75, 1.8)),
                ),
                IconButton(
                  tooltip: 'quran.font_larger'.tr(),
                  icon: const Icon(Icons.text_increase),
                  onPressed: () =>
                      setState(() => _fontScale = (_fontScale + 0.1).clamp(0.75, 1.8)),
                ),
              ],
              IconButton(
                tooltip: _mode == _Mode.text
                    ? 'quran.mushaf_mode'.tr()
                    : 'quran.text_mode'.tr(),
                icon: Icon(_mode == _Mode.text ? Icons.image_outlined : Icons.notes),
                onPressed: () =>
                    setState(() => _mode = _mode == _Mode.text ? _Mode.image : _Mode.text),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pages,
            onPageChanged: (i) => setState(() => _current = startPage + i),
            itemCount: pageCount,
            itemBuilder: (context, i) {
              final page = startPage + i;
              return FutureBuilder<List<Ayah>>(
                future: _pageFutures.putIfAbsent(page, () => data.repo.ayahsOfPage(page)),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ayahs = snap.data!;
                  final headerId = page == startPage ? '${widget.surahId}' : null;
                  if (_mode == _Mode.image) {
                    if (edition == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return MushafPageView(
                      edition: edition,
                      page: page,
                      highlight: null,
                      onAyahTap: (region) {
                        for (final a in ayahs) {
                          if (a.surahId == region.surah && a.ayahNumber == region.ayah) {
                            _openSciences(a, data, edition);
                            return;
                          }
                        }
                      },
                    );
                  }
                  return MushafTextPage(
                    ayahs: ayahs,
                    surahHeader: headerId == null
                        ? null
                        : (widget.surahId, data.surahNameAr(widget.surahId)),
                    onAyahTap: (a) => _openSciences(a, data, edition),
                    fontScale: _fontScale,
                  );
                },
              );
            },
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _current > startPage
                        ? () => _pages!.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut)
                        : null,
                  ),
                  Text(
                    '${'quran.page'.tr()}  ${_current - startPage + 1} / $pageCount',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _current < endPage
                        ? () => _pages!.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut)
                        : null,
                  ),
                ],
              ),
            ),
          ),
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
