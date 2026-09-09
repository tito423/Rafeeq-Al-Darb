import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One saying, and the book it is in.
///
/// [book] is not decoration. The owner's instruction was «كل مقولة لازم تحمل
/// اسم كتابها», and CLAUDE.md §1.1/§1.2 say the same thing in general: nothing
/// attributed to a scholar without a source. There is no constructor that
/// builds a quote without one.
class Quote {
  final String text;

  /// The printed page it sits on in [sourceLabel]'s edition.
  final int page;

  final String bookId;
  final String bookTitle;
  final String authorAr;

  /// The full printed-edition line — publisher, editor, print, year — the
  /// same string the book's reader shows at all times.
  final String sourceLabel;

  const Quote({
    required this.text,
    required this.page,
    required this.bookId,
    required this.bookTitle,
    required this.authorAr,
    required this.sourceLabel,
  });

  /// `bookIndex:quoteIndex` — what travels in a notification payload, so the
  /// card opens on the quote the notification actually showed rather than on
  /// a fresh random one.
  static String key(int book, int quote) => '$book:$quote';
}

/// Every quote the app ships, read from `assets/data/quotes.json`.
///
/// Bundled rather than downloaded: it is ~110 KB, and a notification that
/// fires with no connection has to have something to say.
///
/// Built by `scripts/build_quotes.py` from the library's own books. Three of
/// the four books the owner named are in it; حلية الأولياء is deliberately
/// not, and that script says why at length — it is a book of narrations, and
/// an automatic filter cannot tell Abu Nu'aym's maxims from ungraded hadith.
class QuoteBook {
  final String id;
  final String titleAr;
  final String authorAr;
  final String sourceLabel;
  final List<({String text, int page})> quotes;

  const QuoteBook({
    required this.id,
    required this.titleAr,
    required this.authorAr,
    required this.sourceLabel,
    required this.quotes,
  });
}

class QuoteLibrary {
  final List<QuoteBook> books;
  const QuoteLibrary(this.books);

  int get total => books.fold(0, (n, b) => n + b.quotes.length);

  Quote? at(int bookIndex, int quoteIndex) {
    if (bookIndex < 0 || bookIndex >= books.length) return null;
    final b = books[bookIndex];
    if (quoteIndex < 0 || quoteIndex >= b.quotes.length) return null;
    final q = b.quotes[quoteIndex];
    return Quote(
      text: q.text,
      page: q.page,
      bookId: b.id,
      bookTitle: b.titleAr,
      authorAr: b.authorAr,
      sourceLabel: b.sourceLabel,
    );
  }

  /// `"bookIndex:quoteIndex"`, as carried in a notification payload.
  Quote? byKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final b = int.tryParse(parts[0]);
    final q = int.tryParse(parts[1]);
    if (b == null || q == null) return null;
    return at(b, q);
  }

  /// A uniformly random quote across the whole corpus — weighted by how many
  /// quotes each book has, not one book then one quote, so «لا تحزن»'s 284
  /// are not made as rare as «روضة العقلاء»'s 31.
  (int, int)? randomIndex(Random rng) {
    if (total == 0) return null;
    var n = rng.nextInt(total);
    for (var b = 0; b < books.length; b++) {
      if (n < books[b].quotes.length) return (b, n);
      n -= books[b].quotes.length;
    }
    return null;
  }
}

final quoteLibraryProvider = FutureProvider<QuoteLibrary>((ref) async {
  final raw = await rootBundle.loadString('assets/data/quotes.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  return QuoteLibrary([
    for (final b in doc['books'] as List<dynamic>)
      QuoteBook(
        id: (b as Map<String, dynamic>)['id'] as String,
        titleAr: b['titleAr'] as String? ?? '',
        authorAr: b['authorAr'] as String? ?? '',
        sourceLabel: b['sourceLabel'] as String? ?? '',
        quotes: [
          for (final q in b['quotes'] as List<dynamic>)
            (
              text: (q as Map<String, dynamic>)['t'] as String,
              page: q['p'] as int? ?? 0,
            )
        ],
      )
  ]);
});
