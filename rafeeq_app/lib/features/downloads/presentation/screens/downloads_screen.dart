import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../data/downloads_controller.dart';
import '../../data/reciters_provider.dart';

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The unified offline-content hub (P2‑5): a storage overview + free-space
/// per category, then the mushaf and recitation download lists.
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
            labelColor: AppColors.gold,
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

  /// P3‑25: each overview row jumps to where that category is actually
  /// managed. Mushafs/recitations have their own tab right here on this
  /// screen — a local `TabController` switch. Hadith/books are managed on
  /// a completely different screen (`LibraryScreen`, its own bottom-nav
  /// tab) — pop back out to `AppShell` and request both the bottom-nav tab
  /// and `LibraryScreen`'s own inner tab (same two-provider seam
  /// `tab_request_provider.dart` documents). Adhan has no download-browsing
  /// UI anywhere in the app yet, so its row stays inert rather than
  /// pointing at a destination that doesn't exist.
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
          Navigator.of(context).pop();
          ref.read(requestedTabProvider.notifier).state = AppTab.library;
          ref.read(requestedLibraryTabProvider.notifier).state = 1;
        };
      case DownloadCategory.books:
        return () {
          Navigator.of(context).pop();
          ref.read(requestedTabProvider.notifier).state = AppTab.library;
          ref.read(requestedLibraryTabProvider.notifier).state = 0;
        };
      case DownloadCategory.adhan:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storageSummaryProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(storageSummaryProvider)),
      data: (summary) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(storageSummaryProvider),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('downloads.storage_used'.tr(),
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      _fmtSize(summary.totalBytes),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    if (summary.totalBytes > 0) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () => _confirmFree(context, ref, null),
                          icon: Icon(Icons.delete_sweep_outlined,
                              size: 18, color: scheme.error),
                          label: Text('downloads.free_all'.tr(),
                              style: TextStyle(color: scheme.error)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final c in DownloadCategory.values)
              _CategoryRow(
                usage: summary.usage(c),
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

class _CategoryRow extends StatelessWidget {
  final CategoryUsage usage;
  final VoidCallback? onFree;
  final VoidCallback? onTap;
  const _CategoryRow({required this.usage, this.onFree, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      onTap: onTap,
      leading: Icon(switch (usage.category) {
        DownloadCategory.mushafs => Icons.menu_book_outlined,
        DownloadCategory.recitations => Icons.headphones_outlined,
        DownloadCategory.hadith => Icons.format_quote_outlined,
        DownloadCategory.books => Icons.auto_stories_outlined,
        DownloadCategory.adhan => Icons.campaign_outlined,
      }, size: 20, color: AppColors.gold),
      title: Text(usage.category.labelKey.tr()),
      subtitle: Text(
        usage.bytes == 0
            ? 'downloads.nothing_downloaded'.tr()
            : '${usage.itemCount} · ${_fmtSize(usage.bytes)}',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: onFree == null
          ? null
          : IconButton(
              tooltip: 'downloads.free'.tr(),
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: onFree,
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
    final wanted = {
      for (final c in widget.categories) ...c.managerCategories,
    };
    final items =
        all.where((a) => wanted.contains(a['category'])).toList();
    final sizes = <String, int>{};
    for (final a in items) {
      sizes[a['id'] as String] =
          await DownloadManager.instance.artifactSize(a['id'] as String);
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
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
          child: Text('downloads.downloaded_items'.tr(),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ),
        for (final a in _items)
          Card(
            child: ListTile(
              dense: true,
              title: Text((a['title'] ?? a['fileName'] ?? '') as String),
              subtitle: Text(_fmtSize(_sizes[a['id']] ?? 0),
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _delete(a['id'] as String),
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
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(mushafEditionsProvider)),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MushafDownloadTile(edition: list[i]),
      ),
    );
  }
}

class _MushafDownloadTile extends StatefulWidget {
  final MushafEdition edition;
  const _MushafDownloadTile({required this.edition});

  @override
  State<_MushafDownloadTile> createState() => _MushafDownloadTileState();
}

class _MushafDownloadTileState extends State<_MushafDownloadTile> {
  final _service = MushafPageService.instance;
  int _cached = 0;
  int _bytes = 0;
  bool _busy = false;
  bool _paused = false;
  int _done = 0;

  PrefetchProgress? _progress;

  @override
  void initState() {
    super.initState();
    _refresh();
    // The download runs on MushafPageService, not on this widget. If one is
    // already in flight (e.g. this tile was rebuilt after a tab switch),
    // re-attach to it instead of showing the Download button again.
    if (_service.isPrefetching(widget.edition.id)) {
      _busy = true;
      _bind();
      _done = _progress!.done;
    }
  }

  void _bind() {
    _progress = _service.progressFor(widget.edition.id);
    _progress!.addListener(_onProgress);
  }

  void _unbind() {
    _progress?.removeListener(_onProgress);
    _progress = null;
  }

  void _onProgress() {
    if (!mounted) return;
    final p = _progress!;
    setState(() {
      _done = p.done;
      _paused = p.paused;
    });
    if (!p.running) {
      _unbind();
      setState(() {
        _busy = false;
        _paused = false;
      });
      _refresh();
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  Future<void> _refresh() async {
    final pages = await _service.cachedPages(widget.edition.id);
    final size = await _service.cacheSizeBytes(widget.edition.id);
    if (mounted) {
      setState(() {
        _cached = pages.length;
        _bytes = size;
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _done = 0;
    });
    _bind();
    // Fire-and-forget: the job is owned by the service and _onProgress drives
    // this tile to completion, so it survives this widget being disposed.
    unawaited(_service.prefetchEdition(
      editionId: widget.edition.id,
      sourcePath: widget.edition.sourcePath,
      title: widget.edition.nameAr,
    ));
  }

  Future<void> _delete() async {
    await _service.clearCache(widget.edition.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.edition;
    final total = e.pages;
    final complete = _cached >= total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.nameAr,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (complete)
                Icon(Icons.offline_pin, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            complete
                ? '${'downloads.offline_ready'.tr()} · ${_fmtSize(_bytes)}'
                : '$_cached / $total ${'downloads.pages_cached'.tr()}'
                    '${_bytes > 0 ? ' · ${_fmtSize(_bytes)}' : ''}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          if (_busy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: total == 0 ? null : _done / total,
              color: _paused ? theme.colorScheme.outline : AppColors.gold,
            ),
            const SizedBox(height: 6),
            Text(
              _paused
                  ? '${'downloads.paused'.tr()}  $_done / $total'
                  : '${'downloads.downloading'.tr()}  $_done / $total',
              style: theme.textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (_busy) ...[
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (_paused) {
                      _service.resumePrefetch(e.id);
                    } else {
                      _service.pausePrefetch(e.id);
                    }
                  }),
                  icon: Icon(
                      _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 18),
                  label: Text(_paused
                      ? 'downloads.resume'.tr()
                      : 'downloads.pause'.tr()),
                ),
                TextButton.icon(
                  onPressed: () => _service.cancelPrefetch(e.id),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text('downloads.cancel'.tr()),
                ),
              ] else
                FilledButton.tonalIcon(
                  onPressed: complete ? null : _download,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text('downloads.download'.tr()),
                ),
              const Spacer(),
              if (_cached > 0 && !_busy)
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text('downloads.delete'.tr()),
                ),
            ],
          ),
        ],
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
  // P3‑27: bumped once a "download all" run finishes (or is cancelled) so
  // the per-surah tiles below — each a `_SurahAudioTile` that only checks
  // its own on-disk state once in `initState` — remount and pick up the
  // real file state instead of sitting stale on "not downloaded" after a
  // bulk run just changed the files out from under them.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final reciters = ref.watch(recitersProvider);
    final selected = ref.watch(selectedReciterProvider);
    final mushaf = ref.watch(mushafDataProvider);

    return reciters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(recitersProvider)),
      data: (list) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'downloads.choose_reciter'.tr(),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: list.any((r) => r.identifier == selected)
                      ? selected
                      : list.first.identifier,
                  items: [
                    for (final r in list)
                      DropdownMenuItem(
                        value: r.identifier,
                        child: Text(
                          r.nameAr.isEmpty ? r.nameEn : r.nameAr,
                          overflow: TextOverflow.ellipsis,
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
            ),
          ),
          Expanded(
            child: mushaf.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(mushafDataProvider)),
              data: (data) => Column(
                children: [
                  _FullRecitationCard(
                    key: ValueKey('full/$selected'),
                    edition: selected,
                    data: data,
                    onFinished: () => setState(() => _generation++),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: data.surahs.length,
                      itemBuilder: (_, i) => _SurahAudioTile(
                        key: ValueKey(
                            '$selected/${data.surahs[i].id}/$_generation'),
                        surahId: data.surahs[i].id,
                        surahName: data.surahs[i].nameAr,
                        ayahCount: data.surahs[i].ayahsCount,
                        edition: selected,
                        data: data,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// P3‑27: "خليه في كارت صغير تحت القايمة المنسدلة مباشرة" (a small card
/// right under the reciter dropdown) offering to download the reciter's
/// **whole** recitation in one action — before this, downloading was only
/// possible one surah at a time from the list below. Downloads
/// sequentially (not all 114 at once — kinder to the device and the
/// network) and reuses `AyahAudioService.downloadSurah`'s own per-ayah
/// resume logic, so re-running it after a partial/cancelled run just picks
/// up where it left off instead of re-downloading anything already on disk.
class _FullRecitationCard extends StatefulWidget {
  final String edition;
  final MushafData data;
  final VoidCallback onFinished;
  const _FullRecitationCard({
    super.key,
    required this.edition,
    required this.data,
    required this.onFinished,
  });

  @override
  State<_FullRecitationCard> createState() => _FullRecitationCardState();
}

class _FullRecitationCardState extends State<_FullRecitationCard> {
  final _audio = AyahAudioService.instance;
  bool _checkingStatus = true;
  bool _running = false;
  bool _cancelled = false;
  int _doneSurahs = 0;
  int _totalSurahs = 0;
  int? _currentSurahId;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant _FullRecitationCard old) {
    super.didUpdateWidget(old);
    if (old.edition != widget.edition) {
      // Switched reciters mid-run: stop the old loop and, if a file for the
      // old edition was actually in flight, cancel it immediately rather
      // than letting it finish in the background.
      _cancelled = true;
      final id = _currentSurahId;
      if (id != null) _audio.cancelDownload(old.edition, id);
      _running = false;
      _currentSurahId = null;
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _checkingStatus = true);
    final surahs = widget.data.surahs;
    var done = 0;
    for (final s in surahs) {
      final p = await _audio.surahProgress(
          s.id, s.ayahsCount, widget.data.repo,
          edition: widget.edition);
      if (p.isComplete) done++;
    }
    if (!mounted) return;
    setState(() {
      _doneSurahs = done;
      _totalSurahs = surahs.length;
      _checkingStatus = false;
    });
  }

  Future<void> _downloadAll() async {
    setState(() {
      _running = true;
      _cancelled = false;
    });
    final surahs = widget.data.surahs;
    for (var i = 0; i < surahs.length; i++) {
      if (_cancelled) break;
      final s = surahs[i];
      if (!mounted) return;
      setState(() => _currentSurahId = s.id);
      await _audio.downloadSurah(
        surah: s.id,
        ayahCount: s.ayahsCount,
        repo: widget.data.repo,
        edition: widget.edition,
        title: '${s.id}. ${s.nameAr}',
      );
      if (!mounted) return;
      setState(() => _doneSurahs = i + 1);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _currentSurahId = null;
    });
    widget.onFinished();
  }

  void _cancel() {
    setState(() => _cancelled = true);
    final id = _currentSurahId;
    if (id != null) _audio.cancelDownload(widget.edition, id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_checkingStatus) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: LinearProgressIndicator(),
      );
    }

    final complete = _totalSurahs > 0 && _doneSurahs >= _totalSurahs;

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              complete
                  ? Icons.offline_pin
                  : Icons.download_for_offline_outlined,
              color: complete ? AppColors.success : AppColors.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('downloads.download_all_recitation'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  if (_running)
                    LinearProgressIndicator(
                      value: _totalSurahs == 0 ? null : _doneSurahs / _totalSurahs,
                      color: AppColors.gold,
                    )
                  else
                    Text(
                      complete
                          ? 'downloads.offline_ready'.tr()
                          : '$_doneSurahs / $_totalSurahs ${'quran.surah'.tr()}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!complete)
              _running
                  ? IconButton(
                      tooltip: 'downloads.cancel'.tr(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: _cancel,
                    )
                  : FilledButton.tonal(
                      onPressed: _downloadAll,
                      child: Text('downloads.download'.tr()),
                    ),
          ],
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
  RecitationProgress _progress = const RecitationProgress(0, 0);
  bool _busy = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await _audio.surahProgress(
      widget.surahId,
      widget.ayahCount,
      widget.data.repo,
      edition: widget.edition,
    );
    if (mounted) setState(() => _progress = p);
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    await _audio.downloadSurah(
      surah: widget.surahId,
      ayahCount: widget.ayahCount,
      repo: widget.data.repo,
      edition: widget.edition,
      title: '${widget.surahId}. ${widget.surahName}',
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _paused = false;
      });
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _audio.pauseDownload(widget.edition, widget.surahId);
      } else {
        _audio.resumeDownload(widget.edition, widget.surahId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = _progress.isComplete;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text('${widget.surahId}. ${widget.surahName}'),
      subtitle: _busy || (_progress.done > 0 && !complete)
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: _progress.fraction,
                color: _paused ? theme.colorScheme.outline : AppColors.gold,
              ),
            )
          : Text(
              complete
                  ? 'downloads.offline_ready'.tr()
                  : '${widget.ayahCount} ${'quran.ayahs'.tr()}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
      trailing: complete
          ? Icon(Icons.offline_pin, color: AppColors.success)
          : _busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: _paused
                          ? 'downloads.resume'.tr()
                          : 'downloads.pause'.tr(),
                      icon: Icon(_paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                      onPressed: _togglePause,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'downloads.cancel'.tr(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: () => _audio.cancelDownload(
                          widget.edition, widget.surahId),
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: _download,
                ),
    );
  }
}
