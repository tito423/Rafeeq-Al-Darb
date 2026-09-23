/// مناسك الحج والعمرة, step by step.
///
/// WHAT IS MINE HERE AND WHAT IS NOT.
///
/// The rulings of Hajj are not mine to write, so none are written here. Every
/// step's text is read, verbatim, from the chapter «الحج والعمرة» of «الفقه
/// المنهجي على مذهب الإمام الشافعي» (مصطفى الخن، مصطفى البغا، علي الشربجي؛
/// دار القلم، دمشق ١٤١٣هـ), Shamela 6369, vol. 2 pp. 111-188 — bundled as
/// `al_fiqh_al_manhaji_hajj` by `scripts/build_hajj_guide_book.py`.
///
/// WHY THIS BOOK (2026-09-23). The guide read al-Nawawi's «الإيضاح» until
/// the owner asked for a modern one: «ابني من الحديث وسيب النووي في
/// المكتبة». الفقه المنهجي is written for the ordinary reader, speaks of today
/// (Dhu al-Hulayfah «وهو ما يسمى الآن بأبيار علي», ihram on an aeroplane),
/// and stays in al-Nawawi's school, so the guide's fiqh does not change under
/// the reader. It names none of the authors the owner keeps out. Al-Jaziri's
/// four schools stay under each step (`madhahib_section.dart`).
///
/// What this file holds is the ARRANGEMENT: where each step's text is in
/// that chapter (printed page + paragraph index, as the bundled file splits
/// it), which day it falls on, whether it belongs to Umrah as well as Hajj,
/// and which interactive illustration sits beside it. The book is arranged by
/// topic, not by day, so a step joins its ruling section to the matching
/// stretch of the chapter's own walk-through «كيف تحج؟» (pp. 180-188). No
/// passage is placed under a step it does not speak about, and no paragraph
/// of the chapter is left unreachable. A `toPara` of 99 means «to the end of
/// that page».
///
/// The illustrations only count what the text already says (seven circuits
/// from the Black Stone, seven passes beginning at الصفا, seven pebbles at
/// each of three جمرات in order); they add no ruling of their own.
library;

/// The interactive piece shown beside a step.
enum HajjRite { none, tawaf, sai, jamarat, journey, umrah }

/// Which pilgrimage a step belongs to.
enum HajjTrack { hajj, umrah }

class HajjTextRange {
  final int fromPage;
  final int fromPara;
  final int toPage;
  final int toPara;

  const HajjTextRange({
    required this.fromPage,
    required this.fromPara,
    required this.toPage,
    required this.toPara,
  });
}

class HajjStep {
  /// Translation key suffix: `hajj.step_<key>` is the step's title.
  final String key;

  /// Which days of ذو الحجة this falls on, as a translation key, or null when
  /// the step is not tied to a day (preparation, prohibitions, visitation).
  final String? dayKey;

  final int fromPage;
  final int fromPara;
  final int toPage;
  final int toPara;

  final HajjRite rite;

  /// Exact shared passages followed when the Umrah chapter says «كما سبق».
  /// They are kept as source ranges rather than rewritten summaries.
  final List<HajjTextRange> additionalRanges;

  /// Shared chapters retain their order; each track also has its own chapters.
  final Set<HajjTrack> tracks;

  const HajjStep({
    required this.key,
    required this.fromPage,
    required this.fromPara,
    required this.toPage,
    required this.toPara,
    this.dayKey,
    this.rite = HajjRite.none,
    this.additionalRanges = const [],
    this.tracks = const {HajjTrack.hajj},
  });

  List<HajjTextRange> get textRanges => [
    HajjTextRange(
      fromPage: fromPage,
      fromPara: fromPara,
      toPage: toPage,
      toPara: toPara,
    ),
    ...additionalRanges,
  ];

  String get pageCitation => textRanges
      .map(
        (range) => range.fromPage == range.toPage
            ? '${range.fromPage}'
            : '${range.fromPage}–${range.toPage}',
      )
      .join(', ');
}

/// The route of Hajj in the order the manual walks it (p263–378), as
/// translation keys. Mina appears twice because the pilgrim returns to it.
const journeyPlaces = <String>[
  'hajj.place_makkah',
  'hajj.place_mina',
  'hajj.place_arafat',
  'hajj.place_muzdalifah',
  'hajj.place_mina',
  'hajj.place_makkah',
];

/// The source book, by its Library id.
const hajjGuideBook = 'al_fiqh_al_manhaji_hajj';
const hajjGuideShamelaUrl = 'https://shamela.ws/book/6369';

/// الإفصاح, the modern commentary this printing carries under al-Nawawi's
/// text, and which is NOT his and not ours to show.
///
/// The first build dropped `div.hamesh` only. The real pages also use
/// `p.hamesh`, so 184 complete footnote paragraphs survived the earlier
/// cleanup. The source asset was rebuilt on 2026-09-21 from the stored raw
/// HTML with both forms removed: 1,454 paragraphs became 1,270.
///
/// These checks remain as defence for a previously downloaded flattened copy:
/// numbered note openings, continuation marks, known gloss openings and the
/// dot-only leaves left when a printed page contains apparatus but no matn.
bool isHajjGuideNote(String text) {
  if (_hajjNote.hasMatch(text)) return true;
  if (_hajjDots.hasMatch(text)) return true;
  final bare = text.replaceAll(_marks, '');
  return _hajjGloss.hasMatch(bare);
}

final _hajjNote = RegExp(r'^\s*(\(\s*[\d٠-٩]+\s*\)|=)');
final _hajjDots = RegExp(r'^[\s.·،]+$');
final _marks = RegExp('[ً-ْٰـ]');
final _hajjGloss = RegExp(
  r'^\s*أي\s|قال في الحاشية|قال المحشي|أقول\s*:|(^|\s)اه\s*\.|اه (حاشية|تعليق|تقريرات)|الحكومة السعودية',
);

const hajjSteps = <HajjStep>[
  HajjStep(
    key: 'preparation',
    fromPage: 180,
    fromPara: 0,
    toPage: 180,
    toPara: 5,
    additionalRanges: [
      HajjTextRange(fromPage: 118, fromPara: 0, toPage: 121, toPara: 99),
    ],
  ),
  HajjStep(
    key: 'obligation',
    fromPage: 111,
    fromPara: 0,
    toPage: 115,
    toPara: 99,
    additionalRanges: [
      HajjTextRange(fromPage: 122, fromPara: 0, toPage: 126, toPara: 99),
      // What the Hajj is made of: its obligations and its pillars.
      HajjTextRange(fromPage: 136, fromPara: 0, toPage: 136, toPara: 6),
      HajjTextRange(fromPage: 139, fromPara: 4, toPage: 139, toPara: 5),
    ],
  ),
  HajjStep(
    key: 'mawaqit',
    fromPage: 129,
    fromPara: 0,
    toPage: 131,
    toPara: 2,
    rite: HajjRite.journey,
  ),
  HajjStep(
    key: 'ihram',
    fromPage: 131,
    fromPara: 3,
    toPage: 132,
    toPara: 4,
    additionalRanges: [
      // «الإحرام من الميقات» as an obligation, and the ihram as a pillar.
      HajjTextRange(fromPage: 136, fromPara: 7, toPage: 137, toPara: 1),
      HajjTextRange(fromPage: 139, fromPara: 6, toPage: 139, toPara: 7),
      HajjTextRange(fromPage: 180, fromPara: 6, toPage: 181, toPara: 4),
      HajjTextRange(fromPage: 145, fromPara: 0, toPage: 146, toPara: 1),
    ],
  ),
  HajjStep(
    key: 'nusuk',
    fromPage: 132,
    fromPara: 5,
    toPage: 133,
    toPara: 2,
    additionalRanges: [
      HajjTextRange(fromPage: 167, fromPara: 0, toPage: 171, toPara: 99),
    ],
  ),
  HajjStep(
    key: 'prohibitions',
    fromPage: 133,
    fromPara: 3,
    toPage: 135,
    toPara: 99,
  ),
  HajjStep(
    key: 'tawaf',
    fromPage: 140,
    fromPara: 5,
    toPage: 141,
    toPara: 4,
    rite: HajjRite.tawaf,
    additionalRanges: [
      HajjTextRange(fromPage: 146, fromPara: 2, toPage: 149, toPara: 0),
      HajjTextRange(fromPage: 181, fromPara: 5, toPage: 183, toPara: 9),
    ],
  ),
  HajjStep(
    key: 'sai',
    fromPage: 141,
    fromPara: 5,
    toPage: 142,
    toPara: 5,
    rite: HajjRite.sai,
    additionalRanges: [
      HajjTextRange(fromPage: 149, fromPara: 1, toPage: 149, toPara: 4),
      HajjTextRange(fromPage: 183, fromPara: 10, toPage: 184, toPara: 8),
    ],
  ),
  HajjStep(
    key: 'tarwiyah',
    fromPage: 149,
    fromPara: 5,
    toPage: 150,
    toPara: 1,
    dayKey: 'hajj.day_8',
    rite: HajjRite.journey,
    additionalRanges: [
      HajjTextRange(fromPage: 184, fromPara: 9, toPage: 184, toPara: 9),
    ],
  ),
  HajjStep(
    key: 'arafah',
    fromPage: 140,
    fromPara: 0,
    toPage: 140,
    toPara: 4,
    dayKey: 'hajj.day_9',
    rite: HajjRite.journey,
    additionalRanges: [
      HajjTextRange(fromPage: 150, fromPara: 2, toPage: 150, toPara: 2),
      HajjTextRange(fromPage: 184, fromPara: 10, toPage: 185, toPara: 3),
    ],
  ),
  HajjStep(
    key: 'muzdalifah',
    fromPage: 137,
    fromPara: 2,
    toPage: 137,
    toPara: 3,
    dayKey: 'hajj.night_10',
    rite: HajjRite.journey,
    additionalRanges: [
      HajjTextRange(fromPage: 150, fromPara: 3, toPage: 151, toPara: 1),
      HajjTextRange(fromPage: 185, fromPara: 4, toPage: 186, toPara: 1),
    ],
  ),
  HajjStep(
    key: 'nahr',
    fromPage: 137,
    fromPara: 4,
    toPage: 138,
    toPara: 0,
    dayKey: 'hajj.day_10',
    rite: HajjRite.jamarat,
    additionalRanges: [
      HajjTextRange(fromPage: 142, fromPara: 6, toPage: 143, toPara: 8),
      HajjTextRange(fromPage: 151, fromPara: 2, toPage: 151, toPara: 6),
      HajjTextRange(fromPage: 153, fromPara: 0, toPage: 153, toPara: 99),
      // «كيف تحج؟» on the day of sacrifice, around its sacrifice paragraphs
      // (p.186:6-187:0), which are «الهدي»'s.
      HajjTextRange(fromPage: 186, fromPara: 2, toPage: 186, toPara: 5),
      HajjTextRange(fromPage: 187, fromPara: 1, toPage: 187, toPara: 4),
    ],
  ),
  HajjStep(
    key: 'hady',
    fromPage: 186,
    fromPara: 6,
    toPage: 187,
    toPara: 0,
    additionalRanges: [
      HajjTextRange(fromPage: 160, fromPara: 0, toPage: 166, toPara: 99),
    ],
  ),
  HajjStep(
    key: 'tashreeq',
    fromPage: 138,
    fromPara: 1,
    toPage: 138,
    toPara: 99,
    dayKey: 'hajj.days_11_13',
    rite: HajjRite.jamarat,
    additionalRanges: [
      HajjTextRange(fromPage: 151, fromPara: 7, toPage: 152, toPara: 99),
      HajjTextRange(fromPage: 187, fromPara: 5, toPage: 187, toPara: 9),
    ],
  ),
  HajjStep(
    key: 'farewell',
    fromPage: 139,
    fromPara: 0,
    toPage: 139,
    toPara: 3,
    rite: HajjRite.tawaf,
    additionalRanges: [
      HajjTextRange(fromPage: 188, fromPara: 0, toPage: 188, toPara: 99),
    ],
  ),
  HajjStep(
    key: 'visitation',
    fromPage: 172,
    fromPara: 0,
    toPage: 174,
    toPara: 99,
  ),
  HajjStep(
    key: 'child',
    fromPage: 127,
    fromPara: 0,
    toPage: 128,
    toPara: 99,
    additionalRanges: [
      HajjTextRange(fromPage: 179, fromPara: 3, toPage: 179, toPara: 3),
    ],
  ),
  HajjStep(
    key: 'counsel',
    fromPage: 154,
    fromPara: 0,
    toPage: 159,
    toPara: 99,
    additionalRanges: [
      HajjTextRange(fromPage: 175, fromPara: 0, toPage: 179, toPara: 2),
    ],
  ),
  // Umrah: the chapter «ثانياً: أعمال العمرة» (p.143-144) and the shared
  // passages it rests on, followed by the Umrah path of «كيف تحج؟».
  HajjStep(
    key: 'umrah_obligation',
    fromPage: 116,
    fromPara: 0,
    toPage: 117,
    toPara: 99,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_miqaat',
    fromPage: 129,
    fromPara: 2,
    toPage: 131,
    toPara: 2,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_ihram',
    fromPage: 131,
    fromPara: 3,
    toPage: 133,
    toPara: 2,
    additionalRanges: [
      HajjTextRange(fromPage: 180, fromPara: 6, toPage: 181, toPara: 4),
    ],
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_prohibitions',
    fromPage: 133,
    fromPara: 3,
    toPage: 135,
    toPara: 99,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_rites',
    fromPage: 143,
    fromPara: 9,
    toPage: 144,
    toPara: 99,
    rite: HajjRite.umrah,
    additionalRanges: [
      HajjTextRange(fromPage: 181, fromPara: 5, toPage: 184, toPara: 7),
    ],
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_invalidating',
    fromPage: 162,
    fromPara: 5,
    toPage: 163,
    toPara: 2,
    tracks: {HajjTrack.umrah},
  ),
];

/// The steps one track shows, in reading order.
///
/// The step catalogues are disjoint; shared source passages are attached only
/// where al-Nawawi's Umrah chapter explicitly sends the reader back to them.
List<HajjStep> hajjStepsFor(HajjTrack track) =>
    hajjSteps.where((s) => s.tracks.contains(track)).toList();
