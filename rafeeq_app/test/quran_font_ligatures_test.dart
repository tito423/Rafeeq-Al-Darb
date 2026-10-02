import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «حَتَّىٰٓ» drew its small alef and its madd crossed, as a «+» (owner's
/// screenshot, 2026-10-02). The KFGQPC Hafs font draws «ٰٓ» as ONE glyph
/// (`uni0670_uni0653`) through its `liga` feature, and Skia's paragraph
/// shaper turns `liga` off for any text whose letter spacing is above zero
/// (skia/modules/skparagraph/src/OneLineShaper.cpp, «Disable ligatures if
/// letter spacing is enabled»). The Quran styles inherited Material's
/// `letterSpacing: 0.25` from the ambient text style. Reproduced off-device
/// with HarfBuzz: `-liga` gives the «+», the default gives the right mark.
///
/// So every style that names the Quran font sets the spacing to 0 itself.
void main() {
  test('every KFGQPC Hafs style keeps its ligatures', () {
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains("fontFamily: 'KFGQPCHafs'")) continue;
        // The style's own arguments: this line and the next few.
        final window = lines
            .sublist(i, (i + 6).clamp(0, lines.length))
            .join('\n');
        if (!window.contains('letterSpacing: 0')) {
          missing.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'a Quran style without letterSpacing: 0 inherits the '
            "theme's spacing and loses the font's ligatures:\n"
            '${missing.join('\n')}');
  });
}
