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

import '../../../../core/i18n/proper_name.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/accordion.dart';
import '../../../../core/widgets/paired_list_view.dart';
import '../../../shamela/data/shamela_library.dart';
import '../../data/book_catalog.dart';
import '../../data/book_category.dart';
import '../../data/hidden_books.dart';
import '../../data/library_api_service.dart';
import '../../data/library_featured.dart';
import '../screens/book_text_reader_screen.dart';
import '../widgets/book_card.dart';
import '../widgets/hidden_books_sheet.dart';
import 'spoken_books_view.dart';

class BooksTab extends StatefulWidget {
  const BooksTab({super.key});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

/// Which edition of a book a catalog card is currently acting on.

class _BooksTabState extends State<BooksTab> {
  StreamSubscription<List<DownloadTask>>? _sub;
  StreamSubscription<void>? _bookSub;

  /// download id -> local file path (once on disk). Keyed by `book.id` for the
  /// image PDF and by `book.textDownloadId` for the text edition.
  final Map<String, String> _paths = {};

  /// download id -> bytes on disk.

  @override
  void initState() {
    super.initState();
    // A book taken off the list (or put back) redraws both lists at once.
    HiddenBooks.instance.ensureReady();
    HiddenBooks.instance.addListener(_onHiddenChanged);
    _loadRegistry();
    _sub = DownloadManager.instance.stream.listen((_) => _loadRegistry());
    _bookSub = LibraryApiService.instance.changes.listen(
      (_) => _loadRegistry(),
    );
  }

  Future<void> _loadRegistry() async {
    final paths = <String, String>{};
    for (final book in [...libraryBookCatalog, ...ShamelaLibrary.instance.books]) {
      if (await LibraryApiService.instance.isBookDownloaded(book.id)) {
        paths[book.id] = await LibraryApiService.instance.bookFilePath(book.id);
      }
    }
    if (mounted) {
      setState(() {
        _paths
          ..clear()
          ..addAll(paths);
      });
    }
  }

  void _onHiddenChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    HiddenBooks.instance.removeListener(_onHiddenChanged);
    _sub?.cancel();
    _bookSub?.cancel();
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
      await LibraryApiService.instance.downloadBook(
        book.id,
        book.textEdition!.url,
      );
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
      ..showSnackBar(
        SnackBar(content: Text(pluralN('library.download_failed', failed))),
      );
  }

  void _open(LibraryBook book) {
    if (!_paths.containsKey(book.id)) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BookTextReaderScreen(book: book, path: _paths[book.id]!),
      ),
    );
  }

  Future<void> _delete(LibraryBook book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(''),
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
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            // A segmented control rather than a second underline bar, so the
            // two levels of tabs read as two levels.
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  // One size for all four labels. Shrinking each on its own
                  // left «Categories» and «My library» tiny beside «Audio» at
                  // the largest system font (owner's phone, 1.45, 2026-09-25).
                  // The longest label sets the size; FittedBox stays as the
                  // guard against clipping.
                  const keys = [
                    'library.sub_categories',
                    'library.sub_authors',
                    'library.sub_spoken',
                    'library.sub_mine',
                  ];
                  final base =
                      (Theme.of(context).textTheme.titleSmall ??
                              const TextStyle(fontSize: 14))
                          .copyWith(fontWeight: FontWeight.w700);
                  final scaler = MediaQuery.textScalerOf(context);
                  var widest = 0.0;
                  for (final key in keys) {
                    final painter = TextPainter(
                      text: TextSpan(text: key.tr(), style: base),
                      textScaler: scaler,
                      textDirection: Directionality.of(context),
                      maxLines: 1,
                    )..layout();
                    if (painter.width > widest) widest = painter.width;
                    painter.dispose();
                  }
                  final slot = box.maxWidth / keys.length - 32;
                  final factor = widest > slot && widest > 0
                      ? slot / widest
                      : 1.0;
                  final fontSize = (base.fontSize ?? 14) * factor;
                  return TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: BorderRadius.circular(12),
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    // Flat gold on the white chosen tab: 2.45 : 1 (light theme).
                    labelColor: readableOn(
                      AppColors.gold,
                      Theme.of(context).colorScheme.surface,
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    // A four-way TabBar gives each tab a quarter of the width
                    // and a `Tab`'s text CLIPS rather than ellipsises, so on a
                    // phone a little narrower than the emulator «التصنيفات» lost
                    // its alif and «مسموعة» its meem - «المؤلفين والتصنيفات
                    // واللي جنبها في مكتبتي مقصوصة ومش كاملة». Shrinking a label
                    // to fit its quarter keeps the word whole, which is what a
                    // tab is for.
                    tabs: [
                      for (final key in keys)
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              key.tr(),
                              style: TextStyle(fontSize: fontSize),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CategoriesView(
                  paths: _paths,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _AuthorsView(
                  paths: _paths,
                  onDownload: _download,
                  onOpen: _open,
                ),
                SpokenBooksView(
                  paths: _paths,
                  onDownload: _download,
                  onOpen: _open,
                ),
                _MyLibraryView(paths: _paths, onOpen: _open, onDelete: _delete),
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
    for (final b in visibleBookCatalog()) {
      byAuthor.putIfAbsent(b.authorAr, () => []).add(b);
    }
    // Sort authors alphabetically, sort each author's books
    final authors = byAuthor.keys.toList()..sort();
    for (final list in byAuthor.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }

    // Sideways two authors a row (`PairedListView`).
    return PairedListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gap: 0,
      header: const HiddenBooksButton(),
      children: [
        for (var i = 0; i < authors.length; i++)
          _AuthorExpansionTile(
            key: PageStorageKey<String>(authors[i]),
            authorName: properName(
              authors[i],
              byAuthor[authors[i]]!.first.authorEn,
            ),
            deathDate: byAuthor[authors[i]]!.first.deathLabel(),
            books: byAuthor[authors[i]]!,
            // Closed on entry, by the owner's instruction — the authors view
            // is a long list and opening the first one is an arbitrary
            // choice on a screen where nothing has been picked yet.
            initiallyExpanded: false,
            paths: paths,
            onDownload: onDownload,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _AuthorExpansionTile extends StatefulWidget {
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
  State<_AuthorExpansionTile> createState() => _AuthorExpansionTileState();
}

class _AuthorExpansionTileState extends State<_AuthorExpansionTile> {
  final Set<String> _selected = {};
  bool _selectionMode = false;

  List<LibraryBook> get _missing => [
    for (final b in widget.books)
      if (b.textEdition != null &&
          !widget.paths.containsKey(b.id) &&
          DownloadManager.instance.taskById(b.id)?.status !=
              DownloadStatus.downloading)
        b,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AccordionTile(
      builder: (controller, onExpansionChanged) => ExpansionTile(
        controller: controller,
        onExpansionChanged: onExpansionChanged,
        initiallyExpanded: widget.initiallyExpanded,
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          child: Icon(Icons.person_outline, color: goldText(context), size: 22),
        ),
        title: Text(
          widget.authorName,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          localizeDigits(
            widget.deathDate.isEmpty
                ? pluralN('library.book_count', widget.books.length)
                : '${widget.deathDate} • ${pluralN('library.book_count', widget.books.length)}',
            context.locale.languageCode,
          ),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_selectionMode && _missing.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      for (final b in _missing) {
                        widget.onDownload(b);
                      }
                    },
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(
                      localizeDigits(
                        trn('library.download_author_all', args: ['${_missing.length}']),
                        context.locale.languageCode,
                      ),
                    ),
                  )
                else if (!_selectionMode)
                  const SizedBox(),
                
                if (_selectionMode) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: Text('إلغاء التحديد'),
                    onPressed: () => setState(() {
                      _selectionMode = false;
                      _selected.clear();
                    }),
                  ),
                  Row(
                    children: [
                      if (_selected.any((id) => widget.paths.containsKey(id)))
                        IconButton.filledTonal(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () async {
                            final toDelete = _selected.where((id) => widget.paths.containsKey(id)).toList();
                            for (final id in toDelete) {
                              await LibraryApiService.instance.deleteBook(id);
                            }
                            if (mounted) {
                              setState(() {
                                _selectionMode = false;
                                _selected.clear();
                              });
                            }
                          },
                        ),
                      if (_selected.any((id) => !widget.paths.containsKey(id)))
                        IconButton.filledTonal(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            final toDownload = widget.books.where((b) => _selected.contains(b.id) && !widget.paths.containsKey(b.id));
                            for (final b in toDownload) {
                              widget.onDownload(b);
                            }
                            setState(() {
                              _selectionMode = false;
                              _selected.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ] else ...[
                  TextButton.icon(
                    icon: const Icon(Icons.checklist),
                    label: Text('تحديد'),
                    onPressed: () => setState(() => _selectionMode = true),
                  ),
                ]
              ],
            ),
          ),
          for (final b in widget.books) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Checkbox(
                      value: _selected.contains(b.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) _selected.add(b.id);
                          else _selected.remove(b.id);
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: BookCard(
                    book: b,
                    paths: widget.paths,
                    onDownload: () => widget.onDownload(b),
                    onOpen: () => widget.onOpen(b),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
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
    for (final b in visibleBookCatalog()) {
      byCat.putIfAbsent(b.category, () => []).add(b);
    }
    final cats = byCat.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // P3‑54: each category is now a collapsible `ExpansionTile` — tap the
    // header to expand its books, tap again to collapse — instead of one long
    // always-open list. All start collapsed (owner, 2026-09-29), and this
    // view now comes before the authors view. `PageStorageKey` keeps each tile's open/closed
    // state across rebuilds (locale/theme changes, scrolling far away and
    // back) so the user's expand/collapse choices don't reset under them.
    // Sideways two shelves a row (`PairedListView`).
    return PairedListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gap: 0,
      header: const HiddenBooksButton(),
      children: [
        for (var i = 0; i < cats.length; i++)
          _CategoryExpansionTile(
            key: PageStorageKey<int>(cats[i].index),
            category: cats[i],
            // `shelfOrder` first, then the Arabic collation handle. Every
            // shelf but طالب العلم leaves `shelfOrder` at 0, so this is the
            // old alphabetical sort everywhere else; that one shelf is a
            // graduated path and sorting it by title would put الآجرومية at
            // the top and جامع بيان العلم وفضله — what a student reads first
            // — in the middle.
            books: byCat[cats[i]]!
              ..sort((x, y) {
                final byShelf = x.shelfOrder.compareTo(y.shelfOrder);
                return byShelf != 0 ? byShelf : x.sortKey.compareTo(y.sortKey);
              }),
            initiallyExpanded: false,
            paths: paths,
            onDownload: onDownload,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _CategoryExpansionTile extends StatefulWidget {
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
  State<_CategoryExpansionTile> createState() => _CategoryExpansionTileState();
}

class _CategoryExpansionTileState extends State<_CategoryExpansionTile> {
  final Set<String> _selected = {};
  bool _selectionMode = false;

  List<LibraryBook> get _missing => [
    for (final b in widget.books)
      if (b.textEdition != null &&
          !widget.paths.containsKey(b.id) &&
          DownloadManager.instance.taskById(b.id)?.status !=
              DownloadStatus.downloading)
        b,
  ];

  @override
  Widget build(BuildContext context) {
    return AccordionTile(
      builder: (controller, onExpansionChanged) => ExpansionTile(
        controller: controller,
        onExpansionChanged: onExpansionChanged,
        initiallyExpanded: widget.initiallyExpanded,
        leading: Icon(widget.category.icon, color: goldText(context)),
        title: Text(
          widget.category.labelKey.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: goldText(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          localizeDigits(
            pluralN('library.book_count', widget.books.length),
            context.locale.languageCode,
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_selectionMode && _missing.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      for (final b in _missing) {
                        widget.onDownload(b);
                      }
                    },
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(
                      localizeDigits(
                        trn('library.download_author_all', args: ['${_missing.length}']),
                        context.locale.languageCode,
                      ),
                    ),
                  )
                else if (!_selectionMode)
                  const SizedBox(),

                if (_selectionMode) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: Text('إلغاء التحديد'),
                    onPressed: () => setState(() {
                      _selectionMode = false;
                      _selected.clear();
                    }),
                  ),
                  Row(
                    children: [
                      if (_selected.any((id) => widget.paths.containsKey(id)))
                        IconButton.filledTonal(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () async {
                            final toDelete = _selected.where((id) => widget.paths.containsKey(id)).toList();
                            for (final id in toDelete) {
                              await LibraryApiService.instance.deleteBook(id);
                            }
                            if (mounted) {
                              setState(() {
                                _selectionMode = false;
                                _selected.clear();
                              });
                            }
                          },
                        ),
                      if (_selected.any((id) => !widget.paths.containsKey(id)))
                        IconButton.filledTonal(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            final toDownload = widget.books.where((b) => _selected.contains(b.id) && !widget.paths.containsKey(b.id));
                            for (final b in toDownload) {
                              widget.onDownload(b);
                            }
                            setState(() {
                              _selectionMode = false;
                              _selected.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ] else ...[
                  TextButton.icon(
                    icon: const Icon(Icons.checklist),
                    label: Text('تحديد'),
                    onPressed: () => setState(() => _selectionMode = true),
                  ),
                ]
              ],
            ),
          ),
          for (final (heading, group) in _groups()) ...[
            if (heading != null) _ShelfHeading(heading),
            for (final b in group) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Checkbox(
                        value: _selected.contains(b.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) _selected.add(b.id);
                            else _selected.remove(b.id);
                          });
                        },
                      ),
                    ),
                  Expanded(
                    child: BookCard(
                      book: b,
                      paths: widget.paths,
                      onDownload: () => widget.onDownload(b),
                      onOpen: () => widget.onOpen(b),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  List<(String?, List<LibraryBook>)> _groups() {
    if (widget.category == BookCategory.talibIlm) {
      final stages = <int, List<LibraryBook>>{};
      for (final b in widget.books) {
        stages.putIfAbsent(b.shelfOrder, () => []).add(b);
      }
      return [
        for (final e in stages.entries)
          (
            e.key >= 1 && e.key <= 4
                ? 'library.talib_stage_${e.key}'.tr()
                : null,
            e.value,
          ),
      ];
    }
    final byId = {for (final b in widget.books) b.id: b};
    final featured = [
      for (final id in featuredBookIds[widget.category] ?? const <String>[])
        if (byId[id] != null) byId[id]!,
    ];
    if (featured.isEmpty) return [(null, widget.books)];
    final rest = widget.books.where((b) => !featured.contains(b)).toList();
    return [
      ('library.featured_heading'.tr(), featured),
      if (rest.isNotEmpty) ('library.rest_heading'.tr(), rest),
    ];
  }
}

class _ShelfHeading extends StatelessWidget {
  final String text;
  const _ShelfHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final gold = goldText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
    // One entry per book actually on disk.
    //
    // This used to be split into «مصوّر» and «نصّي» sections, from when the
    // library also carried scanned PDF editions. Those are gone —
    // `LibraryBook` has nothing but a `textEdition` now — and the split had
    // quietly become wrong: `paths` is filled above keyed by `book.id`, while
    // the text section tested for `book.textDownloadId` (`<id>_text`), which
    // nothing ever writes. So «نصّي» could never render and every downloaded
    // book, all of them text, was listed under a heading that said it was a
    // scan. Found by downloading أحكام الجنائز and reading the screen.
    final sorted = [...libraryBookCatalog, ...ShamelaLibrary.instance.books]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final rows = <LibraryBook>[
      for (final b in sorted)
        if (paths.containsKey(b.id)) b,
    ];

    if (rows.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_done_outlined,
                size: 56,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text('library.empty_mine'.tr(), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    // Sideways two books a row (`PairedListView`).
    return PairedListView(
      padding: const EdgeInsets.all(14),
      gap: 8,
      children: [
        for (final b in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _row(context, b),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, LibraryBook b) {
    final scheme = Theme.of(context).colorScheme;
    const size = '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: goldText(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    properName(b.titleAr, b.titleEn),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      b.category.labelKey.tr(),
                      if (size.isNotEmpty) size,
                    ].join(' · '),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
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

// ── Hadith hub (unchanged from Phase 1) ────────────────────────────────────
