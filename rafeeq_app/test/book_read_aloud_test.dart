import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';
import 'package:rafeeq_app/features/library/data/book_read_aloud.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/book_player_bar.dart';

/// The read-aloud sentences and the span the reader lights for each one.
void main() {
  const para1 = 'قَالَ الشَّيْخُ: الْعِلْمُ نُورٌ. وَالْجَهْلُ ظُلْمَةٌ؟  فَاطْلُبِ الْعِلْمَ';
  const para2 = 'بَابُ الصَّلَاةِ';
  final paras = [
    (text: para1, kind: 'body'),
    (text: 'إِنَّ اللَّهَ غَفُورٌ رَحِيمٌ', kind: 'aya'),
    (text: para2, kind: 'head'),
  ];

  test('every sentence is placed exactly where it is in its paragraph', () {
    final cs = BookReadAloud.chunksOf(paras, max: 40);
    expect(cs, isNotEmpty);
    for (final c in cs) {
      final text = paras[c.para].text;
      expect(text.substring(c.start, c.end), c.text,
          reason: 'chunk "${c.text}" mapped to the wrong span');
    }
  });

  test('a Qur\'an paragraph is never read, and sentences never cross paragraphs', () {
    final cs = BookReadAloud.chunksOf(paras);
    expect(cs.any((c) => c.para == 1), isFalse);
    expect(cs.map((c) => c.para).toSet(), {0, 2});
  });

  test("quoted Qur'an and a lone dash are never handed to the voice", () {
    const body = 'وَكَذَلِكَ قَوْلُهُ تَعَالَى {إِنَّمَا الْحَيَاةُ الدُّنْيَا لَعِبٌ} [محمد: ٣٦] يَقْتَضِي الْحَصْرَ.';
    final cs = BookReadAloud.chunksOf([
      (text: body, kind: 'body'),
      (text: '—', kind: 'body'),
      (text: 'ــ', kind: 'body'), // two tatweels, as Ihkam al-Ahkam prints it
      (text: '﴿قُلْ هُوَ اللَّهُ أَحَدٌ﴾ [الإخلاص: ١]', kind: 'body'),
    ]);
    expect(cs.length, 1, reason: 'the dash, the tatweels and the ayah-only paragraph are not sentences');
    expect(cs.single.text, 'وَكَذَلِكَ قَوْلُهُ تَعَالَى يَقْتَضِي الْحَصْرَ.');
    expect(body.substring(cs.single.start, cs.single.end), body,
        reason: 'the lit span still covers the whole sentence on the page');
  });

  test('with the tashkeel hidden the highlight moves onto the stripped text', () {
    final cs = BookReadAloud.chunksOf(paras, max: 40);
    final second = cs.where((c) => c.para == 0).elementAt(1);
    for (final tashkeel in [true, false]) {
      final span = readAloudSpan(
        raw: para1,
        tashkeel: tashkeel,
        hl: second,
        paper: const Color(0xFFFFFFFF),
      ) as TextSpan;
      final lit = (span.children![1] as TextSpan).text!;
      expect(lit,
          tashkeel ? second.text : stripTashkeelForDisplay(second.text));
    }
  });
}
