import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// «رقم الآية الفائتة متظلل مع الحالية». The recited verse's wash is drawn
/// from `getBoxesForSelection` over its own text (trailing space excluded);
/// this pins, on a real laid-out justified RTL paragraph with WidgetSpan
/// markers, that those boxes never reach the PREVIOUS verse's marker.
void main() {
  testWidgets('verse 2 wash boxes do not cover the marker of verse 1', (t) async {
    final key = GlobalKey();
    const v1 = 'وَلَا تَقُولَنَّ لِشَاْىۡءٍ إِنِّى فَاعِلࣱ ذَٰلِكَ غَدًا ';
    const v2 = 'إِلَّآ أَن يَشَآءَ ٱللَّهُ ۚ وَٱذْكُر رَّبَّكَ إِذَا نَسِيتَ ';
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: Text.rich(
            key: key,
            const TextSpan(children: [
              TextSpan(text: v1),
              WidgetSpan(child: SizedBox(width: 30, height: 30)),
              TextSpan(text: v2),
              WidgetSpan(child: SizedBox(width: 30, height: 30)),
            ]),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    ));
    final p = key.currentContext!.findRenderObject()! as RenderParagraph;
    final m1 = v1.length; // the first marker's placeholder offset
    final markerBoxes = p.getBoxesForSelection(
        TextSelection(baseOffset: m1, extentOffset: m1 + 1));
    expect(markerBoxes, isNotEmpty);
    final marker1 = markerBoxes.first.toRect();

    final start = m1 + 1;
    final end = start + v2.length - 1; // trailing space excluded
    final wash = p.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end));
    expect(wash, isNotEmpty);
    for (final b in wash) {
      final overlap = b.toRect().deflate(1).intersect(marker1.deflate(1));
      expect(overlap.width <= 0 || overlap.height <= 0, isTrue,
          reason: 'wash box ${b.toRect()} covers marker $marker1');
    }
  });
}
