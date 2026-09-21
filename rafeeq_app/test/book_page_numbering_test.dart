import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/library/data/builtin_books.dart';

/// «كل الكتب في المكتبة عدادات الصفحات غلط. انا عديت على عشر كتب»
/// (2026-09-21).
///
/// The reader trusted three things the files said about themselves — the
/// `printReliable` flag, the `pageCount`, and each table-of-contents entry's
/// `pageIndex` — and all three are wrong in books that shipped.
///
/// The flag was the worst of them because it only ever meant "monotonic", and
/// a REPEATED page number is monotonic. Shamela splits one printed page into
/// several stream units, so six of the 33 bundled books carry repeats:
/// `mishkat_al_masabih` has 7,436 pages over 1,701 distinct numbers (5,735
/// duplicates) and still claimed a trustworthy print scale. On those books
/// «صفحة ٢٠٠» sat still for page after page while the slider ran to 7,436
/// under a label that stopped at 1,771.
///
/// These tests are written against the SHIPPED files, not fixtures alone,
/// because that is the only place the defect lived, and both halves were RUN
/// against the broken code before being trusted (trap #23):
///
///  * relaxing the strict-increase check back to `<` - the rule as it
///    shipped - fails here with «الأدب المفرد: page 2 is numbered 14 after
///    14 — that is not a scale».
///  * restoring the file's own `pageIndex` fails with «العمدة في الأحكام:
///    «منهجي في التحقيق» says page 7 and opens page 13».
void main() {
  List<BookText> shipped() => [
        for (final id in builtinBookIds)
          BookText.fromBytes(
              File('assets/data/builtin_books/$id.json').readAsBytesSync()),
      ];

  BookText build({
    required List<int> printed,
    bool printMatches = true,
    bool printReliable = true,
    List<Map<String, Object>> toc = const [],
    int? declaredPageCount,
  }) =>
      BookText.fromJson(<String, dynamic>{
        'meta': <String, dynamic>{
          'titleAr': 'x',
          'printMatches': printMatches,
          'printReliable': printReliable,
          'pageCount': declaredPageCount ?? printed.length,
          'sectionCount': 99,
        },
        'toc': toc,
        'pages': [
          for (final p in printed)
            {
              'p': p,
              'paras': [
                {'t': 'نص', 'k': 'body'}
              ],
            },
        ],
      });

  test('a repeated printed page is not a scale, whatever the file claims', () {
    // The shape of every one of the six: the number stands still while the
    // position moves.
    final doc = build(printed: [10, 11, 11, 11, 12]);
    expect(doc.meta.printReliable, isFalse);
    expect(doc.printedPageAt(0), isNull,
        reason: 'with no usable scale the reader shows position, not a number');
  });

  test('a strictly increasing run with gaps IS a scale', () {
    final doc = build(printed: [23, 24, 26, 27, 61]);
    expect(doc.meta.printReliable, isTrue);
    expect(doc.printedPageAt(4), 61);
    expect(doc.firstPrintedPage, 23);
    expect(doc.lastPrintedPage, 61);
  });

  test('Shamela\'s unnumbered cover leaf does not print as «صفحة ٠»', () {
    // Five bundled books open on a page whose `p` is 0 — always index 0,
    // never anywhere else.
    final doc = build(printed: [0, 7, 8, 9]);
    expect(doc.meta.printReliable, isTrue,
        reason: 'one unnumbered leaf must not cost the whole book its scale');
    expect(doc.printedPageAt(0), isNull);
    expect(doc.printedPageAt(1), 7);
    expect(doc.firstPrintedPage, 7,
        reason: 'the rail must not start at zero');
  });

  test('a book that does not claim its print matches never gets a scale', () {
    expect(build(printed: [1, 2, 3], printMatches: false).meta.printReliable,
        isFalse);
    expect(build(printed: [1, 2, 3], printReliable: false).meta.printReliable,
        isFalse);
  });

  test('counts are counted, not read off the meta block', () {
    final doc = build(
      printed: [1, 2, 3],
      declaredPageCount: 448,
      toc: const [
        {'title': 'أ', 'page': 1, 'pageIndex': 0, 'level': 0},
      ],
    );
    expect(doc.meta.pageCount, 3);
    expect(doc.meta.sectionCount, 1);
  });

  test('a section index that contradicts its own page number is re-derived',
      () {
    final doc = build(
      printed: [10, 11, 12, 13],
      toc: const [
        // Says page 12, points at the page numbered 10.
        {'title': 'ب', 'page': 12, 'pageIndex': 0, 'level': 1},
        // Points past the end entirely.
        {'title': 'ج', 'page': 13, 'pageIndex': 99, 'level': 1},
      ],
    );
    expect(doc.toc[0].pageIndex, 2);
    expect(doc.toc[1].pageIndex, 3);
  });

  test('an index is clamped, never thrown, when it cannot be re-derived', () {
    final doc = build(
      printed: [5, 5, 6],
      toc: const [
        {'title': 'د', 'page': 900, 'pageIndex': 77, 'level': 1},
      ],
    );
    expect(doc.toc.single.pageIndex, 2);
  });

  // ── and the same rules over everything that actually ships ──────────────
  test('no shipped book claims a printed scale it does not have', () {
    final docs = shipped();
    expect(docs.length, greaterThanOrEqualTo(32));
    var withScale = 0;
    for (final doc in docs) {
      if (!doc.meta.printReliable) continue;
      withScale++;
      final ps = [for (final p in doc.pages) p.printedPage];
      var i = 0;
      while (i < ps.length && ps[i] <= 0) {
        i++;
      }
      expect(i, lessThanOrEqualTo(1),
          reason: '${doc.meta.titleAr}: more than a cover leaf is unnumbered');
      for (var k = i + 1; k < ps.length; k++) {
        expect(ps[k], greaterThan(ps[k - 1]),
            reason: '${doc.meta.titleAr}: page ${k + 1} is numbered ${ps[k]} '
                'after ${ps[k - 1]} — that is not a scale');
      }
    }
    expect(withScale, greaterThan(0),
        reason: 'the rule cannot be so strict that no book keeps its numbers');
  });

  test('every section in every shipped book opens the page it names', () {
    // Four entries in the whole library name a page the file does not
    // contain at all - the editor's introduction, dropped from the text
    // stream while the contents list kept pointing at it
    // (`nawasikh_al_quran`, `nuzhat_al_nazar`, `umdat_al_ahkam` and
    // `jami_al_ulum_wal_hikam`, one each). Those cannot be opened because
    // the page is not there; they are held to landing inside the book, and
    // the فهرس prints the number of the page it really opens, so the
    // entry and its destination still agree on screen.
    var unreachable = 0;
    for (final doc in shipped()) {
      final present = {for (final p in doc.pages) p.printedPage};
      for (final s in doc.toc) {
        expect(s.pageIndex, inInclusiveRange(0, doc.pages.length - 1),
            reason: '${doc.meta.titleAr}: «${s.title}» points outside the book');
        if (s.page <= 0 || !doc.meta.printReliable) continue;
        if (!present.contains(s.page)) {
          unreachable++;
          continue;
        }
        expect(doc.printedPageAt(s.pageIndex), s.page,
            reason: '${doc.meta.titleAr}: «${s.title}» says page ${s.page} '
                'and opens page ${doc.printedPageAt(s.pageIndex)}');
      }
    }
    expect(unreachable, 4,
        reason: 'the four known-missing pages, counted so a fifth cannot '
            'appear unnoticed');
  });

  test('the counts a book reports are the ones it carries', () {
    for (final doc in shipped()) {
      expect(doc.meta.pageCount, doc.pages.length, reason: doc.meta.titleAr);
      expect(doc.meta.sectionCount, doc.toc.length, reason: doc.meta.titleAr);
    }
  });
}
