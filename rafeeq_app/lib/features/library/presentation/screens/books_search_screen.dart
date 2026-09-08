import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/book_catalog.dart';
import '../../data/library_api_service.dart';
import 'book_text_reader_screen.dart';

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
  bool _searching = false;
  bool _ran = false;

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

  Future<void> _run(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _hits = const [];
        _ran = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final hits = await LibraryApiService.instance.searchAllBooks(q);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _ran = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
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
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_ran && !_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${_hits.length} ${'library.text_search_results'.tr()}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          Expanded(
            child: _hits.isEmpty
                ? _EmptyState(ran: _ran, searching: _searching)
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _hits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _HitCard(
                      hit: _hits[i],
                      onTap: () => _open(_hits[i]),
                    ),
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
          color: AppColors.gold,
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
                      '${'library.text_page'.tr()} ${hit.printedPage}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.gold),
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
