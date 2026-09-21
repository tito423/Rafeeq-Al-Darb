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

  test('ordinary Arabic spacing and already-attached marks are unchanged', () {
    const source = 'قَوْلٌ مُبِينٌۚ ثُمَّ كَلَامٌ';
    expect(shapeQuranForDisplay(source), source);
  });
}
