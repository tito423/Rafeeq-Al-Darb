import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/azkar_settings_provider.dart';

/// Shared settings entry point (haptics, + morning/evening reminders on
/// the Azkar tab only) — pulled out to its own file (P3‑4 round 2) so
/// both the now-separate `AzkarScreen` and `TasbeehScreen` bottom-nav
/// tabs can offer it. The haptics toggle genuinely applies to both (it
/// drives the tap feedback for `AzkarSectionScreen`'s own dhikr counter
/// *and* the Tasbeeh counter), so it always shows.
///
/// P3‑44: the morning/evening reminders **used to** show here
/// unconditionally too — real-device feedback pointed out that on the
/// Tasbeeh tab specifically, "remind me to read morning/evening adhkar"
/// is an Azkar concept with no meaning for a free-form counter, and asked
/// for it removed from that context. [showReminders] (Azkar: true,
/// Tasbeeh: false) is the fix — same shared sheet, the one section that
/// doesn't apply everywhere is now conditional on which tab opened it.
class AzkarSettingsButton extends ConsumerWidget {
  final bool showReminders;
  const AzkarSettingsButton({super.key, this.showReminders = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.tune),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AzkarSettingsSheet(showReminders: showReminders),
      ),
    );
  }
}

class _AzkarSettingsSheet extends ConsumerWidget {
  final bool showReminders;
  const _AzkarSettingsSheet({required this.showReminders});

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay? current,
    void Function(TimeOfDay?) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(azkarSettingsProvider);
    final notifier = ref.read(azkarSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text('azkar.vibration'.tr()),
              value: settings.haptics,
              onChanged: notifier.setHaptics,
            ),
            if (showReminders) ...[
              const Divider(),
              Text('azkar.reminders'.tr(),
                  style: Theme.of(context).textTheme.titleSmall),
              ListTile(
                title: Text('azkar.morning_reminder'.tr()),
                subtitle: Text(settings.morningReminder == null
                    ? 'azkar.reminder_off'.tr()
                    : settings.morningReminder!.format(context)),
                trailing: Wrap(children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _pickTime(context, ref, settings.morningReminder,
                        notifier.setMorningReminder),
                  ),
                  if (settings.morningReminder != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => notifier.setMorningReminder(null),
                    ),
                ]),
              ),
              ListTile(
                title: Text('azkar.evening_reminder'.tr()),
                subtitle: Text(settings.eveningReminder == null
                    ? 'azkar.reminder_off'.tr()
                    : settings.eveningReminder!.format(context)),
                trailing: Wrap(children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _pickTime(context, ref, settings.eveningReminder,
                        notifier.setEveningReminder),
                  ),
                  if (settings.eveningReminder != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => notifier.setEveningReminder(null),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
