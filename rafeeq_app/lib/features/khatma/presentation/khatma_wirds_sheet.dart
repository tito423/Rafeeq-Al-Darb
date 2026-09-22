import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/khatma_range.dart';
import '../data/khatma_store.dart';

/// «لما اضغط الاوراد السابقة يعرض الاوراد السابقة كلها وانا اختار اي واحد
/// ارجعله وكذلك في القادمة».
///
/// Every wird is listed with its real surah/ayah span. Tapping one opens
/// the mushaf on it. A previous wird also offers «ارجع له», which makes it
/// the current wird again (after a confirmation, because it un-reads every
/// wird after it).
Future<void> showKhatmaWirdsSheet(
  BuildContext context, {
  required String khatmaId,
  required bool previous,
  required ValueChanged<int> onOpenPage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => _WirdsList(
        khatmaId: khatmaId,
        previous: previous,
        controller: controller,
        onOpenPage: onOpenPage,
      ),
    ),
  );
}

class _WirdsList extends ConsumerWidget {
  final String khatmaId;
  final bool previous;
  final ScrollController controller;
  final ValueChanged<int> onOpenPage;

  const _WirdsList({
    required this.khatmaId,
    required this.previous,
    required this.controller,
    required this.onOpenPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    Khatma? khatma;
    for (final k in ref.watch(khatmaStoreProvider)) {
      if (k.id == khatmaId) khatma = k;
    }
    final theme = Theme.of(context);
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        previous ? 'khatma.previous_label'.tr() : 'khatma.upcoming_label'.tr(),
        style: theme.textTheme.titleLarge,
      ),
    );
    if (khatma == null || mushaf == null) {
      return Column(
        children: [
          title,
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    final k = khatma;
    final prev = k.previousWirds(mushaf.juzStartPages, mushaf.rubElHizbPages);
    final wirds = previous
        ? prev.reversed.toList()
        : k.upcomingWirds(mushaf.juzStartPages, mushaf.rubElHizbPages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        Expanded(
          child: wirds.isEmpty
              ? Center(child: Text('khatma.no_wirds'.tr()))
              : ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  itemCount: wirds.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    // The previous list runs newest first; the number shown
                    // is always the wird's own place in the khatma.
                    final index = previous ? prev.length - 1 - i : i;
                    final number = previous ? index + 1 : prev.length + i + 1;
                    final w = wirds[i];
                    return _WirdTile(
                      mushaf: mushaf,
                      number: number,
                      isCurrent: !previous && i == 0,
                      startPage: k.pageAt(w.from),
                      endPage: k.pageAt(w.to - 1),
                      at: w.at,
                      onOpen: () {
                        Navigator.of(context).pop();
                        onOpenPage(k.pageAt(w.from));
                      },
                      onRewind: previous
                          ? () => _rewind(context, ref, index, number)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _rewind(
    BuildContext context,
    WidgetRef ref,
    int index,
    int number,
  ) async {
    final mushaf = ref.read(mushafDataProvider).valueOrNull;
    if (mushaf == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(trn('khatma.rewind_confirm', args: ['$number'])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('khatma.rewind'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(khatmaStoreProvider.notifier)
        .rewindTo(khatmaId, index, mushaf.juzStartPages, mushaf.rubElHizbPages);
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(trn('khatma.rewound', args: ['$number']))),
      );
  }
}

class _WirdTile extends ConsumerWidget {
  final MushafData mushaf;
  final int number;
  final bool isCurrent;
  final int startPage;
  final int endPage;
  final DateTime? at;
  final VoidCallback onOpen;
  final VoidCallback? onRewind;

  const _WirdTile({
    required this.mushaf,
    required this.number,
    required this.isCurrent,
    required this.startPage,
    required this.endPage,
    required this.at,
    required this.onOpen,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final range = ref
        .watch(pageSpanRangeProvider((mushaf, startPage, endPage)))
        .valueOrNull;
    final when = at;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isCurrent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: gold),
            )
          : null,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: gold.withValues(alpha: 0.14),
                child: Text(
                  localizeDigits('$number', uiLanguageCode),
                  style: theme.textTheme.labelLarge?.copyWith(color: gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrent
                          ? 'khatma.wird_current'.tr()
                          : trn('khatma.wird_n', args: ['$number']),
                      style: theme.textTheme.titleSmall,
                    ),
                    if (range != null)
                      Text(
                        '${trn('khatma.range_from', args: [mushaf.surahNameAr(range.start.surahId), '${range.start.ayahNumber}'])}\n'
                        '${trn('khatma.range_to', args: [mushaf.surahNameAr(range.end.surahId), '${range.end.ayahNumber}'])}',
                        style: subtle,
                      ),
                    Text(
                      [
                        trn(
                          'khatma.wird_pages',
                          args: ['$startPage', '$endPage'],
                        ),
                        if (when != null)
                          DateFormat.MMMEd(
                            context.locale.toString(),
                          ).format(when),
                      ].join(' · '),
                      style: subtle,
                    ),
                  ],
                ),
              ),
              if (onRewind != null)
                TextButton.icon(
                  onPressed: onRewind,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text('khatma.rewind'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
