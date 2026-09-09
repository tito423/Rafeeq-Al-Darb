import '../../../core/config/app_config.dart';

/// One run of verses recited as ruqyah, addressed by surah and ayah range.
///
/// Deliberately **no text here.** The words are read at runtime from
/// `quran_local.db` through `QuranRepository.ayahRange`, which is the same
/// text the mushaf renders. A ruqyah screen that carried its own copy of the
/// verses would be a second, drifting copy of the Qur'an inside the app — and
/// the one thing this project will not do is keep scripture in two places.
class RuqyahPassage {
  final int surah;
  final int from;
  final int to;

  const RuqyahPassage(this.surah, this.from, [int? to]) : to = to ?? from;

  bool get isWholeSurah => false;
}

/// A named group of passages, with an honest note about *why* it is in the
/// ruqyah.
class RuqyahGroup {
  final String titleKey;

  /// What establishes this group. Group 1 is what the Prophet ﷺ is reported to
  /// have recited as ruqyah; the others are verses long recited for the
  /// purpose without that being a prophetic prescription. The screen shows
  /// this, so the reader is never left to assume the whole list carries the
  /// same weight — see the note in `ruqyah_screen.dart`.
  final String noteKey;

  final List<RuqyahPassage> passages;

  const RuqyahGroup({
    required this.titleKey,
    required this.noteKey,
    required this.passages,
  });
}

/// The ruqyah, in three honestly-separated groups.
///
/// The separation is the point. Lumping «آية الكرسي» — which Bukhari reports
/// the Prophet ﷺ naming as protection — together with the verses about Musa
/// and the magicians, which are recited by long practice rather than by a
/// narration commanding it, would tell the reader something untrue about the
/// second set. So they are three groups with three different notes, not one
/// undifferentiated list.
const ruqyahGroups = <RuqyahGroup>[
  // ── 1. What is established in the Sunnah as ruqyah ──────────────────────
  RuqyahGroup(
    titleKey: 'ruqyah.group_sunnah',
    noteKey: 'ruqyah.group_sunnah_note',
    passages: [
      RuqyahPassage(1, 1, 7), // الفاتحة
      RuqyahPassage(2, 255), // آية الكرسي
      RuqyahPassage(2, 285, 286), // خواتيم البقرة
      RuqyahPassage(112, 1, 4), // الإخلاص
      RuqyahPassage(113, 1, 5), // الفلق
      RuqyahPassage(114, 1, 6), // الناس
    ],
  ),

  // ── 2. The passages recited against sihr ────────────────────────────────
  RuqyahGroup(
    titleKey: 'ruqyah.group_sihr',
    noteKey: 'ruqyah.group_sihr_note',
    passages: [
      RuqyahPassage(2, 102),
      RuqyahPassage(7, 117, 122),
      RuqyahPassage(10, 79, 82),
      RuqyahPassage(20, 65, 69),
    ],
  ),

  // ── 3. The wider set in common use ──────────────────────────────────────
  RuqyahGroup(
    titleKey: 'ruqyah.group_general',
    noteKey: 'ruqyah.group_general_note',
    passages: [
      RuqyahPassage(2, 1, 5),
      RuqyahPassage(2, 163, 164),
      RuqyahPassage(3, 18, 19),
      RuqyahPassage(7, 54, 56),
      RuqyahPassage(23, 115, 118),
      RuqyahPassage(37, 1, 10),
      RuqyahPassage(46, 29, 32),
      RuqyahPassage(55, 33, 36),
      RuqyahPassage(59, 21, 24),
      RuqyahPassage(72, 1, 9),
    ],
  ),
];

/// The prophetic supplications of ruqyah, addressed by their **row id in the
/// bundled azkar database** — again, no text here.
///
/// These six are the ones that are actually in `azkar_items`; they were found
/// by searching the real table, not assumed from a list of what "should" be
/// there. Two duas often printed with the ruqyah («بِسْمِ اللَّهِ أَرْقِيكَ»,
/// «أَذْهِبِ الْبَاسَ رَبَّ النَّاسِ») are **not** in this edition of Ḥiṣn
/// al-Muslim and are therefore not shown — an absent dua is an honest gap; a
/// dua typed in from memory with no takhrij behind it is not.
///
/// Each row carries its own footnote (البخاري، مسلم، أبو داود…), which the
/// screen renders as-is.
const ruqyahDuaItemIds = <int>[
  176, // لا بأس طهور إن شاء الله — البخاري
  177, // أسأل الله العظيم رب العرش العظيم أن يشفيك (سبع مرات) — الترمذي وأبو داود
  274, // بسم الله (ثلاثاً) … أعوذ بالله وقدرته من شر ما أجد وأحاذر — مسلم
  247, // أعوذ بكلمات الله التامات من شر ما خلق — مسلم
  278, // أعوذ بكلمات الله التامات التي لا يجاوزهن بر ولا فاجر… — أحمد بإسناد صحيح
  137, // أعوذ بكلمات الله التامة من غضبه وعقابه… — أبو داود
];

/// One full recorded ruqyah.
class RuqyahRecording {
  final String id;

  /// The reciter, where the source names one. Empty when it does not —
  /// see [titleAr]. An unnamed reciter is written down as unnamed; ten adhan
  /// clips were once attributed to muezzins nobody had verified, and that is
  /// the mistake this field's emptiness is protecting against.
  final String reciterAr;
  final String reciterEn;

  /// Shown as the card's heading when there is no named reciter. Normally
  /// empty, and the reciter's name is the heading instead.
  final String titleAr;
  final String titleEn;

  /// File extension of the mirrored object. The archive.org set are `mp3`;
  /// the owner's own file is `m4a` and is mirrored as-is rather than
  /// re-encoded, because transcoding one lossy format to another only loses
  /// quality for no gain.
  final String ext;

  /// Runtime in seconds, taken from the source item's own metadata — not
  /// estimated, and shown to the reader so a 75-minute recitation is not a
  /// surprise on a phone plan.
  final int seconds;

  /// Exact byte size of the file that was mirrored, so the download tile can
  /// state the real cost. Measured, never rounded from a guess — the library
  /// once shipped every book claiming «1.0 MB» because a widget had the string
  /// written into it.
  final int bytes;

  /// The archive.org item this was taken from, kept so provenance survives in
  /// the code and on the Sources screen rather than only in a commit message.
  final String archiveId;

  const RuqyahRecording({
    required this.id,
    required this.seconds,
    required this.bytes,
    this.reciterAr = '',
    this.reciterEn = '',
    this.titleAr = '',
    this.titleEn = '',
    this.ext = 'mp3',
    this.archiveId = '',
  });

  /// What the card leads with: the reciter when the source names one, the
  /// recording's own title when it does not.
  String headingAr() => reciterAr.isNotEmpty ? reciterAr : titleAr;
  String headingEn() => reciterEn.isNotEmpty ? reciterEn : titleEn;

  /// True when the source does not name a reciter, so the card can say so
  /// rather than leaving a blank line where a name would be.
  bool get reciterUnknown => reciterAr.isEmpty;

  /// Mirrored onto the project's own bucket rather than linked straight at
  /// archive.org: an archive.org item can be replaced or removed by whoever
  /// uploaded it, and a core feature should not go dark when that happens.
  String get url => '${AppConfig.contentBaseUrl}/ruqyah/$id.$ext';

  /// Empty for a recording the owner supplied himself — there is no public
  /// page to link to, and inventing one would be worse than showing none.
  String get sourceUrl =>
      archiveId.isEmpty ? '' : 'https://archive.org/details/$archiveId';

  String get downloadId => 'ruqyah_$id';

  String get fileName => 'ruqyah_$id.$ext';
}

/// Five recorded ruqyahs by five well-known reciters.
///
/// Every one was verified before it was listed here: the archive.org item's
/// metadata was read for the real byte size and duration, and a range request
/// against the real file answered **206 `audio/mpeg`** on 2026-09-09. Nothing
/// goes in this list that has not answered on the wire.
const ruqyahRecordings = <RuqyahRecording>[
  RuqyahRecording(
    id: 'afasy',
    reciterAr: 'مشاري راشد العفاسي',
    reciterEn: 'Mishary Rashid Alafasy',
    seconds: 1511,
    bytes: 60462176,
    archiveId: 'QuranicRuqya1WWW.QRRC.ORGCopy',
  ),
  RuqyahRecording(
    id: 'ajami',
    reciterAr: 'أحمد بن علي العجمي',
    reciterEn: "Ahmad Al-'Ajami",
    seconds: 3760,
    bytes: 90244212,
    archiveId: 'ruqyah-shariah-ahmad-al-ajami',
  ),
  RuqyahRecording(
    id: 'abkar',
    reciterAr: 'إدريس أبكر',
    reciterEn: 'Idris Abkar',
    seconds: 4518,
    bytes: 108436721,
    archiveId: 'ruqyah-shariah-idris-abkar',
  ),
  RuqyahRecording(
    id: 'muaiqly',
    reciterAr: 'ماهر المعيقلي',
    reciterEn: 'Maher Al-Muaiqly',
    seconds: 2280,
    bytes: 54721861,
    archiveId: 'ruqyah-shariah-maher-al-muaiqly',
  ),
  RuqyahRecording(
    id: 'sudais',
    reciterAr: 'عبد الرحمن السديس',
    reciterEn: 'Abdul Rahman Al-Sudais',
    seconds: 2598,
    bytes: 41576448,
    archiveId: '1.-ar-ruqyah-abdul-rahman-sudais',
  ),
  // Supplied by the owner from his own library. Its embedded title tag reads
  // «ضع سماعة الرأس وأسترخي ( رقية شرعية )»; the file names no reciter, so
  // none is claimed — the card says the reciter is not named in the source.
  // Length and size measured from the file itself with ffprobe.
  RuqyahRecording(
    id: 'tarteel_hadi',
    titleAr: 'رقية شرعية — بسماعة الرأس',
    titleEn: 'Ruqyah — for headphones',
    seconds: 2394,
    bytes: 38858921,
    ext: 'm4a',
  ),
];

/// Credited on the Sources screen, and shown at the foot of the audio list.
const ruqyahAudioSourceLabel =
    'التسجيلات من أرشيف الإنترنت (archive.org)، مرآة على خادم التطبيق';
