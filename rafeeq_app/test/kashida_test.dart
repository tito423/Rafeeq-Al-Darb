import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/kashida.dart';

/// Where the text mushaf may draw a letter longer (see `kashida.dart`).
/// The rules were measured by shaping every word of the mushaf with
/// HarfBuzz and the KFGQPC font, a tatweel at every slot (165,063
/// variants, 2026-10-02): no missing glyph and no new mark collision.
void main() {
  List<int> at(String w) => [for (final s in kashidaSlots(w)) s.offset];

  test('between two joined letters, after the first one\'s marks', () {
    // مَنۡ: م (fatha) joins ن — one slot, after the fatha.
    expect(at('مَنۡ'), [2]);
  });

  test('never inside lam-alef', () {
    // قَالَ: ق joins ا — a slot; ل before nothing. لَا: no slot at all.
    expect(at('لَا'), isEmpty);
  });

  test('never after a letter that does not join forward', () {
    // ر and د do not join the letter after them.
    expect(at('رَدَ'), isEmpty);
  });

  test('never after a letter carrying a dagger alef or a madd', () {
    // كَٰفِرِينَ: no slot after «كَٰ» (the font moves «ٰ» onto the fatha).
    const w = 'كَٰفِرِينَ';
    expect(at(w).where((o) => o == 3), isEmpty);
    expect(at('شُرَكَٰٓؤُاْ').where((o) => o == 7), isEmpty);
  });

  test('the word\'s last slot ranks first', () {
    final s = kashidaSlots('يَعۡلَمُونَ');
    final last = s.reduce((a, b) => a.offset > b.offset ? a : b);
    expect(last.rank, 0);
  });

  test('applying a plan inserts tatweels and nothing else', () {
    const w = 'مَنۡ ';
    final out = applyKashida(w, 10, {12: 2});
    expect(out, 'مَــنۡ ');
    expect(out.replaceAll(tatweel, ''), w);
  });
}
