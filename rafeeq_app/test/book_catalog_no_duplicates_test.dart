import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// No book may appear in the library twice.
///
/// Six entries were shipped that did. Three of them — «الأذكار»,
/// «الأربعون النووية», «التبيان في آداب حملة القرآن» — were two uploads of the
/// *same* Shamela book under two ids; both copies were fetched and compared
/// page by page and came back 411/411, 81/81 and 224/224 byte-identical, TOC
/// included. The other three were al-Albani's takhrij volumes catalogued under
/// the classical author's name (`tahqiq_riyad_al_salihin_lil_albani`,
/// `tahqiq_al_iman`, `takhrij_al_kalim_al_tayyib`), which is how they survived
/// the v3.29.0 purge that removed every other book of his.
///
/// The catalogue was 257 entries and 251 books, and **nothing in the suite
/// noticed** — 282 tests passed over it. `book ids are unique` only ever
/// compared ids, and two copies of one book never share an id. This is trap
/// #36 — a catalogue nobody opened is a catalogue of claims — so the test
/// asks the question a reader asks: is this book already on the shelf?
///
/// If a second *edition* of a book is ever wanted deliberately, the two
/// entries must differ in `titleAr` — «الكلم الطيب» vs «صحيح الكلم الطيب» —
/// because that is what the reader sees on the card. An entry that is
/// indistinguishable on screen is a duplicate however it is filed.
String _key(String s) {
  // Not `\w`: Dart's `\w` is ASCII and `unicode: true` does not widen it, so
  // it deletes every Arabic letter (trap #47). Name what to keep instead.
  final bare = normalizeArabic(s)
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^ء-ي٠-٩a-zA-Z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return bare;
}

void main() {
  // The normaliser has to return something before any comparison built on it
  // means anything — `lesson_heading_bare_test.dart` exists because two tests
  // once passed on `'' == ''`.
  test('the title key keeps the Arabic it is given', () {
    expect(_key('الأذكار'), 'الاذكار');
    expect(_key('التبيان في آداب حملة القرآن'), 'التبيان في اداب حمله القران');
    expect(_key('شيخ الإسلام ابن تيمية'), 'شيخ الاسلام ابن تيميه');
    for (final book in libraryBookCatalog) {
      expect(_key(book.titleAr), isNotEmpty, reason: book.id);
      expect(_key(book.authorAr), isNotEmpty, reason: book.id);
    }
  });

  // Every collision is collected and reported together. An `expect` inside
  // the loop stops at the first one, and this defect arrives in batches —
  // six entries at once, the last time.
  List<String> collisions(String Function(LibraryBook) keyOf) {
    final seen = <String, String>{};
    final out = <String>[];
    for (final book in libraryBookCatalog) {
      final key = keyOf(book);
      if (key.isEmpty) continue;
      final first = seen[key];
      if (first != null) {
        out.add('$key → `$first` and `${book.id}`');
      } else {
        seen[key] = book.id;
      }
    }
    return out;
  }

  test('no two books share a title and an author', () {
    expect(
      collisions((b) => '${_key(b.titleAr)} | ${_key(b.authorAr)}'),
      isEmpty,
      reason: 'the same book is in the catalogue twice. Either it is one book '
          'uploaded twice — delete one entry and its object on R2 — or it is a '
          'second edition, which must carry a title the reader can tell apart '
          'on the card.',
    );
  });

  test('no two books point at the same hosted file', () {
    expect(collisions((b) => b.textEdition?.url ?? ''), isEmpty);
  });

  test('no two books share an English title', () {
    // `titleEn` is what a non-Arabic reader sorts and searches by, so a
    // collision there is the same defect on the other six locales.
    expect(collisions((b) => b.titleEn.toLowerCase().trim()), isEmpty);
  });
}
