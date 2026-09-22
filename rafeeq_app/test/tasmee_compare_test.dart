import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/hifz_mask.dart';
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

  // Maryam 2-3, as quran_local.db writes them, and what the Quran-tuned
  // tiny model returned on the owner's Xiaomi on 2026-09-23 while he recited
  // each one correctly. The old equal-skeleton rule scored them 0/5 and 3/5.
  const maryam2 = 'ذِكْرُ رَحْمَتِ رَبِّكَ عَبْدَهُۥ زَكَرِيَّآ';
  const maryam3 = 'إِذْ نَادَىٰ رَبَّهُۥ نِدَآءً خَفِيًّا';

  test('a correct recitation misheard by the model still counts (Maryam 3)',
      () {
    final r = TasmeeEngine.compare(
        ayahText: maryam3, heard: 'إذن دعوا به ندى أن خفية');
    expect(r.total, 5);
    // «نادى» came back as «دعوا» — a different word; the other four are the
    // model's spelling of what was said.
    expect(r.matched, greaterThanOrEqualTo(4));
    expect(r.heardWord[0], isTrue);
    expect(r.heardWord[4], isTrue);
  });

  test('a word split in two by the model still counts (Maryam 2)', () {
    final r = TasmeeEngine.compare(
        ayahText: maryam2, heard: 'زيك رون حمتي ربك عبده وزكريا');
    expect(r.matched, 5);
  });

  test('the neighbouring ayah is still rejected under the looser match', () {
    final r = TasmeeEngine.compare(
        ayahText: maryam3, heard: 'ذكر رحمت ربك عبده زكريا');
    expect(r.matched, 0);
    final back = TasmeeEngine.compare(
        ayahText: maryam2, heard: 'إذ نادى ربه نداء خفيا');
    expect(back.matched, 0);
  });

  test('opening letters are compared as they are recited', () {
    const maryam1 = 'كٓهيعٓصٓ';
    final r = TasmeeEngine.compare(
        ayahText: maryam1,
        heard: 'كاف ها يا عين صاد',
        surahId: 19,
        ayahNumber: 1);
    expect(r.matched, 1);
    // what the model returned on the phone
    final phone = TasmeeEngine.compare(
        ayahText: maryam1, heard: 'كيف حيث صد', surahId: 19, ayahNumber: 1);
    expect(phone.matched, 1);
    // …and only in the surahs that open with letters. «ألم» said as a WORD
    // is al-Fil 1's first word, and is not al-Baqarah 1's letters.
    final fil = TasmeeEngine.compare(
        ayahText: 'أَلَمْ تَرَ', heard: 'ألم تر', surahId: 105, ayahNumber: 1);
    expect(fil.matched, 2);
    final baqarah = TasmeeEngine.compare(
        ayahText: 'الٓمٓ', heard: 'ألم', surahId: 2, ayahNumber: 1);
    expect(baqarah.matched, 0);
    final baqarahRecited = TasmeeEngine.compare(
        ayahText: 'الٓمٓ', heard: 'الف لام ميم', surahId: 2, ayahNumber: 1);
    expect(baqarahRecited.matched, 1);
  });

  test('closeness: near spellings pass, different words do not', () {
    expect(tasmeeCloseness('ربه', 'به'), greaterThanOrEqualTo(0.6));
    expect(tasmeeCloseness('نداء', 'ندي'), greaterThanOrEqualTo(0.6));
    expect(tasmeeCloseness('انزل', 'رفع'), lessThan(0.3));
    expect(tasmeeCloseness('نادي', 'دعوا'), lessThan(0.6));
  });

  // al-Nisa 1 after its basmala, verbatim from quran_local.db, and what the
  // model returned on the owner's phone for a complete, correct recitation.
  // The old walk lost its place at the first unmatched word and never found
  // it again: «نطقت ١ من ٣٢».
  const nisa1 = 'يَٰٓأَيُّهَا ٱلنَّاسُ ٱتَّقُوا۟ رَبَّكُمُ ٱلَّذِى خَلَقَكُم مِّن نَّفْسٍۢ وَٰحِدَةٍۢ وَخَلَقَ مِنْهَا زَوْجَهَا وَبَثَّ مِنْهُمَا رِجَالًۭا كَثِيرًۭا وَنِسَآءًۭ ۚ وَٱتَّقُوا۟ ٱللَّهَ ٱلَّذِى تَسَآءَلُونَ بِهِۦ وَٱلْأَرْحَامَ ۚ إِنَّ ٱللَّهَ كَانَ عَلَيْكُمْ رَقِيبًۭا';
  const nisa1Heard = 'يوحلنا ستكون بكم الذي خلقكم نفسه وحيناتكم وخلق منها زوجه وذن منه مارجال كثيرا ونسى والتقل الله الذي تسرون به والأرحان إن الله كان عليكم ركيبا';

  test('one bad word at the start does not lose the rest (al-Nisa 1)', () {
    final r = TasmeeEngine.compare(ayahText: nisa1, heard: nisa1Heard);
    // ignore: avoid_print
    print('al-Nisa 1: ${r.matched} of ${r.total}');
    expect(r.total, 28);
    expect(r.matched, greaterThanOrEqualTo(20));
  });

  test('a pause mark stays with its word', () {
    final words = ayahWords(nisa1);
    expect(words.length, 28);
    expect(words.where((w) => !RegExp('[ء-ي]').hasMatch(w)), isEmpty);
  });

  test('the model download is the measured size, not a guess', () {
    expect(tasmeeAssets.length, 1);
    expect(tasmeeDownloadBytes, 77691713);
    for (final a in tasmeeAssets) {
      expect(a.url, contains('/asr/whisper-tiny-ar-quran/'));
      expect(a.url, startsWith('https://'));
    }
  });
}
