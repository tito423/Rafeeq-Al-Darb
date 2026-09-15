/// «مناسك الحج والعمرة» — the guide's shape.
///
/// WHAT IS MINE HERE AND WHAT IS NOT.
/// The rulings of Hajj are not mine to write, so none are written here. Every
/// step's text is read, verbatim, from «التحقيق والإيضاح لكثير من مسائل الحج
/// والعمرة والزيارة على ضوء الكتاب والسنة» by الشيخ عبد العزيز بن باز — a short
/// manual written for pilgrims, published by the Saudi Ministry of Islamic
/// Affairs (22nd printing, 1425هـ), with its evidence cited inline. It is in
/// the Library as `ibn_baz_tahqiq_wal_idah`, built from Shamela 31235.
///
/// What this file holds is the ARRANGEMENT, exactly as the Tajweed course
/// does: where each step starts and ends in that book, which day it falls on,
/// whether it belongs to Umrah as well as Hajj, and which interactive
/// illustration sits beside it. The illustrations only count what the text
/// already says (seven circuits starting from the Black Stone, seven passes
/// beginning at الصفا, seven pebbles at each of three جمرات in order); they add
/// no ruling of their own.
///
/// THE BOUNDARIES were read off the parsed book paragraph by paragraph
/// (`scripts/book_text_build/ibn_baz_tahqiq_wal_idah.para_index.txt`), not
/// off the raw crawl and not guessed from page numbers: «عرفة» ends mid-page
/// 61 where the text says «فإذا غربت انصرفوا إلى مزدلفة», and the heading of
/// the Makkah chapter arrives as a body paragraph (p39:3) because Shamela sets
/// it inline.
library;

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

  /// Umrah steps are a subset of the Hajj steps, in the same order.
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

/// The source book, by its Library id.
const hajjGuideBook = 'ibn_baz_tahqiq_wal_idah';
const hajjGuideShamelaUrl = 'https://shamela.ws/book/31235';

const _both = {HajjTrack.hajj, HajjTrack.umrah};

const hajjSteps = <HajjStep>[
  HajjStep(
      key: 'obligation', fromPage: 6, fromPara: 2, toPage: 9, toPara: 3),
  HajjStep(
      key: 'preparation', fromPage: 10, fromPara: 0, toPage: 14, toPara: 2,
      tracks: _both),
  HajjStep(
      key: 'ihram', fromPage: 15, fromPara: 0, toPage: 20, toPara: 1,
      tracks: _both),
  HajjStep(
      key: 'mawaqit', fromPage: 20, fromPara: 2, toPage: 26, toPara: 0,
      rite: HajjRite.journey, tracks: _both),
  HajjStep(
      key: 'nusuk', fromPage: 26, fromPara: 1, toPage: 29, toPara: 2,
      tracks: _both),
  HajjStep(
      key: 'prohibitions', fromPage: 32, fromPara: 2, toPage: 39, toPara: 2,
      tracks: _both),
  HajjStep(
      key: 'tawaf', fromPage: 39, fromPara: 3, toPage: 45, toPara: 2,
      rite: HajjRite.tawaf, tracks: _both),
  HajjStep(
      key: 'sai', fromPage: 45, fromPara: 3, toPage: 50, toPara: 0,
      rite: HajjRite.sai, tracks: _both),
  HajjStep(
      key: 'tarwiyah', fromPage: 50, fromPara: 1, toPage: 51, toPara: 2,
      dayKey: 'hajj.day_8', rite: HajjRite.journey),
  HajjStep(
      key: 'arafah', fromPage: 52, fromPara: 0, toPage: 61, toPara: 0,
      dayKey: 'hajj.day_9', rite: HajjRite.journey),
  HajjStep(
      key: 'muzdalifah', fromPage: 61, fromPara: 1, toPage: 63, toPara: 1,
      dayKey: 'hajj.night_10', rite: HajjRite.journey),
  HajjStep(
      key: 'nahr', fromPage: 63, fromPara: 2, toPage: 71, toPara: 1,
      dayKey: 'hajj.day_10', rite: HajjRite.jamarat),
  HajjStep(
      key: 'tashreeq', fromPage: 71, fromPara: 2, toPage: 75, toPara: 0,
      dayKey: 'hajj.days_11_13', rite: HajjRite.jamarat),
  HajjStep(
      key: 'hady', fromPage: 75, fromPara: 1, toPage: 78, toPara: 0),
  HajjStep(
      key: 'counsel', fromPage: 78, fromPara: 1, toPage: 86, toPara: 1,
      tracks: _both),
  HajjStep(
      key: 'farewell', fromPage: 86, fromPara: 2, toPage: 87, toPara: 3,
      rite: HajjRite.tawaf),
  HajjStep(
      key: 'child', fromPage: 29, fromPara: 3, toPage: 32, toPara: 1,
      tracks: _both),
  HajjStep(
      key: 'visitation', fromPage: 88, fromPara: 0, toPage: 105, toPara: 0,
      tracks: _both),
  HajjStep(
      key: 'quba', fromPage: 105, fromPara: 1, toPage: 107, toPara: 3,
      tracks: _both),
];
