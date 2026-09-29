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
/// **Rebuilt 2026-09-29 on «حصن المسلم»** (owner's order: «استخدم كتاب حصن
/// المسلم للأذكار كلها لأنه شامل أكثر»), from the 133 chapters of the edition
/// in `scripts/azkar_hisn/`. The ids are that edition's own order. The book
/// prints morning and evening as separate chapters (27, 28), so each tile
/// opens its own list, as the owner asked on 2026-09-17.
///
/// The grouping is the one the 2026-09-05 pass made by reading every chapter
/// title (prayer-internal duas under «بعد الصلاة»; clothes, wudu, home,
/// eating, greetings and the rest under «أدعية مأثورة»), carried over by
/// title, not by number.
///
/// `azkar_categories_cover_sections_test.dart` fails the build when an id
/// here is absent from the database, or when a chapter appears under no tile.
const Map<int, List<AzkarCategory>> azkarSectionCategories = {
  1: [AzkarCategory.waking], // أذكار الاستيقاظ من النوم
  2: [AzkarCategory.narrated], // دعاء لبس الثوب
  3: [AzkarCategory.narrated], // دعاء لبس الثوب الجديد
  4: [AzkarCategory.narrated], // الدعاء لمن لبس ثوبا جديدا
  5: [AzkarCategory.narrated], // ما يقول إذا وضع ثوبه
  6: [AzkarCategory.narrated], // دعاء دخول الخلاء
  7: [AzkarCategory.narrated], // دعاء الخروج من الخلاء
  8: [AzkarCategory.narrated], // الذكر قبل الوضوء
  9: [AzkarCategory.narrated], // الذكر بعد الفراغ من الوضوء
  10: [AzkarCategory.narrated], // الذكر عند الخروج من المنزل
  11: [AzkarCategory.narrated], // الذكر عند دخول المنزل
  12: [AzkarCategory.mosque], // دعاء الذهاب إلى المسجد
  13: [AzkarCategory.mosque], // دعاء دخول المسجد
  14: [AzkarCategory.mosque], // دعاء الخروج من المسجد
  15: [AzkarCategory.mosque], // أذكار الأذان
  16: [AzkarCategory.afterPrayer], // دعاء الاستفتاح
  17: [AzkarCategory.afterPrayer], // دعاء الركوع
  18: [AzkarCategory.afterPrayer], // دعاء الرفع من الركوع
  19: [AzkarCategory.afterPrayer], // دعاء السجود
  20: [AzkarCategory.afterPrayer], // دعاء الجلسة بين السجدتين
  21: [AzkarCategory.afterPrayer], // دعاء سجود التلاوة
  22: [AzkarCategory.afterPrayer], // التشهد
  23: [AzkarCategory.afterPrayer], // الصلاة على النبي صلى الله عليه وسلم بعد التشهد
  24: [AzkarCategory.afterPrayer], // الدعاء بعد التشهد الأخير وقبل السلام
  25: [AzkarCategory.afterPrayer], // الأذكار بعد السلام من الصلاة
  26: [AzkarCategory.afterPrayer], // دعاء صلاة الاستخارة
  27: [AzkarCategory.morning], // أذكار الصباح
  28: [AzkarCategory.evening], // أذكار المساء
  29: [AzkarCategory.sleep], // أذكار النوم
  30: [AzkarCategory.sleep], // الدعاء إذا تقلب ليلا
  31: [AzkarCategory.sleep], // دعاء الفزع في النوم ومن بلي بالوحشة
  32: [AzkarCategory.sleep], // ما يفعل من رأى الرؤيا أو الحلم
  33: [AzkarCategory.afterPrayer], // دعاء قنوت الوتر
  34: [AzkarCategory.afterPrayer], // الذكر عقب السلام من الوتر
  35: [AzkarCategory.narrated], // دعاء الهم والحزن
  36: [AzkarCategory.narrated], // دعاء الكرب
  37: [AzkarCategory.narrated], // دعاء لقاء العدو وذي السلطان
  38: [AzkarCategory.narrated], // دعاء من خاف ظلم السلطان
  39: [AzkarCategory.narrated], // الدعاء على العدو
  40: [AzkarCategory.narrated], // ما يقول من خاف قوما
  41: [AzkarCategory.narrated], // دعاء من أصابه شك في الإيمان
  42: [AzkarCategory.narrated], // دعاء قضاء الدين
  43: [AzkarCategory.afterPrayer], // دعاء الوسوسة في الصلاة والقراءة
  44: [AzkarCategory.narrated], // دعاء من استصعب عليه أمر
  45: [AzkarCategory.narrated], // ما يقول ويفعل من أذنب ذنبا
  46: [AzkarCategory.narrated], // دعاء طرد الشيطان ووساوسه
  47: [AzkarCategory.narrated], // الدعاء حينما يقع ما لا يرضاه أو غلب على أمره
  48: [AzkarCategory.narrated], // تهنئة المولود له وجوابه
  49: [AzkarCategory.narrated], // ما يعوذ به الأولاد
  50: [AzkarCategory.narrated], // الدعاء للمريض في عيادته
  51: [AzkarCategory.narrated], // فضل عيادة المريض
  52: [AzkarCategory.narrated], // دعاء المريض الذي يئس من حياته
  53: [AzkarCategory.narrated], // تلقين المحتضر
  54: [AzkarCategory.narrated], // دعاء من أصيب بمصيبة
  55: [AzkarCategory.narrated], // الدعاء عند إغماض الميت
  56: [AzkarCategory.narrated], // الدعاء للميت في الصلاة عليه
  57: [AzkarCategory.narrated], // الدعاء للفرط في الصلاة عليه
  58: [AzkarCategory.narrated], // دعاء التعزية
  59: [AzkarCategory.narrated], // الدعاء عند إدخال الميت القبر
  60: [AzkarCategory.narrated], // الدعاء بعد دفن الميت
  61: [AzkarCategory.narrated], // دعاء زيارة القبور
  62: [AzkarCategory.narrated], // دعاء الريح
  63: [AzkarCategory.narrated], // دعاء الرعد
  64: [AzkarCategory.narrated], // من أدعية الاستسقاء
  65: [AzkarCategory.narrated], // الدعاء إذا نزل المطر
  66: [AzkarCategory.narrated], // الذكر بعد نزول المطر
  67: [AzkarCategory.narrated], // من أدعية الاستصحاء
  68: [AzkarCategory.narrated], // دعاء رؤية الهلال
  69: [AzkarCategory.narrated], // الدعاء عند إفطار الصائم
  70: [AzkarCategory.narrated], // الدعاء قبل الطعام
  71: [AzkarCategory.narrated], // الدعاء عند الفراغ من الطعام
  72: [AzkarCategory.narrated], // دعاء الضيف لصاحب الطعام
  73: [AzkarCategory.narrated], // الدعاء لمن سقاه أو إذا أراد ذلك
  74: [AzkarCategory.narrated], // الدعاء إذا أفطر عند أهل بيت
  75: [AzkarCategory.narrated], // دعاء الصائم إذا حضر الطعام ولم يفطر
  76: [AzkarCategory.narrated], // ما يقول الصائم إذا سابه أحد
  77: [AzkarCategory.narrated], // الدعاء عند رؤية باكورة الثمر
  78: [AzkarCategory.narrated], // دعاء العطاس
  79: [AzkarCategory.narrated], // ما يقال للكافر إذا عطس فحمد الله
  80: [AzkarCategory.narrated], // الدعاء للمتزوج
  81: [AzkarCategory.narrated], // دعاء المتزوج وشراء الدابة
  82: [AzkarCategory.narrated], // الدعاء قبل إتيان الزوجة
  83: [AzkarCategory.narrated], // دعاء الغضب
  84: [AzkarCategory.narrated], // دعاء من رأى مبتلى
  85: [AzkarCategory.narrated], // ما يقال في المجلس
  86: [AzkarCategory.narrated], // كفارة المجلس
  87: [AzkarCategory.narrated], // الدعاء لمن قال غفر الله لك
  88: [AzkarCategory.narrated], // الدعاء لمن صنع إليك معروفا
  89: [AzkarCategory.narrated], // ما يعصم الله به من الدجال
  90: [AzkarCategory.narrated], // الدعاء لمن قال إني أحبك في الله
  91: [AzkarCategory.narrated], // الدعاء لمن عرض عليك ماله
  92: [AzkarCategory.narrated], // الدعاء لمن أقرض عند القضاء
  93: [AzkarCategory.narrated], // دعاء الخوف من الشرك
  94: [AzkarCategory.narrated], // الدعاء لمن قال بارك الله فيك
  95: [AzkarCategory.narrated], // دعاء كراهية الطيرة
  96: [AzkarCategory.travel], // دعاء الركوب
  97: [AzkarCategory.travel], // دعاء السفر
  98: [AzkarCategory.travel], // دعاء دخول القرية أو البلدة
  99: [AzkarCategory.travel], // دعاء دخول السوق
  100: [AzkarCategory.travel], // الدعاء إذا تعس المركوب
  101: [AzkarCategory.travel], // دعاء المسافر للمقيم
  102: [AzkarCategory.travel], // دعاء المقيم للمسافر
  103: [AzkarCategory.travel], // التكبير والتسبيح في سير السفر
  104: [AzkarCategory.travel], // دعاء المسافر إذا أسحر
  105: [AzkarCategory.travel], // الدعاء إذا نزل منزلا في سفر أو غيره
  106: [AzkarCategory.travel], // ذكر الرجوع من السفر
  107: [AzkarCategory.narrated], // ما يقول من أتاه أمر يسره أو يكرهه
  108: [AzkarCategory.narrated], // فضل الصلاة على النبي صلى الله عليه وسلم
  109: [AzkarCategory.narrated], // إفشاء السلام
  110: [AzkarCategory.narrated], // كيف يرد السلام على الكافر إذا سلم
  111: [AzkarCategory.narrated], // الدعاء عند صياح الديك ونهيق الحمار
  112: [AzkarCategory.narrated], // الدعاء عند سماع نباح الكلاب بالليل
  113: [AzkarCategory.narrated], // الدعاء لمن سببته
  114: [AzkarCategory.narrated], // ما يقول المسلم إذا مدح المسلم
  115: [AzkarCategory.narrated], // ما يقول المسلم إذا زكي
  116: [AzkarCategory.narrated], // كيف يلبي المحرم في الحج أو العمرة
  117: [AzkarCategory.narrated], // التكبير إذا أتى الركن الأسود
  118: [AzkarCategory.narrated], // الدعاء بين الركن اليماني والحجر الأسود
  119: [AzkarCategory.narrated], // دعاء الوقوف على الصفا والمروة
  120: [AzkarCategory.narrated], // الدعاء يوم عرفة
  121: [AzkarCategory.narrated], // الذكر عند المشعر الحرام
  122: [AzkarCategory.narrated], // التكبير عند رمي الجمار مع كل حصاة
  123: [AzkarCategory.narrated], // دعاء التعجب والأمر السار
  124: [AzkarCategory.narrated], // ما يفعل من أتاه أمر يسره
  125: [AzkarCategory.narrated], // ما يقول من أحس وجعا في جسده
  126: [AzkarCategory.narrated], // دعاء من خشي أن يصيب شيئا بعينه
  127: [AzkarCategory.narrated], // ما يقال عند الفزع
  128: [AzkarCategory.narrated], // ما يقول عند الذبح أو النحر
  129: [AzkarCategory.narrated], // ما يقول لرد كيد مردة الشياطين
  130: [AzkarCategory.narrated], // الاستغفار والتوبة
  131: [AzkarCategory.narrated], // فضل التسبيح والتحميد، والتهليل، والتكبير
  132: [AzkarCategory.narrated], // كيف كان النبي صلى الله عليه وسلم يسبح؟
  133: [AzkarCategory.narrated], // من أنواع الخير والآداب الجامعة
};
