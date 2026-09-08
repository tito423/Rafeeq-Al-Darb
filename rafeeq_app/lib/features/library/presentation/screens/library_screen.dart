import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/db/hadith_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../data/library_api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../data/book_catalog.dart';
import '../../data/hadith_imam_bios.dart';
import '../../data/book_category.dart';
import 'book_text_reader_screen.dart';
import 'books_search_screen.dart';
import 'hadith_book_screen.dart';
import 'hadith_detail_screen.dart';


/// Library — two top tabs:
///  • "الكتب المتوفرة" — the books catalog, itself split into
///    (كل الكتب · التصنيفات · مكتبتي).
///  • "الحديث" — the 9-collection hadith hub (downloaded on demand).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// P3‑25: an explicit `TabController` instead of `DefaultTabController` —
/// `DownloadsScreen`'s overview rows need to jump straight to "تحميل
/// الكتب"/"الحديث" from outside this screen entirely (a separate pushed
/// route), which `DefaultTabController` has no way to reach; this exposes
/// a controller `build()` can drive from `requestedLibraryTabProvider`.
class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(requestedLibraryTabProvider, (prev, next) {
      if (next == null) return;
      _tabController.animateTo(next);
      ref.read(requestedLibraryTabProvider.notifier).state = null;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('nav.library'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'library.tab_books'.tr()),
            Tab(text: 'library.tab_hadith'.tr()),
            Tab(text: 'library.tab_channels'.tr()),
            Tab(text: 'library.tab_websites'.tr()),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'library.search_all_books'.tr(),
            icon: const Icon(Icons.manage_search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BooksSearchScreen(),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BooksTab(),
          _HadithTab(),
          _IslamicChannelsTab(),
          _IslamicWebsitesTab(),
        ],
      ),
    );
  }
}

// ── Books ──────────────────────────────────────────────────────────────────

class _BooksTab extends StatefulWidget {
  const _BooksTab();

  @override
  State<_BooksTab> createState() => _BooksTabState();
}

/// Which edition of a book a catalog card is currently acting on.

class _BooksTabState extends State<_BooksTab> {
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

  Future<void> _download(LibraryBook book) async {
    try {
      await LibraryApiService.instance.downloadBook(book.id, book.textEdition!.url);
      await _loadRegistry();
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'errors.offline'.tr()}\n$e')),
      );
    }
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
    // Group books by authorAr
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
            authorName: authors[i],
            deathDate: byAuthor[authors[i]]!.first.authorDeathAr,
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
        '$deathDate • ${books.length} ${'library.book_count'.tr()}',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      children: [
        for (final b in books) ...[
          _BookCard(
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
        '${books.length} ${'library.book_count'.tr()}',
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
          _BookCard(
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
                  Text(b.titleAr,
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

/// A book's download size in the unit that actually suits it — most of the
/// library is tens of kilobytes, so rendering everything in MB (as the old
/// fixed "1.0 MB" did) told the reader nothing useful. Empty when unknown,
/// so the card can omit the line rather than guess.
String formatBookSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final Map<String, String> paths;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  const _BookCard({
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
                  child: Text(book.titleAr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${book.authorAr} · ${book.authorDeathAr}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(book.descriptionAr, style: const TextStyle(fontSize: 13)),
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

// ── Hadith hub (unchanged from Phase 1) ────────────────────────────────────

class _HadithTab extends ConsumerStatefulWidget {
  const _HadithTab();

  @override
  ConsumerState<_HadithTab> createState() => _HadithTabState();
}

class _HadithTabState extends ConsumerState<_HadithTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  StreamSubscription<List<DownloadTask>>? _sub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _sub = DownloadManager.instance.stream.listen((tasks) {
      final t = DownloadManager.instance.taskById(hadithDbDownloadId);
      if (t != null && t.status == DownloadStatus.completed) {
        ref.invalidate(hadithRepositoryProvider);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _startDownload() async {
    await DownloadManager.instance.enqueue(
      id: hadithDbDownloadId,
      url: AppConfig.hadithDbUrl,
      category: 'hadith',
      fileName: 'hadith.zip',
      unzipToDatabases: true,
      dbVersion: AppConfig.hadithDbVersion,
      title: 'library.hadith_db'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(hadithRepositoryProvider);

    return repoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(hadithRepositoryProvider)),
      data: (repo) {
        if (repo == null) return _DownloadGate(onDownload: _startDownload);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'library.search_hadith'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _BookList(repo: repo)
                  : _SearchResults(repo: repo, query: _query),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadGate extends StatelessWidget {
  final VoidCallback onDownload;
  const _DownloadGate({required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final task = DownloadManager.instance.taskById(hadithDbDownloadId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final failed = task?.status == DownloadStatus.failed;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('library.hadith_hub'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'library.hadith_download_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (busy) ...[
              LinearProgressIndicator(
                value: task.total == null ? null : task.progress,
                color: AppColors.gold,
              ),
              const SizedBox(height: 8),
              Text(
                task.total != null
                    ? '${(task.progress * 100).round()}%'
                    : 'library.downloading_hadith_db'.tr(),
              ),
            ] else
              FilledButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: Text('downloads.download'.tr()),
              ),
            if (failed) ...[
              const SizedBox(height: 8),
              Text(task?.error ?? 'errors.generic'.tr(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatefulWidget {
  final HadithRepository repo;
  const _BookList({required this.repo});

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  StreamSubscription<List<DownloadTask>>? _sub;

  /// download id -> local path, for the hadith text books in the second
  /// section. Same registry the Books tab uses.
  final Map<String, String> _paths = {};

  /// The catalog's own hadith-category books — رياض الصالحين, الأربعون
  /// النووية and the rest. They were only reachable through
  /// Books -> Categories -> Hadith, which is not where anyone looks for them.
  static final List<LibraryBook> _hadithTexts = libraryBookCatalog
      .where((b) => b.category == BookCategory.hadith)
      .toList()
    ..sort((a, b) => a.titleAr.compareTo(b.titleAr));

  @override
  void initState() {
    super.initState();
    _loadRegistry();
    _sub = DownloadManager.instance.stream.listen((_) => _loadRegistry());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadRegistry() async {
    // Only this section's own books, not the whole 208-title catalog.
    final paths = <String, String>{};
    for (final book in _hadithTexts) {
      if (await LibraryApiService.instance.isBookDownloaded(book.id)) {
        paths[book.id] =
            await LibraryApiService.instance.bookFilePath(book.id);
      }
    }
    if (!mounted) return;
    setState(() => _paths
      ..clear()
      ..addAll(paths));
  }

  Future<void> _download(LibraryBook book) async {
    final edition = book.textEdition;
    if (edition == null) return;
    try {
      await LibraryApiService.instance.downloadBook(book.id, edition.url);
      await _loadRegistry();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'errors.offline'.tr()}\n$e')),
      );
    }
  }

  void _open(LibraryBook book) {
    if (!_paths.containsKey(book.id)) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: book, path: _paths[book.id]!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HadithBook>>(
      future: widget.repo.books(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _HadithSectionHeader(
              title: 'library.section_nine'.tr(),
              subtitle: 'library.section_nine_desc'.tr(),
              icon: Icons.auto_stories_rounded,
            ),
            for (final b in books) ...[
              _HadithBookTile(
                book: b,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HadithBookScreen(book: b, repo: widget.repo),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_hadithTexts.isNotEmpty) ...[
              const SizedBox(height: 18),
              _HadithSectionHeader(
                title: 'library.section_texts'.tr(),
                subtitle: 'library.section_texts_desc'.tr(),
                icon: Icons.menu_book_rounded,
              ),
              for (final b in _hadithTexts) ...[
                _BookCard(
                  book: b,
                  paths: _paths,
                  onDownload: () => _download(b),
                  onOpen: () => _open(b),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// A labelled divider between the two kinds of hadith content.
class _HadithSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HadithSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// P3‑56: a proper card for a hadith collection's imam — the collection name
/// bold and larger, the imam's name below it in a smaller secondary tone, and
/// the chapter/hadith counts smaller again. Every line is single-line with
/// ellipsis so a long imam name (e.g. "الإمام أبو عبد الرحمن أحمد بن شعيب
/// النسائي") can never overflow or collide with the counts, which the old
/// one-line `ListTile` subtitle (imam + counts crammed together) did.
class _HadithBookTile extends StatelessWidget {
  final HadithBook book;
  final VoidCallback onTap;
  const _HadithBookTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bio = hadithImamBios[book.key];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.14),
                    child: Icon(Icons.menu_book_rounded,
                        color: AppColors.gold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book.nameAr,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        // The compiler's full name, wrapped rather than
                        // ellipsised: it used to be clipped to one line, so
                        // "الإمام أبو محمد عبد الرحمن بن عبد الله بن الدارمي"
                        // showed as a fragment with no way to read the rest.
                        Text(
                          book.authorAr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              if (bio != null) ...[
                const SizedBox(height: 10),
                Text(
                  bio,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _CountChip(
                    icon: Icons.format_list_numbered_rounded,
                    label: 'library.hadiths_count'.tr(),
                    value: book.hadithCount,
                  ),
                  const SizedBox(width: 8),
                  _CountChip(
                    icon: Icons.bookmarks_outlined,
                    label: 'library.chapters'.tr(),
                    value: book.chapterCount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One count pill (hadiths / chapters) on a collection's card.
class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _CountChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}


class _SearchResults extends StatefulWidget {
  final HadithRepository repo;
  final String query;
  const _SearchResults({required this.repo, required this.query});

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  late Future<List<HadithItem>> _future = widget.repo.search(widget.query);
  late final Future<List<HadithBook>> _booksFuture = widget.repo.books();

  @override
  void didUpdateWidget(covariant _SearchResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      setState(() {
        _future = widget.repo.search(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_future, _booksFuture]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('errors.generic'.tr()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data![0] as List<HadithItem>;
        final books = {
          for (final b in snapshot.data![1] as List<HadithBook>) b.id: b
        };
        if (items.isEmpty) {
          return Center(child: Text('library.no_results'.tr()));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = items[i];
            final book = books[h.bookId];
            return ListTile(
              title: Text(
                h.arabic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 15),
              ),
              subtitle: Text(
                '${book?.nameAr ?? ''} · ${'library.hadith_number'.tr()} ${h.numberInBook}',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HadithDetailScreen(
                    book: book!,
                    chapterHadiths: [h],
                    initialIndex: 0,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Islamic Channels ──────────────────────────────────────────────────────

class _ChannelInfo {
  final String name;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
  const _ChannelInfo({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
  });
}

const _islamicChannels = [
  _ChannelInfo(
    name: 'د. راغب السرجاني',
    description: 'تاريخ إسلامي وسيرة نبوية وحضارة',
    url: 'https://www.youtube.com/@RaghebElsergany',
    icon: Icons.history_edu,
    color: Color(0xFF1565C0),
  ),
  _ChannelInfo(
    name: 'د. حسن الحسيني',
    description: 'مقارنة أديان وعقيدة ودعوة',
    url: 'https://www.youtube.com/@HassanElhusseiny',
    icon: Icons.menu_book,
    color: Color(0xFF2E7D32),
  ),
  _ChannelInfo(
    name: 'الشيخ أمجد سمير',
    description: 'فقه وعلوم شرعية وتزكية',
    url: 'https://www.youtube.com/@AmgadSamir',
    icon: Icons.school,
    color: Color(0xFF6A1B9A),
  ),
  _ChannelInfo(
    name: 'د. أحمد العربي',
    description: 'تدبر القرآن الكريم وعلومه',
    url: 'https://www.youtube.com/@Dr.AhmedAlarabi',
    icon: Icons.auto_stories,
    color: Color(0xFFC62828),
  ),
  _ChannelInfo(
    name: 'د. هيثم طلعت',
    description: 'ردود علمية وفكرية على الإلحاد والشبهات',
    url: 'https://www.youtube.com/@HaythamTalaat',
    icon: Icons.lightbulb,
    color: Color(0xFFEF6C00),
  ),
  _ChannelInfo(
    name: 'قناة فاهم',
    description: 'محتوى فكري إسلامي بأسلوب بصري عصري',
    url: 'https://www.youtube.com/@fahem',
    icon: Icons.smart_display,
    color: Color(0xFF00838F),
  ),
  _ChannelInfo(
    name: 'د. إياد قنيبي',
    description: 'فكر إسلامي وردود على الشبهات المعاصرة',
    url: 'https://www.youtube.com/@EyadQunaibi',
    icon: Icons.psychology,
    color: Color(0xFF4527A0),
  ),
  _ChannelInfo(
    name: 'قناة مكاني',
    description: 'محتوى دعوي وتعليمي هادف',
    url: 'https://www.youtube.com/@MakanyChannel',
    icon: Icons.mosque,
    color: Color(0xFF00695C),
  ),
  _ChannelInfo(
    name: 'م. أيمن عبدالرحيم',
    description: 'محتوى إيماني ودعوي متنوع',
    url: 'https://www.youtube.com/@AymanAbdelRaheem',
    icon: Icons.volunteer_activism,
    color: Color(0xFF283593),
  ),
  _ChannelInfo(
    name: 'قناة وعي',
    description: 'وعي فكري إسلامي معاصر',
    url: 'https://www.youtube.com/@waikishow',
    icon: Icons.visibility,
    color: Color(0xFF37474F),
  ),
];

class _IslamicChannelsTab extends StatelessWidget {
  const _IslamicChannelsTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _islamicChannels.length,
      itemBuilder: (context, i) {
        final ch = _islamicChannels[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse(ch.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ch.color.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: ch.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(ch.icon, color: ch.color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ch.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.red.shade600,
                      size: 32,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Islamic Websites ──────────────────────────────────────────────────────

class _WebsiteInfo {
  final String name;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
  const _WebsiteInfo({
    required this.name,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
  });
}

const _islamicWebsites = [
  _WebsiteInfo(
    name: 'الإسلام سؤال وجواب',
    description: 'أكبر موقع إسلامي للفتاوى والأسئلة الشرعية بإشراف الشيخ محمد صالح المنجد',
    url: 'https://islamqa.info',
    icon: Icons.question_answer,
    color: Color(0xFF1B5E20),
  ),
  _WebsiteInfo(
    name: 'الدرر السنية',
    description: 'موسوعة شاملة للحديث النبوي والعقيدة والفقه وتخريج الأحاديث',
    url: 'https://dorar.net',
    icon: Icons.diamond,
    color: Color(0xFFC9A227),
  ),
  _WebsiteInfo(
    name: 'طريق الإسلام',
    description: 'دروس ومحاضرات ومقالات إسلامية من كبار العلماء والدعاة',
    url: 'https://ar.islamway.net',
    icon: Icons.route,
    color: Color(0xFF0D47A1),
  ),
  _WebsiteInfo(
    name: 'صيد الفوائد',
    description: 'مكتبة إسلامية شاملة تضم مقالات وكتب ومحاضرات متنوعة',
    url: 'https://saaid.org',
    icon: Icons.catching_pokemon,
    color: Color(0xFF4E342E),
  ),
  _WebsiteInfo(
    name: 'شبكة الألوكة',
    description: 'شبكة علمية ثقافية تضم بحوثاً ومقالات أكاديمية إسلامية',
    url: 'https://www.alukah.net',
    icon: Icons.language,
    color: Color(0xFF311B92),
  ),
];

class _IslamicWebsitesTab extends StatelessWidget {
  const _IslamicWebsitesTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _islamicWebsites.length,
      itemBuilder: (context, i) {
        final site = _islamicWebsites[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => launchUrl(
              Uri.parse(site.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    site.color.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: site.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(site.icon, color: site.color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            site.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: site.color,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
