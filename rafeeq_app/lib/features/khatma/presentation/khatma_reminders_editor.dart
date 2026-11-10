import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../data/khatma_store.dart';

String _fmt(TimeOfDay t, String lang) => localizeDigits(
  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
  lang,
);

/// The daily reminders of one khatma: a chip per time (tap to change it, ×
/// to remove it) and «إضافة تذكير». Any number of them - a quarter at
/// dhuhr, one at asr, one at maghrib (owner, 2026-11-06).
class KhatmaRemindersEditor extends StatelessWidget {
  final List<TimeOfDay> times;
  final ValueChanged<List<TimeOfDay>> onChanged;

  const KhatmaRemindersEditor({
    super.key,
    required this.times,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, {int? replacing}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: replacing != null
          ? times[replacing]
          : const TimeOfDay(hour: 20, minute: 0),
    );
    if (t == null) return;
    final next = [...times];
    if (replacing != null) next.removeAt(replacing);
    onChanged(Khatma.sortedTimes([...next, t]));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined, size: 20, color: goldOn(scheme)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'khatma.reminders'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          (times.isEmpty ? 'khatma.no_reminder' : 'khatma.reminders_hint').tr(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < times.length; i++)
              InputChip(
                avatar: const Icon(Icons.alarm_rounded, size: 18),
                label: Text(_fmt(times[i], lang)),
                onPressed: () => _pick(context, replacing: i),
                onDeleted: () => onChanged([...times]..removeAt(i)),
                deleteButtonTooltipMessage: 'khatma.reminder_remove'.tr(),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_alarm_rounded, size: 18),
              label: Text('khatma.reminder_add'.tr()),
              onPressed: () => _pick(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// The reminders of [khatma] in a sheet of their own; every change is saved
/// and re-armed at once.
Future<void> showKhatmaRemindersSheet(BuildContext context, Khatma khatma) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Consumer(
          builder: (context, ref, _) {
            final live = ref
                .watch(khatmaStoreProvider)
                .where((k) => k.id == khatma.id)
                .firstOrNull;
            if (live == null) return const SizedBox.shrink();
            return KhatmaRemindersEditor(
              times: live.reminderTimes,
              onChanged: (times) => ref
                  .read(khatmaStoreProvider.notifier)
                  .setReminders(live, times),
            );
          },
        ),
      ),
    ),
  );
}
