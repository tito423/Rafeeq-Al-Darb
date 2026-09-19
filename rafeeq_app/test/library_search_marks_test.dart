import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/library_api_service.dart';

/// «بالتشكيل أو من غير»: with harakat matching on, the vowels decide.
void main() {
  const page = '[{"t":"طَلَبُ العِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ","k":"body"}]';

  test('the same letters with other vowels are not a match', () {
    expect(LibraryApiService.hasExactMarks(page, 'العِلْمِ', false), isTrue);
    expect(LibraryApiService.hasExactMarks(page, 'العَلَمِ', false), isFalse);
  });

  test('a phrase must appear together and in order', () {
    expect(LibraryApiService.hasExactMarks(page, 'طَلَبُ العِلْمِ', true), isTrue);
    expect(LibraryApiService.hasExactMarks(page, 'العِلْمِ طَلَبُ', true), isFalse);
    expect(LibraryApiService.hasExactMarks(page, 'العِلْمِ طَلَبُ', false), isTrue,
        reason: 'as separate words, order does not matter');
  });
}
