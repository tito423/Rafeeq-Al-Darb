import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../data/reciters_provider.dart';

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Offline content: whole mushafs and ayah-by-ayah recitations.
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
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            tabs: [
              Tab(text: 'downloads.mushafs'.tr()),
              Tab(text: 'downloads.recitations'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MushafsTab(), _RecitationsTab()],
        ),
      ),
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
      error: (_, _) => Center(child: Text('errors.generic'.tr())),
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
    setState(() => _done = p.done);
    if (!p.running) {
      _unbind();
      setState(() => _busy = false);
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
              color: AppColors.gold,
            ),
            const SizedBox(height: 6),
            Text('${'downloads.downloading'.tr()}  $_done / $total',
                style: theme.textTheme.labelSmall),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (_busy)
                TextButton.icon(
                  onPressed: () => _service.cancelPrefetch(e.id),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text('downloads.cancel'.tr()),
                )
              else
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

class _RecitationsTab extends ConsumerWidget {
  const _RecitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciters = ref.watch(recitersProvider);
    final selected = ref.watch(selectedReciterProvider);
    final mushaf = ref.watch(mushafDataProvider);

    return reciters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('errors.generic'.tr())),
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
              error: (_, _) => Center(child: Text('errors.generic'.tr())),
              data: (data) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: data.surahs.length,
                itemBuilder: (_, i) => _SurahAudioTile(
                  key: ValueKey('$selected/${data.surahs[i].id}'),
                  surahId: data.surahs[i].id,
                  surahName: data.surahs[i].nameAr,
                  ayahCount: data.surahs[i].ayahsCount,
                  edition: selected,
                  data: data,
                ),
              ),
            ),
          ),
        ],
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
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (mounted) setState(() => _busy = false);
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
                color: AppColors.gold,
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
              ? IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: () => _audio.cancelDownload(
                      widget.edition, widget.surahId),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: _download,
                ),
    );
  }
}
