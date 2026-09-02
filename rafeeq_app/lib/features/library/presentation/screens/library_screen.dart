import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/hadith_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import 'hadith_book_screen.dart';
import 'hadith_detail_screen.dart';

const _hadithDownloadId = 'hadith_db';

/// Library — the Hadith hub (9 real collections, downloaded on demand) and
/// a Books catalog whose source list is still pending the owner's
/// confirmation (WORK_QUEUE Stage 2: "STOP AND ASK" before downloading any
/// book), so that tab stays an honest placeholder rather than invented
/// entries.
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
              Tab(text: 'library.tab_hadith'.tr()),
              Tab(text: 'library.tab_catalog'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_HadithTab(), _CatalogTab()],
        ),
      ),
    );
  }
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'library.sources_pending'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HadithTab extends ConsumerStatefulWidget {
  const _HadithTab();

  @override
  ConsumerState<_HadithTab> createState() => _HadithTabState();
}

class _HadithTabState extends ConsumerState<_HadithTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  StreamSubscription<List<DownloadTask>>? _sub;

  // Debounced, not fired on every keystroke — search() now rescans the
  // ~41k-hadith table per call (see HadithRepository.search()'s doc for
  // why it no longer caches an in-memory index), so typing fast would
  // otherwise queue up many redundant full scans in a row.
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
      // A block body, not `=> _future = ...` — that arrow form returns the
      // assignment's value (a Future), and setState() asserts its callback
      // must return void. Caught live: typing in the hadith search field
      // threw "setState() callback argument returned a Future."
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
        // A spinner that never resolves on error is itself a real bug this
        // screen already hit once (an FTS5 query throwing left it spinning
        // forever, since only hasData was checked) — handle hasError too.
        if (snapshot.hasError) {
          return Center(child: Text('errors.generic'.tr()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data![0] as List<HadithItem>;
        final books = {for (final b in snapshot.data![1] as List<HadithBook>) b.id: b};
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
