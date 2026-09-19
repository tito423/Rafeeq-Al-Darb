import 'package:flutter/material.dart';

/// P3‑43 #13: the owner's reference (`design_refs/round3_2026-09-05/
/// 8_azkar_categories_target.jpg`) shows a 10-category coloured-card grid
/// (أذكار الصباح / المساء / النوم / بعد الصلاة / الاستيقاظ / أذكار المسجد /
/// أدعية مأثورة / أدعية قرآنية / دعاء السفر / الرقية الشرعية), asking the
/// real 133 Hisn al-Muslim sections (P3‑11's own flat grid) to be regrouped
/// under it.
///
/// **Two of the ten don't have a real match and are deliberately left out,
/// not force-fit** — per the task's own instruction ("any section that
/// doesn't cleanly fit... should be flagged rather than force-fit"),
/// confirmed by reading every one of the real 134 section titles directly
/// (`SELECT title FROM azkar_sections`), not assumed:
///  - **أدعية قرآنية** (Quranic supplications) — Hisn al-Muslim's real table
///    of contents has no section grouping duas *by source* (Quran vs.
///    Sunnah); every section here is organised by *situation* instead, and
///    there is no per-item source tag in `azkar_items` to derive one
///    honestly without reading and re-classifying all ~700 individual
///    dhikr texts by hand — a real, much larger task than this pass.
///  - **الرقية الشرعية** (legal ruqyah) — still true that **no Hisn
///    al-Muslim section is a ruqyah section**: the nearest real content
///    (sickness / evil-eye sections like §51 or §127) is about
///    *visiting and comforting* the afflicted, not the recitation-for-healing
///    practice ruqyah means, and folding them in would be a
///    mischaracterisation. The owner asked for ruqyah in the Adhkar tab
///    anyway, so it is there now — but as `AzkarCategory.ruqyah`, a tile that
///    opens `RuqyahScreen` instead of an azkar section. That screen assembles
///    the ruqyah from sources the app already has and can stand behind: the
///    verses from `quran_local.db`, and six supplications addressed by row id
///    in `azkar_items`, each carrying its own takhrij. It is **not** a
///    re-labelling of sections that are about something else.
///
/// The other eight are real, content-based groupings of the real section
/// titles (`assets/data/quran_sciences.db`'s `azkar_sections` table),
/// verified section-by-section, not guessed at from titles alone in bulk.
/// One section (§29, "أذكار الصباح والمساء") genuinely covers both morning
/// *and* evening in the source material itself — Hisn al-Muslim has never
/// split it into two separate chapters — so it's the one deliberate
/// exception listed under two categories rather than an arbitrary pick
/// between them.
enum AzkarCategory {
  morning,
  evening,
  sleep,
  waking,
  afterPrayer,
  mosque,
  travel,
  narrated,

  /// Not a grouping of Hisn al-Muslim sections — see the note above. This one
  /// tile opens `RuqyahScreen`, which is composed from the Qur'an database and
  /// specific azkar rows rather than from a section of the book.
  ruqyah,
}

class AzkarCategoryInfo {
  final String titleKey;
  final IconData icon;
  final List<Color> gradient;

  const AzkarCategoryInfo({
    required this.titleKey,
    required this.icon,
    required this.gradient,
  });
}

const azkarCategoryInfo = <AzkarCategory, AzkarCategoryInfo>{
  AzkarCategory.ruqyah: AzkarCategoryInfo(
    titleKey: 'ruqyah.title',
    icon: Icons.healing_outlined,
    gradient: [Color(0xFF0C3B32), Color(0xFF14705C)],
  ),
  AzkarCategory.morning: AzkarCategoryInfo(
    titleKey: 'azkar.category_morning',
    icon: Icons.wb_sunny_outlined,
    gradient: [Color(0xFF1E5FA8), Color(0xFF2B7FD1)],
  ),
  AzkarCategory.evening: AzkarCategoryInfo(
    titleKey: 'azkar.category_evening',
    icon: Icons.nights_stay_outlined,
    gradient: [Color(0xFF2A1B4A), Color(0xFF4A2E7A)],
  ),
  AzkarCategory.sleep: AzkarCategoryInfo(
    titleKey: 'azkar.category_sleep',
    icon: Icons.bedtime_outlined,
    gradient: [Color(0xFF7A2E8C), Color(0xFFA84BC2)],
  ),
  AzkarCategory.afterPrayer: AzkarCategoryInfo(
    titleKey: 'azkar.category_after_prayer',
    icon: Icons.self_improvement,
    gradient: [Color(0xFF1F6B3A), Color(0xFF2E9D4F)],
  ),
  AzkarCategory.waking: AzkarCategoryInfo(
    titleKey: 'azkar.category_waking',
    icon: Icons.alarm,
    gradient: [Color(0xFF0E7C86), Color(0xFF17A6B4)],
  ),
  AzkarCategory.mosque: AzkarCategoryInfo(
    titleKey: 'azkar.category_mosque',
    icon: Icons.mosque_outlined,
    gradient: [Color(0xFFB3540F), Color(0xFFE07A1F)],
  ),
  AzkarCategory.narrated: AzkarCategoryInfo(
    titleKey: 'azkar.category_narrated',
    icon: Icons.auto_awesome_outlined,
    gradient: [Color(0xFF4C7A1A), Color(0xFF74A82C)],
  ),
  AzkarCategory.travel: AzkarCategoryInfo(
    titleKey: 'azkar.category_travel',
    icon: Icons.flight_outlined,
    gradient: [Color(0xFF8C2E8C), Color(0xFFB84BC2)],
  ),
};

/// Section id → the tiles it appears under.
///
/// **Rewritten 2026-09-17, and the rewrite was overdue by one screen.** This
/// map used to hold **134** entries — the section numbering of «حصن المسلم»,
/// with al-Qahtani's own chapter titles as its comments. When `azkar_sections`
/// was rebuilt from an-Nawawi's «الأذكار» the numbering became 1–18, so every
/// id from 19 up pointed at nothing and most tiles would have opened **empty**.
///
/// Nothing caught that. `flutter analyze` sees a valid `Map<int, …>`, the test
/// suite had no opinion, and the ids are plain integers with no referent to
/// check against. It was found by opening the Adhkar tab and looking, which is
/// the only thing that ever finds this class of defect.
///
/// It was also a **second copy of al-Qahtani's arrangement**, living in Dart
/// rather than in the database — the thing the whole replacement was for. See
/// `CONTENT-LICENSES.md`.
///
/// `azkar_categories_cover_sections_test.dart` now fails the build when an id
/// here is absent from the database, or when a chapter in the database appears
/// under no tile at all.
const Map<int, List<AzkarCategory>> azkarSectionCategories = {
  1: [AzkarCategory.waking], // ما يقول إذا استيقظ من منامه
  2: [AzkarCategory.narrated], // ما يقول إذا لبس ثوبه
  3: [AzkarCategory.narrated], // ما يقول إذا لبس ثوبا جديدا
  4: [AzkarCategory.narrated], // ما يقول لصاحبه إذا رأى عليه ثوبا جديدا
  5: [AzkarCategory.narrated], // ما يقول عند الخروج من البيت
  6: [AzkarCategory.narrated], // ما يقول إذا دخل بيته
  7: [AzkarCategory.narrated], // ما يقول عند دخول الخلاء
  8: [AzkarCategory.narrated], // ما يقول إذا خرج من الخلاء
  9: [AzkarCategory.narrated], // ما يقول على وضوئه
  10: [AzkarCategory.mosque], // ما يقول إذا توجه إلى المسجد
  11: [AzkarCategory.mosque], // ما يقوله عند دخول المسجد والخروج منه
  12: [AzkarCategory.narrated], // ما يقوله المريض ويقال عنده
  13: [AzkarCategory.travel], // ما يقول إذا نزل منزلا
  14: [AzkarCategory.narrated], // ما يقوله إذا راعه شيء أو فزع
  // Split in two on 2026-09-17 at the owner's request. an-Nawawi keeps them
  // in one bab; the morning list opens on «أصبحنا وأصبح الملك لله» and the
  // evening list on «أمسينا وأمسى الملك لله», and what he says at both times
  // stands in both lists because that is what his narrations instruct.
  15: [AzkarCategory.morning], // ما يقال عند الصباح
  16: [AzkarCategory.evening], // ما يقال عند المساء
  17: [AzkarCategory.sleep], // ما يقول إذا أراد النوم
  18: [AzkarCategory.narrated], // ما يقول إذا نزل المطر
  19: [AzkarCategory.narrated], // التسمية عند الأكل والشرب
  20: [AzkarCategory.afterPrayer], // الأذكار بعد الصلاة
  // 2026-09-19, «أدعية السفر قليلة جدًا»: an-Nawawi's travel chapters, each
  // item with a named source or his grading (Ibn al-Sunni's ungraded ones
  // left out).
  21: [AzkarCategory.travel], // ما يقوله إذا ركب دابته
  22: [AzkarCategory.travel], // أذكاره إذا خرج (التوديع)
  23: [AzkarCategory.travel], // استحباب طلبه الوصية من أهل الخير
  24: [AzkarCategory.travel], // تكبير المسافر إذا صعد وتسبيحه إذا هبط
  25: [AzkarCategory.travel], // ما يدعو به إذا خاف ناسًا
  26: [AzkarCategory.travel], // ما يقول إذا رجع من سفره
};
