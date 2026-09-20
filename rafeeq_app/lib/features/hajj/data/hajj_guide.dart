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
enum HajjRite { none, tawaf, sai, jamarat, journey }

/// Which pilgrimage a step belongs to.
enum HajjTrack { hajj, umrah }

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
    this.tracks = const {HajjTrack.hajj},
  });
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
/// Shamela puts most of it in `div.hamesh`, which the build already drops —
/// but not all of it: 472 of the 1,576 paragraphs from p.45 on are apparatus
/// that arrived in the ordinary body flow, thirty per cent of the book.
/// They are recognisable the way the Musnad's were (trap #34): a paragraph
/// that opens on a bracketed note number, or on the «=» that continues one
/// from the page before.
///
/// And a second family, found 2026-09-19 (155 more paragraphs between
/// printed pages 45 and 522, shown as an-Nawawi's text until then): the
/// commentary that carries no note number but always one of its OWN marks -
/// a gloss that opens «أي …», «قال في الحاشية», «قال المحشي», the annotator's
/// «أقول:», and «اه» closing a quotation. an-Nawawi uses none of these; the
/// annotator writes «زماننا آخر القرن الرابع عشر» and dates a door of the
/// Ka'ba to King Khalid. Matched on a diacritic-free copy (trap #34), the
/// text itself untouched.
bool isHajjGuideNote(String text) {
  if (_hajjNote.hasMatch(text)) return true;
  final bare = text.replaceAll(_marks, '');
  return _hajjGloss.hasMatch(bare);
}

final _hajjNote = RegExp(r'^\s*(\(\s*[\d٠-٩]+\s*\)|=)');
final _marks = RegExp('[ً-ْٰـ]');
final _hajjGloss = RegExp(
    r'^\s*أي\s|قال في الحاشية|قال المحشي|أقول\s*:|(^|\s)اه\s*\.|اه (حاشية|تعليق|تقريرات)|الحكومة السعودية');

const _both = {HajjTrack.hajj, HajjTrack.umrah};

const hajjSteps = <HajjStep>[
  HajjStep(
      key: 'preparation', fromPage: 45, fromPara: 0, toPage: 92, toPara: 0,
      tracks: _both),
  HajjStep(
      key: 'obligation', fromPage: 92, fromPara: 1, toPage: 112, toPara: 0),
  HajjStep(
      key: 'mawaqit', fromPage: 113, fromPara: 0, toPage: 123, toPara: 1,
      rite: HajjRite.journey, tracks: _both),
  HajjStep(
      key: 'ihram', fromPage: 124, fromPara: 0, toPage: 131, toPara: 0,
      tracks: _both),
  HajjStep(
      key: 'nusuk', fromPage: 132, fromPara: 0, toPage: 145, toPara: 0,
      tracks: _both),
  HajjStep(
      key: 'prohibitions', fromPage: 146, fromPara: 0, toPage: 191, toPara: 1,
      tracks: _both),
  HajjStep(
      key: 'tawaf', fromPage: 192, fromPara: 0, toPage: 250, toPara: 0,
      rite: HajjRite.tawaf, tracks: _both),
  HajjStep(
      key: 'sai', fromPage: 251, fromPara: 0, toPage: 262, toPara: 0,
      rite: HajjRite.sai, tracks: _both),
  HajjStep(
      key: 'tarwiyah', fromPage: 263, fromPara: 0, toPage: 269, toPara: 1,
      dayKey: 'hajj.day_8', rite: HajjRite.journey),
  HajjStep(
      key: 'arafah', fromPage: 270, fromPara: 0, toPage: 294, toPara: 3,
      dayKey: 'hajj.day_9', rite: HajjRite.journey),
  HajjStep(
      key: 'muzdalifah', fromPage: 295, fromPara: 0, toPage: 308, toPara: 0,
      dayKey: 'hajj.night_10', rite: HajjRite.journey),
  HajjStep(
      key: 'nahr', fromPage: 309, fromPara: 0, toPage: 329, toPara: 2,
      dayKey: 'hajj.day_10', rite: HajjRite.jamarat),
  HajjStep(
      key: 'hady', fromPage: 330, fromPara: 0, toPage: 356, toPara: 2),
  HajjStep(
      key: 'tashreeq', fromPage: 357, fromPara: 0, toPage: 377, toPara: 2,
      dayKey: 'hajj.days_11_13', rite: HajjRite.jamarat),
  HajjStep(
      key: 'umrah', fromPage: 378, fromPara: 0, toPage: 387, toPara: 1,
      tracks: {HajjTrack.umrah}),
  HajjStep(
      key: 'farewell', fromPage: 388, fromPara: 0, toPage: 445, toPara: 2,
      rite: HajjRite.tawaf),
  HajjStep(
      key: 'visitation', fromPage: 446, fromPara: 0, toPage: 468, toPara: 1,
      tracks: _both),
  HajjStep(
      key: 'child', fromPage: 505, fromPara: 0, toPage: 512, toPara: 0),
  HajjStep(
      key: 'counsel', fromPage: 513, fromPara: 0, toPage: 522, toPara: 0,
      tracks: _both),
];

/// The steps one track shows, in reading order.
///
/// «العمرة فاضية مش فيها معلومات تخصها»: the Umrah track opened on the
/// same general chapters as the Hajj one (preparation, mawaqit, ihram…) and
/// reached an-Nawawi's own «الباب الرابع في العمرة» - its obligation, its
/// times, «وأركان العمرة أربعة» - only near the end. For Umrah that chapter
/// now comes first; the shared chapters follow as the detail behind it.
List<HajjStep> hajjStepsFor(HajjTrack track) {
  final steps = hajjSteps.where((s) => s.tracks.contains(track)).toList();
  if (track == HajjTrack.umrah) {
    final i = steps.indexWhere((s) => s.key == 'umrah');
    if (i > 0) steps.insert(0, steps.removeAt(i));
  }
  return steps;
}
