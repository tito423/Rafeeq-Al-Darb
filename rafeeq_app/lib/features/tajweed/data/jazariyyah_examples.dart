/// Which ayah each chapter of the Jazariyyah can be heard in.
///
/// HAND-WRITTEN ON PURPOSE, and kept out of `jazariyyah_course.dart`, which is
/// generated from the book and must stay a pure record of where the nazim's
/// words are. Choosing an ayah that demonstrates a rule is a judgement; a
/// generator has no business making it.
///
/// The twelve pointers came over from the retired «تيسير أحكام التجويد» course
/// unchanged — see [TajweedExample] for why they were nobody's property to
/// begin with — and they are re-mapped here onto ابن الجزري's own chapter
/// headings rather than the other book's lesson titles.
///
/// TWO THINGS THE RE-MAPPING HAD TO FACE:
///
///   * **One chapter, several rules.** The Jazariyyah puts الإظهار, الإدغام,
///     الإقلاب and الإخفاء in a single باب — «فِي مَعْرِفَةِ النُّونِ
///     السَّاكِنَةِ وَالتَّنْوِينِ» — where the other book gave each its own
///     lesson. So a lesson carries a LIST, not one example.
///   * **The mim has no chapter of its own here.** ابن الجزري folds the
///     sakin mim into that same باب («وَأَظْهِرَنَّ مِيمَ…»), so its example
///     sits there too rather than being dropped.
///
/// `jazariyyah_examples_test.dart` holds every key to a real lesson title and
/// every reference to a real ayah.
library;

import 'tajweed_example.dart';

/// Keyed by [JazariyyahLesson.title] — the book's own heading, exactly as the
/// generator wrote it.
const jazariyyahExamples = <String, List<TajweedExample>>{
  'في معرفة النون الساكنة والتنوين': [
    TajweedExample(
      surah: 2,
      ayah: 62,
      phrase: 'مَنْ ءَامَنَ',
      listenKey: 'tajweed.listen_izhar',
    ),
    TajweedExample(
      surah: 2,
      ayah: 107,
      phrase: 'مِن وَلِىٍّ',
      listenKey: 'tajweed.listen_idgham',
    ),
    TajweedExample(
      surah: 2,
      ayah: 27,
      phrase: 'مِنۢ بَعْدِ',
      listenKey: 'tajweed.listen_iqlab',
    ),
    TajweedExample(
      surah: 2,
      ayah: 25,
      phrase: 'مِن قَبْلُ',
      listenKey: 'tajweed.listen_ikhfa',
    ),
    TajweedExample(
      surah: 105,
      ayah: 4,
      phrase: 'تَرْمِيهِم بِحِجَارَةٍ',
      listenKey: 'tajweed.listen_meem',
    ),
  ],
  'في المدات': [
    TajweedExample(
      surah: 71,
      ayah: 10,
      phrase: 'ٱسْتَغْفِرُوا',
      listenKey: 'tajweed.listen_madd_tabii',
    ),
    TajweedExample(
      surah: 110,
      ayah: 1,
      phrase: 'جَآءَ',
      listenKey: 'tajweed.listen_muttasil',
    ),
    TajweedExample(
      surah: 108,
      ayah: 1,
      phrase: 'إِنَّآ أَعْطَيْنَٰكَ',
      listenKey: 'tajweed.listen_munfasil',
    ),
    TajweedExample(
      surah: 1,
      ayah: 7,
      phrase: 'ٱلضَّآلِّينَ',
      listenKey: 'tajweed.listen_lazim',
    ),
  ],
  'في الراءات': [
    TajweedExample(
      surah: 1,
      ayah: 1,
      phrase: 'ٱلرَّحْمَٰنِ',
      listenKey: 'tajweed.listen_ra_tafkhim',
    ),
    TajweedExample(
      surah: 2,
      ayah: 49,
      phrase: 'فِرْعَوْنَ',
      listenKey: 'tajweed.listen_ra_tarqiq',
    ),
  ],
  // القلقلة is one of the صفات, and that is the باب it is taught in here.
  'في صفات الحروف': [
    TajweedExample(
      surah: 113,
      ayah: 1,
      phrase: 'قُلْ أَعُوذُ',
      listenKey: 'tajweed.listen_qalqalah',
    ),
  ],
};
