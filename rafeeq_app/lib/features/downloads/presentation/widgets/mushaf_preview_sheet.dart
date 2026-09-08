import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran/presentation/widgets/quran_book_cover_thumbnail.dart';

/// A luxury preview BottomSheet for a mushaf edition, inspired by Quran Flash.
///
/// Shows:
/// 1. The edition name, riwayah, and page/ayah counts.
/// 2. A "book spread" visual: the luxury leather cover on the right, and
///    two facing pages (page 1 and page 2) on the left, rendered from the
///    edition's own real SVG or JPG source — so what you see is exactly
///    what you'll download.
/// 3. Download / delete actions at the bottom.
class MushafPreviewSheet extends StatefulWidget {
  final MushafEdition edition;

  const MushafPreviewSheet({super.key, required this.edition});

  static Future<void> show(BuildContext context, MushafEdition edition) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MushafPreviewSheet(edition: edition),
      );

  @override
  State<MushafPreviewSheet> createState() => _MushafPreviewSheetState();
}

class _MushafPreviewSheetState extends State<MushafPreviewSheet> {
  final _service = MushafPageService.instance;

  // Preview page futures (SVG editions only).
  late Future<String?> _page1;
  late Future<String?> _page2;

  // Download state.
  int _cached = 0;
  int _bytes = 0;
  bool _busy = false;
  bool _paused = false;
  int _done = 0;
  PrefetchProgress? _progress;

  @override
  void initState() {
    super.initState();
    if (!widget.edition.isRaster) {
      _page1 = _loadSvg(1);
      _page2 = _loadSvg(2);
    }
    _refresh();

    if (_service.isPrefetching(widget.edition.id)) {
      _busy = true;
      _bind();
      _done = _progress!.done;
    }
  }

  Future<String?> _loadSvg(int page) async {
    try {
      return await _service.svgForPage(
        editionId: widget.edition.id,
        sourcePath: widget.edition.sourcePath,
        page: page,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Download state management (mirrors MushafDownloadTile) ────────────

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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final e = widget.edition;
    final total = e.pages;
    final complete = _cached >= total;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
          ),
          child: Column(
            children: [
              // Drag handle.
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title.
              Text(
                'downloads.preview_title'.tr(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              // Mushaf info row.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      e.nameAr,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFamily: 'AmiriQuran',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.riwayahAr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${e.pages} ${'quran.pages_count'.tr()} · '
                      '${e.ayahs} ${'quran.ayahs_count'.tr()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Book spread: cover + two facing pages ────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _BookSpread(
                    edition: e,
                    isDark: isDark,
                    page1Future: e.isRaster ? null : _page1,
                    page2Future: e.isRaster ? null : _page2,
                  ),
                ),
              ),
              // Sample-pages label.
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'downloads.page_preview_note'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const Divider(height: 1),
              // ── Download status + actions ────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    if (_busy) ...[
                      LinearProgressIndicator(
                        value: total == 0 ? null : _done / total,
                        color:
                            _paused ? theme.colorScheme.outline : AppColors.gold,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _paused
                            ? '${'downloads.paused'.tr()}  $_done / $total'
                            : '${'downloads.downloading'.tr()}  $_done / $total',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _service.cancelPrefetch(e.id),
                            icon: const Icon(Icons.stop_circle_outlined,
                                size: 18),
                            label: Text('downloads.cancel'.tr()),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Status line.
                      if (complete)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.offline_pin,
                                color: AppColors.success, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${'downloads.already_downloaded'.tr()} · ${_formatBytes(_bytes)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else if (_cached > 0)
                        Text(
                          '$_cached / $total ${'downloads.pages_cached'.tr()}'
                          '${_bytes > 0 ? ' · ${_formatBytes(_bytes)}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Action buttons.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: complete ? null : _download,
                            icon: Icon(
                              complete
                                  ? Icons.check_circle_outline
                                  : Icons.download_rounded,
                              size: 20,
                            ),
                            label: Text(
                              complete
                                  ? 'downloads.already_downloaded'.tr()
                                  : 'downloads.download_full'.tr(),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  complete ? AppColors.success : AppColors.gold,
                              foregroundColor: complete
                                  ? Colors.white
                                  : const Color(0xFF3A2A08),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              textStyle: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_cached > 0 && !complete) ...[
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: _delete,
                              icon:
                                  const Icon(Icons.delete_outline, size: 18),
                              label: Text('downloads.delete'.tr()),
                            ),
                          ],
                        ],
                      ),
                      if (complete) ...[
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _delete,
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: theme.colorScheme.error),
                          label: Text(
                            'downloads.delete'.tr(),
                            style:
                                TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Book Spread: cover + two facing pages ───────────────────────────────────

/// The visual centrepiece: a luxurious leather book-cover on the far right,
/// then two open pages (page 1 on the right, page 2 on the left) arranged
/// like a real Mushaf opened to its first spread. A subtle spine divider and
/// drop shadow complete the 3-D book feel.
class _BookSpread extends StatelessWidget {
  final MushafEdition edition;
  final bool isDark;
  final Future<String?>? page1Future; // null for raster editions
  final Future<String?>? page2Future;

  const _BookSpread({
    required this.edition,
    required this.isDark,
    this.page1Future,
    this.page2Future,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute sizes so the three items (cover + 2 pages) fit nicely.
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        // Cover takes ~25% of the width, pages share the remaining 75%.
        final coverWidth = totalWidth * 0.22;
        final pagesAreaWidth = totalWidth - coverWidth - 16; // 16 for gaps
        final pageWidth = (pagesAreaWidth - 4) / 2; // 4 for spine
        // Height constrained by aspect ratio (3:4) and available height.
        final pageHeight = (pageWidth * 4 / 3).clamp(0.0, totalHeight * 0.92);

        return Center(
          child: Directionality(
            textDirection: ui.TextDirection.rtl, // RTL: cover → page 1 → page 2
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // ── Leather cover ──
              QuranBookCoverThumbnail(
                edition: edition,
                width: coverWidth,
              ),
              const SizedBox(width: 10),
              // ── Open book (page 1 right, page 2 left) ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Directionality(
                    textDirection: ui.TextDirection.rtl,
                    child: Row(
                      children: [
                      // Page 1 (right side in RTL).
                      _PreviewPage(
                        edition: edition,
                        page: 1,
                        svgFuture: page1Future,
                        width: pageWidth,
                        height: pageHeight,
                        isDark: isDark,
                      ),
                      // Spine divider.
                      Container(
                        width: 3,
                        height: pageHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.20),
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.20),
                            ],
                          ),
                        ),
                      ),
                      // Page 2 (left side in RTL).
                      _PreviewPage(
                        edition: edition,
                        page: 2,
                        svgFuture: page2Future,
                        width: pageWidth,
                        height: pageHeight,
                        isDark: isDark,
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

/// A single preview page inside the book spread.
class _PreviewPage extends StatelessWidget {
  final MushafEdition edition;
  final int page;
  final Future<String?>? svgFuture;
  final double width;
  final double height;
  final bool isDark;

  const _PreviewPage({
    required this.edition,
    required this.page,
    this.svgFuture,
    required this.width,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.nightSurface : AppColors.paper;
    final ink = isDark ? AppColors.paperDark : AppColors.ink;

    if (edition.isRaster) {
      return Container(
        width: width,
        height: height,
        color: bgColor,
        child: CachedNetworkImage(
          imageUrl: edition.imagePageUrl(page),
          fit: BoxFit.contain,
          memCacheWidth: (width * 2.5).round(),
          placeholder: (_, _) => _PagePlaceholder(width: width, height: height),
          errorWidget: (_, _, _) =>
              _PagePlaceholder(width: width, height: height, isError: true),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: svgFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return Container(
            width: width,
            height: height,
            color: bgColor,
            child: _PagePlaceholder(
              width: width,
              height: height,
              isError: snap.connectionState == ConnectionState.done,
            ),
          );
        }
        return Container(
          width: width,
          height: height,
          color: bgColor,
          child: SvgPicture.string(
            snap.data!,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
          ),
        );
      },
    );
  }
}

/// Placeholder shown while a preview page is loading.
class _PagePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final bool isError;

  const _PagePlaceholder({
    required this.width,
    required this.height,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: isError
            ? Icon(
                Icons.image_not_supported_outlined,
                size: width * 0.25,
                color: AppColors.gold.withValues(alpha: 0.4),
              )
            : SizedBox(
                width: width * 0.2,
                height: width * 0.2,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }
}
