import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/digits.dart';
import '../data/fasting_reminder_provider.dart';
import '../data/sunnah_fasting.dart';

/// Settings → «تذكير صيام السنن»: Monday and Thursday, the white days, and
/// the time on the evening before. Every change re-arms at once, so the
/// setting is true the moment it is set.
class FastingReminderSection extends ConsumerWidget {
  const FastingReminderSection({super.key});

  Future<void> _set(WidgetRef ref, FastingReminderSettings s) async {
    await ref.read(fastingReminderProvider.notifier).update(s);
    await rearmFastingFrom(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fastingReminderProvider);
    final theme = Theme.of(context);
    final faint = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String two(int v) => v.toString().padLeft(2, '0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.mondayThursday,
              onChanged: (v) => _set(ref, s.copyWith(mondayThursday: v)),
              title: Text('fasting.mon_thu'.tr()),
              subtitle: Text('fasting.mon_thu_desc'.tr(), style: faint),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.whiteDays,
              onChanged: (v) => _set(ref, s.copyWith(whiteDays: v)),
              title: Text('fasting.white_days'.tr()),
              subtitle: Text('fasting.white_days_desc'.tr(), style: faint),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: s.anyOn,
              leading: const Icon(Icons.schedule_rounded),
              title: Text('fasting.time'.tr()),
              trailing: Text(
                localizeDigits('${two(s.hour)}:${two(s.minute)}', uiLanguageCode),
                style: theme.textTheme.titleMedium,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
                );
                if (t == null) return;
                await _set(ref, s.copyWith(hour: t.hour, minute: t.minute));
              },
            ),
            const SizedBox(height: 4),
            Text('fasting.note'.tr(), style: faint),
            const Divider(height: 20),
            // What the reminder will say, so it is not a surprise — the same
            // two hadith, verbatim, with at-Tirmidhi's own grading.
            for (final h in const [mondayThursdayHadith, whiteDaysHadith]) ...[
              Text(
                '«${h.text}»',
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
              Text(h.citationKey.tr(), style: faint),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
