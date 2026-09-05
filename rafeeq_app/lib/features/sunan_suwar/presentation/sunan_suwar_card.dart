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
/// locked to that surah only.
///
/// P3‑44: real-device feedback said this card had too many inline options
/// (title + description + a per-row reminder bell = a 3rd action fighting
/// for space on every row) and asked for a house rule going forward: past
/// 2 options on a card, collapse the extra ones elsewhere rather than pile
/// them inline. The reminder bell moved wholesale to a real Settings
/// section (`SunanSuwarRemindersSection`, `settings_screen.dart`) — this
/// card is now purely "tap a surah, read it," nothing configured from
/// here at all.
class SunanSuwarCard extends ConsumerWidget {
  const SunanSuwarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final theme = Theme.of(context);

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
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SingleSurahScreen(surahId: s.surahId),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reusable across the home card's own tap target and the Settings
/// reminders section — pass `existing` from whichever store read the
/// caller already has.
Future<void> pickSunanReminder(
  BuildContext context,
  int surahId,
  String label,
  SunanReminder? existing,
) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => SunanReminderSheet(
      surahId: surahId,
      label: label,
      existing: existing,
    ),
  );
}

class _SurahRow extends StatelessWidget {
  final SunanSurah surah;
  final String name;
  final VoidCallback onOpen;

  const _SurahRow({
    required this.surah,
    required this.name,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
    );
  }
}

class SunanReminderSheet extends ConsumerStatefulWidget {
  final int surahId;
  final String label;
  final SunanReminder? existing;

  const SunanReminderSheet({
    super.key,
    required this.surahId,
    required this.label,
    required this.existing,
  });

  @override
  ConsumerState<SunanReminderSheet> createState() => _SunanReminderSheetState();
}

class _SunanReminderSheetState extends ConsumerState<SunanReminderSheet> {
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
