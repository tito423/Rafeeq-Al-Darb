import '../../../core/utils/digits.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_range.dart';
import '../data/khatma_store.dart';
import 'khatma_card.dart'
    show completeKhatmaWird, KhatmaPortionRangeBlock, KhatmaProgressSection;
import 'create_khatma_sheet.dart';

/// The full khatma manager (P2‑11) — every active khatma with its own
/// progress/read-today/reminder controls, a "+" to start a new one, and a
/// history section for finished ones. Pushed from `KhatmaCard`.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeKhatmasProvider);
    final done = ref.watch(completedKhatmasProvider);
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('khatma.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text('khatma.new'.tr()),
      ),
      body: (active.isEmpty && done.isEmpty)
          ? const _EmptyBody()
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              children: [
                for (final k in active)
                  _KhatmaTile(
                    khatma: k,
                    mushaf: mushaf,
                    // Stays on this screen: more than one wird can be
                    // finished in a sitting, and «تراجع» has to be here to
                    // be tapped.
                    onReadToday: mushaf == null
                        ? null
                        : () => completeKhatmaWird(context, ref, k, mushaf),
                    onOpenReader: (page) {
                      ref.read(quranJumpRequestProvider.notifier).state = page;
                      ref.read(requestedTabProvider.notifier).state =
                          AppTab.quran;
                      Navigator.of(context).pop();
                    },
                    onSetReminder: () => _pickReminder(context, ref, k),
                    onDelete: () => _confirmDelete(context, ref, k),
                  ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'khatma.history'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppColors.gold),
                  ),
                  const SizedBox(height: 8),
                  for (final k in done) _CompletedTile(khatma: k),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Khatma k,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('khatma.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('khatma.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(khatmaStoreProvider.notifier).delete(k);
  }

  Future<void> _pickReminder(
    BuildContext context,
    WidgetRef ref,
    Khatma k,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: k.reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    await ref.read(khatmaStoreProvider.notifier).setReminder(k, time);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showCreateKhatmaSheet(context);
  }
}

/// P3‑6: this used to carry its own "+ ختمة جديدة" button, duplicating the
/// Scaffold's own `FloatingActionButton.extended` (same label, same action)
/// — both visible on screen at once whenever the list was empty. The FAB
/// alone is enough; [onCreate] is kept unused-by-this-widget on purpose
/// (nothing here needs it now), tapping the illustration area does nothing
/// special, the FAB is the one and only "create" affordance.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text('khatma.start_invite'.tr(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _KhatmaTile extends ConsumerWidget {
  final Khatma khatma;
  final MushafData? mushaf;
  final VoidCallback? onReadToday;
  final ValueChanged<int> onOpenReader;
  final VoidCallback onSetReminder;
  final VoidCallback onDelete;

  const _KhatmaTile({
    required this.khatma,
    required this.mushaf,
    required this.onReadToday,
    required this.onOpenReader,
    required this.onSetReminder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P3‑47: the owner asked for this section to carry the same rich "current
    // wird" card the Home screen shows (design_refs/khatma_app_ref) — the
    // real surah/ayah/page range + opening-ayah text + previous/upcoming
    // portion counts, not just a bare ring. Reuses the exact same public
    // building blocks the Home card uses (KhatmaPortionRangeBlock /
    // KhatmaProgressSection), resolved from real mushaf data.
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final subtleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'khatma.title'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (khatma.streak > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trn('khatma.streak', args: ['${khatma.streak}']),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'reminder') onSetReminder();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'reminder',
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(
                          khatma.reminderTime == null
                              ? 'khatma.set_reminder'.tr()
                              : 'khatma.reminder_at'.tr(
                                  args: [_fmtTime(khatma.reminderTime!)],
                                ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        title: Text(
                          'khatma.delete'.tr(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mushaf == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              )
            else
              Consumer(
                builder: (context, ref, _) {
                  final rangeAsync = ref.watch(
                    khatmaPortionRangeProvider((khatma, mushaf!)),
                  );
                  return rangeAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (range) => range == null
                        ? const SizedBox.shrink()
                        : KhatmaPortionRangeBlock(
                            range: range,
                            mushaf: mushaf!,
                            gold: gold,
                            subtleStyle: subtleStyle,
                          ),
                  );
                },
              ),
            const SizedBox(height: 12),
            KhatmaProgressSection(
              khatma: khatma,
              mushaf: mushaf,
              gold: gold,
              subtleStyle: subtleStyle,
              onOpenPage: onOpenReader,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpenReader(khatma.currentPage),
                    child: Text('khatma.open_reader'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReadToday,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('khatma.mark_read'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _CompletedTile extends StatelessWidget {
  final Khatma khatma;
  const _CompletedTile({required this.khatma});

  @override
  Widget build(BuildContext context) {
    final date = khatma.completedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined, color: AppColors.gold),
        title: Text(
          'khatma.completed_on'.tr(
            args: [
              date != null
                  ? DateFormat.yMMMd(context.locale.toString()).format(date)
                  : '',
            ],
          ),
        ),
        subtitle: Text(
          'khatma.started_on'.tr(
            args: [
              DateFormat.yMMMd(
                context.locale.toString(),
              ).format(khatma.startDate),
            ],
          ),
        ),
      ),
    );
  }
}
