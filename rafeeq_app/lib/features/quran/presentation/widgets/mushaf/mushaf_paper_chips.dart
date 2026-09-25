import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mushaf_paper_provider.dart';

/// The paper mushaf's grounds - normal, warm, night - as one row of chips.
///
/// One widget for every reader that shows the paper mushaf, so the choice
/// is the same setting everywhere: «السور الخاصة كلها وسنن السور تاخد نفس
/// خيارات المصحف كأني فاتحه من تاب القرآن» (owner, 2026-09-25). The Qur'an
/// tab's display sheet and the single-surah reader both build this.
class MushafPaperChips extends ConsumerWidget {
  const MushafPaperChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(mushafPaperProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in MushafPaper.values)
          ChoiceChip(
            label: Text(p.titleKey.tr()),
            selected: current == p,
            onSelected: (_) => ref.read(mushafPaperProvider.notifier).set(p),
          ),
      ],
    );
  }

  /// The chips in a small sheet of their own, for a reader with no display
  /// sheet to put them in.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('quran.paper_title'.tr(),
                    style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 12),
                const MushafPaperChips(),
              ],
            ),
          ),
        ),
      );
}
