import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasbih_items.dart';
import '../data/tasbih_reminder_provider.dart';

/// Settings → «تذكير بالتسابيح»: how often, and every dhikr it rotates
/// through with the hadith it quotes — so the reader knows what is coming.
class TasbihReminderSection extends ConsumerWidget {
  const TasbihReminderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final every = ref.watch(tasbihReminderProvider);
    final theme = Theme.of(context);
    final faint = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    Future<void> choose(int m) async {
      await ref.read(tasbihReminderProvider.notifier).set(m);
      await rearmTasbihReminders(m);
    }

    // A key per interval rather than a plural: «كل ساعتين» is not «كل ٢
    // ساعة», and the list is five long.
    String label(int m) => m == 0 ? 'tasbih.off'.tr() : 'tasbih.every_$m'.tr();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('tasbih.desc'.tr(), style: faint),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in [0, ...tasbihIntervals])
                  ChoiceChip(
                    label: Text(label(m)),
                    selected: every == m,
                    onSelected: (_) => choose(m),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('tasbih.window'.tr(), style: faint),
            const Divider(height: 20),
            for (final item in tasbihItems) ...[
              Text(item.titleKey.tr(),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '«${item.text}»',
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
              Text(item.citationKey.tr(), style: faint),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
