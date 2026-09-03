import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const KhatmaScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: active.isEmpty
              ? _EmptyState(theme: theme, gold: gold)
              : _ActiveKhatmaRow(khatma: active.first, theme: theme, gold: gold),
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
              Text('khatma.start_invite'.tr(),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Icon(Icons.chevron_left, color: theme.colorScheme.outline),
      ],
    );
  }
}

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
    final due = mushaf == null ? 0 : khatma.duePages(mushaf.juzStartPages);
    final daysLeft = khatma.daysLeft;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: khatma.progress,
                strokeWidth: 5,
                backgroundColor: gold.withValues(alpha: 0.15),
                color: gold,
              ),
              Text('${(khatma.progress * 100).round()}%',
                  style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('khatma.title'.tr(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                daysLeft != null
                    ? 'khatma.days_left'.tr(args: ['$daysLeft'])
                    : 'khatma.pages_read'.tr(args: ['${khatma.pagesRead}']),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (khatma.streak > 1) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 14, color: gold),
                    const SizedBox(width: 2),
                    Text('khatma.streak'.tr(args: ['${khatma.streak}']),
                        style: theme.textTheme.labelSmall?.copyWith(color: gold)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (khatma.readToday)
          Chip(
            label: Text('khatma.read_today_done'.tr()),
            avatar: const Icon(Icons.check, size: 16),
            visualDensity: VisualDensity.compact,
          )
        else
          FilledButton.tonal(
            onPressed: mushaf == null
                ? null
                : () async {
                    final before = khatma;
                    final updated = await ref
                        .read(khatmaStoreProvider.notifier)
                        .readToday(khatma, mushaf.juzStartPages);
                    if (!context.mounted) return;
                    ref.read(quranJumpRequestProvider.notifier).state =
                        updated.currentPage;
                    _switchToQuranTab(context);
                    showKhatmaUndoSnackBar(context, ref, before);
                  },
            child: Text('khatma.read_today'.tr(args: ['$due'])),
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

/// Shared "قرأت اليوم" undo snackbar (P3‑6) — a "تراجع" action that restores
/// the exact pre-update [before] snapshot, for an accidental tap. Used by
/// both this card's inline button and `KhatmaScreen`'s tile.
void showKhatmaUndoSnackBar(BuildContext context, WidgetRef ref, Khatma before) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('khatma.read_today_done'.tr()),
      action: SnackBarAction(
        label: 'common.undo'.tr(),
        onPressed: () =>
            ref.read(khatmaStoreProvider.notifier).restore(before),
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
