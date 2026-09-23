import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_step_text.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';

void main() {
  test('only the footnote markers go', () {
    // al-Idah p. 121 as the book stores it
    expect(
      withoutNoteMarkers(
        'فإنْ لم يُحَاذ شَيْئاً (١) أحْرَمَ عَلَى مَرْحَلَتَيْنِ مِنْ مَكةَ (٢) فإنْ اشْتبَهَ',
      ),
      'فإنْ لم يُحَاذ شَيْئاً أحْرَمَ عَلَى مَرْحَلَتَيْنِ مِنْ مَكةَ فإنْ اشْتبَهَ',
    );
    expect(withoutNoteMarkers('(فرع): إذا انْتَهَى'), '(فرع): إذا انْتَهَى');
    expect(
      withoutNoteMarkers('وطَريقُ الاحْتِيَاط لا تَخْفَى (٤).'),
      'وطَريقُ الاحْتِيَاط لا تَخْفَى.',
    );
  });

  final book = BookText.fromBytes(
    File('assets/data/builtin_books/$hajjGuideBook.json').readAsBytesSync(),
  );

  test(
    'Umrah resolves every cross-reference to verbatim source paragraphs',
    () {
      final steps = hajjStepsFor(HajjTrack.umrah);
      final body = [for (final step in steps) ...hajjStepParas(step, book)];
      // al-Fiqh al-Manhaji's chapter (2026-09-23): the Umrah track opens on
      // «حكم العمرة ودليلها» and ends on the penalty for intercourse in
      // ihram, and walks the ihram, the circuits, the passes and the cut.
      expect(body.length, greaterThan(40));
      expect(body.first.text, startsWith('٢ـ حكم العمرة ودليلها'));
      expect(body.last.text, startsWith('ثانياً: إن كان المحرم'));
      expect(body.every((p) => p.text.trim().isNotEmpty), isTrue);
      expect(body.any((p) => p.text.contains('كيفية الإحرام')), isTrue);
      expect(body.any((p) => p.text.contains('محرمات الإحرام')), isTrue);
      expect(body.any((p) => p.text.contains('أعمال العمرة')), isTrue);
      expect(body.any((p) => p.text.contains('العلم الأخضر')), isTrue);
      expect(
        body.any((p) => p.text.contains('يوم التروية')),
        isFalse,
        reason: 'the days of Hajj are not the Umrah',
      );

      final source = <BookPara>[];
      for (final step in steps) {
        for (final range in step.textRanges) {
          for (final page in book.pages) {
            if (page.printedPage < range.fromPage ||
                page.printedPage > range.toPage) {
              continue;
            }
            final first = page.printedPage == range.fromPage
                ? range.fromPara
                : 0;
            final last = page.printedPage == range.toPage
                ? range.toPara
                : page.paras.length - 1;
            for (var i = first; i <= last && i < page.paras.length; i++) {
              if (!isHajjGuideNote(page.paras[i].text)) {
                source.add(page.paras[i]);
              }
            }
          }
        }
      }
      // Verbatim but for the footnote markers, whose notes are not shown.
      expect(
        [for (final p in body) (p.text, p.kind)],
        [
          for (final p in source)
            (p.kind == 'aya' ? p.text : withoutNoteMarkers(p.text), p.kind),
        ],
      );
      expect(
        body.where(
          (p) => p.kind != 'aya' && RegExp(r'\([٠-٩]{1,2}\)').hasMatch(p.text),
        ),
        isEmpty,
        reason: 'a marker whose footnote is not shown points at nothing',
      );
    },
  );

  test('every chapter retains source paragraphs without blanking its body', () {
    for (final step in hajjSteps) {
      final body = hajjStepParas(step, book);
      expect(body, isNotEmpty, reason: step.key);
      final opening = book.pages
          .firstWhere((p) => p.printedPage == step.fromPage)
          .paras[step.fromPara];
      expect(
        body.first.text,
        withoutNoteMarkers(opening.text),
        reason: step.key,
      );
    }
  });
}
