import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_store.dart';
import 'khatma_card.dart' show showKhatmaUndoSnackBar;

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
                    onReadToday: mushaf == null
                        ? null
                        : () async {
                            final before = k;
                            final updated = await ref
                                .read(khatmaStoreProvider.notifier)
                                .readToday(k, mushaf.juzStartPages);
                            if (!context.mounted) return;
                            ref.read(quranJumpRequestProvider.notifier).state =
                                updated.currentPage;
                            ref.read(requestedTabProvider.notifier).state =
                                AppTab.quran;
                            // Shown via the root ScaffoldMessenger (this
                            // Scaffold doesn't nest its own), so it survives
                            // the pop below and appears over Home.
                            showKhatmaUndoSnackBar(context, ref, before);
                            Navigator.of(context).pop();
                          },
                    onOpenReader: () {
                      ref.read(quranJumpRequestProvider.notifier).state =
                          k.currentPage;
                      ref.read(requestedTabProvider.notifier).state =
                          AppTab.quran;
                      Navigator.of(context).pop();
                    },
                    onSetReminder: () => _pickReminder(context, ref, k),
                    onDelete: () => _confirmDelete(context, ref, k),
                  ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('khatma.history'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.gold)),
                  const SizedBox(height: 8),
                  for (final k in done) _CompletedTile(khatma: k),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Khatma k) async {
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
      BuildContext context, WidgetRef ref, Khatma k) async {
    final time = await showTimePicker(
      context: context,
      initialTime: k.reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    await ref.read(khatmaStoreProvider.notifier).setReminder(k, time);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateKhatmaSheet(),
    );
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
            Icon(Icons.auto_stories_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text('khatma.start_invite'.tr(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _KhatmaTile extends StatelessWidget {
  final Khatma khatma;
  final MushafData? mushaf;
  final VoidCallback? onReadToday;
  final VoidCallback onOpenReader;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = AppColors.gold;
    final due = mushaf == null ? 0 : khatma.duePages(mushaf!.juzStartPages);
    final daysLeft = khatma.daysLeft;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: khatma.progress,
                      strokeWidth: 4,
                      backgroundColor: gold.withValues(alpha: 0.15),
                      color: gold,
                    ),
                    Text('${(khatma.progress * 100).round()}%',
                        style: theme.textTheme.labelSmall),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'khatma.pages_read_of'
                            .tr(args: ['${khatma.pagesRead}', '${Khatma.totalPages}']),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        daysLeft != null
                            ? 'khatma.days_left'.tr(args: ['$daysLeft'])
                            : 'khatma.daily_amount'.tr(args: ['${khatma.dailyAmount ?? 1}']),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                        title: Text(khatma.reminderTime == null
                            ? 'khatma.set_reminder'.tr()
                            : 'khatma.reminder_at'
                                .tr(args: [_fmtTime(khatma.reminderTime!)])),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text('khatma.delete'.tr(),
                            style: const TextStyle(color: AppColors.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenReader,
                    child: Text('khatma.open_reader'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: khatma.readToday
                      ? FilledButton.tonalIcon(
                          onPressed: null,
                          icon: const Icon(Icons.check),
                          label: Text('khatma.read_today_done'.tr()),
                        )
                      : FilledButton(
                          onPressed: onReadToday,
                          child: Text('khatma.read_today'.tr(args: ['$due'])),
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
        title: Text('khatma.completed_on'.tr(
          args: [date != null ? DateFormat.yMMMd(context.locale.toString()).format(date) : ''],
        )),
        subtitle: Text('khatma.started_on'.tr(
          args: [DateFormat.yMMMd(context.locale.toString()).format(khatma.startDate)],
        )),
      ),
    );
  }
}

class _CreateKhatmaSheet extends ConsumerStatefulWidget {
  const _CreateKhatmaSheet();

  @override
  ConsumerState<_CreateKhatmaSheet> createState() => _CreateKhatmaSheetState();
}

class _CreateKhatmaSheetState extends ConsumerState<_CreateKhatmaSheet> {
  KhatmaMode _mode = KhatmaMode.dailyPages;
  int _dailyPages = 4;
  int _dailyJuz = 1;
  DateTime? _targetDate;
  TimeOfDay? _reminder;

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('khatma.new'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<KhatmaMode>(
            segments: [
              ButtonSegment(
                value: KhatmaMode.dailyPages,
                label: Text('khatma.mode_pages'.tr()),
              ),
              ButtonSegment(
                value: KhatmaMode.dailyJuz,
                label: Text('khatma.mode_juz'.tr()),
              ),
              ButtonSegment(
                value: KhatmaMode.targetDate,
                label: Text('khatma.mode_date'.tr()),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 18),
          if (_mode == KhatmaMode.dailyPages) _Stepper(
            label: 'khatma.pages_per_day'.tr(),
            value: _dailyPages,
            min: 1,
            max: 30,
            onChanged: (v) => setState(() => _dailyPages = v),
          ),
          if (_mode == KhatmaMode.dailyJuz) _Stepper(
            label: 'khatma.juz_per_day'.tr(),
            value: _dailyJuz,
            min: 1,
            max: 5,
            onChanged: (v) => setState(() => _dailyJuz = v),
          ),
          if (_mode == KhatmaMode.targetDate)
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(_targetDate == null
                  ? 'khatma.pick_date'.tr()
                  : DateFormat.yMMMd(context.locale.toString()).format(_targetDate!)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _reminder == null
                      ? 'khatma.no_reminder'.tr()
                      : 'khatma.reminder_at'.tr(args: [
                          '${_reminder!.hour.toString().padLeft(2, '0')}:${_reminder!.minute.toString().padLeft(2, '0')}'
                        ]),
                  style: TextStyle(color: gold),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 20, minute: 0),
                  );
                  if (t != null) setState(() => _reminder = t);
                },
                child: Text('khatma.set_reminder'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _mode == KhatmaMode.targetDate && _targetDate == null
                  ? null
                  : () async {
                      await ref.read(khatmaStoreProvider.notifier).create(
                            mode: _mode,
                            targetDate: _mode == KhatmaMode.targetDate ? _targetDate : null,
                            dailyAmount: _mode == KhatmaMode.dailyPages
                                ? _dailyPages
                                : _mode == KhatmaMode.dailyJuz
                                    ? _dailyJuz
                                    : null,
                            reminderTime: _reminder,
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: Text('khatma.create'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
