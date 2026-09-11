import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/services/download_engine.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../data/downloads_controller.dart';
import '../../../quran_audio/presentation/widgets/audio_common.dart';
import '../../../quran_audio/presentation/reciter_screen.dart';
import '../../../quran_audio/data/mp3quran_api.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran_audio/data/quran_audio_library.dart';
import '../../../quran_audio/presentation/quran_audio_screen.dart';
import '../widgets/mushaf_download_tile.dart';
import '../../../../core/utils/byte_formatter.dart';

String _fmtSize(int bytes) {
  // Binary units, matching what Android's own storage screen reports.
  return formatBytesBinary(bytes);
}

IconData _iconFor(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => Icons.menu_book_rounded,
  DownloadCategory.recitations => Icons.headphones_rounded,
  DownloadCategory.hadith => Icons.format_quote_rounded,
  DownloadCategory.books => Icons.auto_stories_rounded,
  DownloadCategory.adhan => Icons.campaign_rounded,
};

Color _colorFor(DownloadCategory c) => switch (c) {
  DownloadCategory.mushafs => AppColors.gold,
  DownloadCategory.recitations => AppColors.primarySoft,
  DownloadCategory.hadith => AppColors.info,
  DownloadCategory.books => AppColors.goldSoft,
  DownloadCategory.adhan => AppColors.success,
};

/// How much empty space every list in this screen keeps at its foot.
///
/// The «إصلاح التحميلات» button floats over all three tabs, and a floating
/// button does not reserve any space — so the last row of each list sat
/// underneath it. 48 for the button, 16 for its margin, and enough over that
/// for the row to read as finished rather than as something hidden.
const double kRepairButtonClearance = 96;

/// The unified offline-content hub: a storage overview + free-space per
/// category, then the mushaf and recitation download lists.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('downloads.title'.tr()),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: AppColors.gold,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelColor: AppColors.gold,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'downloads.tab_overview'.tr()),
              Tab(text: 'downloads.mushafs'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OverviewTab(), _MushafsTab()],
        ),
        floatingActionButton: const _RepairButton(),
      ),
    );
  }
}

// ── Overview / storage ─────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  Future<void> _confirmFree(
    BuildContext context,
    WidgetRef ref,
    DownloadCategory? category, // null = everything
  ) async {
    final label = category == null
        ? 'downloads.free_all'.tr()
        : category.labelKey.tr();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(label),
        content: Text('downloads.free_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('downloads.free'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (category != null) {
      await freeCategory(ref, category);
    } else {
      for (final c in DownloadCategory.values) {
        await freeCategory(ref, c);
      }
    }
  }

  /// Each overview row jumps to where that category is actually managed.
  /// Mushafs/recitations have their own tab right here on this screen — a
  /// local `TabController` switch. Hadith/books are managed on a completely
  /// different screen (`LibraryScreen`, its own bottom-nav tab), so pop back
  /// out to `AppShell` and request both the bottom-nav tab and
  /// `LibraryScreen`'s own inner tab. Adhan clips are managed on the Adhan
  /// settings screen.
  VoidCallback? _goToCategory(
    BuildContext context,
    WidgetRef ref,
    DownloadCategory category,
  ) {
    switch (category) {
      case DownloadCategory.mushafs:
        return () => DefaultTabController.of(context).animateTo(1);
      case DownloadCategory.recitations:
        // Whole-surah recitations and their player live in their own section
        // since 3.17.0 — not tied to a mushaf, not in this screen.
        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const QuranAudioScreen()),
        );
      case DownloadCategory.hadith:
        return () {
          // `popUntil(isFirst)` rather than a single `pop()`: this screen is
          // pushed from Settings, which is itself pushed from `AppShell`, so
          // popping once would leave `AppShell` buried and the tab switch
          // below invisible.
          Navigator.of(context).popUntil((route) => route.isFirst);
          ref.read(requestedTabProvider.notifier).state = AppTab.library;
          ref.read(requestedLibraryTabProvider.notifier).state = 1;
        };
      case DownloadCategory.books:
        return () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ref.read(requestedTabProvider.notifier).state = AppTab.library;
          ref.read(requestedLibraryTabProvider.notifier).state = 0;
        };
      case DownloadCategory.adhan:
        return () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdhanSettingsScreen(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storageSummaryProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(storageSummaryProvider)),
      data: (summary) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(storageSummaryProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, kRepairButtonClearance),
          children: [
            const _StorageAutoRefresh(),
            _StorageHero(
              summary: summary,
              onFreeAll: summary.totalBytes > 0
                  ? () => _confirmFree(context, ref, null)
                  : null,
            ),
            const _ActiveDownloadsPanel(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
              child: Text(
                'downloads.by_category'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final c in DownloadCategory.values)
              _CategoryCard(
                usage: summary.usage(c),
                share: summary.totalBytes == 0
                    ? 0
                    : summary.usage(c).bytes / summary.totalBytes,
                onFree: summary.usage(c).bytes > 0
                    ? () => _confirmFree(context, ref, c)
                    : null,
                onTap: _goToCategory(context, ref, c),
              ),
            const SizedBox(height: 16),
            _ArtifactList(
              ref: ref,
              categories: const [
                DownloadCategory.hadith,
                DownloadCategory.books,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Re-reads the totals while downloads move, so the overview is never a
/// snapshot of when the screen opened — «الـ UI بتاع التنزيلات يتحدث تلقائيًا
/// لكل تحميل». At most every two seconds: the totals walk six page folders.
class _StorageAutoRefresh extends ConsumerStatefulWidget {
  const _StorageAutoRefresh();

  @override
  ConsumerState<_StorageAutoRefresh> createState() => _StorageAutoRefreshState();
}

class _StorageAutoRefreshState extends ConsumerState<_StorageAutoRefresh> {
  StreamSubscription<List<DownloadTask>>? _sub;
  Timer? _timer;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) => _poke());
    QuranAudioLibrary.instance.addListener(_poke);
    MushafPageService.instance.changes.addListener(_poke);
  }

  void _poke() {
    if (_timer != null) return;
    final wait = const Duration(seconds: 2) - DateTime.now().difference(_last);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _timer = null;
      _last = DateTime.now();
      if (mounted) ref.invalidate(storageSummaryProvider);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    QuranAudioLibrary.instance.removeListener(_poke);
    MushafPageService.instance.changes.removeListener(_poke);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// «كارت التحميل الرئيسي في التنزيلات … يتكتب فيه بيتم تحميل إيه وكام في
/// المية». Every transfer in flight — a mushaf's pages, a surah of a
/// recitation, a book or pack — with its own bar and percentage; a tap goes to
/// where that download lives. Hidden when nothing is downloading.
class _ActiveDownloadsPanel extends ConsumerStatefulWidget {
  const _ActiveDownloadsPanel();

  @override
  ConsumerState<_ActiveDownloadsPanel> createState() => _ActiveDownloadsPanelState();
}

class _ActiveDownloadsPanelState extends ConsumerState<_ActiveDownloadsPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Page progress moves many times a second; once a second reads smoothly.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final editions = ref.watch(mushafEditionsProvider).valueOrNull ?? const [];
    final data = ref.watch(mushafDataProvider).valueOrNull;
    final service = MushafPageService.instance;
    final audio = QuranAudioLibrary.instance.activeDownloads;
    // A whole recitation is a hundred queued surahs; listing each one buried
    // the few actually transferring. The waiting ones are one count.
    final waiting = audio.where((d) => !d.running).length;
    final items = <(String, double?, VoidCallback)>[
      for (final e in editions)
        if (service.activeEditions.contains(e.id))
          (
            e.localizedName(locale),
            service.progressFor(e.id).fraction,
            () => DefaultTabController.of(context).animateTo(1),
          ),
      for (final d in audio)
        if (d.running)
        (
          '${d.entry.reciterName} — ${surahTitle(data, d.surah, locale)}',
          d.progress <= 0 ? null : d.progress,
          () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReciterScreen(
                  reciter: Mp3Reciter(
                    id: d.entry.reciterId,
                    name: d.entry.reciterName,
                    moshafs: [d.entry.moshaf],
                  ),
                ),
              )),
        ),
      for (final t in DownloadManager.instance.activeTasks)
        (t.title.isEmpty ? t.fileName : t.title, t.total == null ? null : t.progress, () {}),
    ];
    if (items.isEmpty && waiting == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.downloading_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Text('downloads.active_now'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              for (final (title, value, onTap) in items)
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(
                              value == null ? '…' : ltr('${(value * 100).round()}%'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.goldSoft, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        GoldProgressBar(value: value, height: 4, color: AppColors.gold),
                      ],
                    ),
                  ),
                ),
              if (waiting > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${'quran_audio.queued'.tr()} · ${ltr('$waiting')}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLow),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hero panel: total on-disk size over the lattice, with a stacked bar
/// showing how it splits across categories.
class _StorageHero extends StatelessWidget {
  final StorageSummary summary;
  final VoidCallback? onFreeAll;

  const _StorageHero({required this.summary, required this.onFreeAll});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalBytes;
    return IslamicPatternPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sd_storage_rounded,
                color: AppColors.gold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'downloads.storage_used'.tr(),
                style: const TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _fmtSize(total),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.textHigh,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'downloads.items'.plural(summary.totalItems),
            style: const TextStyle(color: AppColors.textLow, fontSize: 12),
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            // A single stacked rail rather than five separate bars: the point
            // is the *proportion* between categories, which only reads at a
            // glance when they share one axis.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final c in DownloadCategory.values)
                      if (summary.usage(c).bytes > 0)
                        Expanded(
                          flex: summary.usage(c).bytes,
                          child: ColoredBox(color: _colorFor(c)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final c in DownloadCategory.values)
                  if (summary.usage(c).bytes > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _colorFor(c),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.labelKey.tr(),
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onFreeAll,
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                label: Text(
                  'downloads.free_all'.tr(),
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryUsage usage;
  final double share;
  final VoidCallback? onFree;
  final VoidCallback? onTap;

  const _CategoryCard({
    required this.usage,
    required this.share,
    this.onFree,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _colorFor(usage.category);
    final empty = usage.bytes == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_iconFor(usage.category), color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usage.category.labelKey.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        empty
                            ? 'downloads.nothing_downloaded'.tr()
                            : '${usage.itemCount} · ${_fmtSize(usage.bytes)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (!empty) ...[
                        const SizedBox(height: 8),
                        GoldProgressBar(
                          value: share.clamp(0.0, 1.0),
                          height: 5,
                          color: accent,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onFree != null)
                  IconButton(
                    tooltip: 'downloads.free'.tr(),
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    onPressed: onFree,
                  )
                else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The per-item list for the DownloadManager-backed categories (hadith, books)
/// — title + on-disk size + individual delete.
class _ArtifactList extends StatefulWidget {
  final WidgetRef ref;
  final List<DownloadCategory> categories;
  const _ArtifactList({required this.ref, required this.categories});

  @override
  State<_ArtifactList> createState() => _ArtifactListState();
}

class _ArtifactListState extends State<_ArtifactList> {
  List<Map<String, dynamic>> _items = const [];
  final Map<String, int> _sizes = {};
  StreamSubscription<List<DownloadTask>>? _sub;
  Timer? _reload;

  @override
  void initState() {
    super.initState();
    _load();
    // A finished book or pack appears here without leaving the screen.
    _sub = DownloadManager.instance.stream.listen((_) {
      _reload ??= Timer(const Duration(seconds: 1), () {
        _reload = null;
        if (mounted) _load();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reload?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await DownloadManager.instance.registeredArtifacts();
    final wanted = {for (final c in widget.categories) ...c.managerCategories};
    final items = all.where((a) => wanted.contains(a['category'])).toList();
    final sizes = <String, int>{};
    for (final a in items) {
      sizes[a['id'] as String] = await DownloadManager.instance.artifactSize(
        a['id'] as String,
      );
    }
    if (mounted) {
      setState(() {
        _items = items;
        _sizes
          ..clear()
          ..addAll(sizes);
      });
    }
  }

  Future<void> _delete(String id) async {
    await DownloadManager.instance.remove(id);
    widget.ref.invalidate(storageSummaryProvider);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
          child: Text(
            'downloads.downloaded_items'.tr(),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final a in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.goldSoft,
                ),
                title: Text(
                  (a['title'] ?? a['fileName'] ?? '') as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _fmtSize(_sizes[a['id']] ?? 0),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.error,
                  ),
                  onPressed: () => _delete(a['id'] as String),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Mushafs ────────────────────────────────────────────────────────────────

class _MushafsTab extends ConsumerWidget {
  const _MushafsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editions = ref.watch(mushafEditionsProvider);
    return editions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(mushafEditionsProvider)),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, kRepairButtonClearance),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => MushafDownloadTile(edition: list[i]),
      ),
    );
  }
}

// ── Repair ─────────────────────────────────────────────────────────────────

/// Resumes everything that was left half-finished, across all three download
/// engines: the platform downloader's files, the whole-surah recitations, and
/// the mushaf pages.
///
/// The button used to call `DownloadManager.resumeAll()` alone, which only
/// knows about hadith, books and adhan clips. Recitations run through
/// [AyahAudioService] and mushaf pages through [MushafPageService], so the two
/// downloads most likely to be interrupted — a 286-file surah, a 604-page
/// edition — were exactly the two repair could never touch. It now asks all
/// three and reports what it actually restarted, rather than always claiming
/// success.
class _RepairButton extends ConsumerStatefulWidget {
  const _RepairButton();

  @override
  ConsumerState<_RepairButton> createState() => _RepairButtonState();
}

class _RepairButtonState extends ConsumerState<_RepairButton> {
  bool _busy = false;

  Future<void> _repair() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('downloads.repairing'.tr())),
    );

    var resumed = 0;
    var freed = 0;
    // Every step has its own deadline. The steps used to be awaited one after
    // another with none, so a single call that never returned — a platform
    // query on a wedged downloader — left the button spinning for good: «زر
    // الإصلاح مش عايزه stuck أبدًا».
    Future<T?> step<T>(Future<T> Function() run) async {
      try {
        return await run().timeout(const Duration(seconds: 12));
      } catch (_) {
        return null;
      }
    }

    try {
      // 0. Unjam first: leaked queue slots, then live transfers that stopped
      // moving. Everything below adds tasks to those queues.
      freed = await step(DownloadEngine.unjamQueues) ?? 0;
      freed += await step(DownloadEngine.cancelStalled) ?? 0;

      // 1. Hadith / books / adhan — the platform downloader's own queue.
      await step(DownloadManager.instance.resumeAll);
      // Let the cancellations above land before re-queueing.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // 2. Whole-surah recitations that were asked for and are not on disk.
      resumed += await step(QuranAudioLibrary.instance.repair) ?? 0;

      // 3. Mushaf editions: paused, stuck, or asked for and not complete.
      resumed += await step(() async {
            final editions = await ref.read(mushafEditionsProvider.future);
            return MushafPageService.instance.repairPartialEditions(editions);
          }) ??
          0;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    // Say what happened, including the case that used to read as "nothing".
    // «لا يوجد ما يُصلَح» after freeing eleven stuck slots is a lie the owner
    // had every reason to read as the button doing nothing.
    final parts = <String>[
      if (freed > 0) 'downloads.repair_unjammed'.tr(args: ['$freed']),
      if (resumed > 0) 'downloads.repair_resumed'.tr(args: ['$resumed']),
    ];
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          parts.isEmpty ? 'downloads.repair_nothing'.tr() : parts.join(' · '),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _busy ? null : _repair,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.build_rounded),
      label: Text('downloads.repair'.tr()),
      backgroundColor: AppColors.gold,
    );
  }
}
