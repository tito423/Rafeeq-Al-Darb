import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/hadith_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/book_catalog.dart';
import '../../data/book_category.dart';
import 'book_reader_screen.dart';
import 'hadith_book_screen.dart';
import 'hadith_detail_screen.dart';

const _hadithDownloadId = 'hadith_db';

String _fmtSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Library — two top tabs:
///  • "الكتب المتوفرة" — the books catalog, itself split into
///    (كل الكتب · التصنيفات · مكتبتي).
///  • "الحديث" — the 9-collection hadith hub (downloaded on demand).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('nav.library'.tr()),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            tabs: [
              Tab(text: 'library.tab_books'.tr()),
              Tab(text: 'library.tab_hadith'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_BooksTab(), _HadithTab()],
        ),
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

class _BooksTabState extends State<_BooksTab> {
  StreamSubscription<List<DownloadTask>>? _sub;

  /// book id -> local file path (once known on disk).
  final Map<String, String> _paths = {};

  /// book id -> bytes on disk.
  final Map<String, int> _sizes = {};

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
      final path = await DownloadManager.instance.registeredPath(book.id);
      if (path != null) {
        paths[book.id] = path;
        sizes[book.id] = await DownloadManager.instance.artifactSize(book.id);
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

  Future<void> _download(LibraryBook book) => DownloadManager.instance.enqueue(
        id: book.id,
        url: book.downloadUrl,
        category: 'books',
        fileName: book.fileName,
        title: book.titleAr,
      );

  void _open(LibraryBook book) {
    final path = _paths[book.id];
    if (path == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookReaderScreen(book: book, path: path),
    ));
  }

  Future<void> _delete(LibraryBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(book.titleAr),
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
      await DownloadManager.instance.remove(book.id);
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
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;
  const _AllBooksView(
      {required this.paths, required this.onDownload, required this.onOpen});

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
        task: DownloadManager.instance.taskById(books[i].id),
        downloaded: paths.containsKey(books[i].id),
        onDownload: () => onDownload(books[i]),
        onOpen: () => onOpen(books[i]),
      ),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  final Map<String, String> paths;
  final void Function(LibraryBook) onDownload;
  final void Function(LibraryBook) onOpen;
  const _CategoriesView(
      {required this.paths, required this.onDownload, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final byCat = <BookCategory, List<LibraryBook>>{};
    for (final b in libraryBookCatalog) {
      byCat.putIfAbsent(b.category, () => []).add(b);
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final cat in cats) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Row(
              children: [
                Icon(cat.icon, size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  cat.labelKey.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.gold),
                ),
              ],
            ),
          ),
          for (final b in byCat[cat]!..sort(
              (x, y) => x.sortKey.compareTo(y.sortKey))) ...[
            _BookCard(
              book: b,
              task: DownloadManager.instance.taskById(b.id),
              downloaded: paths.containsKey(b.id),
              onDownload: () => onDownload(b),
              onOpen: () => onOpen(b),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _MyLibraryView extends StatelessWidget {
  final Map<String, String> paths;
  final Map<String, int> sizes;
  final void Function(LibraryBook) onOpen;
  final void Function(LibraryBook) onDelete;
  const _MyLibraryView({
    required this.paths,
    required this.sizes,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mine =
        libraryBookCatalog.where((b) => paths.containsKey(b.id)).toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    if (mine.isEmpty) {
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
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: mine.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = mine[i];
        final scheme = Theme.of(context).colorScheme;
        final size = _fmtSize(sizes[b.id] ?? 0);
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.titleAr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        [b.category.labelKey.tr(), if (size.isNotEmpty) size]
                            .join(' · '),
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
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final DownloadTask? task;
  final bool downloaded;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  const _BookCard({
    required this.book,
    required this.task,
    required this.downloaded,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = task != null &&
        (task!.status == DownloadStatus.downloading ||
            task!.status == DownloadStatus.queued);
    final failed = task?.status == DownloadStatus.failed;
    final sizeMb = (book.approxSizeBytes / 1000000).toStringAsFixed(1);

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
                value: task!.total == null ? null : task!.progress,
                color: AppColors.gold,
              ),
              const SizedBox(height: 6),
              Text(
                task!.total != null
                    ? '${(task!.progress * 100).round()}%'
                    : '…',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ] else
              Row(
                children: [
                  Text('${'library.size'.tr()}: $sizeMb MB',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                  const Spacer(),
                  if (downloaded)
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text('library.open'.tr()),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onDownload,
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
      final t = DownloadManager.instance.taskById(_hadithDownloadId);
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
      id: _hadithDownloadId,
      url: AppConfig.hadithDbUrl,
      category: 'hadith',
      fileName: 'hadith.zip',
      unzipToDatabases: true,
      title: 'library.hadith_db'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repoAsync = ref.watch(hadithRepositoryProvider);

    return repoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('errors.generic'.tr())),
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
    final task = DownloadManager.instance.taskById(_hadithDownloadId);
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
          itemBuilder: (context, i) {
            final b = books[i];
            return Card(
              child: ListTile(
                title: Text(b.nameAr,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${b.authorAr} · ${b.chapterCount} ${'library.chapters'.tr()} '
                  '· ${b.hadithCount} ${'library.hadiths_count'.tr()}',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HadithBookScreen(book: b, repo: repo),
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
