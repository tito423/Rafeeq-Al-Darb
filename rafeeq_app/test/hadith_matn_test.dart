import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/hadith_matn.dart';

/// The query the "find its explanation" button searches with.
///
/// A hadith from the nine books arrives with its whole isnad in front of it,
/// and that chain is particular to the edition — searching another collection
/// for it finds nothing. The quoted matn is what two collections share.
///
/// The example is the real record the Home card showed on the device
/// (Musnad Ahmad 11222), not an invented one.
void main() {
  const musnad11222 =
      'حَدَّثَنَا عَبْدُ الصَّمَدِ، حَدَّثَنَا عَبْدُ الْعَزِيزِ يَعْنِي ابْنَ مُسْلِمٍ، '
      'حَدَّثَنَا يَزِيدُ، عَنْ مُجَاهِدٍ، عَنْ أَبِي سَعِيدٍ، أَنَّ رَسُولَ اللهِ '
      'صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ قَالَ: " لَا يَدْخُلُ الْجَنَّةَ مَنَّانٌ، '
      'وَلَا عَاقٌّ، وَلَا مُدْمِنُ خَمْرٍ "';

  test('the matn is taken from inside the quotes, not the isnad', () {
    final matn = matnOf(musnad11222)!;
    expect(matn, startsWith('لَا يَدْخُلُ'));
    expect(matn, isNot(contains('حَدَّثَنَا')));
    expect(matn, isNot(contains('عَنْ مُجَاهِدٍ')));
  });

  test('the query is a short distinctive opening of the matn', () {
    final q = matnQuery(musnad11222)!;
    expect(q.split(' ').length, lessThanOrEqualTo(7));
    expect(q, startsWith('لَا يَدْخُلُ الْجَنَّةَ'));
  });

  test('guillemets are handled too — the book texts use them', () {
    expect(matnOf('قال «إنما الأعمال بالنيات وإنما لكل امرئ ما نوى»'),
        'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى');
  });

  test('no quotes, or too short a quote, means no button at all', () {
    // Returning a guess here would send the reader to a search for the isnad,
    // which finds either nothing or the wrong thing.
    expect(matnOf('حدثنا فلان عن فلان عن فلان بلا نص مقتبس'), isNull);
    expect(matnOf('قال " نعم "'), isNull);
    expect(matnQuery('لا اقتباس هنا'), isNull);
  });
}
