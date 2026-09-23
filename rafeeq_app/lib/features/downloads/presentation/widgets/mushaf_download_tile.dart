import 'dart:async';
import '../../../../core/utils/digits.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/mushaf_edition.dart';
import '../../../quran/presentation/widgets/quran_book_cover_thumbnail.dart';
import 'mushaf_preview_sheet.dart';
import '../../../../core/utils/byte_formatter.dart';

String formatBytes(int bytes) => formatBytesBinary(bytes);

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
  // Read from the service's progress on every build. The tile used to keep
  // its own copy and only subscribed to a download it had started itself, so
  // one started by «إصلاح التحميلات», by the preview sheet, or resumed after a
  // launch never moved on screen: «التحميلات حالتها مش بتتحدث».
  bool get _busy => _progress.running;
  bool get _paused => _progress.paused;
  int get _done => _progress.done;

  late final PrefetchProgress _progress =
      _service.progressFor(widget.edition.id);

  @override
  void initState() {
    super.initState();
    _refresh();
    // The download runs on MushafPageService, not on this widget. If one is
    // already in flight (e.g. this tile was rebuilt after a tab switch),
    // re-attach to it instead of showing the Download button again.
    _progress.addListener(_onProgress);
  }

  bool _wasBusy = false;

  void _onProgress() {
    if (!mounted) return;
    final finished = _wasBusy && !_progress.running;
    _wasBusy = _progress.running;
    setState(() {});
    // The page count and size under the bar move with it, not only at the end.
    if (finished || _progress.done % 10 == 0) _refresh();
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgress);
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
    // Fire-and-forget: the job is owned by the service and _onProgress drives
    // this tile to completion, so it survives this widget being disposed.
    unawaited(
      _service.prefetchEdition(
        editionId: widget.edition.id,
        sourcePath: widget.edition.sourcePath,
        imagePath: widget.edition.imagePath,
        imageExt: widget.edition.imageExt,
        toPage: widget.edition.pages,
        title: widget.edition.localizedName(context.locale.languageCode),
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
            // The printing's real cover. Tapping the tile opens the preview
            // sheet, which shows the cover beside the edition's actual pages.
            QuranBookCoverThumbnail(
              edition: e,
              width: 62,
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
                          e.localizedName(context.locale.languageCode),
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
                  // ONE LINE, PINNED. «ثبّت سطر ٠ / ٦٠٤ صفحة محفوظة بجانب نسبة
                  // التحميل … يطلع وينزل مع الرقم». While downloading, this
                  // line used to carry the saved count AND a size that grew
                  // («· 1021.2 KB» -> «· 3.2 MB») and wrapped on a narrow tile,
                  // so the bar under it rose and fell as the numbers changed;
                  // and a second line under the bar counted the same pages
                  // again, differently. Now it is one row of fixed height with
                  // the saved pages at its start and the percentage at its end.
                  if (_busy)
                    _PinnedProgress(
                      saved: _cached,
                      total: total,
                      fraction: total == 0 ? 0 : (_done * 100 ~/ total) / 100,
                      paused: _paused,
                    )
                  else
                    Text(
                      complete
                          ? '${'downloads.offline_ready'.tr()} · ${formatBytes(_bytes)}'
                          : '${localizeDigits(ratio(_cached, total), uiLanguageCode)} ${'downloads.pages_cached'.tr()}'
                                '${_bytes > 0 ? ' · ${formatBytes(_bytes)}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        // `outline` is the palette's DIVIDER grey - it is meant
                        // for hairlines, not for a line someone has to read.
                        // «وصف مصحف المدينة في التنزيلات باهت اللون».
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: total == 0 ? null : _done / total,
                      color: _paused ? theme.colorScheme.outline : AppColors.gold,
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


/// The saved pages and the download percentage on one line that does not
/// move: a fixed height, one line on each side, tabular digits, and the
/// percentage laid over an invisible copy of its widest form («١٠٠٪»), so a
/// number that gains a digit cannot shift anything beside it.
class _PinnedProgress extends StatelessWidget {
  final int saved;
  final int total;

  /// 0..1, floored by the caller: a download at 603 of 604 is not «١٠٠٪».
  final double fraction;
  final bool paused;

  const _PinnedProgress({
    required this.saved,
    required this.total,
    required this.fraction,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String label(double f) =>
        '${(paused ? 'downloads.paused' : 'downloads.downloading').tr()}  '
        '${percentOf(f)}';
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${localizeDigits(ratio(saved, total), uiLanguageCode)} '
              '${'downloads.pages_cached'.tr()}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              Opacity(
                opacity: 0,
                child: Text(label(1), maxLines: 1, softWrap: false, style: style),
              ),
              Text(label(fraction), maxLines: 1, softWrap: false, style: style),
            ],
          ),
        ],
      ),
    );
  }
}
