import '../../library/data/book_text.dart';
import 'hajj_guide.dart';

/// Comparison only: never applied to the text displayed from the book.
String hajjHeadingBare(String text) => text
    .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp(r'[^ء-ي٠-٩a-zA-Z0-9\s]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The source range, verbatim, with the existing commentary filter applied.
/// Only the two known opening headings of the Umrah chapter are omitted:
/// its card already supplies the title. Any unexpected opening stays visible.
List<BookPara> hajjStepParas(HajjStep step, BookText? book) {
  final paras = <BookPara>[];
  for (final page in book?.pages ?? const <BookPage>[]) {
    if (page.printedPage < step.fromPage || page.printedPage > step.toPage) {
      continue;
    }
    final first = page.printedPage == step.fromPage ? step.fromPara : 0;
    final last = page.printedPage == step.toPage
        ? step.toPara
        : page.paras.length - 1;
    for (var i = first; i <= last && i < page.paras.length; i++) {
      final para = page.paras[i];
      if (para.text.trim().isEmpty || isHajjGuideNote(para.text)) continue;
      paras.add(para);
    }
  }
  if (step.key == 'umrah' &&
      paras.length > 2 &&
      hajjHeadingBare(paras[0].text) == 'الباب الرابع' &&
      hajjHeadingBare(paras[1].text) == 'في العمرة وفيه مسائل') {
    return paras.sublist(2);
  }
  return paras;
}
