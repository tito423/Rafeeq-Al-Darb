import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/hadith_repository.dart';
import '../../../core/services/download_manager.dart';
import '../../library/presentation/screens/hadith_detail_screen.dart';
import '../data/daily_hadith_provider.dart';

/// Home, bottom card (P2‑13) — one full hadith (complete text, narrator,
/// book/number, grade line), re-rolled every app launch, with a manual
/// "حديث آخر" re-roll and a tap-through to the full detail screen. Sits
/// just above the bottom nav bar per the Home redesign's own ordering.
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: repoAsync.when(
          loading: () => const _Loading(),
          error: (_, _) => _ErrorState(theme: theme),
          data: (repo) =>
              repo == null ? _DownloadPrompt(theme: theme) : const _PickedHadith(),
        ),
      ),
    );
  }
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
              Text('hadith_daily.title'.tr(),
                  style: widget.theme.textTheme.titleMedium),
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
                  Expanded(
                    child: Text('hadith_daily.title'.tr(),
                        style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'hadith_daily.another'.tr(),
                    icon: _rerolling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isSahihayn)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.verified, size: 16),
                      label: Text('library.sahihayn_badge'.tr()),
                    )
                  else
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(item.grade != null
                          ? (item.grader != null
                              ? '${'library.grade'.tr()}: ${item.grade} '
                                  '(${item.grader})'
                              : '${'library.grade'.tr()}: ${item.grade}')
                          : 'library.grade_unstated'.tr()),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
