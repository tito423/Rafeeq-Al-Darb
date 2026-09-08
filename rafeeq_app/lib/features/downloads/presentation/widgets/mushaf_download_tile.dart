import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran/presentation/widgets/mushaf_3d_thumbnail.dart';
import 'mushaf_preview_sheet.dart';

Color _coverColor(String id) {
  switch (id) {
    case 'hafs_kfqc': return const Color(0xFF1E3A5F); // Blue
    case 'tajweed_color': return const Color(0xFF8B0000); // Dark Red
    case 'warsh': return const Color(0xFF12294F); // Royal navy
    case 'qaloon': return const Color(0xFF5A1E2B); // Wine maroon
    case 'shamarly': return const Color(0xFF1C1C1C); // Black & gold board
    case 'madinah_gold': return const Color(0xFF5C4310); // Antique gold
    case 'indopak_tajweed': return const Color(0xFF0B4A47); // Teal
    default: return const Color(0xFF1E3A5F);
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// One mushaf edition's real offline-download card: shows actual cached-page
/// count read from disk (never a guess), a تحميل/إيقاف مؤقت/إلغاء row wired
/// to [MushafPageService]'s real prefetch job, and a delete action once
/// something is cached.
///
/// Originally private to `downloads_screen.dart`; pulled out to a public
/// widget (P3‑21) so the first-run onboarding screen can offer the exact
/// same real download affordance for its "essential" mushaf-edition
/// download (G4/G5), instead of a second, thinner copy.
class MushafDownloadTile extends StatefulWidget {
  final MushafEdition edition;
  const MushafDownloadTile({super.key, required this.edition});

  @override
  State<MushafDownloadTile> createState() => _MushafDownloadTileState();
}

class _MushafDownloadTileState extends State<MushafDownloadTile> {
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
    final pages = await _service.cachedPages(widget.edition.id,
        totalPages: widget.edition.pages);
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
    unawaited(
      _service.prefetchEdition(
        editionId: widget.edition.id,
        sourcePath: widget.edition.sourcePath,
        imagePath: widget.edition.imagePath,
        imageExt: widget.edition.imageExt,
        toPage: widget.edition.pages,
        title: widget.edition.nameAr,
      ),
    );
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

    return InkWell(
      onTap: () => MushafPreviewSheet.show(context, e),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D Leather Cover rendering for the edition.
            Mushaf3DThumbnail(
              coverColor: _coverColor(e.id),
              width: 52,
              height: 70,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.nameAr,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (complete)
                        Icon(
                          Icons.offline_pin,
                          color: AppColors.success,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complete
                        ? '${'downloads.offline_ready'.tr()} · ${formatBytes(_bytes)}'
                        : '$_cached / $total ${'downloads.pages_cached'.tr()}'
                              '${_bytes > 0 ? ' · ${formatBytes(_bytes)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                            _paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _paused
                                ? 'downloads.resume'.tr()
                                : 'downloads.pause'.tr(),
                          ),
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
            ),
          ],
        ),
      ),
    );
  }
}
