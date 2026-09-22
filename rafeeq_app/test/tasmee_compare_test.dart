import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_engine.dart';

/// The word-by-word comparison «التسميع» reports with. The recogniser itself
/// is measured outside the app (`scripts/measure_quran_asr.py`); what is
/// pinned here is the part that decides what the reader is TOLD.
void main() {
  // al-Kahf 1 as `quran_local.db` writes it — Uthmani, with alif wasla.
  const kahf1 = 'ٱلْحَمْدُ لِلَّهِ ٱلَّذِىٓ أَنزَلَ عَلَىٰ عَبْدِهِ ٱلْكِتَٰبَ '
      'وَلَمْ يَجْعَل لَّهُۥ عِوَجَا';

  test('the ayah splits into its words, marks and wasla aside', () {
    expect(tasmeeWords(kahf1), [
      'الحمد', 'لله', 'الذي', 'انزل', 'علي', 'عبده', 'الكتب', 'ولم',
      'يجعل', 'له', 'عوجا',
    ]);
  });

  test('a recitation in imla\'i spelling still counts as said', () {
    // what the recogniser actually returned for this ayah on the desktop
    const heard = 'الحمد لله الذي انزل علي عبده الكتاب ولم يجعل له عوجا';
    final r = TasmeeEngine.compare(ayahText: kahf1, heard: heard);
    expect(r.total, 11);
    expect(r.matched, 11, reason: 'الكتب / الكتاب are the same word here');
    expect(r.heardWord.every((x) => x), isTrue);
  });

  test('a skipped tail is reported word by word', () {
    const heard = 'الحمد لله الذي انزل';
    final r = TasmeeEngine.compare(ayahText: kahf1, heard: heard);
    expect(r.matched, 4);
    expect(r.heardWord.sublist(0, 4), everyElement(isTrue));
    expect(r.heardWord.sublist(4), everyElement(isFalse));
  });

  test('a word said wrong in the middle is the only one marked', () {
    const heard = 'الحمد لله الذي رفع علي عبده الكتاب ولم يجعل له عوجا';
    final r = TasmeeEngine.compare(ayahText: kahf1, heard: heard);
    expect(r.heardWord[3], isFalse, reason: 'انزل was not said');
    expect(r.matched, 10);
  });

  test('another ayah entirely is rejected, not half-accepted', () {
    const heard = 'قل هو الله احد';
    final r = TasmeeEngine.compare(ayahText: kahf1, heard: heard);
    expect(r.matched, lessThanOrEqualTo(1));
    expect(r.ratio, lessThan(0.2));
  });

  test('the skeleton is what makes Uthmani and imla\'i agree', () {
    expect(tasmeeSkeleton('الكتب'), tasmeeSkeleton('الكتاب'));
    expect(tasmeeSkeleton('السموت'), tasmeeSkeleton('السماوات'));
    expect(tasmeeSkeleton('انزل') == tasmeeSkeleton('رفع'), isFalse);
  });

  test('the model download is the measured size, not a guess', () {
    expect(tasmeeAssets.length, 3);
    expect(tasmeeDownloadBytes, 29104812 + 130659024 + 866987);
    for (final a in tasmeeAssets) {
      expect(a.url, contains('/asr/whisper-base-ar-quran/'));
      expect(a.url, startsWith('https://'));
    }
  });
}
