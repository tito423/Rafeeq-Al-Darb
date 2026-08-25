import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/surah.dart';
import '../providers/quran_provider.dart';
import 'surah_reading_screen.dart';
import 'advanced_search_screen.dart';
import 'mushaf_browser_screen.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchCtrl;
  late final AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final surahsAsync = ref.watch(filteredSurahsProvider);
    final lastRead = ref.watch(lastReadProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: DefaultTabController(
        length: 2,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              _QuranHeader(
                isDark: isDark,
                textColor: textColor,
                subtext: subtext,
                lastRead: lastRead,
                searchCtrl: _searchCtrl,
                onSearch: (q) {
                  ref.read(surahSearchQueryProvider.notifier).state = q;
                },
              ),

              // ── Tabs ──────────────────────────────────────────────────────
              TabBar(
                labelStyle: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.amiri(fontSize: 16),
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: subtext,
                indicatorColor: AppColors.primaryBlue,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'السور'),
                  Tab(text: 'الأجزاء'),
                ],
              ),

              // ── Tab Views ─────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    // Surahs list
                    surahsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                          strokeWidth: 2.5,
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Text(
                          'حدث خطأ أثناء التحميل',
                          style: GoogleFonts.amiri(fontSize: 16, color: textColor),
                        ),
                      ),
                      data: (surahs) => ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: surahs.length,
                        itemBuilder: (_, i) => _SurahListTile(
                          surah: surahs[i],
                          isDark: isDark,
                          index: i,
                          onTap: () {
                            ref.read(lastReadProvider.notifier).save(
                                  surahId: surahs[i].id,
                                  surahNameAr: surahs[i].nameAr,
                                  surahNameEn: surahs[i].nameEn,
                                  ayahNumber: 1,
                                  pageNumber: surahs[i].pageNumber,
                                );
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => SurahReadingScreen(
                                  surahId: surahs[i].id,
                                  surahNameAr: surahs[i].nameAr,
                                  surahNameEn: surahs[i].nameEn,
                                  startPage: surahs[i].pageNumber,
                                ),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // Juz List
                    ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: 30,
                      itemBuilder: (_, i) {
                        final juz = i + 1;
                        final info = kJuzPages[juz]!;
                        return _JuzListTile(
                          juzNumber: juz,
                          pageNumber: info.page,
                          surahName: info.surah,
                          ayahSnippet: info.text,
                          isDark: isDark,
                          textColor: textColor,
                          subtext: subtext,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _QuranHeader extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color subtext;
  final LastRead lastRead;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;

  const _QuranHeader({
    required this.isDark,
    required this.textColor,
    required this.subtext,
    required this.lastRead,
    required this.searchCtrl,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'القرآن الكريم',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '١١٤ سورة • ٦٢٣٦ آية',
                    style: GoogleFonts.amiri(fontSize: 13, color: subtext),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MushafBrowserScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة...',
                    hintStyle: GoogleFonts.amiri(
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? AppColors.darkSubtext : AppColors.primaryBlue,
                    ),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkCardBackground
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdvancedSearchScreen()),
                    );
                  },
                  icon: const Icon(Icons.manage_search_rounded),
                  color: AppColors.primaryBlue,
                  tooltip: 'بحث متقدم في الآيات',
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
}

const kJuzPages = <int, ({int page, String surah, String text})>{
  1: (page: 1, surah: 'سورة الفاتحة', text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
  2: (page: 22, surah: 'سورة البقرة: 142', text: 'سَيَقُولُ السُّفَهَاءُ مِنَ النَّاسِ'),
  3: (page: 42, surah: 'سورة البقرة: 253', text: 'تِلْكَ الرُّسُلُ فَضَّلْنَا بَعْضَهُمْ'),
  4: (page: 62, surah: 'سورة آل عمران: 93', text: 'لَنْ تَنَالُوا الْبِرَّ حَتَّىٰ تُنْفِقُوا'),
  5: (page: 82, surah: 'سورة النساء: 24', text: 'وَالْمُحْصَنَاتُ مِنَ النِّسَاءِ'),
  6: (page: 102, surah: 'سورة النساء: 148', text: 'لَا يُحِبُّ اللَّهُ الْجَهْرَ بِالسُّوءِ'),
  7: (page: 122, surah: 'سورة المائدة: 82', text: 'وَإِذَا سَمِعُوا مَا أُنْزِلَ إِلَى الرَّسُولِ'),
  8: (page: 142, surah: 'سورة الأنعام: 111', text: 'وَلَوْ أَنَّنَا نَزَّلْنَا إِلَيْهِمُ الْمَلَائِكَةَ'),
  9: (page: 162, surah: 'سورة الأعراف: 88', text: 'قَالَ الْمَلَأُ الَّذِينَ اسْتَكْبَرُوا'),
  10: (page: 182, surah: 'سورة الأنفال: 41', text: 'وَاعْلَمُوا أَنَّمَا غَنِمْتُمْ مِنْ شَيْءٍ'),
  11: (page: 202, surah: 'سورة التوبة: 93', text: 'يَعْتَذِرُونَ إِلَيْكُمْ إِذَا رَجَعْتُمْ'),
  12: (page: 222, surah: 'سورة هود: 6', text: 'وَمَا مِنْ دَابَّةٍ فِي الْأَرْضِ'),
  13: (page: 242, surah: 'سورة يوسف: 53', text: 'وَمَا أُبَرِّئُ نَفْسِي إِنَّ النَّفْسَ'),
  14: (page: 262, surah: 'سورة الحجر: 1', text: 'الر تِلْكَ آيَاتُ الْكِتَابِ'),
  15: (page: 282, surah: 'سورة الإسراء: 1', text: 'سُبْحَانَ الَّذِي أَسْرَىٰ بِعَبْدِهِ'),
  16: (page: 302, surah: 'سورة الكهف: 75', text: 'قَالَ أَلَمْ أقل لك إنك لن تستطيع'),
  17: (page: 322, surah: 'سورة الأنبياء: 1', text: 'اقْتَرَبَ لِلنَّاسِ حِسَابُهُمْ'),
  18: (page: 342, surah: 'سورة المؤمنون: 1', text: 'قَدْ أَفْلَحَ الْمُؤْمِنُونَ'),
  19: (page: 362, surah: 'سورة الفرقان: 21', text: 'وَقَالَ الَّذِينَ لَا يَرْجُونَ لِقَاءَنَا'),
  20: (page: 382, surah: 'سورة النمل: 56', text: 'فَمَا كَانَ جَوَابَ قَوْمِهِ'),
  21: (page: 402, surah: 'سورة العنكبوت: 46', text: 'وَلَا تُجَادِلُوا أَهْلَ الْكِتَابِ'),
  22: (page: 422, surah: 'سورة الأحزاب: 31', text: 'وَمَنْ يَقْنُتْ مِنْكُنَّ لِلَّهِ وَرَسُولِهِ'),
  23: (page: 442, surah: 'سورة يس: 28', text: 'وَمَا أَنْزَلْنَا عَلَىٰ قَوْمِهِ مِنْ بَعْدِهِ'),
  24: (page: 462, surah: 'سورة الزمر: 32', text: 'فَمَنْ أَظْلَمُ مِمَّنْ كَذَبَ عَلَى اللَّهِ'),
  25: (page: 482, surah: 'سورة فصلت: 47', text: 'إِلَيْهِ يُرَدُّ عِلْمُ السَّاعَةِ'),
  26: (page: 502, surah: 'سورة الأحقاف: 1', text: 'حم تَنْزِيلُ الْكِتَابِ مِنَ اللَّهِ'),
  27: (page: 522, surah: 'سورة الذاريات: 31', text: 'قَالَ فَمَا خَطْبُكُمْ أَيُّهَا الْمُرْسَلُونَ'),
  28: (page: 542, surah: 'سورة المجادلة: 1', text: 'قَدْ سَمِعَ اللَّهُ قَوْلَ الَّتِي تُجَادِلُكَ'),
  29: (page: 562, surah: 'سورة الملك: 1', text: 'تَبَارَكَ الَّذِي بِيَدِهِ الْمُلْكُ'),
  30: (page: 582, surah: 'سورة النبأ: 1', text: 'عَمَّ يَتَسَاءَلُونَ عَنِ النَّبَإِ الْعَظِيمِ'),
};

class _JuzListTile extends ConsumerWidget {
  final int juzNumber;
  final int pageNumber;
  final String surahName;
  final String ayahSnippet;
  final bool isDark;
  final Color textColor;
  final Color subtext;

  const _JuzListTile({
    required this.juzNumber,
    required this.pageNumber,
    required this.surahName,
    required this.ayahSnippet,
    required this.isDark,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            ref.read(lastReadProvider.notifier).save(
                  surahId: 1,
                  surahNameAr: 'الجزء $juzNumber ($surahName)',
                  surahNameEn: 'Juz $juzNumber',
                  ayahNumber: 1,
                  pageNumber: pageNumber,
                );
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => SurahReadingScreen(
                  surahId: 1,
                  surahNameAr: 'الجزء $juzNumber ($surahName)',
                  surahNameEn: 'Juz $juzNumber',
                  startPage: pageNumber,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Juz number badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$juzNumber',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Juz Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'صفحة $pageNumber',
                            style: GoogleFonts.amiri(
                              fontSize: 12,
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'الجزء $juzNumber — $surahName',
                            style: GoogleFonts.scheherazadeNew(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.3,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '« $ayahSnippet »',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.amiri(
                          fontSize: 13,
                          color: subtext,
                          fontStyle: FontStyle.italic,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left_rounded, color: subtext),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Surah list tile ───────────────────────────────────────────────────────────

class _SurahListTile extends StatelessWidget {
  final Surah surah;
  final bool isDark;
  final int index;
  final VoidCallback onTap;

  const _SurahListTile({
    required this.surah,
    required this.isDark,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor =
        isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Surah number badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${surah.id}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Surah names
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        surah.nameAr,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.3,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${surah.ayahsCount} آية',
                            style: GoogleFonts.amiri(
                              fontSize: 12,
                              color: subtext,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: surah.isMakki
                                  ? const Color(0xFFF39C12).withValues(alpha: 0.15)
                                  : AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              surah.isMakki ? 'مكية' : 'مدنية',
                              style: GoogleFonts.amiri(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: surah.isMakki
                                    ? const Color(0xFFF39C12)
                                    : AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // English name + chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.nameEn,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: subtext,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: subtext,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
