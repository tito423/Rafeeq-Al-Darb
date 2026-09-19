import '../../../core/utils/time_formatter.dart';
import '../../../core/theme/app_colors.dart';
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
            // «طوّر وقت التذكير ويبقى شكله أجمل». A plain row with a small
            // «٢١:٠٠» at its end became a card: the time large, in the app's
            // own 12-hour form, and three evenings people actually choose,
            // with «وقت آخر» for anything else.
            _TimeCard(
              enabled: s.anyOn,
              hour: s.hour,
              minute: s.minute,
              onPick: (h, m) => _set(ref, s.copyWith(hour: h, minute: m)),
            ),
            const SizedBox(height: 4),
            Text('fasting.note'.tr(), style: faint),
            const SizedBox(height: 6),
            Text('fasting.calendar_note'.tr(), style: faint),
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

class _TimeCard extends StatelessWidget {
  final bool enabled;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onPick;

  const _TimeCard({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.onPick,
  });

  static const _presets = [(20, 0), (21, 0), (22, 30)];

  String _label(int h, int m) => formatTime12h(
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
      uiLanguageCode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.gold.withValues(alpha: 0.16),
                scheme.surfaceContainerHighest,
              ],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.nights_stay_rounded, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('fasting.time'.tr(),
                        style: theme.textTheme.titleSmall),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _label(hour, minute),
                      key: ValueKey(hour * 60 + minute),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final (h, m) in _presets)
                    ChoiceChip(
                      label: Text(_label(h, m)),
                      selected: hour == h && minute == m,
                      onSelected: (_) => onPick(h, m),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text('fasting.time_other'.tr()),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (t != null) onPick(t.hour, t.minute);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
