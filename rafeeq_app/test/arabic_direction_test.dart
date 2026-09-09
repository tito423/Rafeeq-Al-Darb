import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/time_formatter.dart';
import 'package:rafeeq_app/core/widgets/arabic_text.dart';

/// The second half of the «"" and the stray dot» bug.
///
/// `stripBidiControls` removes the source's RIGHT-TO-LEFT MARKs, but that only
/// helps if what is left is laid out as an Arabic paragraph. Six of the app's
/// seven locales set the ambient `Directionality` to LTR, and an Arabic
/// sentence laid out in an LTR paragraph puts its trailing neutral — the full
/// stop, the closing quote — at the *other* end of the last line. Measured on
/// the Portuguese build: Sahih al-Bukhari 4543 rendered its full stop to the
/// right of «كِبْرَهُ}» instead of ending the sentence after «سَلُولَ».
///
/// This test measures that difference rather than describing it, and pins the
/// fix: [ArabicText] lays the same string out RTL whatever the ambient
/// direction is.
void main() {
  // A hadith tail shaped exactly like the one that was photographed: Arabic
  // words, then a full stop as the last character.
  const sentence = 'قالت عبد الله بن أبى ابن سلول.';
  const stop = TextSelection(
    baseOffset: sentence.length - 1,
    extentOffset: sentence.length,
  );

  /// Where the full stop lands, as a fraction of the laid-out line width.
  double stopPosition(TextDirection direction) {
    final painter = TextPainter(
      text: const TextSpan(text: sentence),
      textDirection: direction,
    )..layout();
    final box = painter.getBoxesForSelection(stop).single;
    return box.left / painter.width;
  }

  test('an LTR paragraph throws the full stop to the wrong end', () {
    // RTL: the stop ends the sentence, so it sits at the left edge.
    expect(stopPosition(TextDirection.rtl), lessThan(0.2));
    // LTR: the same stop is flung to the right edge — the reported bug.
    expect(stopPosition(TextDirection.ltr), greaterThan(0.8));
  });

  // The mirror of the same bug, on the other side of the app: a Latin
  // fragment inside an Arabic or Urdu paragraph. «7:36 AM» is a bidi-weak
  // numeral and a Latin marker with a space between them, and in an RTL
  // paragraph that space resolves right-to-left and swaps the two halves.
  // The Urdu build's sunrise tile read «AM 7:36» on emulator-5554.
  group('a 12-hour time inside an RTL paragraph', () {
    /// Left edge of the run holding [selection], as a fraction of the line.
    double position(String text, TextSelection selection) {
      final painter = TextPainter(
        text: TextSpan(text: text),
        textDirection: TextDirection.rtl,
      )..layout();
      return painter.getBoxesForSelection(selection).first.left /
          painter.width;
    }

    test('swaps the number and the marker when nothing pins it', () {
      const bare = '7:36 AM';
      // "7:36" is the first four characters, "AM" the last two.
      final number = position(bare, const TextSelection(
          baseOffset: 0, extentOffset: 4));
      final marker = position(bare, const TextSelection(
          baseOffset: 5, extentOffset: 7));
      expect(marker, lessThan(number),
          reason: 'the marker should have been thrown to the left of the '
              'number — that is the bug this test exists to describe');
    });

    test('formatTime12h isolates it, so the order survives', () {
      final formatted = formatTime12h('07:36');
      // The isolate characters are invisible; they add two code units at the
      // ends, so the offsets shift by one.
      final number = position(formatted, const TextSelection(
          baseOffset: 1, extentOffset: 5));
      final marker = position(formatted, const TextSelection(
          baseOffset: 6, extentOffset: 8));
      expect(marker, greaterThan(number),
          reason: 'inside a LEFT-TO-RIGHT ISOLATE the marker must stay to the '
              'right of the number: $formatted');
    });
  });

  testWidgets('ArabicText lays Arabic out RTL under an LTR ancestor',
      (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ArabicText(sentence)),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.textDirection, TextDirection.rtl);
  });
}
