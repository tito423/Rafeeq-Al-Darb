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
  /// The saying itself, in the reader's language when we have it there.
  final String text;

  /// The saying in Arabic, always — the words the author actually wrote.
  ///
  /// The card shows the translation to a reader who chose another language,
  /// and this under it in the Arabic face: a translated maxim without the
  /// original is a claim about a book rather than a quotation from it.
  final String arabic;

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
    required this.arabic,
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
/// Extracted by `scripts/build_quotes.py` from the library's own books, then
/// curated and translated by `scripts/quotes_curated.py`: the extractor cannot
/// tell a maxim from the middle of an argument, so the shipped set is the
/// subset that reads as a finished thought, each one carried in all seven
/// languages. حلية الأولياء is deliberately absent — it is a book of
/// narrations, and an automatic filter cannot tell Abu Nu'aym's maxims from
/// ungraded hadith.
class QuoteBook {
  final String id;
  final String titleAr;
  final String authorAr;
  final String sourceLabel;
  /// `text` is keyed by language code and always carries `ar`.
  final List<({Map<String, String> text, int page})> quotes;

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

  /// [locale] is the language the reader has chosen; the Arabic is the
  /// fallback, because it is the one language every quote is certain to have.
  Quote? at(int bookIndex, int quoteIndex, {String locale = 'ar'}) {
    if (bookIndex < 0 || bookIndex >= books.length) return null;
    final b = books[bookIndex];
    if (quoteIndex < 0 || quoteIndex >= b.quotes.length) return null;
    final q = b.quotes[quoteIndex];
    final arabic = q.text['ar'] ?? '';
    return Quote(
      text: q.text[locale] ?? arabic,
      arabic: arabic,
      page: q.page,
      bookId: b.id,
      bookTitle: b.titleAr,
      authorAr: b.authorAr,
      sourceLabel: b.sourceLabel,
    );
  }

  /// `"bookIndex:quoteIndex"`, as carried in a notification payload.
  Quote? byKey(String key, {String locale = 'ar'}) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final b = int.tryParse(parts[0]);
    final q = int.tryParse(parts[1]);
    if (b == null || q == null) return null;
    return at(b, q, locale: locale);
  }

  /// A uniformly random quote across the whole corpus — weighted by how many
  /// quotes each book has, not one book then one quote, so a book with
  /// thirty-four is not made as rare as one with six.
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

/// Parse the bundled corpus. **There is one of these.**
///
/// There were two: `quote_navigation.dart` re-read and re-parsed the same
/// asset to open a notification's card, and when the schema grew a language
/// map the second copy still expected a bare string and stopped compiling —
/// which is the lucky outcome. The five copies of the byte formatter this
/// project once carried all drifted silently instead.
QuoteLibrary parseQuoteLibrary(Map<String, dynamic> doc) => QuoteLibrary([
      for (final b in doc['books'] as List<dynamic>)
        QuoteBook(
          id: (b as Map<String, dynamic>)['id'] as String,
          titleAr: b['titleAr'] as String? ?? '',
          authorAr: b['authorAr'] as String? ?? '',
          sourceLabel: b['sourceLabel'] as String? ?? '',
          quotes: [
            for (final q in b['quotes'] as List<dynamic>)
              (
                // schema 2: `t` is a map of language code to text, and it
                // always carries `ar`. Schema 1 shipped a bare Arabic string,
                // and a build that still has one is read rather than crashed
                // on.
                text: switch ((q as Map<String, dynamic>)['t']) {
                  final Map<String, dynamic> m => {
                      for (final e in m.entries) e.key: e.value as String,
                    },
                  final String only => {'ar': only},
                  _ => const {'ar': ''},
                },
                page: q['p'] as int? ?? 0,
              )
          ],
        )
    ]);

final quoteLibraryProvider = FutureProvider<QuoteLibrary>((ref) async {
  final raw = await rootBundle.loadString('assets/data/quotes.json');
  return parseQuoteLibrary(jsonDecode(raw) as Map<String, dynamic>);
});
