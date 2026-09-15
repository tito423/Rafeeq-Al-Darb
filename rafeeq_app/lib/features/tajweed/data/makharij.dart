/// مخارج الحروف — the seventeen articulation points, read out of a book.
///
/// WHAT IS MINE HERE AND WHAT IS NOT, exactly as in `tajweed_course.dart`:
/// none of the science is written by me. Every definition below is quoted
/// **verbatim** from «غاية المريد في علم التجويد» لعطية قابل نصر (ت ١٤٢٤هـ),
/// الطبعة السابعة مزيدة ومنقحة, from the pages named on each entry — the book
/// this app already hosts as `ghayat_al_murid`. What is mine is the
/// arrangement: which makhraj belongs to which region, and the order they are
/// walked in, both of which are the book's own.
///
/// WHY THIS BOOK AND NOT «هداية القاري». هداية القاري is the fuller reference
/// and its chapter list is the whole syllabus — but the copy Shamela serves is
/// **hollow exactly where it matters**: `ajax/pageContent/22869/50` (printed
/// p.65, «الفصل الثاني / في بيان تفصيل المخارج») returns a title and an anchor
/// with no text at all, and 203 of its 749 pages are like that, including the
/// whole of مخارج الحروف, صفات الحروف and التفخيم والترقيق. The crawl is
/// faithful; the source is empty. غاية المريد has **zero** empty pages.
///
/// THE COUNT IS THE BOOK'S OWN, AND IT IS THE TEST. On p.131 it says:
/// «أما عند مخارج الحروف فيكون عددها واحدًا وثلاثين حرفًا. فالجوف يخرج منه
/// ثلاثة أحرف، والحلق ستة، واللسان ثمانية عشر، والشفتان أربعة». So the data
/// below must come to 3 + 6 + 18 + 4 = 31 letters over 17 makharij, and
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

  /// The place itself, in the book's wording.
  final String place;

  /// The letters that leave from it, as the book lists them and in its order.
  final List<String> letters;

  /// The printed page in «غاية المريد» this entry is read from.
  final int page;

  /// An ayah the letter can be heard in, where the book gives one. The book
  /// supplies these for the jawf; the rest are left null rather than invented
  /// — «ممنوع استخدام أكواد وهمية».
  final String? ayahExample;

  const Makhraj({
    required this.id,
    required this.region,
    required this.place,
    required this.letters,
    required this.page,
    this.ayahExample,
  });
}

/// What each region is called and what the book says it is, verbatim.
class MakhrajRegionInfo {
  final MakhrajRegion region;
  final String name;
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
    definition: 'ومعناه لغة: الخلاء. واصطلاحًا: الخلاء الواقع داخل الحلق '
        'والفم وتخرج منه ثلاثة أحرف وهي حروف المد',
    page: 127,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.halq,
    name: 'الحلق',
    definition: 'وفيه ثلاثة مخارج تخرج منها ستة أحرف',
    page: 128,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.lisan,
    name: 'اللسان',
    definition: 'وفيه عشرة مخارج تخرج منها ثمانية عشرة حرفًا',
    page: 128,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.shafatan,
    name: 'الشَّفتان',
    definition: 'وفيهما مخرجان',
    page: 130,
  ),
  MakhrajRegionInfo(
    region: MakhrajRegion.khayshum,
    name: 'الخيشوم',
    definition: 'الخيشوم هو أقصى الأنف من الداخل وفيه مخرج واحد تخرج منه '
        'الغنة',
    page: 130,
  ),
];

/// The seventeen, in the book's own order: الجوف، الحلق، اللسان، الشفتان،
/// الخيشوم — «مخارجُ الحروفِ سبعةَ عشرْ … على الذي يختارُه منِ اختبرْ»، the
/// line of the Jazariyyah the book quotes on p.127 for this arrangement (مذهب
/// الخليل بن أحمد، واختاره الإمام ابن الجزري).
const makharij = <Makhraj>[
  // ── الجوف ───────────────────────────────────────────────────────────────
  Makhraj(
    id: 'jawf',
    region: MakhrajRegion.jawf,
    place: 'الخلاء الواقع داخل الحلق والفم',
    letters: ['ا', 'و', 'ي'],
    page: 127,
    ayahExample: '{قَالَ} {يَقُولُ} {قِيلَ}',
  ),

  // ── الحلق ───────────────────────────────────────────────────────────────
  Makhraj(
    id: 'halq_aqsa',
    region: MakhrajRegion.halq,
    place: 'أقصى الحلق: أي أبعده مما يلي الصدر',
    letters: ['ء', 'هـ'],
    page: 128,
  ),
  Makhraj(
    id: 'halq_wasat',
    region: MakhrajRegion.halq,
    place: 'وسط الحلق: وهو ما بين أقصاه وأدناه',
    letters: ['ع', 'ح'],
    page: 128,
  ),
  Makhraj(
    id: 'halq_adna',
    region: MakhrajRegion.halq,
    place: 'أدنى الحلق: أي أقربه مما يلي الفم',
    letters: ['غ', 'خ'],
    page: 128,
  ),

  // ── اللسان ──────────────────────────────────────────────────────────────
  Makhraj(
    id: 'lisan_aqsa_qaf',
    region: MakhrajRegion.lisan,
    place: 'أقصى اللسان من فوق -أي أبعده مما يلي الحلق- مع ما يحاذيه من '
        'الحنك الأعلى',
    letters: ['ق'],
    page: 128,
  ),
  Makhraj(
    id: 'lisan_aqsa_kaf',
    region: MakhrajRegion.lisan,
    place: 'أقصى اللسان مع ما يحاذيه من الحنك الأعلى، إلا أن مخرجها أسفل من '
        'مخرج القاف، قريب من وسط اللسان',
    letters: ['ك'],
    page: 128,
  ),
  Makhraj(
    id: 'lisan_wasat',
    region: MakhrajRegion.lisan,
    place: 'وسط اللسان مع ما يحاذيه من الحنك الأعلى',
    letters: ['ج', 'ش', 'ي'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_hafa_dad',
    region: MakhrajRegion.lisan,
    place: 'إحدى حافتي اللسان مما يلي الأضراس العليا اليسرى أو اليمنى',
    letters: ['ض'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_hafa_lam',
    region: MakhrajRegion.lisan,
    place: 'أدنى حافة اللسان إلى منتهاها مع ما يحاذيها من اللَّثَة العليا',
    letters: ['ل'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_taraf_nun',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان تحت مخرج اللام قليلا مع ما يليه من لَثَة الأسنان العليا',
    letters: ['ن'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_taraf_ra',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان قريب إلى ظهره قليلا بعد مخرج النون',
    letters: ['ر'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_asaliyya',
    region: MakhrajRegion.lisan,
    place: 'طرف اللسان مع ما بين الثنايا العليا والسفلى، قريب إلى أطراف '
        'الثنايا السفلى',
    letters: ['ص', 'ز', 'س'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_nitiyya',
    region: MakhrajRegion.lisan,
    place: 'ظهر طرف اللسان مع أصول الثنايا العليا',
    letters: ['ط', 'د', 'ت'],
    page: 129,
  ),
  Makhraj(
    id: 'lisan_lithawiyya',
    region: MakhrajRegion.lisan,
    place: 'ظهر طرف اللسان مع أطراف الثنايا العليا',
    letters: ['ظ', 'ذ', 'ث'],
    page: 129,
  ),

  // ── الشفتان ─────────────────────────────────────────────────────────────
  Makhraj(
    id: 'shafa_fa',
    region: MakhrajRegion.shafatan,
    place: 'بطن الشَّفة السفلى مع أطراف الثنايا العليا',
    letters: ['ف'],
    page: 130,
  ),
  Makhraj(
    id: 'shafa_bmw',
    region: MakhrajRegion.shafatan,
    place: 'ما بين الشفتين معًا، مع انطباق عند الباء والميم وانفراج قليل عند '
        'الواو المدية',
    letters: ['ب', 'م', 'و'],
    page: 130,
  ),

  // ── الخيشوم ─────────────────────────────────────────────────────────────
  Makhraj(
    id: 'khayshum',
    region: MakhrajRegion.khayshum,
    place: 'أقصى الأنف من الداخل',
    letters: ['الغنة'],
    page: 130,
  ),
];

/// The book's own tally, quoted on p.131, which the test holds the data to.
const makharijLetterCountByRegion = <MakhrajRegion, int>{
  MakhrajRegion.jawf: 3,
  MakhrajRegion.halq: 6,
  MakhrajRegion.lisan: 18,
  MakhrajRegion.shafatan: 4,
};

/// «المكتبة الشاملة — غاية المريد في علم التجويد، لعطية قابل نصر» — the same
/// label the hosted book carries, so the Sources screen and the book agree.
const makharijSourceLabel =
    'غاية المريد في علم التجويد، لعطية قابل نصر (ت ١٤٢٤هـ) — '
    'الطبعة السابعة مزيدة ومنقحة، ص١٢٦–١٣١';
