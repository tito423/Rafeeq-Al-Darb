import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart' show formatBytes;
import '../../../../core/utils/digits.dart' show trn, percentOf;

/// One downloadable pack, offered on the first-run page.
///
/// «والاوبشنز اللي ممكن يحملها المستخدم في نفس الصفحة بدل مايتفاجأ بيها جوه
/// مش موجودة زي التفاسير مثلا». The first run offered the paper mushaf and
/// nothing else, so a reader met علوم القرآن for the first time as a
/// download prompt inside an ayah card, weeks later — the thing he asked not
/// to be surprised by.
///
/// It shows the real size before he spends it (`formatBytes` wraps the
/// figure in an LTR isolate, trap #16), the live progress while it runs, and
/// nothing at all once the pack is on the device: a first-run page should
/// not offer what the reader already has.
class ContentPackTile extends StatefulWidget {
  final IconData icon;
  final String titleKey;
  final String hintKey;
  final int bytes;
  final String downloadId;
  final Future<void> Function() onDownload;

  /// Null while it is unknown; true hides the tile entirely.
  final bool installed;

  const ContentPackTile({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.hintKey,
    required this.bytes,
    required this.downloadId,
    required this.onDownload,
    this.installed = false,
  });

  @override
  State<ContentPackTile> createState() => _ContentPackTileState();
}

class _ContentPackTileState extends State<ContentPackTile> {
  StreamSubscription<List<DownloadTask>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((_) {
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
    if (widget.installed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final task = DownloadManager.instance.taskById(widget.downloadId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final done = task?.status == DownloadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, color: AppColors.gold, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titleKey.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  trn(widget.hintKey, args: [formatBytes(widget.bytes)]),
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
                if (busy) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: task.total == null ? null : task.progress,
                    color: AppColors.gold,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            const Icon(Icons.check_circle_rounded, color: AppColors.gold)
          else if (busy)
            Text(percentOf(task.progress),
                style: const TextStyle(fontWeight: FontWeight.w700))
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.night,
              ),
              onPressed: widget.onDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('downloads.download'.tr()),
            ),
        ],
      ),
    );
  }
}
