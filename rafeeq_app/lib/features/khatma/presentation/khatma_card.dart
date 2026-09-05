import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_range.dart';
import '../data/khatma_store.dart';
import 'khatma_screen.dart';

/// Home, top card (P2‑11) — shows the nearest active khatma's progress ring
/// + today's portion + "اقرأ اليوم", or an honest "ابدأ ختمة" invitation
/// when none exists yet. Tapping the card (not the button) opens the full
/// manager (`KhatmaScreen`) — create/edit/history live there.
class KhatmaCard extends ConsumerWidget {
  const KhatmaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeKhatmasProvider);
    final theme = Theme.of(context);
    final gold = AppColors.gold;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: active.isEmpty
              ? _EmptyState(theme: theme, gold: gold)
              : _ActiveKhatmaRow(
                  khatma: active.first,
                  theme: theme,
                  gold: gold,
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  final Color gold;
  const _EmptyState({required this.theme, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.auto_stories_outlined, color: gold, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('khatma.title'.tr(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'khatma.start_invite'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_left, color: theme.colorScheme.outline),
      ],
    );
  }
}

/// P3‑6 redesign: the owner's real "ختمة" app reference
/// (`design_refs/khatma_app_ref/1_daily_wird_card.jpg`) shows today's
/// portion as a real surah/ayah/page range — "من سورة الفاتحة - آية 1"
/// through "إلى سورة البقرة - آية 141" — plus a khatma-wide previous/
/// upcoming portion count, not just a bare percentage ring. Replaces the
/// old ring+single-button row with that richer layout, resolved from the
/// real mushaf data (`khatmaPortionRangeProvider`), never fabricated.
class _ActiveKhatmaRow extends ConsumerWidget {
  final Khatma khatma;
  final ThemeData theme;
  final Color gold;
  const _ActiveKhatmaRow({
    required this.khatma,
    required this.theme,
    required this.gold,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mushaf = ref.watch(mushafDataProvider).valueOrNull;
    final subtleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, size: 14, color: gold),
                  const SizedBox(width: 2),
                  Text(
                    'khatma.streak'.tr(args: ['${khatma.streak}']),
                    style: theme.textTheme.labelSmall?.copyWith(color: gold),
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
                khatmaPortionRangeProvider((khatma, mushaf)),
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
                        mushaf: mushaf,
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
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: mushaf == null
                    ? null
                    : () {
                        ref.read(quranJumpRequestProvider.notifier).state =
                            khatma.currentPage;
                        _switchToQuranTab(context);
                      },
                child: Text('khatma.open_reader'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: khatma.readToday
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.check, size: 16),
                      label: Text('khatma.read_today_done'.tr()),
                    )
                  : FilledButton(
                      onPressed: mushaf == null
                          ? null
                          : () async {
                              final before = khatma;
                              await ref
                                  .read(khatmaStoreProvider.notifier)
                                  .readToday(
                                    khatma,
                                    mushaf.juzStartPages,
                                    mushaf.rubElHizbPages,
                                  );
                              if (!context.mounted) return;
                              showKhatmaUndoSnackBar(context, ref, before);
                            },
                      child: Text('khatma.mark_read'.tr()),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// `HomeScreen.onNavigate(1)` is how every other quick-access card gets to
  /// the Quran tab — reuse it via the nearest `_HomeNavigate` inherited
  /// callback instead of duplicating shell-navigation logic here.
  void _switchToQuranTab(BuildContext context) {
    HomeNavigate.of(context)?.call(1);
  }
}

/// The "من سورة X - آية Y (صفحة P)" / "إلى ..." block plus the opening
/// ayah's own text as a preview line, matching the reference's "من قوله
/// تعالى" + ayah-text presentation.
class KhatmaPortionRangeBlock extends StatelessWidget {
  final KhatmaPortionRange range;
  final MushafData mushaf;
  final Color gold;
  final TextStyle? subtleStyle;

  const KhatmaPortionRangeBlock({
    super.key,
    required this.range,
    required this.mushaf,
    required this.gold,
    required this.subtleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'khatma.juz_label'.tr(args: ['${range.juz}']),
                  style: theme.textTheme.labelMedium?.copyWith(color: gold),
                ),
              ),
              Text('khatma.from_saying'.tr(), style: subtleStyle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            range.start.textUthmani,
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 17,
              height: 1.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _RangeLine(
            label: 'khatma.range_from'.tr(
              args: [
                mushaf.surahNameAr(range.start.surahId),
                '${range.start.ayahNumber}',
              ],
            ),
            page: range.startPage,
          ),
          const SizedBox(height: 4),
          _RangeLine(
            label: 'khatma.range_to'.tr(
              args: [
                mushaf.surahNameAr(range.end.surahId),
                '${range.end.ayahNumber}',
              ],
            ),
            page: range.endPage,
          ),
        ],
      ),
    );
  }
}

class _RangeLine extends StatelessWidget {
  final String label;
  final int page;
  const _RangeLine({required this.label, required this.page});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('khatma.page_n'.tr(args: ['$page']), style: style),
      ],
    );
  }
}

/// "الختمة الحالية" — a linear progress bar plus the honest previous/
/// upcoming portion counts (P3‑6's "الأوراد السابقة" / "الأوراد القادمة").
class KhatmaProgressSection extends StatelessWidget {
  final Khatma khatma;
  final MushafData? mushaf;
  final Color gold;
  final TextStyle? subtleStyle;

  const KhatmaProgressSection({
    super.key,
    required this.khatma,
    required this.mushaf,
    required this.gold,
    required this.subtleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final upcoming = mushaf == null
        ? null
        : khatma.portionsRemaining(
            mushaf!.juzStartPages,
            mushaf!.rubElHizbPages,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: khatma.progress,
            minHeight: 6,
            backgroundColor: gold.withValues(alpha: 0.15),
            color: gold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'khatma.portions_previous'.tr(args: ['${khatma.portionsRead}']),
              style: subtleStyle,
            ),
            if (upcoming != null)
              Text(
                'khatma.portions_upcoming'.tr(args: ['$upcoming']),
                style: subtleStyle,
              ),
          ],
        ),
      ],
    );
  }
}

/// Shared "قرأت اليوم" undo snackbar (P3‑6) — a "تراجع" action that restores
/// the exact pre-update [before] snapshot, for an accidental tap. Used by
/// both this card's inline button and `KhatmaScreen`'s tile.
void showKhatmaUndoSnackBar(
  BuildContext context,
  WidgetRef ref,
  Khatma before,
) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('khatma.read_today_done'.tr()),
      action: SnackBarAction(
        label: 'common.undo'.tr(),
        onPressed: () => ref.read(khatmaStoreProvider.notifier).restore(before),
      ),
    ),
  );
}

/// A tiny inherited callback so cards below `HomeScreen` (this one) can ask
/// the shell to switch tabs without each accepting their own `onNavigate`
/// parameter one level down — `HomeScreen` already receives it from
/// `AppShell`; this just makes it reachable from `KhatmaCard`, which is
/// built inside `HomeScreen`'s widget tree.
class HomeNavigate extends InheritedWidget {
  final void Function(int tab) onNavigate;
  const HomeNavigate({
    super.key,
    required this.onNavigate,
    required super.child,
  });

  static void Function(int tab)? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HomeNavigate>()
        ?.onNavigate;
  }

  @override
  bool updateShouldNotify(HomeNavigate oldWidget) =>
      onNavigate != oldWidget.onNavigate;
}
