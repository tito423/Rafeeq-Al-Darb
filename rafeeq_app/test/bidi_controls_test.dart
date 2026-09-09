import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

/// `stripBidiControls` is allowed to remove invisible formatting characters and
/// nothing else. This is the guard on that promise, because the thing it is
/// applied to is hadith text and CLAUDE.md §1.2 forbids rewriting it.

// The six code points, built from their numbers rather than pasted in as
// characters. Pasted they are invisible in an editor — and the analyzer
// rejects them outright (`text_direction_code_point_in_literal`), which is
// how this file cost `flutter analyze lib test` its clean run.
const _lrm = 0x200E; // LEFT-TO-RIGHT MARK
const _rlm = 0x200F; // RIGHT-TO-LEFT MARK
const _lri = 0x2066; // LEFT-TO-RIGHT ISOLATE
const _rli = 0x2067; // RIGHT-TO-LEFT ISOLATE
const _fsi = 0x2068; // FIRST STRONG ISOLATE
const _pdi = 0x2069; // POP DIRECTIONAL ISOLATE
const _controls = [_lrm, _rlm, _lri, _rli, _fsi, _pdi];

String _c(int codePoint) => String.fromCharCode(codePoint);

void main() {
  // The real tail of Sunan Abi Dawud 1417 as it sits in the bundled hadith.db,
  // read out of the database byte by byte: the closing quote and the full stop
  // are each wrapped in RIGHT-TO-LEFT MARKs, which is what threw them to the
  // wrong end of the line in the owner's screenshot.
  final rlm = _c(_rlm);
  final tail = 'يُحِبُّ الْوِتْرَ $rlm"$rlm $rlm.$rlm';

  test('removes only characters that have no glyph', () {
    final out = stripBidiControls(tail);
    expect(out, 'يُحِبُّ الْوِتْرَ " .');
    // Every visible character survives, in order.
    final visible = tail
        .split('')
        .where((c) => !_controls.contains(c.codeUnitAt(0)))
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
    final isolated = '${_c(_fsi)}نص${_c(_pdi)} و${_c(_lri)}more${_c(_pdi)}';
    expect(stripBidiControls(isolated), 'نص وmore');
  });
}
