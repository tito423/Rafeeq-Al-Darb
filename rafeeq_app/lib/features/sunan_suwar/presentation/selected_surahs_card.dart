import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import 'single_surah_screen.dart';

/// «سور مختارة» (2026-09-22): يوسف، مريم، الرحمن، الواقعة، يس، ق — in the
/// order the owner named them. Two rows of three so the card stays short,
/// and each opens `SingleSurahScreen`, the reader locked to that surah's
/// own pages: «تفتح السورة نفسها بس على قد السورة».
const selectedSurahIds = [12, 19, 55, 56, 36, 50];

class SelectedSurahsCard extends ConsumerWidget {
  const SelectedSurahsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    Widget tile(int id) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: gold.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: gold.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SingleSurahScreen(surahId: id),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      mushaf?.surahNameAr(id) ?? '…',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'AmiriQuran',
                        color: gold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'selected_surahs.title'.tr(),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < selectedSurahIds.length; row += 3)
              Row(
                children: [
                  for (final id in selectedSurahIds.skip(row).take(3)) tile(id),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
