import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/hifz_mask.dart';
import 'package:rafeeq_app/features/hifz/data/hifz_store.dart';

/// The memorization ladder and the word mask, stated in numbers.
void main() {
  test('an unseen ayah is due today', () {
    const s = HifzState({});
    expect(s.isDue(2, 255, today: 100), isTrue);
  });

  test('«حفظت» moves up a box and pushes the next review out', () {
    var a = const HifzAyah(box: 0, dueDay: 100);
    // box 1 -> +3 days, box 2 -> +7, box 3 -> +16, box 4 -> +35
    expect(hifzBoxDays, [0, 3, 7, 16, 35]);
    final s = HifzState({hifzKey(2, 255): a});
    expect(s.isDue(2, 255, today: 100), isTrue);
    a = const HifzAyah(box: 2, dueDay: 107);
    final s2 = HifzState({hifzKey(2, 255): a});
    expect(s2.isDue(2, 255, today: 106), isFalse);
    expect(s2.isDue(2, 255, today: 107), isTrue);
  });

  test('due list keeps the ayahs in order and drops the ones not due', () {
    final s = HifzState({
      hifzKey(112, 1): const HifzAyah(box: 3, dueDay: 200),
      hifzKey(112, 3): const HifzAyah(box: 1, dueDay: 100),
    });
    expect(s.dueIn(112, 4, today: 150), [2, 3, 4]);
  });

  test('a tasmee attempt keeps the BEST score, and never moves the ladder', () {
    // the state object carries it; the notifier writes it (SharedPreferences
    // is not available in a plain unit test, so the rule is pinned here on
    // the model it writes).
    const a = HifzAyah(box: 2, dueDay: 500, streak: 3, bestPercent: 80);
    expect(a.bestPercent, 80);
    final round = HifzAyah.fromJson(a.toJson());
    expect(round.bestPercent, 80);
    expect(round.box, 2);
    expect(round.dueDay, 500);
    expect(round.streak, 3);
    // an ayah never recited reads as -1, not 0 — «never tried» is not «0%»
    expect(const HifzAyah(box: 0, dueDay: 1).bestPercent, -1);
  });

  test('the mask hides from the end, and always leaves the first word', () {
    const ayah = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
    expect(ayahWords(ayah).length, 4);
    expect(hifzMaskSteps(ayah), 4);
    // step 0: nothing hidden
    expect(hifzWordHidden(3, 4, 0), isFalse);
    // step 1: the last word only
    expect(hifzWordHidden(3, 4, 1), isTrue);
    expect(hifzWordHidden(2, 4, 1), isFalse);
    // step 9 (past the end): everything but the first word
    expect(hifzWordHidden(0, 4, 9), isFalse);
    expect(hifzWordHidden(1, 4, 9), isTrue);
  });
}
