import '../../../core/utils/quran_search_match.dart';

/// Topics of the Qur'an, each with two things:
///
///  * **refs** — a small curated set of the verses most often cited for the
///    topic, shown first as «آيات مختارة». Every reference is real and
///    verifiable against the bundled `quran_local.db`.
///  * **pattern** — the words that carry the topic, searched over the whole
///    mushaf, so the topic lists every verse that speaks of it in those words.
///
/// The second half is new. The owner searched «الصبر» and got about ten
/// verses — the curated set was all the topic had — and said «مش عايز خيار
/// يكون موجود ومش شغال فعليًا». The Qur'an mentions patience in ninety.
///
/// Every pattern below was run over the real corpus before it was written here
/// (`scratchpad/measure_topics2.py`), and every distinct word it matched was
/// read. The false friends that turned up are excluded by name: «والدم»
/// (and the blood) under parents, «المنافقين» (loosely «المنفقين») under
/// charity, «الصدقات» under honesty, «العالمين» and «الأعلام» under
/// knowledge, «نوحي» (We reveal) under Nuh, «أجنّة» (embryos) under
/// paradise. What a pattern cannot tell apart it does not pretend to: this is
/// a search by the topic's words, and it is labelled as that on screen.
class TopicRef {
  final int surah;
  final int fromAyah;
  final int toAyah;
  const TopicRef(this.surah, this.fromAyah, [int? toAyah])
      : toAyah = toAyah ?? fromAyah;
}

class Topic {
  /// Translation key under `search.*`, e.g. `search.patience`.
  final String labelKey;
  final List<TopicRef> refs;
  final TopicPattern pattern;
  const Topic(this.labelKey, this.refs, this.pattern);
}

class TopicCategory {
  /// Translation key under `search.*`, e.g. `search.cat_akhlaq`.
  final String labelKey;
  final List<Topic> topics;
  const TopicCategory(this.labelKey, this.topics);
}

const List<TopicCategory> topicTree = [
  TopicCategory('search.cat_aqeedah', [
    Topic(
      'search.tawheed',
      [
        TopicRef(112, 1, 4), // Al-Ikhlas
        TopicRef(2, 255), // Ayat al-Kursi
        TopicRef(6, 102),
      ],
      // «لا إله إلا» and «إله واحد» (Uthmani «إِلَٰهٌ وَٰحِدٌ» → «الاه واحد»).
      TopicPattern(phrases: ['لا اله الا', 'الاه واحد']),
    ),
  ]),
  TopicCategory('search.cat_akhlaq', [
    Topic(
      'search.patience',
      [
        TopicRef(2, 153),
        TopicRef(2, 155, 157),
        TopicRef(3, 200),
        TopicRef(39, 10),
      ],
      TopicPattern(pattern: 'ص[اوي]?ب[اوي]?ر'),
    ),
    Topic(
      'search.mercy',
      [
        TopicRef(7, 156),
        TopicRef(21, 107),
        TopicRef(6, 12),
      ],
      // Not the bare root: «أرحام» (wombs) shares it.
      TopicPattern(pattern: 'رحم[ةت]|^[وفبل]?ارحم|يرحم|ترحم|رحمنا|راحمين|مرحمة'),
    ),
    Topic(
      'search.honesty',
      [
        TopicRef(9, 119),
        TopicRef(33, 23, 24),
      ],
      TopicPattern(
        pattern: 'صد[ا]?ق|صديق',
        excludeContaining: ['صدقة', 'صدقات', 'تصدق', 'متصدق', 'مصدق'],
      ),
    ),
    Topic(
      'search.parents',
      [
        TopicRef(17, 23, 24),
        TopicRef(31, 14),
        TopicRef(46, 15),
      ],
      TopicPattern(
        pattern: 'والد|ابوي',
        excludeWords: ['والدم', 'والدار', 'والدواب'],
      ),
    ),
    Topic(
      'search.forgiveness',
      [
        TopicRef(3, 135),
        TopicRef(11, 3),
        TopicRef(39, 53),
      ],
      TopicPattern(pattern: 'غ[اوي]?ف[اوي]?ر'),
    ),
    Topic(
      'search.knowledge',
      [
        TopicRef(20, 114),
        TopicRef(58, 11),
        TopicRef(39, 9),
        TopicRef(96, 1, 5),
      ],
      TopicPattern(
        pattern: 'ع[اوي]?ل[اوي]?م',
        excludeContaining: ['عالمين', 'عالمون', 'اعلام', 'علامات', 'علامة', 'معلومات'],
      ),
    ),
  ]),
  TopicCategory('search.cat_prophets', [
    Topic(
      'search.prophet_nuh',
      [
        TopicRef(71, 1, 28),
        TopicRef(11, 25, 49),
      ],
      TopicPattern(pattern: r'^(و|ف|ب|ل|يا)?نوحا?$'),
    ),
    Topic(
      'search.prophet_ibrahim',
      [
        TopicRef(21, 51, 73),
        TopicRef(2, 124, 129),
        TopicRef(37, 83, 113),
      ],
      TopicPattern(pattern: 'ابراهيم|ابرهيم'),
    ),
    Topic(
      'search.prophet_musa',
      [
        TopicRef(20, 9, 98),
        TopicRef(28, 3, 43),
      ],
      TopicPattern(pattern: 'موسي'),
    ),
    Topic(
      'search.prophet_yusuf',
      [
        TopicRef(12, 1, 101),
      ],
      TopicPattern(pattern: 'يوسف'),
    ),
  ]),
  TopicCategory('search.cat_rulings', [
    Topic(
      'search.prayer_topic',
      [
        TopicRef(2, 43),
        TopicRef(29, 45),
        TopicRef(4, 103),
      ],
      // Uthmani «ٱلصَّلَوٰة» normalises to «الصلواة».
      TopicPattern(pattern: 'صلوا?ة|صلوات|مصلين|مصلي'),
    ),
    Topic(
      'search.charity',
      [
        TopicRef(2, 261),
        TopicRef(2, 274),
        TopicRef(9, 103),
      ],
      TopicPattern(
        pattern: 'صدقة|صدقات|زكوا?ة|انفق|ينفق|تنفق|منفقين',
        excludeContaining: ['منافق'],
      ),
    ),
  ]),
  TopicCategory('search.cat_hereafter', [
    Topic(
      'search.paradise',
      [
        TopicRef(2, 25),
        TopicRef(32, 17),
        TopicRef(76, 12, 22),
      ],
      TopicPattern(pattern: 'جنة|جنات|فردوس', excludeWords: ['اجنة']),
    ),
    Topic(
      'search.hellfire',
      [
        TopicRef(2, 24),
        TopicRef(66, 6),
        TopicRef(4, 56),
      ],
      TopicPattern(pattern: 'جهنم|سعير|جحيم|لظي|سقر|حطمة'),
    ),
  ]),
];
