import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 17 Mushaf Styles from Quranflash & Official Complexes ────────────────────

enum MushafStyle {
  medina1,
  medina2,
  medina3,
  medinaOld,
  tajweedColor,
  shamarly,
  warsh1,
  warsh2,
  qaloon,
  douri,
  shubah,
  line12,
  tahajod,
  naskhTaleek,
  urdu12,
  urdu13,
  urdu15,
}

class MushafStyleInfo {
  final MushafStyle style;
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final String riwayah;
  final int totalPages;
  final String category; // hafs, riwayat, scripts
  final String localThumbCover;
  final String localThumbPage1;
  final String localThumbPage2;
  final String githubUrl;
  final String s3FallbackUrl;
  final int baseWidth;
  final int baseHeight;

  const MushafStyleInfo({
    required this.style,
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.riwayah,
    required this.totalPages,
    required this.category,
    required this.localThumbCover,
    required this.localThumbPage1,
    required this.localThumbPage2,
    required this.githubUrl,
    required this.s3FallbackUrl,
    required this.baseWidth,
    required this.baseHeight,
  });

  String pageUrl(int pageNumber) {
    final pg = pageNumber.toString();
    final pg3 = pg.padLeft(3, '0');
    final pg4 = pg.padLeft(4, '0');
    return githubUrl
        .replaceAll('{page}', pg)
        .replaceAll('{page3}', pg3)
        .replaceAll('{page4}', pg4);
  }

  String fallbackUrl(int pageNumber) {
    final pg4 = pageNumber.toString().padLeft(4, '0');
    return s3FallbackUrl.replaceAll('{page4}', pg4);
  }
}

// ── Complete Catalog of 17 Visual Mushafs ─────────────────────────────────────

const kMushafStyles = <MushafStyleInfo>[
  // ── Hafs Category ──
  MushafStyleInfo(
    style: MushafStyle.medina1,
    id: 'medina1',
    nameAr: 'مصحف المدينة النبوية (الإصدار الأول)',
    nameEn: 'Normal Medina Mushaf',
    description: 'رواية حفص عن عاصم — مجمع الملك فهد لطباعة المصحف الشريف',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/medina1/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/medina1/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/medina1/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/medina1/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Medina1/data/L/{page4}.gif',
    baseWidth: 460,
    baseHeight: 672,
  ),
  MushafStyleInfo(
    style: MushafStyle.medina2,
    id: 'medina2',
    nameAr: 'مصحف المدينة النبوية (المحسَّن)',
    nameEn: 'Medium Medina Mushaf',
    description: 'رواية حفص عن عاصم — مجمع الملك فهد (مقاس وسط محسَّن ومريح)',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/medina2/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/medina2/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/medina2/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/medina2/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Medina2/data/L/{page4}.gif',
    baseWidth: 477,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.medina3,
    id: 'medina3',
    nameAr: 'المصحف الجوامعي الكبير',
    nameEn: 'Jawamee Mushaf',
    description: 'رواية حفص عن عاصم — مجمع الملك فهد (مقاس جوامعي كبير وواضح)',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/medina3/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/medina3/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/medina3/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/medina3/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Medina3/data/L/{page4}.gif',
    baseWidth: 468,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.medinaOld,
    id: 'medina_old',
    nameAr: 'مصحف المدينة القديم (الكلاسيكي)',
    nameEn: 'Old Medina Mushaf',
    description: 'رواية حفص عن عاصم — خط الخطاط عثمان طه الأصلي الأول',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/medina_old/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/medinaOld/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/medinaOld/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/medinaOld/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/MedinaOld/data/L/{page4}.gif',
    baseWidth: 463,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.tajweedColor,
    id: 'tajweed',
    nameAr: 'مصحف التجويد الملوَّن',
    nameEn: 'Tajweed Moshaf',
    description: 'رواية حفص عن عاصم — مع ترميز أحكام التجويد بالألوان (دار المعرفة)',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/tajweed/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/tajweedColor/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/tajweedColor/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/tajweedColor/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Tajweed/data/L/{page4}.gif',
    baseWidth: 479,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.shamarly,
    id: 'shamarly',
    nameAr: 'مصحف الشمرلي (15 سطر - المصرية)',
    nameEn: 'Shamarly Mushaf',
    description: 'رواية حفص عن عاصم — الطبعة المصرية العريقة الشهيرة (15 سطراً)',
    riwayah: 'حفص عن عاصم',
    totalPages: 522,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/shamarly/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/shamarly/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/shamarly/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/shamarly/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Shamarly/data/L/{page4}.gif',
    baseWidth: 477,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.line12,
    id: 'line12',
    nameAr: 'مصحف 12 سطر (الخط الكبير)',
    nameEn: '12 Lines Mushaf',
    description: 'رواية حفص عن عاصم — مصحف 12 سطراً بخط كبير ومريح للعين',
    riwayah: 'حفص عن عاصم',
    totalPages: 850,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/line12/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/line12/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/line12/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/line12/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/12line/data/L/{page4}.gif',
    baseWidth: 442,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.tahajod,
    id: 'tahajod',
    nameAr: 'مصحف التهجد وقيام الليل',
    nameEn: 'Tahajod Mushaf',
    description: 'رواية حفص عن عاصم — مقاس عريض مخصص للقيام والتهجد (دار الصفوة)',
    riwayah: 'حفص عن عاصم',
    totalPages: 266,
    category: 'hafs',
    localThumbCover: 'assets/mushaf_thumbs/tahajod/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/tahajod/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/tahajod/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/tahajod/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Tahajod/data/L/{page4}.gif',
    baseWidth: 792,
    baseHeight: 1100,
  ),

  // ── Riwayat Category ──
  MushafStyleInfo(
    style: MushafStyle.warsh1,
    id: 'warsh1',
    nameAr: 'مصحف رواية ورش (مجمع الملك فهد)',
    nameEn: 'Warsh Mushaf (Azraq)',
    description: 'رواية ورش عن نافع المدني من طريق الأزرق — مجمع الملك فهد',
    riwayah: 'ورش عن نافع (الأزرق)',
    totalPages: 604,
    category: 'riwayat',
    localThumbCover: 'assets/mushaf_thumbs/warsh1/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/warsh1/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/warsh1/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/warsh1/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Warsh1/data/L/{page4}.gif',
    baseWidth: 475,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.warsh2,
    id: 'warsh2',
    nameAr: 'مصحف ورش (طريق الأصبهاني)',
    nameEn: 'Warsh (Asbahani)',
    description: 'رواية ورش عن نافع المدني من طريق أبي بكر الأصبهاني',
    riwayah: 'ورش عن نافع (الأصبهاني)',
    totalPages: 604,
    category: 'riwayat',
    localThumbCover: 'assets/mushaf_thumbs/warsh2/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/warsh2/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/warsh2/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/warsh2/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Warsh2/data/L/{page4}.gif',
    baseWidth: 505,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.qaloon,
    id: 'qaloon',
    nameAr: 'مصحف رواية قالون عن نافع',
    nameEn: 'Qaloon Mushaf',
    description: 'رواية قالون عن نافع المدني — مجمع الملك فهد لطباعة المصحف الشريف',
    riwayah: 'قالون عن نافع',
    totalPages: 604,
    category: 'riwayat',
    localThumbCover: 'assets/mushaf_thumbs/qaloon/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/qaloon/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/qaloon/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/qaloon/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Qaloon/data/L/{page4}.gif',
    baseWidth: 475,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.douri,
    id: 'douri',
    nameAr: 'مصحف رواية الدوري عن أبي عمرو',
    nameEn: 'Douri Mushaf',
    description: 'رواية الدوري عن أبي عمرو البصري — مجمع الملك فهد لطباعة المصحف',
    riwayah: 'الدوري عن أبي عمرو',
    totalPages: 604,
    category: 'riwayat',
    localThumbCover: 'assets/mushaf_thumbs/douri/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/douri/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/douri/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/douri/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Douri/data/L/{page4}.gif',
    baseWidth: 471,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.shubah,
    id: 'shubah',
    nameAr: 'مصحف رواية شعبة عن عاصم',
    nameEn: 'Shubah Mushaf',
    description: 'رواية شعبة بن عياش عن عاصم الكوفي — مجمع الملك فهد لطباعة المصحف',
    riwayah: 'شعبة عن عاصم',
    totalPages: 604,
    category: 'riwayat',
    localThumbCover: 'assets/mushaf_thumbs/shubah/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/shubah/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/shubah/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/shubah/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Shubah/data/L/{page4}.gif',
    baseWidth: 474,
    baseHeight: 671,
  ),

  // ── Scripts & Languages Category ──
  MushafStyleInfo(
    style: MushafStyle.naskhTaleek,
    id: 'naskh_taleek',
    nameAr: 'مصحف خط نسخ تعليق (الفارسي)',
    nameEn: 'Naskh Taleek Mushaf',
    description: 'مصحف مكتوب بالخط الفارسي والنسخ تعليق الجميل',
    riwayah: 'حفص عن عاصم',
    totalPages: 604,
    category: 'scripts',
    localThumbCover: 'assets/mushaf_thumbs/naskh_taleek/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/naskh_taleek/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/naskh_taleek/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/naskh_taleek/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/NaskhTaleek/data/L/{page4}.gif',
    baseWidth: 462,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.urdu12,
    id: 'urdu12',
    nameAr: 'مصحف الأوردو (12 سطر)',
    nameEn: 'Urdu 12 Lines',
    description: 'مصحف أوردو 12 سطراً لقراء شبه القارة الهندية والباكستانية',
    riwayah: 'أوردو',
    totalPages: 736,
    category: 'scripts',
    localThumbCover: 'assets/mushaf_thumbs/urdu12/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/urdu12/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/urdu12/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/urdu12/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Urdu12/data/L/{page4}.gif',
    baseWidth: 453,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.urdu13,
    id: 'urdu13',
    nameAr: 'مصحف الأوردو (13 سطر)',
    nameEn: 'Urdu 13 Lines',
    description: 'مصحف أوردو 13 سطراً للطباعة الباكستانية والهندية',
    riwayah: 'أوردو',
    totalPages: 850,
    category: 'scripts',
    localThumbCover: 'assets/mushaf_thumbs/urdu13/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/urdu13/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/urdu13/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/urdu13/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Urdu13/data/L/{page4}.gif',
    baseWidth: 446,
    baseHeight: 671,
  ),
  MushafStyleInfo(
    style: MushafStyle.urdu15,
    id: 'urdu15',
    nameAr: 'مصحف الأوردو (15 سطر)',
    nameEn: 'Urdu 15 Lines',
    description: 'مصحف أوردو 15 سطراً المعتمد لحفاظ القرآن الكريم',
    riwayah: 'أوردو',
    totalPages: 623,
    category: 'scripts',
    localThumbCover: 'assets/mushaf_thumbs/urdu15/cover.gif',
    localThumbPage1: 'assets/mushaf_thumbs/urdu15/page1.gif',
    localThumbPage2: 'assets/mushaf_thumbs/urdu15/page2.gif',
    githubUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master/mushaf/urdu15/{page}.png',
    s3FallbackUrl: 'https://s3.amazonaws.com/quranflash/books/Urdu15/data/L/{page4}.gif',
    baseWidth: 431,
    baseHeight: 671,
  ),
];

MushafStyleInfo getMushafStyleInfo(MushafStyle style) =>
    kMushafStyles.firstWhere((s) => s.style == style, orElse: () => kMushafStyles.first);

// ── Providers ─────────────────────────────────────────────────────────────────

class MushafStyleNotifier extends StateNotifier<MushafStyle> {
  MushafStyleNotifier() : super(MushafStyle.medina1) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('mushaf_style_index') ?? 0;
    state = MushafStyle.values[idx.clamp(0, MushafStyle.values.length - 1)];
  }

  Future<void> setStyle(MushafStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_style_index', style.index);
  }
}

final mushafStyleProvider =
    StateNotifierProvider<MushafStyleNotifier, MushafStyle>(
  (_) => MushafStyleNotifier(),
);

final mushafStyleInfoProvider = Provider<MushafStyleInfo>((ref) {
  final style = ref.watch(mushafStyleProvider);
  return getMushafStyleInfo(style);
});

// ── Mushaf Background Theme / Paper Color ─────────────────────────────────────

enum MushafBackgroundTheme {
  cream,
  white,
  dark,
  night,
  sepia,
  oud,
}

extension MushafBackgroundThemeExtension on MushafBackgroundTheme {
  int get colorValue {
    switch (this) {
      case MushafBackgroundTheme.cream:
        return 0xFFFFFDF7;
      case MushafBackgroundTheme.white:
        return 0xFFFFFFFF;
      case MushafBackgroundTheme.dark:
        return 0xFF1E293B;
      case MushafBackgroundTheme.night:
        return 0xFF0B1320;
      case MushafBackgroundTheme.sepia:
        return 0xFFF4ECD8;
      case MushafBackgroundTheme.oud:
        return 0xFF2D231E;
    }
  }

  String get nameAr {
    switch (this) {
      case MushafBackgroundTheme.cream:
        return 'كريمي';
      case MushafBackgroundTheme.white:
        return 'أبيض';
      case MushafBackgroundTheme.dark:
        return 'داكن';
      case MushafBackgroundTheme.night:
        return 'ليلي';
      case MushafBackgroundTheme.sepia:
        return 'عتيق (سيبيا)';
      case MushafBackgroundTheme.oud:
        return 'عود ملكي';
    }
  }
}

class MushafThemeNotifier extends StateNotifier<MushafBackgroundTheme> {
  MushafThemeNotifier() : super(MushafBackgroundTheme.cream) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('mushaf_theme_index') ?? 0;
    state = MushafBackgroundTheme.values[idx.clamp(0, MushafBackgroundTheme.values.length - 1)];
  }

  Future<void> setTheme(MushafBackgroundTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_theme_index', theme.index);
  }
}

final mushafThemeProvider =
    StateNotifierProvider<MushafThemeNotifier, MushafBackgroundTheme>(
  (_) => MushafThemeNotifier(),
);
