import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_step_text.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';

void main() {
  final book = BookText.fromBytes(
    File('assets/data/builtin_books/$hajjGuideBook.json').readAsBytesSync(),
  );

  test(
    'Umrah resolves every cross-reference to verbatim source paragraphs',
    () {
      final steps = hajjStepsFor(HajjTrack.umrah);
      final body = [for (final step in steps) ...hajjStepParas(step, book)];
      expect(body.length, greaterThan(100));
      expect(body.first.text, startsWith('الأوْلَى: الْعُمْرَةُ فَرْض'));
      expect(body.last.text, startsWith('الرَّابِعَةُ: لَوْ جَامَعَ'));
      expect(body.every((p) => p.text.trim().isNotEmpty), isTrue);
      expect(body.any((p) => p.text.contains('في آداب الإِحرام')), isTrue);
      expect(body.any((p) => p.text.contains('في محرمات الإِحرام')), isTrue);
      expect(body.any((p) => p.text.contains('في كيفية الطواف')), isTrue);
      expect(body.any((p) => p.text.contains('في السعي')), isTrue);
      expect(
        body.any((p) => p.text.contains('يدخل وقت طواف الإِفاضة بعد نصف')),
        isFalse,
        reason: 'the modern hamesh must not be attributed to al-Nawawi',
      );
      expect(
        body.any((p) => p.text.contains('الدعاء عند الركن العراقي')),
        isFalse,
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
      expect(body, source);
    },
  );

  test('every chapter retains source paragraphs without blanking its body', () {
    for (final step in hajjSteps) {
      final body = hajjStepParas(step, book);
      expect(body, isNotEmpty, reason: step.key);
      final opening = book.pages
          .firstWhere((p) => p.printedPage == step.fromPage)
          .paras[step.fromPara];
      expect(body.first, same(opening), reason: step.key);
    }
  });
}
