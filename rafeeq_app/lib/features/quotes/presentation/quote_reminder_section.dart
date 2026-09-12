import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/quote_reminder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/quote_background_catalog.dart';
import '../data/quote_repository.dart';
import '../data/quote_reminder_provider.dart';
import 'quote_card_screen.dart';

/// «إشعار كل مدة يحددها المالك (نص ساعة أو أكتر أو أقل)» — the interval, and
/// a way to see what one of them looks like without waiting for it.
///
/// Choosing an interval re-arms the window immediately rather than at the
/// next app start, so the setting is true the moment it is set.
class QuoteReminderSection extends ConsumerWidget {
  const QuoteReminderSection({super.key});

  Future<void> _apply(WidgetRef ref, int minutes) async {
    await ref.read(quoteReminderProvider.notifier).set(minutes);
    final library = await ref.read(quoteLibraryProvider.future);
    await QuoteReminderService.instance
        .reschedule(library: library, everyMinutes: minutes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(quoteReminderProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final library = ref.watch(quoteLibraryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The Home card is its own setting, above the reminder: one is a
            // card you go and look at, the other interrupts you, and a reader
            // may well want the first without the second.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(homeQuoteCardProvider),
              onChanged: (v) =>
                  ref.read(homeQuoteCardProvider.notifier).set(v),
              secondary: Icon(Icons.auto_awesome_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
              title: Text('quotes.home_card'.tr(),
                  style: theme.textTheme.bodyMedium),
              subtitle: Text(
                'quotes.home_card_desc'.tr(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const Divider(height: 8),
            Row(
              children: [
                Icon(Icons.format_quote,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('quotes.reminder_title'.tr(),
                          style: theme.textTheme.bodyMedium),
                      Text(
                        library.maybeWhen(
                          data: (lib) => 'quotes.reminder_desc'.tr(namedArgs: {
                            'count': 'quotes.count'.plural(lib.total),
                            'books': 'quotes.books'.plural(lib.books.length),
                          }),
                          orElse: () => 'quotes.reminder_desc_plain'.tr(),
                        ),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('quotes.off'.tr()),
                  selected: minutes == 0,
                  onSelected: (_) => _apply(ref, 0),
                ),
                for (final m in kQuoteIntervals)
                  ChoiceChip(
                    label: Text(_label(m)),
                    selected: minutes == m,
                    onSelected: (_) => _apply(ref, m),
                  ),
              ],
            ),
            if (minutes > 0) ...[
              const SizedBox(height: 6),
              Text(
                'quotes.window_note'.tr(namedArgs: {
                  'n': '${QuoteReminderService.slotCount(minutes)}',
                }),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                label: Text('quotes.preview'.tr()),
                onPressed: () async {
                  final lib = await ref.read(quoteLibraryProvider.future);
                  final pick = lib.randomIndex(Random());
                  if (pick == null) return;
                  final quote = lib.at(pick.$1, pick.$2);
                  if (quote == null || !context.mounted) return;
                  final photos =
                      await ref.read(quoteBackgroundsProvider.future);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          QuoteCardScreen(quote: quote, photos: photos),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «٣٠ دقيقة» / «ساعتان» — an interval reads better as hours once it is one.
  String _label(int minutes) {
    if (minutes % 60 == 0) {
      return 'quotes.hours'.plural(minutes ~/ 60);
    }
    return 'quotes.minutes'.plural(minutes);
  }
}
