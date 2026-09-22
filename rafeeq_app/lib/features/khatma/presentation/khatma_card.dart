import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/digits.dart';
import 'package:flutter/material.dart';

import '../data/ayah_opening.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arabic_text.dart';
import '../../quran/data/mushaf_data_provider.dart';
import '../../quran/data/quran_jump_provider.dart';
import '../data/khatma_range.dart';
import '../data/khatma_store.dart';
import 'khatma_screen.dart';
import 'khatma_wirds_sheet.dart';

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
        Icon(Icons.chevron_right, color: theme.colorScheme.outline),
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
                    trn('khatma.streak', args: ['${khatma.streak}']),
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
          onOpenPage: mushaf == null
              ? null
              : (page) {
                  ref.read(quranJumpRequestProvider.notifier).state = page;
                  _switchToQuranTab(context);
                },
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
            // «غير قرأت اليوم دي لـ أتممت القراءة لأني أصلًا ممكن أقرا أكتر
            // من ورد»: always enabled; each tap finishes one wird.
            Expanded(
              child: FilledButton.icon(
                onPressed: mushaf == null
                    ? null
                    : () => completeKhatmaWird(context, ref, khatma, mushaf),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('khatma.mark_read'.tr()),
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
                  trn('khatma.juz_label', args: ['${range.juz}']),
                  style: theme.textTheme.labelMedium?.copyWith(color: gold),
                ),
              ),
              Text('khatma.from_saying'.tr(), style: subtleStyle),
            ],
          ),
          const SizedBox(height: 6),
          // ArabicText: an ayah laid out in an LTR paragraph moves its
          // trailing marks. See daily_hadith_card for the measured case.
          // Cut on a whole word, not wherever the line runs out. `maxLines`
          // with an ellipsis was breaking the ayah mid-word — «بياكل جزء
          // من الآية وهو بيعرضها» — which is not something to do to an
          // ayah. See `ayah_opening.dart`. No `maxLines` here now: the string
          // is already bounded before it reaches the text engine.
          ArabicText(
            ayahOpening(range.start.textUthmani),
            style: const TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 17,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _RangeLine(
            label: trn(
              'khatma.range_from',
              args: [
                mushaf.surahNameAr(range.start.surahId),
                '${range.start.ayahNumber}',
              ],
            ),
            page: range.startPage,
          ),
          const SizedBox(height: 4),
          _RangeLine(
            label: trn(
              'khatma.range_to',
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
        Text(trn('khatma.page_n', args: ['$page']), style: style),
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
  final ValueChanged<int>? onOpenPage;

  const KhatmaProgressSection({
    super.key,
    required this.khatma,
    required this.mushaf,
    required this.gold,
    required this.subtleStyle,
    this.onOpenPage,
  });

  @override
  Widget build(BuildContext context) {
    final m = mushaf;
    final previousCount = m == null
        ? khatma.portionsRead
        : khatma.previousWirds(m.juzStartPages, m.rubElHizbPages).length;
    final upcomingCount = m == null
        ? null
        : khatma.portionsRemaining(m.juzStartPages, m.rubElHizbPages);
    final open = onOpenPage;

    // Each count opens the full list of those wirds — «يعرض الأوراد كلها
    // وأنا أختار أي واحد».
    Widget countButton({
      required IconData icon,
      required String label,
      required int? count,
      required bool previous,
    }) {
      return Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: m == null || open == null || (count ?? 0) == 0
              ? null
              : () => showKhatmaWirdsSheet(
                  context,
                  khatmaId: khatma.id,
                  previous: previous,
                  onOpenPage: open,
                ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: subtleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      count == null
                          ? '—'
                          : localizeDigits('$count', uiLanguageCode),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        const SizedBox(height: 10),
        Row(
          children: [
            countButton(
              icon: Icons.history_rounded,
              label: 'khatma.previous_label'.tr(),
              count: previousCount,
              previous: true,
            ),
            const SizedBox(width: 8),
            countButton(
              icon: Icons.upcoming_rounded,
              label: 'khatma.upcoming_label'.tr(),
              count: upcomingCount,
              previous: false,
            ),
          ],
        ),
        if (m != null)
          _FinishedWirdLine(khatmaId: khatma.id, mushaf: m, gold: gold),
      ],
    );
  }
}

/// The wird just finished, for the «تراجع» line inside the khatma card.
/// `stamp` tells one tap from the next, so an older timer never hides the
/// line a newer tap put up.
typedef FinishedWird = ({String khatmaId, int number, int stamp});

final lastFinishedWirdProvider = StateProvider<FinishedWird?>((ref) => null);

/// «أتممت القراءة»: finishes the current wird. «تراجع» is offered INSIDE
/// the khatma card ([_FinishedWirdLine]) and leaves by itself.
///
/// It used to be a SnackBar. That one had already stuck on the screen once
/// (an action makes a bar persist by default in Flutter 3.38), and the owner
/// asked on 2026-09-22 for it not to appear at all: «خلي تراجع في الختمة
/// متظهرش اصلا لانها ممكن تعلق … اظهره في الختمة نفسها ويروح تلقائي».
Future<void> completeKhatmaWird(
  BuildContext context,
  WidgetRef ref,
  Khatma khatma,
  MushafData mushaf,
) async {
  final store = ref.read(khatmaStoreProvider.notifier);
  final last = ref.read(lastFinishedWirdProvider.notifier);
  final updated = await store.completeWird(
    khatma,
    mushaf.juzStartPages,
    mushaf.rubElHizbPages,
  );
  last.state = (
    khatmaId: khatma.id,
    number: updated.portionsRead,
    stamp: DateTime.now().microsecondsSinceEpoch,
  );
}

/// «أتممت الورد ٣ · تراجع», for six seconds, then gone. Nothing global: it
/// is part of the card, so it cannot outlive it or cover anything else.
class _FinishedWirdLine extends ConsumerStatefulWidget {
  final String khatmaId;
  final MushafData mushaf;
  final Color gold;
  const _FinishedWirdLine({
    required this.khatmaId,
    required this.mushaf,
    required this.gold,
  });

  @override
  ConsumerState<_FinishedWirdLine> createState() => _FinishedWirdLineState();
}

class _FinishedWirdLineState extends ConsumerState<_FinishedWirdLine> {
  static const _shown = Duration(seconds: 6);
  Timer? _timer;
  int? _armedFor;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hide(int stamp) {
    final now = ref.read(lastFinishedWirdProvider);
    if (now != null && now.stamp == stamp) {
      ref.read(lastFinishedWirdProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(lastFinishedWirdProvider);
    final mine = w != null && w.khatmaId == widget.khatmaId;
    if (mine && _armedFor != w.stamp) {
      _armedFor = w.stamp;
      _timer?.cancel();
      _timer = Timer(_shown, () => _hide(w.stamp));
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !mine
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 4, 2),
                decoration: BoxDecoration(
                  color: widget.gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: widget.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trn('khatma.wird_done', args: ['${w.number}']),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        ref.read(lastFinishedWirdProvider.notifier).state =
                            null;
                        ref.read(khatmaStoreProvider.notifier).undoLastWird(
                              widget.khatmaId,
                              widget.mushaf.juzStartPages,
                              widget.mushaf.rubElHizbPages,
                            );
                      },
                      child: Text('common.undo'.tr()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
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
