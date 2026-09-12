/// «تعليم التجويد» — the course's shape.
///
/// WHAT IS MINE HERE AND WHAT IS NOT.
/// The science of tajweed is not mine to write, so none of it is written here:
/// every lesson's text is read at runtime from «تيسير أحكام التجويد — المستوى
/// الأول» by د. يحيى الغوثاني, a real graded course on Shamela already laid out
/// as question and answer, with «تحفة الأطفال», «المقدمة الجزرية» and «قواعد
/// التجويد على رواية حفص» beside it as references. What this file holds is the
/// *arrangement*: where each lesson starts and ends in that book, and which
/// ayah lets you hear its rule.
///
/// «يتقصه النطق الفعلي للحروف والغنن والمدود والإقلاب والإظهار وخلافه عشان
/// يكون كامل مكمل» — and the answer is not a recording of someone saying
/// letters. It is the Qur'an: every rule happens in real ayahs, so each lesson
/// that teaches one carries its own, shown in the app's mushaf text and played
/// in a mujawwad recitation, where the ghunnah is actually held and the madd is
/// actually stretched.
///
/// TWO THINGS THAT WERE CHECKED, because neither was safe to assume:
///
/// * **The ayahs.** All twelve were matched against the bundled
///   `quran_local.db` — surah, ayah and the phrase the rule occurs in — before
///   they were written down. Twelve verified, none failed.
/// * **The boundaries.** The first cut of this file pointed each lesson at a
///   printed page, and the book does not start its topics at the top of one:
///   «الإقلاب» begins seven paragraphs down page 9, under the tail of
///   «إدغام بلا غنّة», and «المد الجائز المنفصل» begins three paragraphs down
///   page 20 under more examples of المتصل. Worse, التفخيم and الترقيق were
///   the wrong way round — page 27 is الترقيق and page 28 is التفخيم. Every
///   range below was read off the real text, paragraph by paragraph, which is
///   the only way it could have been right.
library;

/// One stop in the course: a span of the source book, read verbatim.
///
/// The span is inclusive at both ends and addressed the way the book is
/// actually stored — printed page, then index within that page's paragraphs.
class TajweedLesson {
  /// The title this lesson is given on screen, in the source's own wording.
  final String sectionTitle;

  final int fromPage;
  final int fromPara;
  final int toPage;
  final int toPara;

  /// The ayah the rule can be heard in, when the lesson teaches one rule
  /// clearly enough to point at. Null for the openings, the surveys and the
  /// classifications.
  final TajweedExample? example;

  const TajweedLesson({
    required this.sectionTitle,
    required this.fromPage,
    required this.fromPara,
    required this.toPage,
    required this.toPara,
    this.example,
  });
}

/// The place in the Qur'an where a rule occurs.
class TajweedExample {
  final int surah;
  final int ayah;

  /// The words inside that ayah the rule happens in — shown beside the button
  /// so the eye lands on it while the ear hears it.
  final String phrase;

  /// What to listen for, in one line. Written here because it is a pointer,
  /// not a ruling: the ruling is in the lesson text from the book.
  final String listenKey;

  const TajweedExample({
    required this.surah,
    required this.ayah,
    required this.phrase,
    required this.listenKey,
  });
}

/// The book the lessons are read from, and the three that sit beside it.
const tajweedCourseBook = 'taysir_ahkam_at_tajwid';
const tajweedReferenceBooks = <String>[
  'tuhfat_al_atfal',
  'al_muqaddimah_al_jazariyyah',
  'qawaid_at_tajwid_hafs',
];

const tajweedLessons = <TajweedLesson>[
  TajweedLesson(
    sectionTitle: 'مقدمات وتعريفات',
    fromPage: 4,
    fromPara: 0,
    toPage: 5,
    toPara: 0,
  ),
  TajweedLesson(
    sectionTitle: 'مراتب التلاوة',
    fromPage: 5,
    fromPara: 1,
    toPage: 6,
    toPara: 2,
  ),
  TajweedLesson(
    sectionTitle: 'أحكام النون الساكنة والتنوين',
    fromPage: 6,
    fromPara: 3,
    toPage: 6,
    toPara: 5,
  ),
  TajweedLesson(
    sectionTitle: 'الإظهار',
    fromPage: 7,
    fromPara: 0,
    toPage: 7,
    toPara: 14,
    example: TajweedExample(
      surah: 2,
      ayah: 62,
      phrase: 'مَنْ ءَامَنَ',
      listenKey: 'tajweed.listen_izhar',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'الإدغام',
    fromPage: 8,
    fromPara: 0,
    toPage: 9,
    toPara: 4,
    example: TajweedExample(
      surah: 2,
      ayah: 107,
      phrase: 'مِن وَلِىٍّ',
      listenKey: 'tajweed.listen_idgham',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'الإقلاب',
    fromPage: 9,
    fromPara: 5,
    toPage: 9,
    toPara: 11,
    example: TajweedExample(
      surah: 2,
      ayah: 27,
      phrase: 'مِنۢ بَعْدِ',
      listenKey: 'tajweed.listen_iqlab',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'الإخفاء',
    fromPage: 10,
    fromPara: 0,
    toPage: 11,
    toPara: 10,
    example: TajweedExample(
      surah: 2,
      ayah: 25,
      phrase: 'مِن قَبْلُ',
      listenKey: 'tajweed.listen_ikhfa',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'أحكام الميم الساكنة',
    fromPage: 12,
    fromPara: 0,
    toPage: 12,
    toPara: 10,
    example: TajweedExample(
      surah: 105,
      ayah: 4,
      phrase: 'تَرْمِيهِم بِحِجَارَةٍ',
      listenKey: 'tajweed.listen_meem',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'أحكام المد: تعريفه وأنواعه',
    fromPage: 13,
    fromPara: 0,
    toPage: 14,
    toPara: 12,
  ),
  TajweedLesson(
    sectionTitle: 'المد الطبيعي',
    fromPage: 15,
    fromPara: 0,
    toPage: 15,
    toPara: 7,
    example: TajweedExample(
      surah: 71,
      ayah: 10,
      phrase: 'ٱسْتَغْفِرُوا',
      listenKey: 'tajweed.listen_madd_tabii',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'مد البدل',
    fromPage: 16,
    fromPara: 0,
    toPage: 16,
    toPara: 8,
  ),
  TajweedLesson(
    sectionTitle: 'مد العوض',
    fromPage: 17,
    fromPara: 0,
    toPage: 17,
    toPara: 8,
  ),
  TajweedLesson(
    sectionTitle: 'مد الصلة',
    fromPage: 18,
    fromPara: 0,
    toPage: 18,
    toPara: 9,
  ),
  TajweedLesson(
    sectionTitle: 'المد الفرعي: الواجب المتصل',
    fromPage: 19,
    fromPara: 0,
    toPage: 20,
    toPara: 1,
    example: TajweedExample(
      surah: 110,
      ayah: 1,
      phrase: 'جَآءَ',
      listenKey: 'tajweed.listen_muttasil',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'المد الجائز المنفصل',
    fromPage: 20,
    fromPara: 2,
    toPage: 20,
    toPara: 9,
    example: TajweedExample(
      surah: 108,
      ayah: 1,
      phrase: 'إِنَّآ أَعْطَيْنَٰكَ',
      listenKey: 'tajweed.listen_munfasil',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'المد اللازم والمد العارض للسكون',
    fromPage: 21,
    fromPara: 0,
    toPage: 22,
    toPara: 1,
    example: TajweedExample(
      surah: 1,
      ayah: 7,
      phrase: 'ٱلضَّآلِّينَ',
      listenKey: 'tajweed.listen_lazim',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'مد اللين',
    fromPage: 22,
    fromPara: 2,
    toPage: 22,
    toPara: 9,
  ),
  TajweedLesson(
    sectionTitle: 'القلقلة',
    fromPage: 23,
    fromPara: 0,
    toPage: 24,
    toPara: 6,
    example: TajweedExample(
      surah: 113,
      ayah: 1,
      phrase: 'قُلْ أَعُوذُ',
      listenKey: 'tajweed.listen_qalqalah',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'أقسام المد اللازم',
    fromPage: 25,
    fromPara: 0,
    toPage: 26,
    toPara: 3,
  ),
  // The book teaches الترقيق first (page 27) and التفخيم after it (page 28).
  // The first cut of this file had them the other way round.
  TajweedLesson(
    sectionTitle: 'أحكام الراءات: الترقيق',
    fromPage: 27,
    fromPara: 0,
    toPage: 27,
    toPara: 10,
    example: TajweedExample(
      surah: 2,
      ayah: 49,
      phrase: 'فِرْعَوْنَ',
      listenKey: 'tajweed.listen_ra_tarqiq',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'أحكام الراءات: التفخيم',
    fromPage: 28,
    fromPara: 0,
    toPage: 28,
    toPara: 10,
    example: TajweedExample(
      surah: 1,
      ayah: 1,
      phrase: 'ٱلرَّحْمَٰنِ',
      listenKey: 'tajweed.listen_ra_tafkhim',
    ),
  ),
  TajweedLesson(
    sectionTitle: 'الوقف والابتداء',
    fromPage: 29,
    fromPara: 0,
    toPage: 30,
    toPara: 4,
  ),
  TajweedLesson(
    sectionTitle: 'السكت عند حفص عن عاصم',
    fromPage: 31,
    fromPara: 0,
    toPage: 31,
    toPara: 8,
  ),
];
