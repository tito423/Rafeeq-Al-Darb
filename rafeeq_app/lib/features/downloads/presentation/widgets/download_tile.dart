import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/download_manager.dart';

/// Riverpod bridge over the singleton download engine.
final downloadTasksProvider = StreamProvider<List<DownloadTask>>(
  (ref) => DownloadManager.instance.stream,
);

/// A real progress tile driven by the download engine stream.
/// Shows live percentage/bytes with pause/resume/cancel actions.
class DownloadTile extends ConsumerWidget {
  final String taskId;
  final String title;
  final DownloadTask? task;

  const DownloadTile({
    super.key,
    required this.taskId,
    required this.title,
    this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final manager = DownloadManager.instance;
    final t = task ?? manager.taskById(taskId);

    final status = t?.status;
    final hasSize = t != null && t.total != null && t.total! > 0;
    final progress = t?.progress ?? 0.0;

      String subtitle;
    switch (status) {
      case DownloadStatus.downloading: {
        final receivedMb = (t?.received ?? 0) / 1048576;
        final totalMb = (t?.total ?? 0) / 1048576;
        subtitle = hasSize
            ? '${(progress * 100).round()}% — ${receivedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB'
            : '${t?.received ?? 0} bytes';
        break;
      }
      case DownloadStatus.paused:
        subtitle = 'متوقف مؤقتاً';
        break;
      case DownloadStatus.completed:
        subtitle = 'تم التنزيل ✓';
        break;
      case DownloadStatus.failed:
        subtitle = 'فشل: ${t?.error ?? ''}';
        break;
      case DownloadStatus.canceled:
        subtitle = 'أُلغي';
        break;
      case DownloadStatus.queued:
        subtitle = 'في الانتظار…';
        break;
      case null:
        subtitle = 'غير مُنزَّل';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status == DownloadStatus.completed
                      ? Icons.check_circle
                      : Icons.downloading,
                  color: status == DownloadStatus.completed
                      ? scheme.primary
                      : scheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline),
                    onPressed: () => manager.pause(taskId),
                  )
                else if (status == DownloadStatus.paused ||
                    status == DownloadStatus.failed ||
                    status == DownloadStatus.canceled)
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => manager.resume(taskId),
                  )
                else if (status == DownloadStatus.queued ||
                    status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => manager.cancel(taskId),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: status == DownloadStatus.completed
                  ? 1
                  : (hasSize ? progress : null),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
