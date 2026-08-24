import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/khatma_plan.dart';
import '../providers/khatma_provider.dart';
import 'khatma_setup_screen.dart';

// ── Import for navigating to Quran reading ────────────────────────────────────
// We use a callback/navigator pattern to avoid circular imports
typedef NavigateToPageFn = void Function(int pageNumber);

// ─────────────────────────────────────────────────────────────────────────────
// Khatma Dashboard Screen — Current Wird Display
// ─────────────────────────────────────────────────────────────────────────────

class KhatmaDashboardScreen extends ConsumerWidget {
  /// Optional callback to navigate to a specific Quran page in the reading screen.
  final NavigateToPageFn? onReadPage;

  const KhatmaDashboardScreen({super.key, this.onReadPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(khatmaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final surface = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'ختمتي',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: textColor, size: 20),
            tooltip: 'تعديل الختمة',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KhatmaSetupScreen()),
              );
            },
          ),
        ],
      ),
      body: plan.id == 'default' && plan.currentPage == 1 && plan.completedDays == 0
          ? _buildNoKhatma(context, textColor, subtext)
          : _buildDashboard(context, ref, plan, isDark, surface, textColor, subtext),
    );
  }

  // ── No khatma state ────────────────────────────────────────────────────────
  Widget _buildNoKhatma(BuildContext context, Color textColor, Color subtext) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, size: 80, color: AppColors.accentGold.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          Text(
            'لا توجد ختمة نشطة',
            style: GoogleFonts.scheherazadeNew(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ ختمتك الآن واجعل القرآن رفيقك',
            style: GoogleFonts.amiri(fontSize: 16, color: subtext),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KhatmaSetupScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: Text('ابدأ ختمة جديدة', style: GoogleFonts.scheherazadeNew(fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active khatma dashboard ────────────────────────────────────────────────
  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    KhatmaPlan plan,
    bool isDark,
    Color surface,
    Color textColor,
    Color subtext,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Wird range card ────────────────────────────────────────────────
          _WirdCard(plan: plan, isDark: isDark, surface: surface, textColor: textColor, subtext: subtext),
          const SizedBox(height: 20),

          // ── Progress bar ───────────────────────────────────────────────────
          _ProgressSection(plan: plan, isDark: isDark, surface: surface, textColor: textColor, subtext: subtext),
          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────────────────────────────
          _StatsRow(plan: plan, surface: surface, textColor: textColor, subtext: subtext),
          const SizedBox(height: 28),

          // ── اقرأ الورد CTA ─────────────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                if (onReadPage != null) {
                  onReadPage!(plan.todayStartPage);
                  Navigator.pop(context);
                } else {
                  // fallback: pop and let caller handle navigation
                  Navigator.pop(context, plan.todayStartPage);
                }
              },
              icon: const Icon(Icons.menu_book_rounded, size: 22),
              label: Text(
                'اقرأ الورد — ص ${plan.todayStartPage}–${plan.todayEndPage}',
                style: GoogleFonts.scheherazadeNew(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── أتممت القراءة CTA ──────────────────────────────────────────────
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: plan.isComplete
                  ? null
                  : () => _confirmCompletion(context, ref, plan),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text(
                'أتممت القراءة ✓',
                style: GoogleFonts.scheherazadeNew(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentGold,
                side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),

          if (plan.isComplete) ...[
            const SizedBox(height: 20),
            _CompletionBanner(surface: surface),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmCompletion(BuildContext context, WidgetRef ref, KhatmaPlan plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'تأكيد إتمام الورد',
          style: GoogleFonts.scheherazadeNew(fontWeight: FontWeight.bold, color: AppColors.accentGold),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          'هل أتممت قراءة الصفحات ${plan.todayStartPage}–${plan.todayEndPage}؟\n\nسيتقدم وردك غداً إلى الصفحة ${plan.todayEndPage + 1}.',
          style: GoogleFonts.amiri(fontSize: 16),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لا، لاحقاً', style: GoogleFonts.amiri()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black87,
            ),
            onPressed: () async {
              await ref.read(khatmaProvider.notifier).markDayComplete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'بارك الله فيك! اليوم ${plan.completedDays + 1} من ${plan.targetDays} ✓',
                      style: GoogleFonts.amiri(fontSize: 16),
                      textDirection: TextDirection.rtl,
                    ),
                    backgroundColor: AppColors.accentGold.withValues(alpha: 0.9),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: Text('نعم، أتممتها', style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Wird Card ─────────────────────────────────────────────────────────────────

class _WirdCard extends StatelessWidget {
  final KhatmaPlan plan;
  final bool isDark;
  final Color surface;
  final Color textColor;
  final Color subtext;

  const _WirdCard({
    required this.plan,
    required this.isDark,
    required this.surface,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F1714), const Color(0xFF14251D), const Color(0xFF1A3326)]
              : [const Color(0xFF14251D), const Color(0xFF1B382B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: AppColors.accentGold, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'ورد اليوم',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'اليوم ${plan.completedDays + 1} / ${plan.targetDays}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Page range display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageBadge(page: plan.todayStartPage, label: 'من صفحة'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Icon(Icons.arrow_back_rounded, color: AppColors.accentGold, size: 20),
                    Text(
                      '${plan.dailyPages} صفحة',
                      style: GoogleFonts.amiri(fontSize: 13, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              _PageBadge(page: plan.todayEndPage, label: 'إلى صفحة'),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'الجزء ${(plan.todayStartPage / 20).ceil()}',
            style: GoogleFonts.scheherazadeNew(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageBadge extends StatelessWidget {
  final int page;
  final String label;
  const _PageBadge({required this.page, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.amiri(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentGold.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.accentGold, width: 2),
          ),
          child: Center(
            child: Text(
              '$page',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.accentGold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Progress Section ──────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final KhatmaPlan plan;
  final bool isDark;
  final Color surface;
  final Color textColor;
  final Color subtext;

  const _ProgressSection({
    required this.plan,
    required this.isDark,
    required this.surface,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (plan.progressFraction * 100);
    final pastFraction = plan.completedDays / plan.targetDays;
    final currentFraction = 1.0 / plan.targetDays;
    final upcomingFraction = 1.0 - pastFraction - currentFraction;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تقدم الختمة',
                style: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tricolor progress bar: Past | Today | Upcoming
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  // Past (completed)
                  if (pastFraction > 0)
                    Flexible(
                      flex: (pastFraction * 1000).toInt().clamp(1, 1000),
                      child: Container(color: AppColors.accentGold),
                    ),
                  // Today (current)
                  Flexible(
                    flex: (currentFraction * 1000).toInt().clamp(1, 1000),
                    child: Container(color: AppColors.accentGold.withValues(alpha: 0.5)),
                  ),
                  // Upcoming
                  if (upcomingFraction > 0)
                    Flexible(
                      flex: (upcomingFraction.abs() * 1000).toInt().clamp(1, 1000),
                      child: Container(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressLabel(label: 'مكتمل', color: AppColors.accentGold),
              _ProgressLabel(label: 'اليوم', color: AppColors.accentGold.withValues(alpha: 0.5)),
              _ProgressLabel(label: 'متبقي', color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'صفحة ${plan.currentPage} من 604 • متبقي ${plan.daysRemaining} يوم',
            style: GoogleFonts.amiri(fontSize: 14, color: subtext),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _ProgressLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.amiri(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final KhatmaPlan plan;
  final Color surface;
  final Color textColor;
  final Color subtext;

  const _StatsRow({
    required this.plan,
    required this.surface,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'أيام مكتملة', value: '${plan.completedDays}', icon: Icons.check_circle_rounded, surface: surface, textColor: textColor, subtext: subtext)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'أيام متبقية', value: '${plan.daysRemaining}', icon: Icons.hourglass_bottom_rounded, surface: surface, textColor: textColor, subtext: subtext)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'صفحات / يوم', value: '${plan.dailyPages}', icon: Icons.book_rounded, surface: surface, textColor: textColor, subtext: subtext)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color surface;
  final Color textColor;
  final Color subtext;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentGold, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentGold),
          ),
          Text(
            label,
            style: GoogleFonts.amiri(fontSize: 12, color: subtext),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Completion Banner ─────────────────────────────────────────────────────────

class _CompletionBanner extends StatelessWidget {
  final Color surface;
  const _CompletionBanner({required this.surface});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مبارك! أتممت الختمة 🎉',
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'تقبل الله منك وجعلها في ميزان حسناتك',
                  style: GoogleFonts.amiri(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
