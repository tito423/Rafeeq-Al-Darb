import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/presentation/widgets/mushaf/ayah_marker.dart';

// The text mushaf's flowing paragraph ends every verse with a marker. On the
// owner's Xiaomi (2026-09-26) al-Fatiha showed them reversed within every
// line (⑤ after the basmala): Flutter 3.38.7 reports a right-to-left line's
// placeholder boxes in visual order, so `WidgetSpan` children - and even the
// placeholder's own selection box - land in another verse's slot.
// `resolveMarkerSlots` places each marker from its verse's own words; this
// checks it on lines holding several verses, at three widths so that a
// verse is also broken right after its closing space.
void main() {
  const words = ['بتث', 'جحخ', 'دذر', 'زسش', 'صضط', 'عغف', 'قكل', 'منه'];

  for (final align in [TextAlign.justify, TextAlign.right]) {
    for (final width in [330.0, 250.0, 175.0]) {
      testWidgets('each marker follows its own verse ($align, $width)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 10),
                    children: [
                      for (final w in words) ...[
                        TextSpan(text: '$w '),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: SizedBox(width: 20, height: 10),
                        ),
                      ],
                    ],
                  ),
                  textAlign: align,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ),
        );
        final rp = tester.renderObject<RenderParagraph>(find.byType(RichText));
        Rect box(int at) => rp
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 1),
            )
            .first
            .toRect();
        final slots = resolveMarkerSlots(rp, [
          for (var i = 0; i < words.length; i++) i * 5 + 4,
        ]);
        expect(slots.toSet().length, words.length, reason: 'one slot each');
        var shared = 0;
        for (var i = 0; i < words.length; i++) {
          final slot = slots[i]!;
          final lastLetter = box(i * 5 + 2);
          final sameLine = (slot.center.dy - lastLetter.center.dy).abs() < 5;
          if (sameLine) {
            // Right-to-left: the marker comes after (left of) the words.
            expect(
              slot.right,
              lessThanOrEqualTo(lastLetter.left + 0.5),
              reason: 'verse $i: marker left of its words',
            );
          } else {
            // Broken after the space: the marker opens the next line.
            expect(
              slot.top,
              greaterThan(lastLetter.top),
              reason: 'verse $i: marker on the following line',
            );
          }
          if (i + 1 < words.length) {
            final nextFirst = box(i * 5 + 5);
            if ((nextFirst.center.dy - slot.center.dy).abs() < 5) {
              shared++;
              expect(
                slot.left,
                greaterThanOrEqualTo(nextFirst.right - 0.5),
                reason: 'verse $i: marker right of verse ${i + 1}',
              );
            }
          }
        }
        expect(
          shared,
          greaterThan(1),
          reason: 'lines must hold several verses',
        );
      });
    }
  }
}
