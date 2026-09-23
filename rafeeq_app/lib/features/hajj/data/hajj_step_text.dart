import '../../library/data/book_text.dart';
import 'hajj_guide.dart';

/// The source range, verbatim, with the existing commentary filter applied
/// and the footnote markers taken out (see [withoutNoteMarkers]).
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
        paras.add(
          para.kind == 'aya'
              ? para
              : BookPara(
                  text: withoutNoteMarkers(para.text),
                  kind: para.kind,
                  ref: para.ref,
                ),
        );
      }
    }
  }
  return paras;
}

/// The edition's footnote markers — «(١)» … «(٦)» — with the space before
/// each, and nothing else.
///
/// Every one of them points into the hashiyah of this printing (checked on
/// the raw Shamela page 121: «(١) كالجائي من سواكن إلى جدة…», «(٢) أي لأنه لا
/// ميقات…»), and that hashiyah is not al-Nawawi's and is dropped by the
/// editor-notes rule. Left in, the markers pointed at nothing: the owner
/// asked «الأرقام الكتير دي ايه» on 2026-09-23. One or two digits only, so a
/// «(فرع)» or a number with a colon is never touched; ayah paragraphs are
/// passed through as they are.
String withoutNoteMarkers(String text) =>
    text.replaceAll(_noteMarker, '').replaceAll(RegExp(r' {2,}'), ' ');

final _noteMarker = RegExp(r'\s*\([٠-٩0-9]{1,2}\)');
