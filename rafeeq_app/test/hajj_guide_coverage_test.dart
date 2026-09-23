import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_step_text.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';

/// The guide on «الحج والعمرة» of الفقه المنهجي (2026-09-23).
void main() {
  final book = BookText.fromBytes(
    File('assets/data/builtin_books/$hajjGuideBook.json').readAsBytesSync(),
  );

  test('the guide reads the bundled chapter, pp. 111-188', () {
    expect(hajjGuideBook, 'al_fiqh_al_manhaji_hajj');
    expect(book.pages.first.printedPage, 111);
    expect(book.pages.last.printedPage, 188);
  });

  test('every step has text, and every range points inside the chapter', () {
    for (final step in hajjSteps) {
      expect(hajjStepParas(step, book), isNotEmpty, reason: step.key);
      for (final r in step.textRanges) {
        expect(r.fromPage, inInclusiveRange(111, 188), reason: step.key);
        expect(r.toPage, inInclusiveRange(r.fromPage, 188), reason: step.key);
        final first = book.pages.firstWhere((p) => p.printedPage == r.fromPage);
        expect(r.fromPara, lessThan(first.paras.length), reason: step.key);
      }
    }
  });

  test('no paragraph of the chapter is left unreachable', () {
    final covered = <String>{};
    for (final step in hajjSteps) {
      for (final r in step.textRanges) {
        for (final page in book.pages) {
          final p = page.printedPage;
          if (p < r.fromPage || p > r.toPage) continue;
          final a = p == r.fromPage ? r.fromPara : 0;
          final b = p == r.toPage ? r.toPara : page.paras.length - 1;
          for (var i = a; i <= b && i < page.paras.length; i++) {
            covered.add('$p:$i');
          }
        }
      }
    }
    final missing = [
      for (final page in book.pages)
        for (var i = 0; i < page.paras.length; i++)
          if (!covered.contains('${page.printedPage}:$i') &&
              page.paras[i].text.trim().isNotEmpty)
            '${page.printedPage}:$i ${page.paras[i].text.substring(0, page.paras[i].text.length.clamp(0, 50))}',
    ];
    expect(missing, isEmpty);
  });

  test('the miqat step opens on the book\'s own miqat text', () {
    final step = hajjSteps.firstWhere((s) => s.key == 'mawaqit');
    final text = hajjStepParas(step, book).map((p) => p.text).join(' ');
    expect(text, contains('ذو الحُليفة'));
    expect(text, contains('أبيار علي'));
  });
}
