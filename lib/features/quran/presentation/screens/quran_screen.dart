import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/surah.dart';
import '../providers/quran_provider.dart';
import 'surah_reading_screen.dart';

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
      body: SafeArea(
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

            // ── Surah list ────────────────────────────────────────────────
            Expanded(
              child: surahsAsync.when(
                loading: () => Center(
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
            ),
          ],
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

        // Juz chips row
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 30,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _JuzChip(
              juzNumber: i + 1,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _JuzChip extends StatelessWidget {
  final int juzNumber;
  final bool isDark;

  const _JuzChip({required this.juzNumber, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardBackground
            : AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        'الجزء $juzNumber',
        style: GoogleFonts.amiri(
          fontSize: 12,
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
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
