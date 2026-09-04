import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/hadith_repository.dart';
import '../../../core/i18n/hadith_grade_i18n.dart';
import '../../../core/services/download_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../library/presentation/screens/hadith_detail_screen.dart';
import '../data/daily_hadith_provider.dart';

/// Home, bottom card (P2‑13) — one full hadith (complete text, narrator,
/// book/number, grade line), re-rolled every app launch, with a manual
/// "حديث آخر" re-roll and a tap-through to the full detail screen. Sits
/// just above the bottom nav bar per the Home redesign's own ordering.
///
/// P3‑4: wrapped in an ornamental frame (gold corner flourishes, a gold
/// hairline border, small stars flanking the title) — the owner sent a
/// real reference (`design_refs/round2_2026-09-04/ref_hadith_card.jpg`) of
/// the old app's own "حديث شريف" card. Followed its *structure* (corner
/// ornament, gold border, star accents), not its literal near-black-green
/// palette — this uses the app's own navy/gold theme instead, same
/// adaptation rule already applied to P3‑29's Shamela reference.
class DailyHadithCard extends ConsumerStatefulWidget {
  const DailyHadithCard({super.key});

  @override
  ConsumerState<DailyHadithCard> createState() => _DailyHadithCardState();
}

class _DailyHadithCardState extends ConsumerState<DailyHadithCard> {
  StreamSubscription<List<DownloadTask>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) {
      final t = DownloadManager.instance.taskById(hadithDbDownloadId);
      if (t != null && t.status == DownloadStatus.completed) {
        ref.invalidate(hadithRepositoryProvider);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(hadithRepositoryProvider);
    final theme = Theme.of(context);

    return _OrnateFrame(
      child: repoAsync.when(
        loading: () => const _Loading(),
        error: (_, _) => _ErrorState(theme: theme),
        data: (repo) =>
            repo == null ? _DownloadPrompt(theme: theme) : const _PickedHadith(),
      ),
    );
  }
}

/// The ornamental frame itself — a gold hairline border, a subtle navy→gold
/// gradient fill (this app's own night palette, not the reference's
/// near-black-green), and a gold quarter-circle flourish mirrored into all
/// four corners.
class _OrnateFrame extends StatelessWidget {
  final Widget child;
  const _OrnateFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.nightElevated, AppColors.night]
              : [AppColors.lightScaffold, Colors.white],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 6, left: 6, child: _CornerFlourish()),
          Positioned(
            top: 6,
            right: 6,
            child: Transform.flip(flipX: true, child: const _CornerFlourish()),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: Transform.flip(flipY: true, child: const _CornerFlourish()),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Transform.flip(
              flipX: true,
              flipY: true,
              child: const _CornerFlourish(),
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _CornerFlourish extends StatelessWidget {
  const _CornerFlourish();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(26, 26),
        painter: _FlourishPainter(),
      );
}

/// Two nested quarter-circle arcs, echoing the reference card's own corner
/// ornament without trying to pixel-match its specific artwork.
class _FlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.gold.withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromLTWH(-size.width * 0.35, -size.height * 0.35,
          size.width * 1.35, size.height * 1.35),
      0,
      math.pi / 2,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.05, size.height * 0.05,
          size.width * 0.7, size.height * 0.7),
      0,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlourishPainter old) => false;
}

/// A small gold star, used to flank the title text the same way the
/// reference's "★ حديث شريف ★" banner does.
class _TitleStar extends StatelessWidget {
  const _TitleStar();
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.star, size: 12, color: AppColors.gold.withValues(alpha: 0.8));
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorState extends StatelessWidget {
  final ThemeData theme;
  const _ErrorState({required this.theme});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text('errors.generic'.tr())),
        ],
      );
}

/// Reuses the exact same download (`hadithDbDownloadId`) `LibraryScreen`'s
/// hadith tab already offers — tapping either one drives the same task, so
/// starting it here and finishing the library later (or vice versa) just
/// works, no separate "did I already start this?" state to track.
class _DownloadPrompt extends StatefulWidget {
  final ThemeData theme;
  const _DownloadPrompt({required this.theme});

  @override
  State<_DownloadPrompt> createState() => _DownloadPromptState();
}

class _DownloadPromptState extends State<_DownloadPrompt> {
  @override
  Widget build(BuildContext context) {
    final task = DownloadManager.instance.taskById(hadithDbDownloadId);
    final downloading = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final scheme = widget.theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.menu_book_outlined, color: scheme.primary, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _TitleStar(),
                  const SizedBox(width: 6),
                  Text('hadith_daily.title'.tr(),
                      style: widget.theme.textTheme.titleMedium),
                  const SizedBox(width: 6),
                  const _TitleStar(),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                downloading
                    ? 'hadith_daily.downloading'.tr()
                    : 'hadith_daily.download_prompt'.tr(),
                style: widget.theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (downloading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          FilledButton.tonal(
            onPressed: () => DownloadManager.instance.enqueue(
              id: hadithDbDownloadId,
              url: AppConfig.hadithDbUrl,
              category: 'hadith',
              fileName: 'hadith.zip',
              unzipToDatabases: true,
              dbVersion: AppConfig.hadithDbVersion,
            ),
            child: Text('library.download'.tr()),
          ),
      ],
    );
  }
}

class _PickedHadith extends ConsumerStatefulWidget {
  const _PickedHadith();

  @override
  ConsumerState<_PickedHadith> createState() => _PickedHadithState();
}

class _PickedHadithState extends ConsumerState<_PickedHadith> {
  // P3‑36: local, layout-invisible "in flight" flag for the reroll button's
  // own spinner — deliberately NOT derived from the provider's AsyncValue
  // (see the doc on `DailyHadithNotifier.reroll`), so a reroll can never
  // collapse the card itself, only swap this one small icon.
  bool _rerolling = false;

  Future<void> _reroll() async {
    setState(() => _rerolling = true);
    await ref.read(dailyHadithProvider.notifier).reroll();
    if (mounted) setState(() => _rerolling = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dailyHadithProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return async.when(
      loading: () => const _Loading(),
      error: (_, _) => _ErrorState(theme: theme),
      data: (daily) {
        if (daily == null) {
          // repo resolved but the pool query returned nothing — shouldn't
          // happen with real content, but honest-empty beats a fake card.
          return Text('errors.generic'.tr());
        }
        final item = daily.item;
        final book = daily.book;
        final isSahihayn = book.id == 1 || book.id == 2;

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HadithDetailScreen(
                book: book,
                chapterHadiths: [item],
                initialIndex: 0,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const _TitleStar(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'hadith_daily.title'.tr(),
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _TitleStar(),
                  // P3‑41: a real device screenshot showed this row
                  // overflowing by 16px on a narrower/scaled-font phone —
                  // the plain `IconButton`'s default 48×48 tap target was
                  // the fixed-width cost this Row couldn't always afford
                  // alongside two star glyphs + the book icon. Shrinking
                  // its own footprint (not the touch target's visual
                  // affordance, just the padding around it) removes that
                  // margin without changing what it does.
                  IconButton(
                    tooltip: 'hadith_daily.another'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: _rerolling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    onPressed: _rerolling ? null : _reroll,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.arabic,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 17,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${book.nameAr} · ${'library.hadith_number'.tr()} ${item.numberInBook}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              // P3‑41: the owner's real-device feedback — no "Grade:"
              // label, just the grade itself, localized where we honestly
              // can (see hadith_grade_i18n.dart). For Bukhari/Muslim, the
              // book name shown just above *is* the grade ("صحيح مسلم"
              // literally reads "Sahih Muslim") — a separate badge
              // repeating that was pure redundancy, so it's gone rather
              // than shown twice.
              if (!isSahihayn && item.grade != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(item.grader != null
                          ? '${localizedHadithGrade(item.grade!, context.locale.languageCode)} '
                              '(${localizedHadithGrader(item.grader!, context.locale.languageCode)})'
                          : localizedHadithGrade(
                              item.grade!, context.locale.languageCode)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
