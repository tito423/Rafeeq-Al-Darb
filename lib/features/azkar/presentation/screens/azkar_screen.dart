import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'azkar_detail_screen.dart';

// ── Azkar categories config ───────────────────────────────────────────────────

class _AzkarCategory {
  final String key; // DB category key
  final String nameAr;
  final IconData icon;
  final List<Color> gradient;
  final String description;

  const _AzkarCategory({
    required this.key,
    required this.nameAr,
    required this.icon,
    required this.gradient,
    required this.description,
  });
}

const _categories = [
  _AzkarCategory(
    key: 'صباح',
    nameAr: 'أذكار الصباح',
    icon: Icons.wb_sunny_rounded,
    gradient: [AppColors.primaryBlue, Color(0xFF1B3328)],
    description: 'ابدأ يومك بذكر الله',
  ),
  _AzkarCategory(
    key: 'مساء',
    nameAr: 'أذكار المساء',
    icon: Icons.nights_stay_rounded,
    gradient: [Color(0xFF14251D), Color(0xFF0F1714)],
    description: 'اختم يومك بذكر الله',
  ),
  _AzkarCategory(
    key: 'نوم',
    nameAr: 'أذكار النوم',
    icon: Icons.bedtime_rounded,
    gradient: [Color(0xFF2C3E35), Color(0xFF1B2620)],
    description: 'أذكار قبل النوم',
  ),
  _AzkarCategory(
    key: 'تسبيح',
    nameAr: 'التسبيح والتحميد',
    icon: Icons.auto_awesome_rounded,
    gradient: [AppColors.primaryBlue, AppColors.primaryBlue2],
    description: 'سبحان الله وبحمده',
  ),
  _AzkarCategory(
    key: 'استغفار',
    nameAr: 'الاستغفار',
    icon: Icons.refresh_rounded,
    gradient: [Color(0xFF1B3328), AppColors.primaryBlue],
    description: 'أستغفر الله العظيم',
  ),
  _AzkarCategory(
    key: 'دعاء',
    nameAr: 'أدعية قرآنية',
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFFB59355), Color(0xFF8A6D3B)],
    description: 'من آيات القرآن الكريم',
  ),
  _AzkarCategory(
    key: 'صلاة',
    nameAr: 'أذكار الصلاة',
    icon: Icons.mosque_rounded,
    gradient: [Color(0xFF8A6D3B), Color(0xFF5E4926)],
    description: 'أذكار ما بعد الصلاة',
  ),
  _AzkarCategory(
    key: 'متنوع',
    nameAr: 'أذكار متنوعة',
    icon: Icons.favorite_rounded,
    gradient: [AppColors.accentGold, Color(0xFFB59355)],
    description: 'أذكار وأدعية شتى',
  ),
];

// ── Azkar screen ──────────────────────────────────────────────────────────────

class AzkarScreen extends ConsumerWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C5CE7,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFF6C5CE7),
                            size: 26,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'الأذكار والأدعية',
                              style: GoogleFonts.scheherazadeNew(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'من حصن المسلم وكتب السنة',
                              style: GoogleFonts.amiri(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Featured daily azkar banner ───────────────────────────────
            SliverToBoxAdapter(child: _FeaturedBanner(isDark: isDark)),

            // ── Section header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text(
                  'اختر نوع الذكر',
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),

            // ── Category grid ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.2,
                children: _categories
                    .map((cat) => _CategoryCard(category: cat, isDark: isDark))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Featured banner ───────────────────────────────────────────────────────────

class _FeaturedBanner extends StatelessWidget {
  final bool isDark;
  const _FeaturedBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isMorning = hour >= 4 && hour < 12;

    final cat = isMorning ? _categories[0] : _categories[1];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AzkarDetailScreen(
            categoryKey: cat.key,
            categoryName: cat.nameAr,
            gradientColors: cat.gradient,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cat.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cat.gradient.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                cat.icon,
                size: 100,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(cat.icon, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMorning
                            ? '🌅 وقت أذكار الصباح'
                            : '🌙 وقت أذكار المساء',
                        style: GoogleFonts.amiri(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        cat.nameAr,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ابدأ الآن',
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _AzkarCategory category;
  final bool isDark;

  const _CategoryCard({required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AzkarDetailScreen(
            categoryKey: category.key,
            categoryName: category.nameAr,
            gradientColors: category.gradient,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: category.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: category.gradient.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative pattern
            Positioned(
              right: -8,
              bottom: -8,
              child: Icon(
                category.icon,
                size: 70,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(category.icon, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(
                    category.nameAr,
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: GoogleFonts.amiri(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
