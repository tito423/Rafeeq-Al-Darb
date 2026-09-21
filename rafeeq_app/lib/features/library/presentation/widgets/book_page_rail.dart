import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/byte_formatter.dart' show ratio;
import '../../../../core/utils/digits.dart';
import '../../data/book_text.dart';

/// The book reader's bottom rail: a fast-jump slider across the whole book
/// and the typed «الانتقال إلى» button under it.
///
/// Lifted out of `book_text_reader_screen.dart` — that file was already at
/// the ceiling `code_layout_test` holds it to, and this is a self-contained
/// strip that only needs the document, where the reader is in it, and three
/// callbacks.
///
/// The two chevron buttons the owner flagged as still there are gone —
/// turning pages happens by swipe or by dragging this slider for long-range
/// scrubbing. Dragging updates the visible page live; the position is only
/// persisted once the drag ends, so a long scrub doesn't spam prefs.
///
/// ── «عدادات الصفح مش صح في المكتبة» (2026-09-21) ──
///
/// The two ends of the rail counted SEQUENCE POSITION (1 … pages.length)
/// while the button right under them printed the page number off the paper.
/// A Shamela edition's text stream starts wherever the publisher's front
/// matter ends, so on a healthy book the two scales legitimately differ and
/// the reader still saw them disagree: «إخبار أهل الرسوخ» showed
/// «صفحة ٦١» over «٣٨ / ٣٨» (38 pages numbered 23–61), «الأربعون
/// النووية» «صفحة ٣٥» over «١ … ٨١» (81 pages numbered 35–115).
/// One strip of screen was speaking two numbering systems at once, so the
/// ends now carry the first and last PRINTED page whenever the book has a
/// printed scale, and 1 … count when it does not - matching the label under
/// them either way.
///
/// That was the half of it that is a LAYOUT bug. «كل الكتب في المكتبة
/// عدادات الصفحات غلط. انا عديت على عشر كتب» sent the audit wider
/// and it found the other half in the DATA, which is why
/// [BookTextMeta.printReliable] is now recomputed at parse time rather than
/// believed. See `BookText._printedNumbersUsable` and
/// `BookText._resolveSectionIndex` for what was counted and what it cost.
class BookPageRail extends StatelessWidget {
  final BookText doc;
  final int pageIndex;
  final Color paper;
  final Color ink;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  final VoidCallback onGoto;

  const BookPageRail({
    super.key,
    required this.doc,
    required this.pageIndex,
    required this.paper,
    required this.ink,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onGoto,
  });

  @override
  Widget build(BuildContext context) {
    final printed = doc.meta.printReliable;
    final here = doc.printedPageAt(pageIndex);
    final start = printed ? doc.firstPrintedPage : pageIndex + 1;
    final end = printed ? doc.lastPrintedPage : doc.pages.length;
    final endStyle =
        TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.65));

    return Material(
      color: paper,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(localizeDigits('$start', uiLanguageCode),
                        textAlign: TextAlign.center, style: endStyle),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.5,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        min: 0,
                        max: (doc.pages.length - 1).toDouble(),
                        value: pageIndex.toDouble(),
                        divisions:
                            doc.pages.length > 1 ? doc.pages.length - 1 : null,
                        onChanged: (v) => onChanged(v.round()),
                        onChangeEnd: (v) => onChangeEnd(v.round()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(localizeDigits('$end', uiLanguageCode),
                        textAlign: TextAlign.center, style: endStyle),
                  ),
                ],
              ),
            ),
            // typed goto, kept as a precise alternative to the slider
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextButton(
                onPressed: onGoto,
                style: TextButton.styleFrom(foregroundColor: ink),
                child: Text(
                  // `printedPageAt`, not `printed`: a book can have a usable
                  // scale and still open on Shamela's unnumbered cover leaf,
                  // and «صفحة ٠» is not a page number.
                  here != null
                      ? '${'library.text_page'.tr()} '
                          '${localizeDigits('$here', uiLanguageCode)}'
                      : localizeDigits(
                          ratio(pageIndex + 1, doc.pages.length),
                          uiLanguageCode),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
