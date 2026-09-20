import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_step_text.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';

void main() {
  final book = BookText.fromBytes(
    File('assets/data/builtin_books/$hajjGuideBook.json').readAsBytesSync(),
  );

  test('heading comparison preserves Arabic and distinguishes body text', () {
    expect(hajjHeadingBare('الباب الرَّابع'), isNotEmpty);
    expect(hajjHeadingBare('الباب الرَّابع'), 'الباب الرابع');
    expect(
      hajjHeadingBare('في الْعُمْرة وَفِيهِ مَسَائِلُ'),
      'في العمرة وفيه مسائل',
    );
    expect(
      hajjHeadingBare('الأوْلَى: الْعُمْرَةُ فَرْض'),
      isNot(hajjHeadingBare('الباب الرَّابع')),
    );
  });

  test(
    'Umrah omits only its two headings and keeps the real body verbatim',
    () {
      final step = hajjStepsFor(HajjTrack.umrah).first;
      final original = book.pages
          .where((p) => p.printedPage >= 378 && p.printedPage <= 387)
          .expand((p) => p.paras)
          .where((p) => p.text.trim().isNotEmpty && !isHajjGuideNote(p.text))
          .toList();
      final body = hajjStepParas(step, book);
      expect(body, isNotEmpty);
      expect(body.first.text, startsWith('الأوْلَى: الْعُمْرَةُ'));
      expect(body, original.sublist(2));
      expect(
        book.pages.firstWhere((p) => p.printedPage == 378).paras.first.text,
        'الباب الرَّابع',
      );
    },
  );

  test('every chapter retains source paragraphs without blanking its body', () {
    for (final step in hajjSteps) {
      final body = hajjStepParas(step, book);
      expect(body, isNotEmpty, reason: step.key);
      if (step.key != 'umrah') {
        final opening = book.pages
            .firstWhere((p) => p.printedPage == step.fromPage)
            .paras[step.fromPara];
        expect(body.first, same(opening), reason: step.key);
      }
    }
  });
}
