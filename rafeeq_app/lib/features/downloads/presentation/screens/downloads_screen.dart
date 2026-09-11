import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/services/download_engine.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/services/recitation_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../data/downloads_controller.dart';
import '../../data/reciters_provider.dart';
import '../widgets/full_recitation_card.dart';
import '../widgets/playback_source_card.dart';
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
      length: 3,
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
              Tab(text: 'downloads.recitations'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_OverviewTab(), _MushafsTab(), _RecitationsTab()],
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
        return () => DefaultTabController.of(context).animateTo(2);
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
            _StorageHero(
              summary: summary,
              onFreeAll: summary.totalBytes > 0
                  ? () => _confirmFree(context, ref, null)
                  : null,
            ),
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

  @override
  void initState() {
    super.initState();
    _load();
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

// ── Recitations ────────────────────────────────────────────────────────────

class _RecitationsTab extends ConsumerStatefulWidget {
  const _RecitationsTab();

  @override
  ConsumerState<_RecitationsTab> createState() => _RecitationsTabState();
}

class _RecitationsTabState extends ConsumerState<_RecitationsTab> {
  /// Filters the 114-surah list — with سورة البقرة alone being a 286-file
  /// download, finding one surah by scrolling was the slowest part of using
  /// this screen.
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final reciters = ref.watch(recitersProvider);
    final selected = ref.watch(selectedReciterProvider);
    final mushaf = ref.watch(mushafDataProvider);

    return reciters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(recitersProvider)),
      data: (list) {
        final current = list.any((r) => r.identifier == selected)
            ? selected
            : list.first.identifier;
        return Column(
          children: [
            _ReciterPicker(reciters: list, selected: current),
            Expanded(
              child: mushaf.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
                data: (data) {
                  final surahs = _filter.isEmpty
                      ? data.surahs
                      : data.surahs
                            .where(
                              (s) =>
                                  s.nameAr.contains(_filter) ||
                                  s.nameEn.toLowerCase().contains(
                                    _filter.toLowerCase(),
                                  ) ||
                                  s.id.toString() == _filter,
                            )
                            .toList();
                  return Column(
                    children: [
                      FullRecitationCard(
                        key: ValueKey('full/$current'),
                        edition: current,
                        reciterName: list
                            .where((r) => r.identifier == current)
                            .map((r) => context.locale.languageCode == 'ar'
                                ? r.nameAr
                                : r.nameEn)
                            .firstOrNull,
                        data: data,
                        onFinished: () {},
                      ),
                      // Whose recitation is on the device, and where playback
                      // comes from — «ولو أكتر من قارئ يقوللي فلان وفلان
                      // ويحطهم في قايمة وأنا أختار أشغّل من التلاوة المحملة
                      // ولا من الـ API».
                      const PlaybackSourceCard(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _filter = v.trim()),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'downloads.find_surah'.tr(),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, kRepairButtonClearance),
                          itemCount: surahs.length,
                          itemBuilder: (_, i) => _SurahAudioTile(
                            key: ValueKey('$current/${surahs[i].id}'),
                            surahId: surahs[i].id,
                            surahName: surahs[i].nameAr,
                            ayahCount: surahs[i].ayahsCount,
                            edition: current,
                            data: data,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The reciter chooser, plus an honest note about where this reciter's audio
/// comes from — a reciter with a verified everyayah mirror downloads faster
/// and resumes properly, and saying so beats letting the user find out.
class _ReciterPicker extends ConsumerWidget {
  final List<Reciter> reciters;
  final String selected;

  const _ReciterPicker({required this.reciters, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mirrored = RecitationSource.hasVerifiedMirror(selected);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected,
                  icon: const Icon(Icons.expand_more_rounded),
                  items: [
                    for (final r in reciters)
                      DropdownMenuItem(
                        value: r.identifier,
                        child: Row(
                          children: [
                            Icon(
                              Icons.record_voice_over_rounded,
                              size: 18,
                              color: RecitationSource.hasVerifiedMirror(
                                    r.identifier,
                                  )
                                  ? AppColors.gold
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.displayName(context.locale.languageCode),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(selectedReciterProvider.notifier).select(v);
                    }
                  },
                ),
              ),
              Row(
                children: [
                  Icon(
                    mirrored ? Icons.bolt_rounded : Icons.cloud_outlined,
                    size: 14,
                    color: mirrored ? AppColors.gold : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      mirrored
                          ? 'downloads.source_verified'.tr()
                          : 'downloads.source_cdn'.tr(),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahAudioTile extends StatefulWidget {
  final int surahId;
  final String surahName;
  final int ayahCount;
  final String edition;
  final MushafData data;

  const _SurahAudioTile({
    super.key,
    required this.surahId,
    required this.surahName,
    required this.ayahCount,
    required this.edition,
    required this.data,
  });

  @override
  State<_SurahAudioTile> createState() => _SurahAudioTileState();
}

class _SurahAudioTileState extends State<_SurahAudioTile> {
  final _audio = AyahAudioService.instance;

  @override
  void initState() {
    super.initState();
    // Seed this surah's live notifier from disk (won't clobber an in-flight
    // download — see refreshSurahJob). All progress is then read straight from
    // the service's notifier, so scrolling this tile off-screen and back, or
    // leaving and reopening the screen, never loses the live progress.
    _audio.refreshSurahJob(
      widget.edition,
      widget.surahId,
      widget.ayahCount,
      widget.data.repo,
    );
  }

  void _start() => _audio.startSurahDownload(
    edition: widget.edition,
    surah: widget.surahId,
    ayahCount: widget.ayahCount,
    repo: widget.data.repo,
    title: '${widget.surahId}. ${widget.surahName}',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ValueListenableBuilder<RecitationJob>(
      valueListenable: _audio.surahJob(widget.edition, widget.surahId),
      builder: (context, job, _) {
        final complete = job.isComplete;
        final downloading = job.status == RecitationJobStatus.downloading;
        final paused = job.status == RecitationJobStatus.paused;
        final failed = job.status == RecitationJobStatus.failed;
        final active = downloading || paused;
        final showBar = active || (job.done > 0 && !complete);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: complete
                ? AppColors.success.withValues(alpha: 0.10)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: complete || active ? null : _start,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(
                  children: [
                    // The surah number in a bordered rosette, the way a
                    // mushaf marks its ayah numbers.
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        '${widget.surahId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.goldSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.surahName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (showBar) ...[
                            GoldProgressBar(
                              value: job.total == 0 ? null : job.fraction,
                              height: 6,
                              color: paused ? scheme.outline : AppColors.gold,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${job.done} / ${job.total}'
                              '${paused ? '  ·  ${'downloads.paused'.tr()}' : ''}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ] else
                            Text(
                              complete
                                  ? 'downloads.offline_ready'.tr()
                                  : failed
                                  ? 'downloads.incomplete_tap_retry'.tr()
                                  : 'quran.ayahs'.plural(widget.ayahCount),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: complete
                                    ? AppColors.success
                                    : failed
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (complete)
                      const Padding(
                        padding: EdgeInsets.only(right: 8, left: 8),
                        child: Icon(
                          Icons.offline_pin_rounded,
                          color: AppColors.success,
                        ),
                      )
                    else if (active)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: paused
                                ? 'downloads.resume'.tr()
                                : 'downloads.pause'.tr(),
                            icon: Icon(
                              paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                            ),
                            onPressed: () {
                              if (paused) {
                                _audio.resumeDownload(
                                  widget.edition,
                                  widget.surahId,
                                );
                                // Resume re-scans disk and asks for whatever
                                // is still missing — see pauseDownload's doc.
                                _start();
                              } else {
                                _audio.pauseDownload(
                                  widget.edition,
                                  widget.surahId,
                                );
                              }
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'downloads.cancel'.tr(),
                            icon: const Icon(Icons.stop_circle_outlined),
                            onPressed: () => _audio.cancelDownload(
                              widget.edition,
                              widget.surahId,
                            ),
                          ),
                        ],
                      )
                    else
                      IconButton(
                        tooltip: 'downloads.download'.tr(),
                        icon: const Icon(Icons.download_rounded),
                        color: AppColors.gold,
                        onPressed: _start,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


// ── Repair ─────────────────────────────────────────────────────────────────

/// Resumes everything that was left half-finished, across all three download
/// engines.
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
    try {
      // 0. UNJAM FIRST. Everything below adds tasks to the two queues, and a
      // queue whose slots have leaked accepts them and never enqueues one —
      // which is exactly why the owner reported this button «ولا بيعمل اي
      // حاجة نهائي». See `DownloadEngine.releaseStuckTasks` for the leak.
      freed = await DownloadEngine.unjamQueues();

      // 1. Hadith / books / adhan — the platform downloader's own queue.
      await DownloadManager.instance.resumeAll();

      // 2. Recitations — every reciter with files on disk, not only the one
      // currently selected. A surah left half-finished under a reciter he had
      // since switched away from was invisible to repair, and the button said
      // «لا يوجد ما يُصلَح» while the storage screen still showed it.
      try {
        final repo = await ref.read(quranRepositoryProvider.future);
        final data = await ref.read(mushafDataProvider.future);
        final editions = <String>{
          ref.read(selectedReciterProvider),
          ...await AyahAudioService.instance.editionsWithFiles(),
        };
        for (final edition in editions) {
          resumed += await AyahAudioService.instance.repairPartialDownloads(
            edition: edition,
            surahs: data.surahs,
            repo: repo,
          );
        }
      } catch (_) {
        // A missing Quran DB just means there is nothing to repair here.
      }

      // 3. Mushaf editions with a partial page cache.
      try {
        final editions = await ref.read(mushafEditionsProvider.future);
        resumed +=
            await MushafPageService.instance.repairPartialEditions(editions);
      } catch (_) {}
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
