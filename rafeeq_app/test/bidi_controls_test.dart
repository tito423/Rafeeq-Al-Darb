import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

/// `stripBidiControls` is allowed to remove invisible formatting characters and
/// nothing else. This is the guard on that promise, because the thing it is
/// applied to is hadith text and CLAUDE.md §1.2 forbids rewriting it.
void main() {
  // The real tail of Sunan Abi Dawud 1417 as it sits in the bundled hadith.db,
  // read out of the database byte by byte: the closing quote and the full stop
  // are each wrapped in RIGHT-TO-LEFT MARKs, which is what threw them to the
  // wrong end of the line in the owner's screenshot.
  const tail = 'يُحِبُّ الْوِتْرَ ‏"‏ ‏.‏';

  test('removes only characters that have no glyph', () {
    final out = stripBidiControls(tail);
    expect(out, 'يُحِبُّ الْوِتْرَ " .');
    // Every visible character survives, in order.
    final visible = tail
        .split('')
        .where((c) => !'‎‏⁦⁧⁨⁩'.contains(c))
        .join();
    expect(out, visible);
  });

  test('touches no letter, diacritic, quote or stop', () {
    const samples = [
      'حَدَّثَنَا إِبْرَاهِيمُ بْنُ مُوسَى، أَخْبَرَنَا عِيسَى',
      'قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ".',
      'ﷺ ٣٥٨٦٠ 1417 — «الوتر» …',
      '',
    ];
    for (final s in samples) {
      expect(stripBidiControls(s), s, reason: s);
    }
  });

  test('is idempotent', () {
    final once = stripBidiControls(tail);
    expect(stripBidiControls(once), once);
  });

  test('handles the isolate codes too, not just the marks', () {
    const isolated = '⁨نص⁩ و⁦more⁩';
    expect(stripBidiControls(isolated), 'نص وmore');
  });
}
