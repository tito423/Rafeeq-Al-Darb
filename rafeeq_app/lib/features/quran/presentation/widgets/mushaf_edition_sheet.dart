import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../data/mushaf_edition.dart';
import 'quran_book_cover_thumbnail.dart';

/// Picker for the printed mushaf being read.
///
/// The preview is the edition's real first page, rendered from the very file
/// the reader will page through — so the thumbnail cannot misrepresent the
/// mushaf, and no separate cover images need shipping.
class MushafEditionSheet extends ConsumerWidget {
  const MushafEditionSheet({super.key});

  /// Returns the id of the printing picked, or null when dismissed.
  static Future<String?> show(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const MushafEditionSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final editions = ref.watch(mushafEditionsProvider);
    final selectedId = ref.watch(selectedMushafEditionProvider);

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'quran.choose_edition'.tr(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: editions.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      ErrorRetry(onRetry: () => ref.invalidate(mushafEditionsProvider)),
                  data: (list) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _EditionTile(
                      edition: list[i],
                      selected: list[i].id == selectedId,
                      onTap: () {
                        ref
                            .read(selectedMushafEditionProvider.notifier)
                            .select(list[i].id);
                        Navigator.of(context).pop(list[i].id);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditionTile extends StatelessWidget {
  final MushafEdition edition;
  final bool selected;
  final VoidCallback onTap;

  const _EditionTile({
    required this.edition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? gold.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? gold : gold.withValues(alpha: 0.22),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuranBookCoverThumbnail(edition: edition),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          edition.localizedName(
                              context.locale.languageCode),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: gold, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'quran.riwayah'.tr()}: '
                    '${edition.localizedRiwayah(context.locale.languageCode)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'quran.pages_count'.plural(edition.pages)} · '
                    '${'quran.ayahs_count'.plural(edition.ayahs)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  if (!edition.sciencesAligned) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'quran.sciences_hafs_only'.tr(),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

