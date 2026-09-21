import '../../library/data/book_text.dart';
import 'hajj_guide.dart';

/// The source range, verbatim, with the existing commentary filter applied.
List<BookPara> hajjStepParas(HajjStep step, BookText? book) {
  final paras = <BookPara>[];
  for (final range in step.textRanges) {
    for (final page in book?.pages ?? const <BookPage>[]) {
      if (page.printedPage < range.fromPage ||
          page.printedPage > range.toPage) {
        continue;
      }
      final first = page.printedPage == range.fromPage ? range.fromPara : 0;
      final last = page.printedPage == range.toPage
          ? range.toPara
          : page.paras.length - 1;
      for (var i = first; i <= last && i < page.paras.length; i++) {
        final para = page.paras[i];
        if (para.text.trim().isEmpty || isHajjGuideNote(para.text)) continue;
        paras.add(para);
      }
    }
  }
  return paras;
}
