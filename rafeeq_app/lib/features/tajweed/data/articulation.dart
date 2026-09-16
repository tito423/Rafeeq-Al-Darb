/// How each makhraj actually *moves* — the part of the data the diagram needs
/// in order to show articulation rather than point at it.
///
/// «التصميم بعيد كل البعد عن الحقيقي ومفيش فيه حركة توضح ازاي بتخرج الحروف».
/// A dot that pulses says "here"; it does not say how. What a reader needs to
/// see is the tongue rising to the place, the lips meeting, the air stopping
/// or passing, and where the sound leaves from.
///
/// None of this is a ruling and none of it is invented science: it is the
/// mechanics of the places ابن الجزري already names. His matn says
/// «لِلشَّفَتَيْنِ: الوَاوُ بَاءٌ مِيمُ» — the lips meet; it says «فَالْفَا مَعَ
/// اطرَافِ الثَّنَايَا المُشْرِفَهْ» — the lower lip rises to the upper teeth;
/// it says «وَغُنَّةٌ: مَخْرَجُهَا الخَيْشُومُ». Each entry below is one of
/// those lines turned into a movement.
library;

/// What the mouth does for a makhraj.
enum Articulator {
  /// The tongue rises at one place until it meets the roof.
  tongue,

  /// The two lips meet (ب، م) or part a little (و).
  lips,

  /// The lower lip rises to the upper teeth (ف).
  lipToTeeth,

  /// A narrowing deep in the throat; nothing in the mouth moves.
  throat,

  /// Nothing closes at all — the air runs right through (حروف المد).
  open,

  /// The sound leaves through the nose (الغنة).
  nose,
}

/// Where the air ends up, which is what the stream in the diagram follows.
enum AirPath { outMouth, outNose, blocked }

class ArticulationSpec {
  final Articulator articulator;
  final AirPath air;

  /// Where along the tongue the contact happens, in the diagram's 0..1 x
  /// space. Null for everything that is not a tongue movement.
  final double? contactX;

  /// How high the tongue goes, 0..1 of the gap to the palate. الضاد and اللام
  /// press their *edge* rather than the middle, so they do not close fully in
  /// a side view — the section would otherwise lie about what it shows.
  final double closure;

  const ArticulationSpec({
    required this.articulator,
    required this.air,
    this.contactX,
    this.closure = 1.0,
  });
}

/// One spec per makhraj id in `makharij.dart`. Kept beside the data rather
/// than inside the painter so a wrong movement is a wrong *fact*, visible in
/// review, and so `test/makharij_test.dart` can insist every makhraj has one.
const articulationByMakhraj = <String, ArticulationSpec>{
  'jawf': ArticulationSpec(
    articulator: Articulator.open,
    air: AirPath.outMouth,
  ),
  'halq_aqsa': ArticulationSpec(
    articulator: Articulator.throat,
    air: AirPath.outMouth,
  ),
  'halq_wasat': ArticulationSpec(
    articulator: Articulator.throat,
    air: AirPath.outMouth,
  ),
  'halq_adna': ArticulationSpec(
    articulator: Articulator.throat,
    air: AirPath.outMouth,
  ),
  'lisan_aqsa_qaf': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.blocked,
    contactX: 0.685,
  ),
  'lisan_aqsa_kaf': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.blocked,
    contactX: 0.615,
  ),
  'lisan_wasat': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.50,
    closure: 0.85,
  ),
  // الضاد: «إحدى حافتي اللسان» — an edge, not the middle of the section.
  'lisan_hafa_dad': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.42,
    closure: 0.7,
  ),
  'lisan_hafa_lam': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.315,
    closure: 0.9,
  ),
  // النون المظهرة carries a ghunnah, so its air leaves through the nose.
  'lisan_taraf_nun': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outNose,
    contactX: 0.255,
  ),
  'lisan_taraf_ra': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.225,
    closure: 0.85,
  ),
  'lisan_asaliyya': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.185,
    closure: 0.75,
  ),
  'lisan_nitiyya': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.blocked,
    contactX: 0.185,
  ),
  'lisan_lithawiyya': ArticulationSpec(
    articulator: Articulator.tongue,
    air: AirPath.outMouth,
    contactX: 0.152,
    closure: 0.8,
  ),
  'shafa_fa': ArticulationSpec(
    articulator: Articulator.lipToTeeth,
    air: AirPath.outMouth,
  ),
  'shafa_bmw': ArticulationSpec(
    articulator: Articulator.lips,
    air: AirPath.blocked,
  ),
  'khayshum': ArticulationSpec(
    articulator: Articulator.nose,
    air: AirPath.outNose,
  ),
};
