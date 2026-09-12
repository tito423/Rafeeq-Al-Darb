/// «الكتب المتوفرة» — the books catalogue, and its three sub-views
/// (المؤلفين · التصنيفات · مكتبتي).
///
/// Split out of `library_screen.dart`, which had all five tabs, every one of
/// their sub-views and a websites catalogue in one 1,625-line file with
/// twenty-five classes in it.
library;
import 'dart:async';


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_manager.dart';
import '../widgets/book_card.dart';
import '../../data/library_api_service.dart';
import '../../../../core/i18n/proper_name.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/book_catalog.dart';
import '../../data/book_category.dart';
import '../screens/book_text_reader_screen.dart';

class BooksTab extends StatefulWidget {
  const BooksTab({super.key});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

/// Which edition of a book a catalog card is currently acting on.

class _BooksTabState extends State<BooksTab> {
  StreamSubscription<List<DownloadTask>>? _sub;

  /// download id -> local file path (once on disk). Keyed by `book.id` for the
  /// image PDF and by `book.textDownloadId` for the text edition.
  final Map<String, String> _paths = {};

  /// download id -> bytes on disk.

  @override
  void initState() {
    super.initState();
    _loadRegistry();
    _sub = DownloadManager.instance.stream.listen((_) => _loadRegistry());
  }

  Future<void> _loadRegistry() async {
    final paths = <String, String>{};
    for (final book in libraryBookCatalog) {
      if (await LibraryApiService.instance.isBookDownloaded(book.id)) {
        paths[book.id] = await LibraryApiService.instance.bookFilePath(book.id);
      }
    }
    if (mounted) {
      setState(() {
        _paths..clear()..addAll(paths);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Books download **one at a time**, and a failure never puts an exception
  /// on screen.
  ///
  /// «لما ضغطت تحميل كل الكتب طلعت رسايل برمجية مصيبة مش عارف بتاعة إيه» —
  /// the author card's "download all" fired this method once per book in a
  /// plain `for` loop, so thirty requests opened against the same R2 host in
  /// the same instant. The bucket reset most of them, and each failure
  /// rendered its raw `DioException [connection error] … SocketException:
  /// Connection reset by peer (errno = 104), address = pub-….r2.dev, port =
  /// 50528` into a SnackBar on top of the card the owner was reading. Two
  /// separate faults: the flood, and a programmer's exception used as a user
  /// message.
  ///
  /// Chaining onto `_queue` keeps the concurrency at one whatever calls it
  /// and however many times; the raw text goes to `debugPrint` where it
  /// belongs, and the reader gets one counted sentence after the queue
  /// drains rather than a SnackBar per book.
  Future<void> _queue = Future<void>.value();
  int _pending = 0;
  int _failed = 0;

  void _download(LibraryBook book) {
    _pending++;
    _queue = _queue.then((_) => _downloadOne(book));
  }

  Future<void> _downloadOne(LibraryBook book) async {
    try {
      await LibraryApiService.instance
          .downloadBook(book.id, book.textEdition!.url);
      await _loadRegistry();
    } catch (e) {
      debugPrint('library: ${book.id} failed to download: $e');
      _failed++;
    } finally {
      _pending--;
      if (_pending == 0) _reportFailures();
    }
  }

  void _reportFailures() {
    final failed = _failed;
    _failed = 0;
    if (failed == 0 || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('library.download_failed'.plural(failed)),
      ));
  }

  void _open(LibraryBook book) {
    if (!_paths.containsKey(book.id)) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: book, path: _paths[book.id]!),
    ));
  }

  Future<void> _delete(LibraryBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(''),
        content: Text('library.delete_confirm'.tr()),
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
    if (ok == true) {
      await LibraryApiService.instance.deleteBook(book.id);
      await _loadRegistry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: AppColors.gold,
              indicatorColor: AppColors.gold,
              tabs: [
                Tab(text: 'library.sub_authors'.tr()),
                Tab(text: 'library.sub_categories'.tr()),
                Tab(text: 'library.sub_mine'.tr()),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AuthorsView(
                  paths: _paths,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _CategoriesView(
                  paths: _paths,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _MyLibraryView(
                  paths: _paths,
                  
                  onOpen: _open,
                  onDelete: _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Authors view — groups books by author using ExpansionTile. Each author
/// expands to show their books with download/open buttons.
class _AuthorsView extends StatelessWidget {
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;
  const _AuthorsView({
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    // Grouped by the Arabic name, which is the stable identity — the Latin
    // form is what gets DISPLAYED, and is taken from the group's first book.
    final byAuthor = <String, List<LibraryBook>>{};
    for (final b in libraryBookCatalog) {
      byAuthor.putIfAbsent(b.authorAr, () => []).add(b);
    }
    // Sort authors alphabetically, sort each author's books
    final authors = byAuthor.keys.toList()..sort();
    for (final list in byAuthor.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var i = 0; i < authors.length; i++)
          _AuthorExpansionTile(
            key: PageStorageKey<String>(authors[i]),
            authorName: properName(
                authors[i], byAuthor[authors[i]]!.first.authorEn),
            deathDate: byAuthor[authors[i]]!.first.deathLabel(),
            books: byAuthor[authors[i]]!,
            initiallyExpanded: i == 0,
            paths: paths,
            onDownload: onDownload,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _AuthorExpansionTile extends StatelessWidget {
  final String authorName;
  final String deathDate;
  final List<LibraryBook> books;
  final bool initiallyExpanded;
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;

  const _AuthorExpansionTile({
    super.key,
    required this.authorName,
    required this.deathDate,
    required this.books,
    required this.initiallyExpanded,
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: CircleAvatar(
        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
        child: Icon(Icons.person_outline, color: AppColors.gold, size: 22),
      ),
      title: Text(
        authorName,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        // A living author has no death date; do not render a dangling
        // bullet. The isolates that used to wrap each half are gone with the
        // reason for them: the death line is written in the reader's own
        // language now, not Arabic inside a left-to-right paragraph.
        deathDate.isEmpty
            ? 'library.book_count'.plural(books.length)
            : '$deathDate • ${'library.book_count'.plural(books.length)}',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      children: [
        // «حط خيار جديد في المكتبة في خانة المؤلفين لإمكانية تحميل كتب المؤلف
        // كلها دفعة واحدة». Only books with a hosted text and not already on
        // the device are counted, and the button goes once there are none.
        if (_missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  for (final b in _missing) {
                    onDownload(b);
                  }
                },
                icon: const Icon(Icons.download_for_offline_rounded),
                label: Text('library.download_author_all'
                    .tr(args: ['${_missing.length}'])),
              ),
            ),
          ),
        for (final b in books) ...[
          BookCard(
            book: b,
            paths: paths,
            onDownload: () => onDownload(b),
            onOpen: () => onOpen(b),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  List<LibraryBook> get _missing => [
        for (final b in books)
          if (b.textEdition != null &&
              !paths.containsKey(b.id) &&
              DownloadManager.instance.taskById(b.id)?.status !=
                  DownloadStatus.downloading)
            b,
      ];
}

class _CategoriesView extends StatelessWidget {
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;
  const _CategoriesView({
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final byCat = <BookCategory, List<LibraryBook>>{};
    for (final b in libraryBookCatalog) {
      byCat.putIfAbsent(b.category, () => []).add(b);
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // P3‑54: each category is now a collapsible `ExpansionTile` — tap the
    // header to expand its books, tap again to collapse — instead of one long
    // always-open list. The first category opens by default so the tab never
    // looks empty on entry. `PageStorageKey` keeps each tile's open/closed
    // state across rebuilds (locale/theme changes, scrolling far away and
    // back) so the user's expand/collapse choices don't reset under them.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (var i = 0; i < cats.length; i++)
          _CategoryExpansionTile(
            key: PageStorageKey<int>(cats[i].index),
            category: cats[i],
            books: byCat[cats[i]]!
              ..sort((x, y) => x.sortKey.compareTo(y.sortKey)),
            initiallyExpanded: i == 0,
            paths: paths,
            onDownload: onDownload,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _CategoryExpansionTile extends StatelessWidget {
  final BookCategory category;
  final List<LibraryBook> books;
  final bool initiallyExpanded;
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;

  const _CategoryExpansionTile({
    super.key,
    required this.category,
    required this.books,
    required this.initiallyExpanded,
    required this.paths,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: Icon(category.icon, color: AppColors.gold),
      title: Text(
        category.labelKey.tr(),
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'library.book_count'.plural(books.length),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      children: [
        for (final b in books) ...[
          BookCard(
            book: b,
            paths: paths,
            onDownload: () => onDownload(b),
            onOpen: () => onOpen(b),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MyLibraryView extends StatelessWidget {
  final Map<String, String> paths;
  
  final void Function(LibraryBook) onOpen;
  final void Function(LibraryBook) onDelete;
  const _MyLibraryView({
    required this.paths,
    
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // One entry per (book, edition) actually on disk, grouped into two
    // sections — مصوّر then نصي — instead of one flat list interleaving
    // both editions of the same book (P3‑15: the owner found that
    // confusing, "بدل ما يبقى مكررين الاسمين تحت بعض").
    final sorted = [...libraryBookCatalog]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final imageRows = <LibraryBook>[
      for (final b in sorted)
        if (paths.containsKey(b.id)) b,
    ];
    final textRows = <LibraryBook>[
      for (final b in sorted)
        if (b.hasText && paths.containsKey(b.textDownloadId)) b,
    ];

    if (imageRows.isEmpty && textRows.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_done_outlined,
                  size: 56, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('library.empty_mine'.tr(), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (imageRows.isNotEmpty) ...[
          _SectionHeader('library.edition_image'.tr()),
          for (final b in imageRows) ...[
            _row(context, b),
            const SizedBox(height: 8),
          ],
        ],
        if (textRows.isNotEmpty) ...[
          if (imageRows.isNotEmpty) const SizedBox(height: 8),
          _SectionHeader('library.edition_text'.tr()),
          for (final b in textRows) ...[
            _row(context, b),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _row(BuildContext context, LibraryBook b) {
    final scheme = Theme.of(context).colorScheme;
    final size = '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.article_outlined,
                size: 18, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(properName(b.titleAr, b.titleEn),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      b.category.labelKey.tr(),
                      if (size.isNotEmpty) size,
                    ].join(' · '),
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => onOpen(b),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('library.open'.tr()),
            ),
            IconButton(
              tooltip: 'library.delete'.tr(),
              onPressed: () => onDelete(b),
              icon: Icon(Icons.delete_outline, color: scheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
      ),
    );
  }
}



// ── Hadith hub (unchanged from Phase 1) ────────────────────────────────────
