import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/azkar_settings_provider.dart';

/// Shared settings entry point (haptics + morning/evening reminders) —
/// pulled out to its own file (P3‑4 round 2) so both the now-separate
/// `AzkarScreen` and `TasbeehScreen` bottom-nav tabs can offer it. The
/// haptics toggle affects the tasbeeh counter's tap feedback directly, so
/// it needs to stay reachable from the Tasbeeh tab too, not just Azkar's.
class AzkarSettingsButton extends ConsumerWidget {
  const AzkarSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.tune),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _AzkarSettingsSheet(),
      ),
    );
  }
}

class _AzkarSettingsSheet extends ConsumerWidget {
  const _AzkarSettingsSheet();

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
        ),
      ),
    );
  }
}
