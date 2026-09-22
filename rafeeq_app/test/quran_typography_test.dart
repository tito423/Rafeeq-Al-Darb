import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/quran_typography.dart';

void main() {
  test('standalone combining waqf signs attach to the preceding word', () {
    const source = 'ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ ۖ وَلَا';

    expect(
      shapeQuranForDisplay(source),
      'ٱلْقَيُّومُۚ لَا تَأْخُذُهُۥ سِنَةٌۖ وَلَا',
    );
    expect(
      source,
      contains(' ۚ '),
      reason: 'the sourced Quran text is immutable',
    );
  });

  test('standalone structural symbols keep their own spacing', () {
    const source = 'نَصٌّ ۞ نَصٌّ ۩ نَصٌّ';
    expect(shapeQuranForDisplay(source), source);
  });

  // 2:128 as stored: «أُمَّةًۭ مُّسْلِمَةًۭ» — fathatan + U+06ED, drawn by the
  // font as a small meem under the word.
  test('a non-izhar tanween is drawn as the open tanween', () {
    const source = 'أُمَّةًۭ مُّسْلِمَةًۭ لَّكَ مَّرَضٌۭ فَزَادَهُمُ';
    final shaped = shapeQuranForDisplay(source);
    expect(shaped, isNot(contains('ۭ')));
    expect('ࣰ'.allMatches(shaped).length, 2);
    expect('ࣱ'.allMatches(shaped).length, 1);
    expect(source, contains('ۭ'), reason: 'the stored text is untouched');
  });

  // 2:41 «كَافِرٍۭ بِهِۦ» — iqlab, where the printed mushaf sets the meem.
  test('the iqlab meem after a kasratan stays', () {
    const source = 'كَافِرٍۭ بِهِۦ';
    expect(shapeQuranForDisplay(source), source);
  });

  test('ordinary Arabic spacing and already-attached marks are unchanged', () {
    const source = 'قَوْلٌ مُبِينٌۚ ثُمَّ كَلَامٌ';
    expect(shapeQuranForDisplay(source), source);
  });
}
