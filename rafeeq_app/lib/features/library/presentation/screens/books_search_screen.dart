import 'dart:async';
import '../../../../core/utils/digits.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/book_catalog.dart';
import '../../data/library_api_service.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/name_match.dart';
import 'book_text_reader_screen.dart';
import '../../../../core/i18n/proper_name.dart';
import '../widgets/author_search_result.dart';

/// Searches every downloaded book at once.
///
/// The reader has always been able to search inside the book it has open, and
/// the nine hadith collections have always been searchable as one corpus
/// through their own FTS index. The text library had neither — each book was
/// its own island — which is why finding a phrase meant remembering which book
/// it was in first. This is the missing half.
class BooksSearchScreen extends StatefulWidget {
  const BooksSearchScreen({super.key});

  @override
  State<BooksSearchScreen> createState() => _BooksSearchScreenState();
}

class _BooksSearchScreenState extends State<BooksSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<BookSearchHit> _hits = const [];
  List<LibraryBook> _books = const [];

  /// Authors found, by their Arabic name (the catalogue's identity), each
  /// with every book the library has of theirs.
  List<(String, List<LibraryBook>)> _authors = const [];

  /// Book ids on the phone, read once per search, so an author card knows
  /// what «download all» still has to fetch.
  Set<String> _onDevice = const {};

  /// Author whose books are downloading -> (done, total).
  final Map<String, (int, int)> _authorProgress = {};
  bool _searching = false;
  bool _ran = false;

  /// «طوّر نظام البحث في المكتبة ووسّع خياراته … بالمؤلف أو الكتاب، بالتشكيل
  /// أو من غير، بجملة أو غيره». Where to look, and how strictly.
  _Scope _scope = _Scope.all;
  bool _phrase = false;
  bool _exactMarks = false;
  String? _downloading;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    // Typing a phrase shouldn't fire a query per keystroke across every book.
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  /// Titles and authors come from the catalogue itself - every book,
  /// downloaded or not - matched without harakat.
  List<LibraryBook> _matchCatalogue(String q) {
    final t = q.trim();
    final n = normalizeArabic(t);
    final loose = normalizeArabicLoose(t);
    final lower = t.toLowerCase();
    bool hit(String ar, String en) =>
        normalizeArabic(ar).contains(n) ||
        normalizeArabicLoose(ar).contains(loose) ||
        nameMatches(ar, t) ||
        en.toLowerCase().contains(lower);
    // Titles only: an author is answered by an author card
    // (`_matchAuthors`), not by the list of his books.
    return [
      if (_scope == _Scope.all || _scope == _Scope.title)
        for (final b in libraryBookCatalog)
          if (hit(b.titleAr, b.titleEn)) b,
    ];
  }

  /// Authors matching [q]: WHOLE words first. «ابن الجوزي» is Abu al-Faraj
  /// Ibn al-Jawzi only - Ibn Qayyim al-Jawziyya came first before, because
  /// «الجوزي» starts «الجوزية» (owner, 2026-09-26). Starts-of-words are the
  /// fallback when nobody matches whole, so a half-typed name still finds.
  List<(String, List<LibraryBook>)> _matchAuthors(String q) {
    if (_scope != _Scope.all && _scope != _Scope.author) return const [];
    final t = q.trim();
    final byAuthor = <String, List<LibraryBook>>{};
    for (final b in libraryBookCatalog) {
      byAuthor.putIfAbsent(b.authorAr, () => []).add(b);
    }
    final lower = t.toLowerCase();
    var names = [
      for (final e in byAuthor.entries)
        if (nameMatchesExact(e.key, t) ||
            e.value.first.authorEn.toLowerCase() == lower)
          e.key,
    ];
    if (names.isEmpty) {
      final n = normalizeArabic(t);
      names = [
        for (final e in byAuthor.entries)
          if (nameMatches(e.key, t) ||
              normalizeArabic(e.key).contains(n) ||
              e.value.first.authorEn.toLowerCase().contains(lower))
            e.key,
      ];
    }
    names.sort((a, b) => byAuthor[b]!.length.compareTo(byAuthor[a]!.length));
    return [
      for (final n in names)
        (n, byAuthor[n]!..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
    ];
  }

  List<LibraryBook> _missingOf(List<LibraryBook> books) => [
        for (final b in books)
          if (b.textEdition != null && !_onDevice.contains(b.id)) b,
      ];

  /// One at a time, like the Authors tab (thirty at once had the bucket
  /// reset most of them - books_tab `_download`).
  Future<void> _downloadAuthor(String author, List<LibraryBook> books) async {
    final todo = _missingOf(books);
    if (todo.isEmpty || _authorProgress.containsKey(author)) return;
    setState(() => _authorProgress[author] = (0, todo.length));
    var failed = 0;
    for (var i = 0; i < todo.length; i++) {
      try {
        await LibraryApiService.instance
            .downloadBook(todo[i].id, todo[i].textEdition!.url);
        _onDevice = {..._onDevice, todo[i].id};
      } catch (e) {
        debugPrint('library: ${todo[i].id} failed to download: $e');
        failed++;
      }
      if (!mounted) return;
      setState(() => _authorProgress[author] = (i + 1, todo.length));
    }
    if (!mounted) return;
    setState(() => _authorProgress.remove(author));
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pluralN('library.download_failed', failed))));
    }
  }

  Future<void> _run(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _hits = const [];
        _books = const [];
        _authors = const [];
        _ran = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final books =
          _scope == _Scope.text ? <LibraryBook>[] : _matchCatalogue(q);
      final hits = (_scope == _Scope.all || _scope == _Scope.text)
          ? await LibraryApiService.instance
              .searchAllBooks(q, phrase: _phrase, exactMarks: _exactMarks)
          : <BookSearchHit>[];
      final authors =
          _scope == _Scope.text ? <(String, List<LibraryBook>)>[] : _matchAuthors(q);
      final onDevice = (await LibraryApiService.instance.downloadedBookIds())
          .toSet();
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _books = books;
        _authors = authors;
        _onDevice = onDevice;
        _ran = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
        _books = const [];
        _authors = const [];
        _ran = true;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _open(BookSearchHit hit) async {
    final book = libraryBookCatalog.where((b) => b.id == hit.bookId).firstOrNull;
    if (book == null) return;
    final path = await LibraryApiService.instance.bookFilePath(hit.bookId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(
        book: book,
        path: path,
        initialPageIndex: hit.pageIndex,
      ),
    ));
  }

  /// A book found by title or author: opened if it is on the device,
  /// otherwise downloaded first, with a spinner on its card.
  Future<void> _openBook(LibraryBook b) async {
    final api = LibraryApiService.instance;
    if (!await api.isBookDownloaded(b.id)) {
      final url = b.textEdition?.url;
      if (url == null) return;
      setState(() => _downloading = b.id);
      try {
        await api.downloadBook(b.id, url);
      } catch (_) {
        if (!mounted) return;
        setState(() => _downloading = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(pluralN('library.download_failed', 1))));
        return;
      }
      if (!mounted) return;
      setState(() => _downloading = null);
    }
    final path = await api.bookFilePath(b.id);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookTextReaderScreen(book: b, path: path),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('library.search_all_books'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _run,
              decoration: InputDecoration(
                hintText: 'library.search_all_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _run('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          _SearchOptions(
            scope: _scope,
            phrase: _phrase,
            exactMarks: _exactMarks,
            onScope: (v) {
              setState(() => _scope = v);
              _run(_controller.text);
            },
            onPhrase: (v) {
              setState(() => _phrase = v);
              _run(_controller.text);
            },
            onExactMarks: (v) {
              setState(() => _exactMarks = v);
              _run(_controller.text);
            },
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_ran && !_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  pluralN('library.text_search_results',
                      _hits.length + _books.length + _authors.length),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          Expanded(
            child: _hits.isEmpty && _books.isEmpty && _authors.isEmpty
                ? _EmptyState(ran: _ran, searching: _searching)
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (_authors.isNotEmpty) ...[
                        _ResultsHeader('library.search_authors_found'.tr(),
                            Icons.person_search_rounded),
                        for (final (name, books) in _authors)
                          AuthorSearchResult(
                            name: properName(name, books.first.authorEn),
                            deathDate: books.first.deathLabel(),
                            books: books,
                            missing: _missingOf(books),
                            progress: _authorProgress[name],
                            onDownloadAll: () => _downloadAuthor(name, books),
                            bookTile: (b) => _BookResult(
                              book: b,
                              busy: _downloading == b.id,
                              onOpen: () => _openBook(b),
                            ),
                          ),
                      ],
                      if (_books.isNotEmpty) ...[
                        _ResultsHeader('library.search_books_found'.tr(),
                            Icons.auto_stories_rounded),
                        for (final b in _books)
                          _BookResult(
                            book: b,
                            busy: _downloading == b.id,
                            onOpen: () => _openBook(b),
                          ),
                      ],
                      if (_hits.isNotEmpty) ...[
                        _ResultsHeader('library.search_in_text_found'.tr(),
                            Icons.format_quote_rounded),
                        for (final h in _hits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HitCard(hit: h, onTap: () => _open(h)),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool ran;
  final bool searching;
  const _EmptyState({required this.ran, required this.searching});

  @override
  Widget build(BuildContext context) {
    if (searching) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ran ? Icons.search_off : Icons.menu_book_outlined,
                size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              ran
                  ? 'library.no_results'.tr()
                  : 'library.search_all_empty'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final BookSearchHit hit;
  final VoidCallback onTap;
  const _HitCard({required this.hit, required this.onTap});

  /// FTS5 wraps the matched words in braces; turn those into real emphasis.
  List<TextSpan> _spans(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final out = <TextSpan>[];
    final re = RegExp(r'\{(.*?)\}');
    var last = 0;
    for (final m in re.allMatches(hit.snippet)) {
      if (m.start > last) {
        out.add(TextSpan(text: hit.snippet.substring(last, m.start)));
      }
      out.add(TextSpan(
        text: m.group(1),
        style: base?.copyWith(
          color: goldText(context),
          fontWeight: FontWeight.w700,
        ),
      ));
      last = m.end;
    }
    if (last < hit.snippet.length) {
      out.add(TextSpan(text: hit.snippet.substring(last)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hit.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${'library.text_page'.tr()} '
                          '${localizeDigits('${hit.printedPage}', uiLanguageCode)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: goldText(context)),
                    ),
                  ),
                ],
              ),
              if (hit.bookAuthor.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  hit.bookAuthor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: _spans(context)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Scope { all, title, author, text }

/// Where to search, and - for the text - how strictly.
class _SearchOptions extends StatelessWidget {
  final _Scope scope;
  final bool phrase;
  final bool exactMarks;
  final ValueChanged<_Scope> onScope;
  final ValueChanged<bool> onPhrase;
  final ValueChanged<bool> onExactMarks;

  const _SearchOptions({
    required this.scope,
    required this.phrase,
    required this.exactMarks,
    required this.onScope,
    required this.onPhrase,
    required this.onExactMarks,
  });

  @override
  Widget build(BuildContext context) {
    final inText = scope == _Scope.all || scope == _Scope.text;
    Widget scopeChip(_Scope s, String key, IconData icon) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            // the check would sit on the avatar icon, muddy
            showCheckmark: false,
            avatar: Icon(icon, size: 17),
            label: Text(key.tr()),
            selected: scope == s,
            onSelected: (_) => onScope(s),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              scopeChip(_Scope.all, 'library.search_scope_all',
                  Icons.travel_explore_rounded),
              scopeChip(_Scope.title, 'library.search_scope_title',
                  Icons.menu_book_rounded),
              scopeChip(_Scope.author, 'library.search_scope_author',
                  Icons.person_rounded),
              scopeChip(_Scope.text, 'library.search_scope_text',
                  Icons.format_quote_rounded),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: inText
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 8, runSpacing: 4, children: [
                      FilterChip(
                        avatar: const Icon(Icons.short_text_rounded, size: 17),
                        label: Text('library.search_opt_phrase'.tr()),
                        selected: phrase,
                        onSelected: onPhrase,
                      ),
                      FilterChip(
                        avatar:
                            const Icon(Icons.text_fields_rounded, size: 17),
                        label: Text('library.search_opt_marks'.tr()),
                        selected: exactMarks,
                        onSelected: onExactMarks,
                      ),
                    ]),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ResultsHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Row(children: [
          Icon(icon, size: 18, color: goldText(context)),
          const SizedBox(width: 6),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// A book matched by its title or its author.
class _BookResult extends StatelessWidget {
  final LibraryBook book;
  final bool busy;
  final VoidCallback onOpen;
  const _BookResult(
      {required this.book, required this.busy, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.gold.withValues(alpha: 0.14),
              ),
              child: Icon(Icons.auto_stories_rounded,
                  color: goldText(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.titleAr,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(book.authorAr,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
