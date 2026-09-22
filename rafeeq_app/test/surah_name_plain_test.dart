import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

/// The hifz list's surah names, as quran_local.db stores them.
void main() {
  test('marks go, letters stay', () {
    expect(surahNamePlain('سُورَةُ ٱلْفَاتِحَةِ'), 'سورة الفاتحة');
    expect(surahNamePlain('سُورَةُ المَائـِدَةِ'), 'سورة المائدة');
  });

  test('a madda written as a mark is a letter (Al Imran)', () {
    // 0x627 0x653 in the source — stripping it naively printed «ال عمران».
    expect(surahNamePlain('سُورَةُ آلِ عِمۡرَانَ'),
        'سورة آل عمران');
  });
}
