import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_engine.dart';

/// What quran-asr-small (the tasmee' recogniser since 2026-11-14) really
/// wrote for four EveryAyah reciters held out of its training, each ayah
/// passed through a phone-like band and the app's 3.4 kHz low-pass
/// (scripts/measure_asr_quran_small.py, PC, sherpa-onnx 1.13.8). It writes
/// bare Uthmani letters with no hamza seats, alif maqsura or ta marbuta, so
/// these hold that the word comparison still accepts its spelling and still
/// rejects the wrong ayah.
///
/// Ayah text: `text_uthmani` from quran_local.db, unaltered.
const _ayahs = <(int, int), String>{
  (
    2,
    255,
  ): 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَيُّ ٱلۡقَيُّومُۚ لَا تَأۡخُذُهُۥ سِنَةٞ وَلَا نَوۡمٞۚ لَّهُۥ مَا فِي ٱلسَّمَٰوَٰتِ وَمَا فِي ٱلۡأَرۡضِۗ مَن ذَا ٱلَّذِي يَشۡفَعُ عِندَهُۥٓ إِلَّا بِإِذۡنِهِۦۚ يَعۡلَمُ مَا بَيۡنَ أَيۡدِيهِمۡ وَمَا خَلۡفَهُمۡۖ وَلَا يُحِيطُونَ بِشَيۡءٖ مِّنۡ عِلۡمِهِۦٓ إِلَّا بِمَا شَآءَۚ وَسِعَ كُرۡسِيُّهُ ٱلسَّمَٰوَٰتِ وَٱلۡأَرۡضَۖ وَلَا يَـُٔودُهُۥ حِفۡظُهُمَاۚ وَهُوَ ٱلۡعَلِيُّ ٱلۡعَظِيمُ',
  (
    18,
    1,
  ): 'ٱلۡحَمۡدُ لِلَّهِ ٱلَّذِيٓ أَنزَلَ عَلَىٰ عَبۡدِهِ ٱلۡكِتَٰبَ وَلَمۡ يَجۡعَل لَّهُۥ عِوَجَاۜ',
  (67, 1):
      'تَبَٰرَكَ ٱلَّذِي بِيَدِهِ ٱلۡمُلۡكُ وَهُوَ عَلَىٰ كُلِّ شَيۡءٖ قَدِيرٌ',
  (
    67,
    2,
  ): 'ٱلَّذِي خَلَقَ ٱلۡمَوۡتَ وَٱلۡحَيَوٰةَ لِيَبۡلُوَكُمۡ أَيُّكُمۡ أَحۡسَنُ عَمَلٗاۚ وَهُوَ ٱلۡعَزِيزُ ٱلۡغَفُورُ',
};

const _heard = <(String, int, int, String)>[
  (
    'alalaqimy',
    2,
    255,
    'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السموت وما في الارض من ذا الذي يشفع عنده الا باذنه يعلم ما بين ايديهم وما خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السموت والارض ولا يوده حفظهما وهو العلي العظيم',
  ),
  ('alalaqimy', 18, 1, 'الحمد لله الذي انزل علي عبده الكتب ولم يجعل له عوجا'),
  ('alalaqimy', 67, 1, 'تبرك الذي بيده الملك وهو علي كل شيء قدير'),
  (
    'alalaqimy',
    67,
    2,
    'الذي خلق الموت والحيوه ليبلوكم ايكم احسن عملا وهو العزيز الغفور',
  ),
  (
    'rifai',
    2,
    255,
    'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السموت وما في الارض من ذا الذي يشفع عنده الا باذنه يعلم ما بين ايديهم وما خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السموت والارض ولا يوده حفظهما وهو العلي العظيم',
  ),
  ('rifai', 18, 1, 'الحمد لله الذي انزل علي عبده الكتب ولم يجعل له عوجا'),
  ('rifai', 67, 1, 'تبرك الذي بيده الملك وهو علي كل شيء قدير'),
  (
    'rifai',
    67,
    2,
    'الذي خلق الموت والحيوه ليبلوكم ايكم احسن عملا وهو العزيز الغفور',
  ),
  (
    'menshawi32',
    2,
    255,
    'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السموت وما في الارض من ذا الذي يشفع عنده الا باذنه يعلم ما بين ايديهم وما خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السموت والارض ولا يوده حفظهما وهو العلي العظيم',
  ),
  ('menshawi32', 18, 1, 'الحمد لله الذي انزل علي عبده الكتب ولم يجعل له عوجا'),
  ('menshawi32', 67, 1, 'تبرك الذي بيده الملك وهو علي كل شيء قدير'),
  (
    'menshawi32',
    67,
    2,
    'الذي خلق الموت والحيوه ليبلوكم ايكم احسن عملا وهو العزيز الغفور',
  ),
  (
    'sahlyassin',
    2,
    255,
    'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السموت وما في الارض من ذا الذي يشفع عنده الا باذنه يعلم ما بين ايديهم وما خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السموت والارض ولا يوده حفظهما وهو العلي العظيم',
  ),
  ('sahlyassin', 18, 1, 'الحمد لله الذي انزل علي عبده الكتب ولم يجعل له عوجا'),
  ('sahlyassin', 67, 1, 'تبرك الذي بيده الملك وهو علي كل شيء قدير'),
  (
    'sahlyassin',
    67,
    2,
    'الذي خلق الموت والحيوه ليبلوكم ايكم احسن عملا وهو العزيز الغفور',
  ),
];

void main() {
  for (final (reciter, s, a, heard) in _heard) {
    test('$reciter $s:$a is heard as recited', () {
      final r = TasmeeEngine.compare(
        ayahText: _ayahs[(s, a)]!,
        heard: heard,
        surahId: s,
        ayahNumber: a,
      );
      expect(
        r.ratio,
        greaterThanOrEqualTo(0.9),
        reason: '${r.matched}/${r.total}: $heard',
      );
    });
  }

  test('the wrong ayah is still a plain drop', () {
    for (final (heardOf, against) in [
      ((67, 1), (2, 255)),
      ((18, 1), (67, 2)),
      ((67, 2), (18, 1)),
    ]) {
      final heard = _heard
          .firstWhere((h) => h.$2 == heardOf.$1 && h.$3 == heardOf.$2)
          .$4;
      final r = TasmeeEngine.compare(
        ayahText: _ayahs[against]!,
        heard: heard,
        surahId: against.$1,
        ayahNumber: against.$2,
      );
      expect(r.ratio, lessThan(0.35), reason: '$heardOf vs $against');
    }
  });
}
