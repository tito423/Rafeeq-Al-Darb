import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/proper_name.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../core/services/download_manager.dart';
import '../../data/book_catalog.dart';

/// One downloadable book, as a card.
///
/// Lives here rather than inside a tab because **two** tabs draw it: the books
/// catalogue, and the hadith tab's «كتب الحديث النصّية» section. It was private
/// to the single 1,625-line file that held both, which is exactly the kind of
/// sharing a screen file hides — splitting that file is what surfaced it.
class BookCard extends StatelessWidget {
  final LibraryBook book;
  final Map<String, String> paths;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  const BookCard({
    super.key,
    required this.book,
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final dlId = book.id;
    final task = DownloadManager.instance.taskById(dlId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final failed = task?.status == DownloadStatus.failed;
    final downloaded = paths.containsKey(dlId);
    // Real measured size of the hosted file; empty when unknown, so the
    // card says nothing rather than repeating the old fixed '1.0 MB'.
    final sizeLabel = formatBookSize(book.textEdition?.sizeBytes ?? 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(book.category.icon, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(properName(book.titleAr, book.titleEn),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Builder(builder: (_) {
              final author = properName(book.authorAr, book.authorEn);
              final death = book.deathLabel();
              return Text(
                death.isEmpty ? author : '$author · $death',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              );
            }),
            const SizedBox(height: 8),
            Text(book.description(),
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),

            if (busy) ...[
              LinearProgressIndicator(
                value: task.total == null ? null : task.progress,
                color: AppColors.gold,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    task.total != null
                        ? '${(task.progress * 100).round()}%'
                        : '…',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const Spacer(),
                  // P3‑24: the button used to just disappear while
                  // downloading, with no way to back out — same
                  // pause/cancel pattern `downloads_screen.dart`'s mushaf
                  // and recitation tiles already use.
                  TextButton.icon(
                    onPressed: () => DownloadManager.instance.cancel(dlId),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text('common.cancel'.tr()),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  
                    if (sizeLabel.isNotEmpty)
                      Text('${'library.size'.tr()}: $sizeLabel',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                  const Spacer(),
                  if (downloaded)
                    FilledButton.icon(
                      onPressed: () => onOpen(),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text('library.open'.tr()),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => onDownload(),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text('library.download'.tr()),
                    ),
                ],
              ),
            if (failed) ...[
              const SizedBox(height: 6),
              Text(task?.error ?? 'errors.generic'.tr(),
                  style: TextStyle(color: scheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A book's download size in the unit that actually suits it — most of the
/// library is tens of kilobytes, so rendering everything in MB (as the old
/// fixed "1.0 MB" did) told the reader nothing useful. Empty when unknown,
/// so the card can omit the line rather than guess.
String formatBookSize(int bytes) {
  if (bytes <= 0) return '';
  return formatBytesBinary(bytes);
}
