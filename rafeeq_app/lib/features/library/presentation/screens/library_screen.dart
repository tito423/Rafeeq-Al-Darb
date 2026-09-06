import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/tab_request_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/db/hadith_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../data/book_catalog.dart';
import '../../data/book_category.dart';
import 'book_reader_screen.dart';
import 'book_text_reader_screen.dart';
import 'hadith_book_screen.dart';
import 'hadith_detail_screen.dart';

String _fmtSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

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
      TabController(length: 2, vsync: this);

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
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          tabs: [
            Tab(text: 'library.tab_books'.tr()),
            Tab(text: 'library.tab_hadith'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_BooksTab(), _HadithTab()],
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
enum BookEdition { image, text }

class _BooksTabState extends State<_BooksTab> {
  StreamSubscription<List<DownloadTask>>? _sub;

  /// download id -> local file path (once on disk). Keyed by `book.id` for the
  /// image PDF and by `book.textDownloadId` for the text edition.
  final Map<String, String> _paths = {};

  /// download id -> bytes on disk.
  final Map<String, int> _sizes = {};

  /// book id -> which edition its card is showing (default: image PDF).
  final Map<String, BookEdition> _edition = {};

  @override
  void initState() {
    super.initState();
    _loadRegistry();
    _sub = DownloadManager.instance.stream.listen((_) => _loadRegistry());
  }

  Future<void> _loadRegistry() async {
    final paths = <String, String>{};
    final sizes = <String, int>{};
    for (final book in libraryBookCatalog) {
      for (final id in [
        book.id,
        if (book.hasText) book.textDownloadId,
      ]) {
        final path = await DownloadManager.instance.registeredPath(id);
        if (path != null) {
          paths[id] = path;
          sizes[id] = await DownloadManager.instance.artifactSize(id);
        }
      }
    }
    if (mounted) {
      setState(() {
        _paths
          ..clear()
          ..addAll(paths);
        _sizes
          ..clear()
          ..addAll(sizes);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  BookEdition _editionOf(LibraryBook b) =>
      _edition[b.id] ?? (b.hasImage ? BookEdition.image : BookEdition.text);

  void _setEdition(LibraryBook b, BookEdition e) =>
      setState(() => _edition[b.id] = e);

  Future<void> _download(LibraryBook book, BookEdition edition) {
    if (edition == BookEdition.text) {
      final te = book.textEdition!;
      return DownloadManager.instance.enqueue(
        id: book.textDownloadId,
        url: te.url,
        category: 'books_text',
        fileName: te.fileName,
        title: '${book.titleAr} · ${'library.edition_text'.tr()}',
      );
    }
    if (!book.hasImage) return Future.value(); // no مصوّر edition to fetch
    return DownloadManager.instance.enqueue(
      id: book.id,
      url: book.downloadUrl!,
      category: 'books',
      fileName: book.fileName!,
      title: book.titleAr,
    );
  }

  void _open(LibraryBook book, BookEdition edition) {
    if (edition == BookEdition.text) {
      final path = _paths[book.textDownloadId];
      if (path == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BookTextReaderScreen(book: book, path: path),
      ));
      return;
    }
    final path = _paths[book.id];
    if (path == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookReaderScreen(book: book, path: path),
    ));
  }

  Future<void> _delete(LibraryBook book, BookEdition edition) async {
    final label = edition == BookEdition.text
        ? 'library.edition_text'.tr()
        : 'library.edition_image'.tr();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${book.titleAr} · $label'),
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
      await DownloadManager.instance.remove(
        edition == BookEdition.text ? book.textDownloadId : book.id,
      );
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
                Tab(text: 'library.sub_all'.tr()),
                Tab(text: 'library.sub_categories'.tr()),
                Tab(text: 'library.sub_mine'.tr()),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AllBooksView(
                  paths: _paths,
                  editionOf: _editionOf,
                  onSetEdition: _setEdition,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _CategoriesView(
                  paths: _paths,
                  editionOf: _editionOf,
                  onSetEdition: _setEdition,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _MyLibraryView(
                  paths: _paths,
                  sizes: _sizes,
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

class _AllBooksView extends StatelessWidget {
  final Map<String, String> paths;
  final BookEdition Function(LibraryBook) editionOf;
  final void Function(LibraryBook, BookEdition) onSetEdition;
  final void Function(LibraryBook, BookEdition) onDownload;
  final void Function(LibraryBook, BookEdition) onOpen;
  const _AllBooksView({
    required this.paths,
    required this.editionOf,
    required this.onSetEdition,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final books = [...libraryBookCatalog]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _BookCard(
        book: books[i],
        paths: paths,
        edition: editionOf(books[i]),
        onSetEdition: (e) => onSetEdition(books[i], e),
        onDownload: (e) => onDownload(books[i], e),
        onOpen: (e) => onOpen(books[i], e),
      ),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  final Map<String, String> paths;
  final BookEdition Function(LibraryBook) editionOf;
  final void Function(LibraryBook, BookEdition) onSetEdition;
  final void Function(LibraryBook, BookEdition) onDownload;
  final void Function(LibraryBook, BookEdition) onOpen;
  const _CategoriesView({
    required this.paths,
    required this.editionOf,
    required this.onSetEdition,
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
            editionOf: editionOf,
            onSetEdition: onSetEdition,
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
  final BookEdition Function(LibraryBook) editionOf;
  final void Function(LibraryBook, BookEdition) onSetEdition;
  final void Function(LibraryBook, BookEdition) onDownload;
  final void Function(LibraryBook, BookEdition) onOpen;

  const _CategoryExpansionTile({
    super.key,
    required this.category,
    required this.books,
    required this.initiallyExpanded,
    required this.paths,
    required this.editionOf,
    required this.onSetEdition,
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
            edition: editionOf(b),
            onSetEdition: (e) => onSetEdition(b, e),
            onDownload: (e) => onDownload(b, e),
            onOpen: (e) => onOpen(b, e),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MyLibraryView extends StatelessWidget {
  final Map<String, String> paths;
  final Map<String, int> sizes;
  final void Function(LibraryBook, BookEdition) onOpen;
  final void Function(LibraryBook, BookEdition) onDelete;
  const _MyLibraryView({
    required this.paths,
    required this.sizes,
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
            _row(context, b, BookEdition.image),
            const SizedBox(height: 8),
          ],
        ],
        if (textRows.isNotEmpty) ...[
          if (imageRows.isNotEmpty) const SizedBox(height: 8),
          _SectionHeader('library.edition_text'.tr()),
          for (final b in textRows) ...[
            _row(context, b, BookEdition.text),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _row(BuildContext context, LibraryBook b, BookEdition edition) {
    final isText = edition == BookEdition.text;
    final scheme = Theme.of(context).colorScheme;
    final size = _fmtSize(sizes[isText ? b.textDownloadId : b.id] ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(isText ? Icons.article_outlined : Icons.image_outlined,
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
              onPressed: () => onOpen(b, edition),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('library.open'.tr()),
            ),
            IconButton(
              tooltip: 'library.delete'.tr(),
              onPressed: () => onDelete(b, edition),
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

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final Map<String, String> paths;
  final BookEdition edition;
  final void Function(BookEdition) onSetEdition;
  final void Function(BookEdition) onDownload;
  final void Function(BookEdition) onOpen;

  const _BookCard({
    required this.book,
    required this.paths,
    required this.edition,
    required this.onSetEdition,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Everything below is about the *selected* edition.
    final isText = edition == BookEdition.text;
    final dlId = isText ? book.textDownloadId : book.id;
    final task = DownloadManager.instance.taskById(dlId);
    final busy = task != null &&
        (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued);
    final failed = task?.status == DownloadStatus.failed;
    final downloaded = paths.containsKey(dlId);
    final approxBytes = isText
        ? (book.textEdition?.approxSizeBytes ?? 0)
        : (book.approxSizeBytes ?? 0);
    final sizeMb = (approxBytes / 1000000).toStringAsFixed(1);

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
            if (book.hasText && book.hasImage) ...[
              SegmentedButton<BookEdition>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: BookEdition.image,
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text('library.edition_image'.tr()),
                  ),
                  ButtonSegment(
                    value: BookEdition.text,
                    icon: const Icon(Icons.article_outlined, size: 16),
                    label: Text('library.edition_text'.tr()),
                  ),
                ],
                selected: {edition},
                onSelectionChanged: (s) => onSetEdition(s.first),
              ),
              const SizedBox(height: 8),
            ],
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
                  if (approxBytes > 0)
                    Text('${'library.size'.tr()}: $sizeMb MB',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12)),
                  const Spacer(),
                  if (downloaded)
                    FilledButton.icon(
                      onPressed: () => onOpen(edition),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text('library.open'.tr()),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => onDownload(edition),
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

class _BookList extends StatelessWidget {
  final HadithRepository repo;
  const _BookList({required this.repo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HadithBook>>(
      future: repo.books(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _HadithBookTile(
            book: books[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HadithBookScreen(book: books[i], repo: repo),
              ),
            ),
          ),
        );
      },
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${book.chapterCount} ${'library.chapters'.tr()}  ·  '
                      '${book.hadithCount} ${'library.hadiths_count'.tr()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
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
