import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../data/sunan_suwar_catalog.dart';
import '../data/sunan_suwar_store.dart';
import 'sunan_suwar_card.dart';

/// P3‑44: the per-surah reminder bell used to live inline on the Home
/// "سنن السور" card — moved here wholesale per real-device feedback ("more
/// than 2 options on a card should collapse elsewhere"). Same underlying
/// store/sheet (`sunan_suwar_store.dart`, `pickSunanReminder`), just
/// reached from Settings instead of fighting for space on every home row.
class SunanSuwarRemindersSection extends ConsumerWidget {
  const SunanSuwarRemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final reminders = ref.watch(sunanSuwarStoreProvider);
    final gold = AppColors.gold;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          for (final (i, s) in sunanSuwarCatalog.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Builder(
              builder: (context) {
                final reminder = reminders[s.surahId];
                final name = mushaf?.surahNameAr(s.surahId) ?? '…';
                return ListTile(
                  leading: Icon(
                    reminder == null
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: reminder == null ? scheme.outline : gold,
                  ),
                  title: Text(name, style: const TextStyle(fontFamily: 'AmiriQuran')),
                  subtitle: Text(
                    reminder == null
                        ? 'sunan_suwar.reminder_off'.tr()
                        : 'sunan_suwar.reminder_on_at'.tr(namedArgs: {
                            'day': _weekdayKeys[reminder.weekday]!.tr(),
                            'time':
                                '${reminder.time.hour.toString().padLeft(2, '0')}:'
                                '${reminder.time.minute.toString().padLeft(2, '0')}',
                          }),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pickSunanReminder(
                    context,
                    s.surahId,
                    name,
                    reminder,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

const _weekdayKeys = {
  1: 'sunan_suwar.mon',
  2: 'sunan_suwar.tue',
  3: 'sunan_suwar.wed',
  4: 'sunan_suwar.thu',
  5: 'sunan_suwar.fri',
  6: 'sunan_suwar.sat',
  7: 'sunan_suwar.sun',
};
