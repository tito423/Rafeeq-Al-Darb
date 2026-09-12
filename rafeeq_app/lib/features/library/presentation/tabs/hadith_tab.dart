/// «الحديث» — the nine collections, downloaded on demand, with their books,
/// chapters and the search across them.
library;
import 'dart:async';

import '../../../../core/widgets/arabic_text.dart';
import '../../../../core/widgets/future_view.dart';
import '../../../../core/utils/arabic_normalize.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/hadith_repository.dart';
import '../../../../core/services/download_manager.dart';
import '../widgets/book_card.dart';
import '../../data/library_api_service.dart';
import '../../../../core/i18n/proper_name.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
import '../../data/book_catalog.dart';
import '../../data/hadith_imam_bios.dart';
import '../../data/book_category.dart';
import '../screens/book_text_reader_screen.dart';
import '../screens/hadith_book_screen.dart';
import '../screens/hadith_detail_screen.dart';

class HadithTab extends ConsumerStatefulWidget {
  const HadithTab({super.key});

  @override
  ConsumerState<HadithTab> createState() => _HadithTabState();
}

class _HadithTabState extends ConsumerState<HadithTab> {
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
      // Same rule as the books tab: the exception goes to the log, the
      // reader gets a sentence.
      debugPrint('library(hadith texts): ${book.id} failed to download: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errors.offline'.tr())),
      );
    }
  }

  void _open(LibraryBook book) {
    if (!_paths.containsKey(book.id)) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: book, path: _paths[book.id]!),
    ));
  }

  /// Held in state, not created in `build`. It used to read
  /// `future: widget.repo.books()` inline, which starts a **new** query
  /// against the 110 MB hadith database on every single rebuild of this tab —
  /// and a `FutureBuilder` handed a new future rebuilds again when it
  /// resolves. Hoisting it means one query per visit.
  late Future<List<HadithBook>> _booksFuture = widget.repo.books();

  void _retryBooks() =>
      setState(() => _booksFuture = widget.repo.books());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HadithBook>>(
      future: _booksFuture,
      builder: (context, snapshot) => FutureView<List<HadithBook>>(
        snapshot: snapshot,
        onRetry: _retryBooks,
        builder: (books) {
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
                BookCard(
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
      ),
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
    final bio = hadithImamBioKeys[book.key]?.tr();
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
                          properName(book.authorAr, book.authorEn),
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
                  // .plural(), not '$n $noun': Russian showed «97 Главы»
                  // where 97 takes the genitive plural, «97 глав».
                  _CountChip(
                    icon: Icons.format_list_numbered_rounded,
                    text: 'library.hadiths_count'.plural(book.hadithCount),
                  ),
                  const SizedBox(width: 8),
                  _CountChip(
                    icon: Icons.bookmarks_outlined,
                    text: 'library.chapters'.plural(book.chapterCount),
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

  /// Already pluralised — the count is inside the string, because the noun
  /// after it changes with the number in Arabic, Russian and Urdu.
  final String text;
  const _CountChip({
    required this.icon,
    required this.text,
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
            text,
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
              // ArabicText: same reason as the chapter list — an Arabic
              // result laid out in an LTR paragraph moves its punctuation.
              title: ArabicText(
                stripBidiControls(h.arabic),
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
