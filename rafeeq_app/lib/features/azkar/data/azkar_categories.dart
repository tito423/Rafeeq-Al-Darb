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
///  - **الرقية الشرعية** (legal ruqyah) — no section is titled or scoped as
///    ruqyah specifically either; the nearest real content (sickness/
///    evil-eye sections like §51 or §127) is about *visiting/comforting*
///    the afflicted, not the specific recitation-for-healing practice
///    ruqyah technically means, so folding them in would be a
///    mischaracterisation, not a fit.
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

/// Real section-id → category assignments, read section-by-section against
/// the real `azkar_sections` titles (§1 "المقدمة" excluded — already
/// filtered elsewhere as front matter, not a dhikr category, per P3‑11).
const Map<int, List<AzkarCategory>> azkarSectionCategories = {
  2: [AzkarCategory.narrated], // فضل الذكر
  3: [AzkarCategory.waking], // أذكار الاستيقاظ من النوم
  4: [AzkarCategory.narrated],
  5: [AzkarCategory.narrated],
  6: [AzkarCategory.narrated],
  7: [AzkarCategory.narrated],
  8: [AzkarCategory.narrated],
  9: [AzkarCategory.narrated],
  10: [AzkarCategory.narrated],
  11: [AzkarCategory.narrated],
  12: [AzkarCategory.narrated],
  13: [AzkarCategory.narrated],
  14: [AzkarCategory.mosque], // دعاء الذهاب إلى المسجد
  15: [AzkarCategory.mosque], // دعاء دخول المسجد
  16: [AzkarCategory.mosque], // دعاء الخروج من المسجد
  17: [AzkarCategory.mosque], // أذكار الأذان
  18: [AzkarCategory.afterPrayer], // دعاء الاستفتاح
  19: [AzkarCategory.afterPrayer],
  20: [AzkarCategory.afterPrayer],
  21: [AzkarCategory.afterPrayer],
  22: [AzkarCategory.afterPrayer],
  23: [AzkarCategory.afterPrayer],
  24: [AzkarCategory.afterPrayer], // التشهد
  25: [AzkarCategory.afterPrayer],
  26: [AzkarCategory.afterPrayer],
  27: [AzkarCategory.afterPrayer], // الأذكار بعد السلام من الصلاة
  28: [AzkarCategory.afterPrayer], // دعاء صلاة الاستخارة
  29: [
    AzkarCategory.morning,
    AzkarCategory.evening,
  ], // أذكار الصباح والمساء — genuinely one combined section, see class doc
  30: [AzkarCategory.sleep], // أذكار النوم
  31: [AzkarCategory.sleep],
  32: [AzkarCategory.sleep],
  33: [AzkarCategory.sleep],
  34: [AzkarCategory.afterPrayer], // دعاء قنوت الوتر
  35: [AzkarCategory.afterPrayer],
  36: [AzkarCategory.narrated],
  37: [AzkarCategory.narrated],
  38: [AzkarCategory.narrated],
  39: [AzkarCategory.narrated],
  40: [AzkarCategory.narrated],
  41: [AzkarCategory.narrated],
  42: [AzkarCategory.narrated],
  43: [AzkarCategory.narrated],
  44: [AzkarCategory.afterPrayer], // دعاء الوسوسة في الصلاة والقراءة
  45: [AzkarCategory.narrated],
  46: [AzkarCategory.narrated],
  47: [AzkarCategory.narrated],
  48: [AzkarCategory.narrated],
  49: [AzkarCategory.narrated],
  50: [AzkarCategory.narrated],
  51: [AzkarCategory.narrated],
  52: [AzkarCategory.narrated],
  53: [AzkarCategory.narrated],
  54: [AzkarCategory.narrated],
  55: [AzkarCategory.narrated],
  56: [AzkarCategory.narrated],
  57: [AzkarCategory.narrated],
  58: [AzkarCategory.narrated],
  59: [AzkarCategory.narrated],
  60: [AzkarCategory.narrated],
  61: [AzkarCategory.narrated],
  62: [AzkarCategory.narrated],
  63: [AzkarCategory.narrated],
  64: [AzkarCategory.narrated],
  65: [AzkarCategory.narrated],
  66: [AzkarCategory.narrated],
  67: [AzkarCategory.narrated],
  68: [AzkarCategory.narrated],
  69: [AzkarCategory.narrated],
  70: [AzkarCategory.narrated],
  71: [AzkarCategory.narrated],
  72: [AzkarCategory.narrated],
  73: [AzkarCategory.narrated],
  74: [AzkarCategory.narrated],
  75: [AzkarCategory.narrated],
  76: [AzkarCategory.narrated],
  77: [AzkarCategory.narrated],
  78: [AzkarCategory.narrated],
  79: [AzkarCategory.narrated],
  80: [AzkarCategory.narrated],
  81: [AzkarCategory.narrated],
  82: [AzkarCategory.narrated],
  83: [AzkarCategory.narrated],
  84: [AzkarCategory.narrated],
  85: [AzkarCategory.narrated],
  86: [AzkarCategory.narrated],
  87: [AzkarCategory.narrated],
  88: [AzkarCategory.narrated],
  89: [AzkarCategory.narrated],
  90: [AzkarCategory.narrated],
  91: [AzkarCategory.narrated],
  92: [AzkarCategory.narrated],
  93: [AzkarCategory.narrated],
  94: [AzkarCategory.narrated],
  95: [AzkarCategory.narrated],
  96: [AzkarCategory.narrated],
  97: [AzkarCategory.travel], // دعاء ركوب الدابة
  98: [AzkarCategory.travel], // دعاء السفر
  99: [AzkarCategory.travel],
  100: [AzkarCategory.travel], // دعاء دخول السوق
  101: [AzkarCategory.travel],
  102: [AzkarCategory.travel],
  103: [AzkarCategory.travel],
  104: [AzkarCategory.travel],
  105: [AzkarCategory.travel],
  106: [AzkarCategory.travel],
  107: [AzkarCategory.travel], // ذكر الرجوع من السفر
  108: [AzkarCategory.narrated],
  109: [AzkarCategory.narrated],
  110: [AzkarCategory.narrated],
  111: [AzkarCategory.narrated],
  112: [AzkarCategory.narrated],
  113: [AzkarCategory.narrated],
  114: [AzkarCategory.narrated],
  115: [AzkarCategory.narrated],
  116: [AzkarCategory.narrated],
  117: [AzkarCategory.narrated],
  118: [AzkarCategory.narrated],
  119: [AzkarCategory.narrated],
  120: [AzkarCategory.narrated],
  121: [AzkarCategory.narrated],
  122: [AzkarCategory.narrated],
  123: [AzkarCategory.narrated],
  124: [AzkarCategory.narrated],
  125: [AzkarCategory.narrated],
  126: [AzkarCategory.narrated],
  127: [AzkarCategory.narrated],
  128: [AzkarCategory.narrated],
  129: [AzkarCategory.narrated],
  130: [AzkarCategory.narrated],
  131: [AzkarCategory.narrated],
  132: [AzkarCategory.narrated],
  133: [AzkarCategory.narrated],
  134: [AzkarCategory.narrated],
};
