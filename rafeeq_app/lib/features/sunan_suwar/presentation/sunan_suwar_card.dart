import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/sunan_suwar_catalog.dart';
import '../data/sunan_suwar_store.dart';
import 'single_surah_screen.dart';

const _weekdayKeys = {
  1: 'sunan_suwar.mon',
  2: 'sunan_suwar.tue',
  3: 'sunan_suwar.wed',
  4: 'sunan_suwar.thu',
  5: 'sunan_suwar.fri',
  6: 'sunan_suwar.sat',
  7: 'sunan_suwar.sun',
};

/// Home, middle card (P2‑12) — the 4 sunnah surahs, each opening a reader
/// locked to that surah only, each with its own independent weekly
/// reminder.
class SunanSuwarCard extends ConsumerWidget {
  const SunanSuwarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final reminders = ref.watch(sunanSuwarStoreProvider);
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('sunan_suwar.title'.tr(), style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final s in sunanSuwarCatalog)
              _SurahRow(
                surah: s,
                name: mushaf?.surahNameAr(s.surahId) ?? '',
                reminder: reminders[s.surahId],
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SingleSurahScreen(surahId: s.surahId),
                  ),
                ),
                onSetReminder: () => _pickReminder(
                  context,
                  ref,
                  s.surahId,
                  mushaf?.surahNameAr(s.surahId) ?? '',
                  reminders[s.surahId],
                ),
                gold: gold,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminder(
    BuildContext context,
    WidgetRef ref,
    int surahId,
    String label,
    SunanReminder? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ReminderSheet(
        surahId: surahId,
        label: label,
        existing: existing,
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final SunanSurah surah;
  final String name;
  final SunanReminder? reminder;
  final VoidCallback onOpen;
  final VoidCallback onSetReminder;
  final Color gold;

  const _SurahRow({
    required this.surah,
    required this.name,
    required this.reminder,
    required this.onOpen,
    required this.onSetReminder,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? '…' : name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontFamily: 'AmiriQuran')),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.virtueNoteKey.tr()} — ${surah.sourceKey.tr()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'sunan_suwar.reminder'.tr(),
              icon: Icon(
                reminder == null ? Icons.notifications_none : Icons.notifications_active,
                color: reminder == null ? null : gold,
              ),
              onPressed: onSetReminder,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderSheet extends ConsumerStatefulWidget {
  final int surahId;
  final String label;
  final SunanReminder? existing;

  const _ReminderSheet({
    required this.surahId,
    required this.label,
    required this.existing,
  });

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late int _weekday = widget.existing?.weekday ?? DateTime.friday;
  late TimeOfDay _time = widget.existing?.time ?? const TimeOfDay(hour: 20, minute: 0);

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
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _weekdayKeys.entries)
                ChoiceChip(
                  label: Text(e.value.tr()),
                  selected: _weekday == e.key,
                  selectedColor: gold.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _weekday = e.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            icon: const Icon(Icons.schedule),
            label: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.existing != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(sunanSuwarStoreProvider.notifier)
                          .clearReminder(widget.surahId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text('sunan_suwar.remove_reminder'.tr()),
                  ),
                ),
              if (widget.existing != null) const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(sunanSuwarStoreProvider.notifier).setReminder(
                          widget.surahId,
                          widget.label,
                          SunanReminder(weekday: _weekday, time: _time),
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text('sunan_suwar.save_reminder'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
