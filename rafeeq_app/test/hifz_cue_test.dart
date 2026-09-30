import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/hifz_mask.dart';

void main() {
  test('each level covers what it says', () {
    List<bool> row(HifzCue c) => [for (var i = 0; i < 5; i++) hifzCueHidden(i, 5, c)];
    expect(row(HifzCue.full), [false, false, false, false, false]);
    expect(row(HifzCue.alternate), [false, true, false, true, false]);
    expect(row(HifzCue.firstWord), [false, true, true, true, true]);
    expect(row(HifzCue.none), [true, true, true, true, true]);
  });

  test('the first letter keeps its own marks and nothing more', () {
    expect(hifzFirstLetter('ٱلۡحَمۡدُ'), 'ٱ');
    expect(hifzFirstLetter('رَبِّ'), 'رَ');
    expect(hifzFirstLetter('ٱللَّهِ'), 'ٱ');
    expect(hifzFirstLetter('قُلۡ'), 'قُ');
  });

  test('the ladder follows the score', () {
    expect(hifzCueAfter(HifzCue.full, 0.95), HifzCue.firstLetters);
    expect(hifzCueAfter(HifzCue.none, 1.0), HifzCue.none);
    expect(hifzCueAfter(HifzCue.alternate, 0.5), HifzCue.firstLetters);
    expect(hifzCueAfter(HifzCue.full, 0.1), HifzCue.full);
    expect(hifzCueAfter(HifzCue.firstWord, 0.75), HifzCue.firstWord);
  });
}
