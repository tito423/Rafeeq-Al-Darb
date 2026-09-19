@Tags(['export'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_lesson_text.dart';

/// Writes build/review/{hajj,tajweed}.json: every Hajj step and tajweed
/// lesson exactly as the app cuts it out of its source book, for the
/// scholarly review site (scripts/build_review_site.py). Run with
/// `flutter test --tags export test/export_review_texts_test.dart`.
void main() {
  test('export', () async {
    Future<BookText> b(String id) =>
        BookText.fromFile('assets/data/builtin_books/$id.json');
    Directory('build/review').createSync(recursive: true);

    final hajj = await b(hajjGuideBook);
    final steps = <String, Object>{};
    for (final t in HajjTrack.values) {
      steps[t.name] = [
        for (final s in hajjStepsFor(t))
          {
            'key': s.key,
            'pages': '${s.fromPage}-${s.toPage}',
            'paras': [
              for (final p in hajj.pages)
                if (p.printedPage >= s.fromPage && p.printedPage <= s.toPage)
                  for (var i = (p.printedPage == s.fromPage ? s.fromPara : 0);
                      i <= (p.printedPage == s.toPage ? s.toPara : p.paras.length - 1) &&
                          i < p.paras.length;
                      i++)
                    if (!isHajjGuideNote(p.paras[i].text) &&
                        p.paras[i].text.trim().isNotEmpty)
                      {'kind': p.paras[i].kind, 'text': p.paras[i].text},
            ],
          },
      ];
    }
    File('build/review/hajj.json').writeAsStringSync(jsonEncode(steps));

    final tuhfa = await b(tuhfaBook);
    final jaz = await b(jazariyyahBook);
    final tam = await b(tamhidBook);
    final tajweed = {
      'tuhfa': [
        for (final l in tuhfaLessons)
          {
            'title': l.title,
            'paras': [
              for (final p in tuhfaLessonParas(l, tuhfa))
                {'kind': p.commentary ? 'commentary' : p.kind, 'text': p.text},
            ],
          },
      ],
      'jazariyyah': [
        for (final l in jazariyyahLessons)
          {
            'title': l.title,
            'paras': [
              for (final p in jazariyyahLessonParas(l, jaz))
                {'kind': p.kind, 'text': p.text},
            ],
          },
      ],
      'tamhid': [
        for (final l in tamhidLessons)
          {
            'title': l.title,
            'paras': [
              for (final p in tamhidLessonParas(l, tam))
                {'kind': p.kind, 'text': p.text},
            ],
          },
      ],
    };
    File('build/review/tajweed.json').writeAsStringSync(jsonEncode(tajweed));
  });
}
