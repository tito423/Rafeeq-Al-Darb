import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../khatma/presentation/khatma_card.dart' show HomeNavigate;
import '../../data/mushaf_data_provider.dart';
import '../../data/quran_jump_provider.dart';
import '../../data/quran_last_read.dart';

/// P3‑4: "متابعة القراءة" (Continue Reading) — its own Home card, split out
/// of the Khatma card it used to be folded into. The owner's reference
/// (`design_refs/round2_2026-09-04/ref_home_v2.jpg`) shows it as a
/// separate resume-reading nudge, distinct from the khatma daily-goal
/// card below it — bookmark-style ("where you left off"), not tied to any
/// khatma's progress.
///
/// Built on real data only: `quran_screen.dart` already persists the
/// reader's last-open page (`kQuranLastPageKey`) every time it changes —
/// this card reads that same value and resolves the real first ayah on
/// that page (`data.repo.ayahsOfPage`) for the surah name + ayah number,
/// rather than inventing a page-1 default. If the key has never been set
/// (a fresh install, Quran tab never opened), the card renders nothing —
/// an honest "there's nothing to continue yet" rather than a fabricated
/// "الفاتحة · آية 1" every guest would otherwise see identically.
class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPage = ref.watch(quranLastPageProvider);
    if (lastPage == null) return const SizedBox.shrink();

    final mushaf = ref.watch(mushafDataProvider);
    return mushaf.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (lastPage < 1 || lastPage > 604) return const SizedBox.shrink();
        return _ContinueReadingBody(page: lastPage, data: data);
      },
    );
  }
}

class _ContinueReadingBody extends ConsumerStatefulWidget {
  final int page;
  final MushafData data;
  const _ContinueReadingBody({required this.page, required this.data});

  @override
  ConsumerState<_ContinueReadingBody> createState() =>
      _ContinueReadingBodyState();
}

class _ContinueReadingBodyState extends ConsumerState<_ContinueReadingBody> {
  late Future<List<Ayah>> _ayahs;

  @override
  void initState() {
    super.initState();
    _ayahs = widget.data.repo.ayahsOfPage(widget.page);
  }

  @override
  void didUpdateWidget(covariant _ContinueReadingBody old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _ayahs = widget.data.repo.ayahsOfPage(widget.page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ayah>>(
      future: _ayahs,
      builder: (context, snap) {
        final first = snap.data?.firstOrNull;
        if (first == null) return const SizedBox.shrink();
        final surah = widget.data.surahs
            .where((s) => s.id == first.surahId)
            .firstOrNull;
        if (surah == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final gold = AppColors.gold;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ref.read(quranJumpRequestProvider.notifier).state = widget.page;
              HomeNavigate.of(context)?.call(1);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: gold, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('home.continue_reading_title'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(surah.nameAr, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${'quran.ayah'.tr()} ${first.ayahNumber} · '
                          '${'quran.page'.tr()} ${widget.page}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
