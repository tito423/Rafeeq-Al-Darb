/// مناسك الحج والعمرة, step by step.
///
/// WHAT IS MINE HERE AND WHAT IS NOT.
/// The rulings of Hajj are not mine to write, so none are written here. Every
/// step's text is read, verbatim, from «الإيضاح في مناسك الحج والعمرة»
/// للإمام النووي (ت ٦٧٦هـ) — the classical pilgrim's manual, in the Library
/// as `al_idah_fi_manasik_al_hajj_wal_umrah`, built from Shamela 96232.
///
/// IT USED TO READ التحقيق والإيضاح للشيخ ابن باز, and that is why it
/// changed: «اي كتاب له حقوق ملكية احذفه واستبدل بدل منه المنقول عنه». A
/// screen that prints a living-memory scholar's book page by page is
/// reproducing it, whatever the citation under it says. النووي died in 1277,
/// and his manual is the book Ibn Baz's own was written in the tradition of.
///
/// What this file holds is the ARRANGEMENT, exactly as the Tajweed course
/// does: where each step starts and ends in that book, which day it falls on,
/// whether it belongs to Umrah as well as Hajj, and which interactive
/// illustration sits beside it. The illustrations only count what the text
/// already says (seven circuits starting from the Black Stone, seven passes
/// beginning at الصفا, seven pebbles at each of three جمرات in order); they add
/// no ruling of their own.
///
/// THE BOUNDARIES are this printing's own chapter openings, read page by page
/// off the built text (`scripts/_idah_bounds.txt`): الباب الأول opens p.45,
/// الميقات p.113, الطواف p.206, السعي p.251, عرفات p.263, المزدلفة p.295,
/// يوم النحر p.309, أيام التشريق p.357. Nothing starts before p.45: the
/// pages under it are the modern edition's own front matter.
///
/// مسجد قباء HAD A STEP AND NO LONGER DOES. It was a heading in Ibn Baz's
/// manual; al-Nawawi's باب الزيارة does not set one, and a card pointing at a
/// section of a book that has none is §1.1's first rule broken.
library;

/// THE BOUNDARIES WERE RE-POINTED ON 2026-09-17, and the reason matters.
///
/// The only printing of «الإيضاح» that Shamela has carries a SECOND author's
/// whole book alongside it — «الإفصاح على مسائل الإيضاح» by عبد الفتاح حسين
/// رواه المكي, who is not a classical author. The edition card says so
/// plainly, with «وعليه:», and nobody had read it.
///
/// Measured before anything was changed: of the 1,474 paragraphs these
/// nineteen steps render, **280 (19.0%) were his, not an-Nawawi's** — under a
/// caption that says «النص من كتاب الإيضاح … للإمام النووي». That is §1.2
/// broken regardless of the rights question: the screen attributed one man's
/// words to another.
///
/// So the hosted file was filtered, and because `hajj_screen.dart` slices by
/// paragraph INDEX inside a page, filtering renumbered everything the guide
/// pointed at. `scripts/remap_hajj_bounds.py` re-pointed each boundary **by
/// its own text**, not by arithmetic: it reads the anchor paragraph from the
/// unfiltered file and finds it again in the filtered one.
///
/// Twelve of the nineteen steps turned out to END on one of his notes. Each
/// of those snaps INWARDS by one — never outwards, which would put him back.
/// No `from` boundary moved: every step began on an-Nawawi and only ever ran
/// past the end.

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
const hajjGuideBook = 'al_idah_fi_manasik_al_hajj_wal_umrah';
const hajjGuideShamelaUrl = 'https://shamela.ws/book/96232';

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
    fromPage: 45,
    fromPara: 0,
    toPage: 92,
    toPara: 0,
  ),
  HajjStep(
    key: 'obligation',
    fromPage: 92,
    fromPara: 1,
    toPage: 112,
    toPara: 0,
  ),
  HajjStep(
    key: 'mawaqit',
    fromPage: 113,
    fromPara: 0,
    toPage: 123,
    toPara: 0,
    rite: HajjRite.journey,
  ),
  HajjStep(key: 'ihram', fromPage: 124, fromPara: 0, toPage: 131, toPara: 0),
  HajjStep(key: 'nusuk', fromPage: 132, fromPara: 0, toPage: 145, toPara: 0),
  HajjStep(
    key: 'prohibitions',
    fromPage: 146,
    fromPara: 0,
    toPage: 191,
    toPara: 1,
  ),
  HajjStep(
    key: 'tawaf',
    fromPage: 192,
    fromPara: 0,
    toPage: 250,
    toPara: 0,
    rite: HajjRite.tawaf,
  ),
  HajjStep(
    key: 'sai',
    fromPage: 251,
    fromPara: 0,
    toPage: 262,
    toPara: 0,
    rite: HajjRite.sai,
  ),
  HajjStep(
    key: 'tarwiyah',
    fromPage: 263,
    fromPara: 0,
    toPage: 269,
    toPara: 0,
    dayKey: 'hajj.day_8',
    rite: HajjRite.journey,
  ),
  HajjStep(
    key: 'arafah',
    fromPage: 270,
    fromPara: 0,
    toPage: 294,
    toPara: 2,
    dayKey: 'hajj.day_9',
    rite: HajjRite.journey,
  ),
  HajjStep(
    key: 'muzdalifah',
    fromPage: 295,
    fromPara: 0,
    toPage: 308,
    toPara: 0,
    dayKey: 'hajj.night_10',
    rite: HajjRite.journey,
  ),
  HajjStep(
    key: 'nahr',
    fromPage: 309,
    fromPara: 0,
    toPage: 329,
    toPara: 1,
    dayKey: 'hajj.day_10',
    rite: HajjRite.jamarat,
  ),
  HajjStep(key: 'hady', fromPage: 330, fromPara: 0, toPage: 356, toPara: 1),
  HajjStep(
    key: 'tashreeq',
    fromPage: 357,
    fromPara: 0,
    toPage: 377,
    toPara: 2,
    dayKey: 'hajj.days_11_13',
    rite: HajjRite.jamarat,
  ),
  HajjStep(
    key: 'farewell',
    fromPage: 388,
    fromPara: 0,
    toPage: 445,
    toPara: 1,
    rite: HajjRite.tawaf,
  ),
  HajjStep(
    key: 'visitation',
    fromPage: 446,
    fromPara: 0,
    toPage: 468,
    toPara: 1,
  ),
  HajjStep(key: 'child', fromPage: 505, fromPara: 0, toPage: 512, toPara: 0),
  HajjStep(key: 'counsel', fromPage: 513, fromPara: 0, toPage: 522, toPara: 0),
  // The Umrah chapter repeatedly says «كما سبق» instead of repeating the
  // procedure. Each such reference is followed to the exact shared passage;
  // chapters that concern Hajj alone remain outside the Umrah track.
  HajjStep(
    key: 'umrah_obligation',
    fromPage: 378,
    fromPara: 2,
    toPage: 380,
    toPara: 0,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_miqaat',
    fromPage: 383,
    fromPara: 0,
    toPage: 384,
    toPara: 1,
    additionalRanges: [
      HajjTextRange(fromPage: 115, fromPara: 1, toPage: 123, toPara: 0),
    ],
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_ihram',
    fromPage: 385,
    fromPara: 1,
    toPage: 386,
    toPara: 0,
    additionalRanges: [
      HajjTextRange(fromPage: 124, fromPara: 0, toPage: 124, toPara: 3),
      HajjTextRange(fromPage: 126, fromPara: 1, toPage: 130, toPara: 1),
      HajjTextRange(fromPage: 142, fromPara: 0, toPage: 143, toPara: 1),
      HajjTextRange(fromPage: 144, fromPara: 2, toPage: 145, toPara: 0),
    ],
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_prohibitions',
    fromPage: 146,
    fromPara: 0,
    toPage: 191,
    toPara: 1,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_rites',
    fromPage: 386,
    fromPara: 1,
    toPage: 387,
    toPara: 0,
    additionalRanges: [
      HajjTextRange(fromPage: 206, fromPara: 1, toPage: 247, toPara: 0),
      HajjTextRange(fromPage: 251, fromPara: 0, toPage: 262, toPara: 0),
    ],
    rite: HajjRite.umrah,
    tracks: {HajjTrack.umrah},
  ),
  HajjStep(
    key: 'umrah_invalidating',
    fromPage: 387,
    fromPara: 1,
    toPage: 387,
    toPara: 1,
    tracks: {HajjTrack.umrah},
  ),
];

/// The steps one track shows, in reading order.
///
/// The step catalogues are disjoint; shared source passages are attached only
/// where al-Nawawi's Umrah chapter explicitly sends the reader back to them.
List<HajjStep> hajjStepsFor(HajjTrack track) =>
    hajjSteps.where((s) => s.tracks.contains(track)).toList();
