import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../data/book_catalog.dart';
import '../../data/library_api_service.dart';

/// «تحميل الكل» in every shelf, and picking some books to download or delete
/// together (owner, 2026-10-05). One implementation for the categories, the
/// authors and the spoken list - the first cut of this had three copies, with
/// Arabic written into the code and a category button that read «كتب المؤلف».
class BookSelection extends ChangeNotifier {
  bool _active = false;
  final Set<String> ids = {};

  bool get active => _active;

  void start() {
    _active = true;
    notifyListeners();
  }

  void end() {
    _active = false;
    ids.clear();
    notifyListeners();
  }

  void toggle(String id) {
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    notifyListeners();
  }

  void setAll(Iterable<String> all, bool on) {
    on ? ids.addAll(all) : ids.clear();
    notifyListeners();
  }
}

/// A book the library can fetch now: it has a hosted text, is not on the
/// device and is not already on its way.
bool canFetchBook(LibraryBook b, Map<String, String> paths) =>
    b.textEdition != null &&
    !paths.containsKey(b.id) &&
    DownloadManager.instance.taskById(b.id)?.status !=
        DownloadStatus.downloading &&
    !LibraryApiService.instance.bookDownloads.value.containsKey(b.id);

/// The row above a shelf: «تحميل كل …» + «تحديد», or, while selecting,
/// «تحديد الكل», the count, and download / delete of what is ticked.
class BookBulkBar extends StatelessWidget {
  final BookSelection selection;
  final List<LibraryBook> books;
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;

  /// The «download all» label, with one `{}` for the count.
  final String allLabelKey;

  const BookBulkBar({
    super.key,
    required this.selection,
    required this.books,
    required this.paths,
    required this.onDownload,
    required this.allLabelKey,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    String n(int v) => localizeDigits('$v', lang);
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        if (!selection.active) {
          final missing = [for (final b in books) if (canFetchBook(b, paths)) b];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (missing.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => missing.forEach(onDownload),
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(allLabelKey.tr(args: [n(missing.length)])),
                  ),
                TextButton.icon(
                  onPressed: selection.start,
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text('library.select'.tr()),
                ),
              ],
            ),
          );
        }
        final picked = [for (final b in books) if (selection.ids.contains(b.id)) b];
        final toFetch = [for (final b in picked) if (canFetchBook(b, paths)) b];
        final toDelete = [for (final b in picked) if (paths.containsKey(b.id)) b];
        final all = picked.length == books.length && books.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: all ? true : (picked.isEmpty ? false : null),
                    tristate: true,
                    onChanged: (_) =>
                        selection.setAll(books.map((b) => b.id), !all),
                  ),
                  Expanded(
                    child: Text(
                      picked.isEmpty
                          ? 'library.select_all'.tr()
                          : 'library.selected_n'.tr(args: [n(picked.length)]),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'library.select_cancel'.tr(),
                    onPressed: selection.end,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: toFetch.isEmpty
                        ? null
                        : () {
                            toFetch.forEach(onDownload);
                            selection.end();
                          },
                    icon: const Icon(Icons.download_rounded),
                    label: Text('library.download_n'.tr(args: [n(toFetch.length)])),
                  ),
                  FilledButton.tonalIcon(
                    // Red on the theme's green tonal fill was hard to read
                    // (seen on emulator-5554); the error container pair is
                    // made to be read together.
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: toDelete.isEmpty
                        ? null
                        : () => _delete(context, toDelete, n),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('library.delete_n'.tr(args: [n(toDelete.length)])),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, List<LibraryBook> books,
      String Function(int) n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('library.delete_n_confirm'.tr(args: [n(books.length)])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('library.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // deleteBook announces each removal on LibraryApiService.changes, which
    // the books tab listens to, so the cards and counts redraw on their own.
    for (final b in books) {
      await LibraryApiService.instance.deleteBook(b.id);
    }
    selection.end();
  }
}

/// A book card with a tick box in front of it while [selection] is active.
class SelectableBook extends StatelessWidget {
  final BookSelection selection;
  final LibraryBook book;
  final Widget child;

  const SelectableBook({
    super.key,
    required this.selection,
    required this.book,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: selection,
        builder: (context, child) => !selection.active
            ? child!
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Checkbox(
                      value: selection.ids.contains(book.id),
                      onChanged: (_) => selection.toggle(book.id),
                    ),
                  ),
                  Expanded(child: child!),
                ],
              ),
        child: child,
      );
}
