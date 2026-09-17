import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/byte_formatter.dart';

/// «0 / 33» stays «0 / 33» when an Arabic paragraph is drawn around it.
///
/// THE DEFECT, found twice in one day on emulator-5554. The mushaf page badge
/// showed page 1 of 604 as **«٦٠٤ / ١»**, and the tasbeeh counter showed 0 of
/// 33 as **«33 / 0»**. Both were `'$a / $b'` in a single string.
///
/// Why the obvious fixes do not work, both tried on the device before this
/// helper was written:
///
///  * `ltr()` pins where the run sits inside its paragraph. It does not
///    change what the neutrals INSIDE the run resolve to.
///  * `textDirection: TextDirection.ltr` sets the paragraph's base direction.
///    Rule N1 still treats a number as R when resolving a neutral between two
///    numbers, so the separator still goes right-to-left and the pair still
///    swaps.
///
/// A rendering test is the only honest check here: asserting on the string
/// would only prove the marks are present, not that the glyphs come out in
/// the right order. So this lays the text out with a real RTL Directionality
/// and reads the offsets back out of the paint.
void main() {
  testWidgets('a plain «a / b» string really does flip under RTL', (t) async {
    // The proof that the helper is needed at all. If this ever stops being
    // true, the platform changed and the helper can go.
    const plain = '0 / 33';
    final key = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: Text(plain, key: key)),
      ),
    );
    final painter = TextPainter(
      text: const TextSpan(text: plain),
      textDirection: TextDirection.rtl,
    )..layout();
    // Offset 0 is «0», offset 4 is the start of «33». If the run flipped,
    // «33» is painted to the LEFT of «0».
    final zero = painter.getOffsetForCaret(
      const TextPosition(offset: 0),
      Rect.zero,
    );
    final thirtyThree = painter.getOffsetForCaret(
      const TextPosition(offset: 4),
      Rect.zero,
    );
    expect(thirtyThree.dx, lessThan(zero.dx),
        reason: 'the bare string is expected to flip — that is the bug');
  });

  testWidgets('ratio() keeps the first number first', (t) async {
    final fixed = ratio(0, 33);
    final painter = TextPainter(
      text: TextSpan(text: fixed),
      textDirection: TextDirection.rtl,
    )..layout();
    final first = fixed.indexOf('0');
    final second = fixed.indexOf('33');
    final a = painter.getOffsetForCaret(
      TextPosition(offset: first),
      Rect.zero,
    );
    final b = painter.getOffsetForCaret(
      TextPosition(offset: second),
      Rect.zero,
    );
    expect(a.dx, lessThan(b.dx),
        reason: 'ratio() must paint «0» to the left of «33» under RTL; '
            'got ${a.dx} and ${b.dx}');
    await t.pump();
  });

  test('ratio keeps both operands and the separator, and adds no visible ink',
      () {
    final out = ratio(1, 604);
    expect(out, contains('1'));
    expect(out, contains('604'));
    expect(out, contains('/'));
    // Everything it adds is zero-width: two isolates and two marks.
    final visible = out.replaceAll(RegExp('[\u200E\u2066\u2069]'), '');
    expect(visible, '1 / 604');
  });

  test('it works with Arabic-Indic digits too, which is the real case', () {
    final out = ratio('١', '٦٠٤');
    final visible = out.replaceAll(RegExp('[\u200E\u2066\u2069]'), '');
    expect(visible, '١ / ٦٠٤');
  });

  test('a custom separator is honoured', () {
    final out = ratio(3, 7, separator: ' من ');
    final visible = out.replaceAll(RegExp('[\u200E\u2066\u2069]'), '');
    expect(visible, '3 من 7');
  });
}
