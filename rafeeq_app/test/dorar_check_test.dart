import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/dorar/data/dorar_check.dart';

/// Matn extraction on ten real hadiths from hadith.db (fixture made from the
/// bundled DB, 2026-09-26). Each query below was sent to dorar_api.json the
/// same day: all but 12000 returned gradings scoring >= 0.8 (15, 14, 8, 4,
/// 4, 11, 15, 15, 7); 12000 is an isnad note with no matn and returned none.
void main() {
  final rows = {
    for (final r in jsonDecode(File('test/fixtures/dorar_check_hadiths.json')
        .readAsStringSync()) as List)
      r['id'] as int: r['arabic'] as String,
  };
  String q(int id) => matnQueryWords(rows[id]!).join(' ');

  test('isnad is dropped, matn kept', () {
    expect(q(1), 'انما الاعمال بالنيات وانما لكل امرئ ما نوي فمن كانت');
    expect(q(2), 'احيانا ياتيني مثل صلصلة الجرس وهو اشده علي فيفصم عني');
    // «عن عبيد الله بن عبد الله بن عتبة بن مسعود أن عبد الله بن عباس أخبره»
    expect(q(7), 'هرقل ارسل اليه في ركب من قريش وكانوا تجارا بالشام');
    // «قال عمرو أخبرني عطاء سمع جابرا»
    expect(q(5000), 'كنا نعزل علي عهد النبي والقران ينزل');
    expect(q(20000), 'امر رسول الله بقتل الوزغ وسماه فويسقا');
    expect(q(30000), 'رايت رسول الله توضا فخلل لحيته');
    expect(q(45000), 'صلاة مع الامام افضل من خمس وعشرين صلاة يصليها وحده');
  });

  test('match score: the same hadith passes, an unrelated one does not', () {
    final words = q(1).split(' ');
    expect(
        matchScore(words,
            'إنَّما الأعمالُ بالنِّيَّاتِ، وإنَّما لكُلِّ امرئٍ ما نوى، فمَن كانت هِجرتُه'),
        greaterThanOrEqualTo(DorarCheck.minScore));
    expect(matchScore(words, 'لَمَّا أسلَمَ خالِدُ بنُ سَعيدٍ وصنَعَ به أبوهُ'),
        lessThan(DorarCheck.minScore));
  });

  test('ة and ه score as one letter; diacritics ignored', () {
    expect(matchScore(['صلاة', 'الجماعة'], 'صلاهُ الجماعهِ'), 1.0);
  });
}
