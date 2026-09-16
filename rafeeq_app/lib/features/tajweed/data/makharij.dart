/// مخارج الحروف — the seventeen articulation points, read out of the matn.
///
/// WHAT IS MINE HERE AND WHAT IS NOT. None of the science is written by me.
/// Every [Makhraj.matn] line below is quoted **verbatim** from «المقدمة
/// الجزرية» لابن الجزري (ت ٨٣٣هـ), أبيات ٩–١٩, ص٥٦–٥٨ of the printing this
/// app hosts as `al_muqaddimah_al_jazariyyah_matn` — the same text level two
/// teaches. What is mine is [Makhraj.place]: a short plain naming of the
/// anatomical spot his verse compresses, so a beginner can read the entry
/// before he can read the verse. The arrangement — which makhraj belongs to
/// which region, and the order they are walked in — is his, in his order.
///
/// WHY THIS SOURCE. It used to be «غاية المريد في علم التجويد» لعطية قابل نصر
/// (ت ١٤٢٤هـ) — a book by a modern author from a commercial house, quoted here
/// verbatim on every entry. «انا مش عاوز في التطبيق اي مشكلة لحقوق الملكية
/// نهائيا», so it went, out of the course and off the bucket, and this file was
/// re-read onto the two books of ابن الجزري the app now teaches: the matn for
/// the letters and the arrangement, and «التمهيد في علم التجويد» له, ص١٠٥–١٠٦,
/// for the prose behind the wording. Both authors' rights expired six hundred
/// years ago.
///
/// WHY THE MATN'S COUNT AND NOT THE TAMHID'S. His prose in التمهيد gives the
/// حلق «ثلاثة مخارج، لسبعة أحرف» — counting the ألف at أقصى الحلق with الهمزة
/// and again among حروف المد, and he flags it himself: «ولم يذكر الخليل هذا
/// الحرف هنا». His matn resolves that: «فَأَلِفُ الجَوْفِ وَأُخْتَاهَا»، then
/// «ثُمَّ لِأَقْصَى الحَلْقِ: هَمْزٌ هَاءُ» — the ألف once, at the jawf. So the
/// table below follows the matn, which is his own later, versified choice, and
/// it comes to 3 + 6 + 18 + 4 = 31 letters over 17 makharij.
/// `test/makharij_test.dart` fails if it ever does not. A wrong letter cannot
/// hide behind a pretty diagram.
library;

/// One of the five **general** regions (المخارج العامة).
enum MakhrajRegion { jawf, halq, lisan, shafatan, khayshum }

/// One **specific** makhraj (مخرج خاص) — a single articulation point.
class Makhraj {
  /// Stable id, used by the diagram to address a region and by saved state.
  final String id;

  final MakhrajRegion region;

  /// The place itself, named plainly. **This line is the app's**, not a
  /// quotation: it says in prose what [matn] says in verse.
  final String place;

  /// ابن الجزري's own words for this makhraj, verbatim from the matn.
  final String matn;

  /// The letters that leave from it, in the matn's order.
  final List<String> letters;

  /// The printed page of «المقدمة الجزرية» the [matn] line is on.
  final int page;

  /// An ayah the letter can be heard in, where the matn itself names the
  /// letters plainly enough to point at one. The jawf has one; the rest are
  /// left null rather than invented — «ممنوع استخدام أكواد وهمية».
  final String? ayahExample;

  const Makhraj({
    required this.id,
    required this.region,
    required this.place,
    required this.matn,
    required this.letters,
    required this.page,
    this.ayahExample,
  });
}

/// What each region is called, and the verse it is established by.
class MakhrajRegionInfo {
  final MakhrajRegion region;
  final String name;

  /// The matn's own lines for the region, verbatim.
  final String definition;

  final int page;

  const MakhrajRegionInfo({
    required this.region,
    required this.name,
    required this.definition,
    required this.page,
  });
}

const makhrajRegions = <MakhrajRegionInfo>[
  MakhrajRegionInfo(
    region: MakhrajRegion.jawf,
    name: 'الجوف',
    definition: 'فَأَلِفُ الجَوْفِ وَأُخْتَاهَا وَهِي … '
        'حُرُوفُ مَدٍّ لِلْهَوَاءِ تَنْتَهِي',
    page: 56,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.halq,
    name: 'الحلق',
    definition: 'ثُمَّ لِأَقْصَى الحَلْقِ: هَمْزٌ هَاءُ … '
        'ثُمَّ لِوَسْطِهِ: فَعَيْنٌ حَاءُ • أَدْنَاهُ: غَيْنٌ خَاؤُهَا',
    page: 56,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.lisan,
    name: 'اللسان',
    definition: 'وَالقَافُ أَقْصَى اللِّسَانِ فَوْقُ، ثُمَّ الكَافُ • '
        'أَسْفَلُ، وَالوَسْطُ: فَجِيمُ الشِّينُ يَا',
    page: 56,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.shafatan,
    name: 'الشَّفتان',
    definition: 'وَمِنْ بَطْنِ الشَّفَهْ … '
        'فَالْفَا مَعَ اطْرَافِ الثَّنَايَا المُشْرِفَهْ • '
        'لِلشَّفَتَيْنِ: الوَاوُ بَاءٌ مِيمُ',
    page: 58,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.khayshum,
    name: 'الخيشوم',
    definition: 'وَغُنَّةٌ: مَخْرَجُهَا الخَيْشُومُ',
    page: 58,
  ),
];

/// The seventeen, in the matn's own order: الجوف، الحلق، اللسان، الشفتان،
/// الخيشوم — «مَخَارِجُ الحُرُوفِ سَبْعَةَ عَشَرْ … عَلَى الَّذِي يَخْتَارُهُ
/// مَنِ اخْتَبَرْ» (البيت ٩، ص٥٦)، وهو مذهب الخليل بن أحمد، واختاره الناظم.
const makharij = <Makhraj>[
  // ── الجوف ───────────────────────────────────────────────────────────────
  Makhraj(
    id: 'jawf',
    region: MakhrajRegion.jawf,
    place: 'الخلاء الواقع في جوف الفم والحلق، تنتهي إليه حروف المد الثلاثة',
    matn: 'فَأَلِفُ الجَوْفِ وَأُخْتَاهَا وَهِي … '
        'حُرُوفُ مَدٍّ لِلْهَوَاءِ تَنْتَهِي',
    letters: ['ا', 'و', 'ي'],
    page: 56,
    ayahExample: '{قَالَ} {يَقُولُ} {قِيلَ}',
  ),

  // ── الحلق ───────────────────────────────────────────────────────────────
  Makhraj(
    id: 'halq_aqsa',
    region: MakhrajRegion.halq,
    place: 'أقصى الحلق: أبعده مما يلي الصدر',
    matn: 'ثُمَّ لِأَقْصَى الحَلْقِ: هَمْزٌ هَاءُ',
    letters: ['ء', 'هـ'],
    page: 56,
  ),
  Makhraj(
    id: 'halq_wasat',
    region: MakhrajRegion.halq,
    place: 'وسط الحلق: ما بين أقصاه وأدناه',
    matn: 'ثُمَّ لِوَسْطِهِ: فَعَيْنٌ حَاءُ',
    letters: ['ع', 'ح'],
    page: 56,
  ),
  Makhraj(
    id: 'halq_adna',
    region: MakhrajRegion.halq,
    place: 'أدنى الحلق: أقربه مما يلي الفم',
    matn: 'أَدْنَاهُ: غَيْنٌ خَاؤُهَا',
    letters: ['غ', 'خ'],
    page: 56,
  ),

  // ── اللسان ──────────────────────────────────────────────────────────────
  Makhraj(
    id: 'lisan_aqsa_qaf',
    region: MakhrajRegion.lisan,
    place: 'أقصى اللسان من فوق، مع ما يحاذيه من الحنك الأعلى',
    matn: 'وَالقَافُ أَقْصَى اللِّسَانِ فَوْقُ',
    letters: ['ق'],
    page: 56,
  ),
  Makhraj(
    id: 'lisan_aqsa_kaf',
    region: MakhrajRegion.lisan,
    place: 'أقصى اللسان أسفل من مخرج القاف قليلًا، مع ما يحاذيه من الحنك '
        'الأعلى',
    matn: 'ثُمَّ الكَافُ أَسْفَلُ',
    letters: ['ك'],
    page: 56,
  ),
  Makhraj(
    id: 'lisan_wasat',
    region: MakhrajRegion.lisan,
    place: 'وسط اللسان مع ما يحاذيه من الحنك الأعلى',
    matn: 'وَالوَسْطُ: فَجِيمُ الشِّينُ يَا',
    letters: ['ج', 'ش', 'ي'],
    page: 56,
  ),
  Makhraj(
    id: 'lisan_hafa_dad',
    region: MakhrajRegion.lisan,
    place: 'إحدى حافتي اللسان مع ما يليها من الأضراس، من اليسرى أو اليمنى',
    matn: 'وَالضَّادُ: مِنْ حَافَتِهِ إِذْ وَلِيَا … '
        'لَاضْرَاسَ مِنْ أَيْسَرَ أَوْ يُمْنَاهَا',
    letters: ['ض'],
    page: 56,
  ),
  Makhraj(
    id: 'lisan_hafa_lam',
    region: MakhrajRegion.lisan,
    place: 'أدنى حافة اللسان إلى منتهى طرفه، مع ما يحاذيها من اللَّثَة العليا',
    matn: 'وَاللَّامُ: أَدْنَاهَا لِمُنْتَهَاهَا',
    letters: ['ل'],
    page: 57,
  ),
  Makhraj(
    id: 'lisan_taraf_nun',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان تحت مخرج اللام قليلًا، مع ما يليه من لَثَة الأسنان '
        'العليا',
    matn: 'وَالنُّونُ: مِنْ طَرَفِهِ تَحْتُ اجْعَلُوا',
    letters: ['ن'],
    page: 57,
  ),
  Makhraj(
    id: 'lisan_taraf_ra',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان قريبًا من مخرج النون، مع إدخاله إلى ظهر اللسان',
    matn: 'وَالرَّا: يُدَانِيهِ لِظَهْرٍ أَدْخَلُ',
    letters: ['ر'],
    page: 57,
  ),
  Makhraj(
    id: 'lisan_nitiyya',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان مع أصول الثنايا العليا',
    matn: 'وَالطَّاءُ وَالدَّالُ وَتَا: مِنْهُ وَمِنْ … عُلْيَا الثَّنَايَا',
    letters: ['ط', 'د', 'ت'],
    page: 57,
  ),
  Makhraj(
    id: 'lisan_asaliyya',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان مع ما فوق الثنايا السفلى — وهي حروف الصفير',
    matn: 'وَالصَّفِيرُ: مُسْتَكِنْ … مِنْهُ وَمِنْ فَوْقِ الثَّنَايَا '
        'السُّفْلَى',
    letters: ['ص', 'ز', 'س'],
    page: 57,
  ),
  Makhraj(
    id: 'lisan_lithawiyya',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان مع أطراف الثنايا العليا',
    matn: 'وَالظَّاءُ وَالذَّالُ وَثَا: لِلْعُلْيَا … مِنْ طَرَفَيْهِمَا',
    letters: ['ظ', 'ذ', 'ث'],
    page: 58,
  ),

  // ── الشفتان ─────────────────────────────────────────────────────────────
  Makhraj(
    id: 'shafa_fa',
    region: MakhrajRegion.shafatan,
    place: 'بطن الشَّفة السفلى مع أطراف الثنايا العليا',
    matn: 'وَمِنْ بَطْنِ الشَّفَهْ … '
        'فَالْفَا مَعَ اطْرَافِ الثَّنَايَا المُشْرِفَهْ',
    letters: ['ف'],
    page: 58,
  ),
  Makhraj(
    id: 'shafa_bmw',
    region: MakhrajRegion.shafatan,
    place: 'ما بين الشفتين: تنطبقان عند الباء والميم، وتنفرجان قليلًا عند '
        'الواو المدية',
    matn: 'لِلشَّفَتَيْنِ: الوَاوُ بَاءٌ مِيمُ',
    letters: ['ب', 'م', 'و'],
    page: 58,
  ),

  // ── الخيشوم ─────────────────────────────────────────────────────────────
  Makhraj(
    id: 'khayshum',
    region: MakhrajRegion.khayshum,
    place: 'أقصى الأنف من الداخل، ومنه تخرج الغنة',
    matn: 'وَغُنَّةٌ: مَخْرَجُهَا الخَيْشُومُ',
    letters: ['الغنة'],
    page: 58,
  ),
];

/// The matn's own tally, counted off أبيات ١٠–١٩, which the test holds the
/// data to: ٣ للجوف، ٦ للحلق، ١٨ للسان، ٤ للشفتين — وواحد للخيشوم هو الغنة.
const makharijLetterCountByRegion = <MakhrajRegion, int>{
  MakhrajRegion.jawf: 3,
  MakhrajRegion.halq: 6,
  MakhrajRegion.lisan: 18,
  MakhrajRegion.shafatan: 4,
};

/// Both of ابن الجزري's books, named as the Sources screen names them.
const makharijSourceLabel =
    'المقدمة الجزرية، لابن الجزري (ت ٨٣٣هـ) — الأبيات ٩–١٩، ص٥٦–٥٨؛ '
    'والتمهيد في علم التجويد، له — ص١٠٥–١٠٦';
