import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/khatma/data/ayah_opening.dart';

/// «في الختمة بياكل جزء من الآية وهو بيعرضها في جزء الختمة».
///
/// The card drew the ayah with `maxLines: 2` and `TextOverflow.ellipsis`,
/// which lets the text engine break wherever the line runs out — mid-word.
/// The card's label says «من قوله تعالى», so an opening is the right thing to
/// show; a damaged one is not.
void main() {
  // 8:41, the ayah his screenshot was cut inside.
  const anfal41 =
      'وَٱعْلَمُوٓا۟ أَنَّمَا غَنِمْتُم مِّن شَىْءٍ فَأَنَّ لِلَّهِ خُمُسَهُۥ وَلِلرَّسُولِ '
      'وَلِذِى ٱلْقُرْبَىٰ وَٱلْيَتَـٰمَىٰ وَٱلْمَسَـٰكِينِ وَٱبْنِ ٱلسَّبِيلِ';

  test('the cut lands on a space, never inside a word', () {
    final opening = ayahOpening(anfal41, words: 6);
    expect(opening.endsWith('…'), isTrue);
    // Everything before the ellipsis is whole words of the original.
    final kept = opening.substring(0, opening.length - 1).trim();
    expect(anfal41.startsWith(kept), isTrue,
        reason: 'the kept part must be a prefix of the real ayah, unaltered');
    expect(kept.split(' ').length, 6);
  });

  test('a short ayah is shown whole, with no ellipsis at all', () {
    const kawthar = 'إِنَّآ أَعْطَيْنَـٰكَ ٱلْكَوْثَرَ';
    expect(ayahOpening(kawthar), kawthar);
    expect(ayahOpening(kawthar).contains('…'), isFalse);
  });

  test('the text kept is never rewritten', () {
    // No normalising, no stripping of marks — §1.2.
    final opening = ayahOpening(anfal41, words: 3);
    expect(opening, startsWith('وَٱعْلَمُوٓا۟ أَنَّمَا غَنِمْتُم'));
  });

  test('it says whether it cut', () {
    expect(ayahIsCut(anfal41, words: 6), isTrue);
    expect(ayahIsCut('إِنَّآ أَعْطَيْنَـٰكَ ٱلْكَوْثَرَ'), isFalse);
  });

  test('empty and whitespace do not throw', () {
    expect(ayahOpening(''), '');
    expect(ayahOpening('   '), '');
  });
}
