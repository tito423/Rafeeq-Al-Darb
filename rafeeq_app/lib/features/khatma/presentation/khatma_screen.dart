import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_range.dart';
import '../data/khatma_store.dart';
import 'create_khatma_sheet.dart';
import 'khatma_card.dart'
    show completeKhatmaWird, KhatmaPortionRangeBlock, KhatmaProgressSection;

/// The full khatma manager (P2‑11) — every active khatma with its own
/// progress/read-today/reminder controls, a "+" to start a new one, and a
/// history section for finished ones. Pushed from `KhatmaCard`.
class KhatmaScreen extends ConsumerWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeKhatmasProvider);
    final done = ref.watch(completedKhatmasProvider);
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('khatma.title'.tr())),
      // With no khatma yet the plans are on a large card in the middle
      // (owner, 2026-09-30: «خلي كارت كبير يظهر في نص الشاشة مليان
      // بالاختيارات»), so the corner button would only repeat it.
      floatingActionButton: (active.isEmpty && done.isEmpty)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCreateSheet(context, ref),
              icon: const Icon(Icons.add),
              label: Text('khatma.new'.tr()),
            ),
      body: (active.isEmpty && done.isEmpty)
          ? const _EmptyBody()
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              children: [
                for (final k in active)
                  _KhatmaTile(
                    khatma: k,
                    mushaf: mushaf,
                    // Stays on this screen: more than one wird can be
                    // finished in a sitting, and the «تراجع» line inside the tile has
                    // to be here to be tapped.
                    onReadToday: mushaf == null
                        ? null
                        : () => completeKhatmaWird(context, ref, k, mushaf),
                    onOpenReader: (page) {
                      ref.read(quranJumpRequestProvider.notifier).state = page;
                      ref.read(requestedTabProvider.notifier).state =
                          AppTab.quran;
                      Navigator.of(context).pop();
                    },
                    onSetReminder: () => _pickReminder(context, ref, k),
                    onDelete: () => _confirmDelete(context, ref, k),
                  ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'khatma.history'.tr(),
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: goldText(context)),
                  ),
                  const SizedBox(height: 8),
                  for (final k in done) _CompletedTile(khatma: k),
                ],
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Khatma k,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('khatma.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          // Destructive, so it is drawn as one — not in the app's green.
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('khatma.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(khatmaStoreProvider.notifier).delete(k);
  }

  Future<void> _pickReminder(
    BuildContext context,
    WidgetRef ref,
    Khatma k,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: k.reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (time == null) return;
    await ref.read(khatmaStoreProvider.notifier).setReminder(k, time);
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showCreateKhatmaSheet(context);
  }
}

/// No khatma yet: a large card of plans - a week, a month, two months, a
/// year - each with the pages a day it asks (604 pages, rounded up), and a
/// «your own settings» way in. Each opens the create sheet at that length.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  static const _plans = [
    (7, Icons.bolt_rounded, Color(0xFFEE5253)),
    (30, Icons.calendar_month_rounded, Color(0xFF10AC84)),
    (60, Icons.event_available_rounded, Color(0xFF2E86DE)),
    // «غير في سنة … خليها اختر مدة الختمة» (owner, 2026-10-03): the fourth
    // tile opens the sheet where the reader sets the duration himself.
    (0, Icons.tune_rounded, Color(0xFF8854D0)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = context.locale.languageCode;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    AppColors.gold.withValues(alpha: 0.16),
                    scheme.surfaceContainerHighest,
                  ),
                  scheme.surfaceContainerHighest,
                ],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.auto_stories_rounded,
                  size: 56,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 8),
                Text(
                  'khatma.plan_title'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'khatma.start_invite'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    for (final (days, icon, color) in _plans)
                      Material(
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => days == 0
                              ? showCreateKhatmaSheet(context)
                              : showCreateKhatmaSheet(context, days: days),
                          child: Ink(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  Color.lerp(color, Colors.black, 0.3)!,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: Colors.white, size: 34),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    days == 0
                                        ? 'khatma.plan_choose'.tr()
                                        : 'khatma.plan_$days'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (days > 0)
                                Text(
                                  'khatma.plan_pages'.tr(
                                    args: [
                                      localizeDigits(
                                        '${(604 / days).ceil()}',
                                        lang,
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KhatmaTile extends ConsumerWidget {
  final Khatma khatma;
  final MushafData? mushaf;
  final VoidCallback? onReadToday;
  final ValueChanged<int> onOpenReader;
  final VoidCallback onSetReminder;
  final VoidCallback onDelete;

  const _KhatmaTile({
    required this.khatma,
    required this.mushaf,
    required this.onReadToday,
    required this.onOpenReader,
    required this.onSetReminder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P3‑47: the owner asked for this section to carry the same rich "current
    // wird" card the Home screen shows (design_refs/khatma_app_ref) — the
    // real surah/ayah/page range + opening-ayah text + previous/upcoming
    // portion counts, not just a bare ring. Reuses the exact same public
    // building blocks the Home card uses (KhatmaPortionRangeBlock /
    // KhatmaProgressSection), resolved from real mushaf data.
    final theme = Theme.of(context);
    const gold = AppColors.gold;
    final subtleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'khatma.title'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (khatma.streak > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          trn('khatma.streak', args: ['${khatma.streak}']),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'reminder') onSetReminder();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'reminder',
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(
                          khatma.reminderTime == null
                              ? 'khatma.set_reminder'.tr()
                              : 'khatma.reminder_at'.tr(
                                  args: [_fmtTime(khatma.reminderTime!)],
                                ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        title: Text(
                          'khatma.delete'.tr(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mushaf == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              )
            else
              Consumer(
                builder: (context, ref, _) {
                  final rangeAsync = ref.watch(
                    khatmaPortionRangeProvider((khatma, mushaf!)),
                  );
                  return rangeAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: LinearProgressIndicator(),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (range) => range == null
                        ? const SizedBox.shrink()
                        : KhatmaPortionRangeBlock(
                            range: range,
                            mushaf: mushaf!,
                            gold: gold,
                            subtleStyle: subtleStyle,
                          ),
                  );
                },
              ),
            const SizedBox(height: 12),
            KhatmaProgressSection(
              khatma: khatma,
              mushaf: mushaf,
              gold: gold,
              subtleStyle: subtleStyle,
              onOpenPage: onOpenReader,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onOpenReader(khatma.currentPage),
                    child: Text('khatma.open_reader'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReadToday,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('khatma.mark_read'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// In the reader's digits - it was Latin inside the Arabic interface
  /// (found by a search for raw padded times, 2026-09-26).
  String _fmtTime(TimeOfDay t) => localizeDigits(
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
    uiLanguageCode,
  );
}

class _CompletedTile extends StatelessWidget {
  final Khatma khatma;
  const _CompletedTile({required this.khatma});

  @override
  Widget build(BuildContext context) {
    final date = khatma.completedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.emoji_events_outlined, color: goldText(context)),
        title: Text(
          'khatma.completed_on'.tr(
            args: [
              date != null
                  ? DateFormat.yMMMd(context.locale.toString()).format(date)
                  : '',
            ],
          ),
        ),
        subtitle: Text(
          'khatma.started_on'.tr(
            args: [
              DateFormat.yMMMd(
                context.locale.toString(),
              ).format(khatma.startDate),
            ],
          ),
        ),
      ),
    );
  }
}
