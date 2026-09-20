import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v3.43.0 replaced five printings with one, `madinah_qc`, which ships page
/// images — so `MushafEdition.isRaster` became true for the only edition
/// there is. Two conditions had been written when a VECTOR printing sat
/// beside the scans and read «image mode OR this printing is a scan»:
///
///   * `quran_screen.dart`  `if (_mode == MushafMode.image || edition.isRaster)`
///   * `mushaf_toolbar.dart` `bool get _textOnly => textMode && !isRaster;`
///
/// Both collapsed to a constant. The first made `MushafTextPage` unreachable
/// — the whole text mushaf, its basmala line, its pinch zoom and its
/// auto-scroll — and the second deleted «التلاوة المستمرة» from the strip.
/// The switch still SAID «وضع النص» and still fired; it just could not
/// change what was drawn, which is why nothing looked broken.
///
/// `flutter analyze` and 439 tests had no opinion on any of it. Proven to
/// reproduce before this test was trusted: putting `|| (edition?.isRaster ??
/// false)` back into the render branch fails «the render branch picks the
/// page images on the reader's mode alone», and putting `&& !isRaster` back
/// on the getter fails «the text-only controls key off the mode alone».
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  /// The comments in both files discuss the old clauses on purpose, so the
  /// search has to look at code only.
  String codeOnly(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('the render branch picks the page images on the readers mode alone',
      () {
    final code = codeOnly(
        read('lib/features/quran/presentation/screens/quran_screen.dart'));

    expect(code, contains('if (_mode == MushafMode.image) {'),
        reason: 'the branch that returns MushafPageView should test the '
            'reader mode and nothing else');

    final coerced = RegExp(r'_mode\s*==\s*MushafMode\.image\s*\|\|[^)]*isRaster');
    expect(coerced.hasMatch(code), isFalse,
        reason: 'a condition ORs `isRaster` onto the image mode again. Every '
            'printing is raster now, so that is always true: MushafTextPage '
            'below it becomes dead code and the text mushaf disappears.');
  });

  test('the text-only controls key off the mode alone', () {
    final code = codeOnly(read(
        'lib/features/quran/presentation/widgets/mushaf/mushaf_toolbar.dart'));

    expect(code, contains('bool get _textOnly => textMode;'),
        reason: '_textOnly gates «التلاوة المستمرة» and the label of the '
            'text/image switch. Anding `!isRaster` onto it makes it always '
            'false, and the recitation button leaves the toolbar.');
  });

  test('exactly one printing ships, and it is a raster one', () {
    // The guard above only matters while this holds. If a vector printing is
    // ever added back, these tests still pass and stay correct.
    final editions =
        read('assets/data/mushaf/editions.json');
    expect(editions, contains('"madinah_qc"'));
    expect('"image_path"'.allMatches(editions).length, 1,
        reason: 'one printing, one image path - see HANDOVER.md');
  });
}
