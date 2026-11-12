import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../../core/utils/time_formatter.dart';
import '../data/khatma_store.dart';

/// 12-hour clock with the locale's AM/PM marker (owner, 2026-11-12).
String _fmt(TimeOfDay t, String lang) => localizeDigits(
  formatTime12h(
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
    lang,
  ),
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
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child ?? const SizedBox.shrink(),
      ),
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
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < times.length; i++)
              _TimePill(
                label: _fmt(times[i], lang),
                onTap: () => _pick(context, replacing: i),
                onRemove: () => onChanged([...times]..removeAt(i)),
                removeTooltip: 'khatma.reminder_remove'.tr(),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: Text('khatma.reminder_add'.tr()),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 44),
              ),
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

/// One reminder time: a rounded gold-tinted pill, the time large, a small
/// remove button at its end.
class _TimePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String removeTooltip;

  const _TimePill({
    required this.label,
    required this.onTap,
    required this.onRemove,
    required this.removeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.gold.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_rounded, size: 18, color: goldOn(scheme)),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: removeTooltip,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
