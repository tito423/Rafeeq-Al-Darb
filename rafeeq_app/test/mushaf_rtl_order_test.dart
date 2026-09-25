import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first ayah of a line must sit at the RIGHT end of it.
///
/// Seen on emulator-5554 on 2026-09-25 (3.63.7 + the King Fahd text and
/// font): the text mushaf laid al-Rahman out as «ٱلرَّحۡمَٰنُ» at the LEFT
/// end of the line and «عَلَّمَهُ ٱلۡبَيَانَ» at the right - every page set
/// left to right while each word's letters were joined correctly.
Future<void> _load(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

double _xOf(RenderParagraph p, int from, int to) =>
    p.getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to))
        .first
        .left;

void main() {
  for (final (family, path) in [
    ('KFGQPCHafs', 'assets/fonts/KFGQPC-HAFS-Uthmanic-Script-v18.ttf'),
    ('AmiriQuran', 'assets/fonts/AmiriQuran-Regular.ttf'),
  ]) {
    testWidgets('$family: first ayah at the right end of the line',
        (tester) async {
      await _load(family, path);
      // Long enough to wrap: a justified line is any line but the LAST, and
      // the last line of the device page was the one line drawn right.
      const a1 = 'ٱلۡحَمۡدُ لِلَّهِ ٱلَّذِيٓ أَنزَلَ عَلَىٰ عَبۡدِهِ ٱلۡكِتَٰبَ وَلَمۡ يَجۡعَل لَّهُۥ عِوَجَاۜ ';
      const a2 = 'قَيِّمٗا لِّيُنذِرَ بَأۡسٗا شَدِيدٗا مِّن لَّدُنۡهُ وَيُبَشِّرَ ٱلۡمُؤۡمِنِينَ ٱلَّذِينَ يَعۡمَلُونَ ٱلصَّٰلِحَٰتِ أَنَّ لَهُمۡ أَجۡرًا حَسَنٗا ';
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: a1),
                WidgetSpan(child: SizedBox(width: 20, height: 20)),
                const TextSpan(text: a2),
                WidgetSpan(child: SizedBox(width: 20, height: 20)),
              ]),
              key: key,
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: family, fontSize: 24),
            ),
          ),
        ),
      ));
      final p = key.currentContext!.findRenderObject()! as RenderParagraph;
      // The first word of the first line, and the last word of the same
      // line: in right-to-left order the first is further right.
      final first = p.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 3)).first;
      final lastOnLine = p.getBoxesForSelection(
          const TextSelection(baseOffset: 30, extentOffset: 33)).first;
      // ignore: avoid_print
      print('$family first x=${first.left} y=${first.top}  later x=${lastOnLine.left} y=${lastOnLine.top}');
      expect(first.top, lastOnLine.top, reason: 'both on line 1');
      expect(first.left, greaterThan(lastOnLine.left),
          reason: 'the first word must be right of a later one');
    });
  }
}
