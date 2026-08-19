import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../quran/presentation/providers/quran_provider.dart';
import '../../../quran/presentation/screens/surah_reading_screen.dart';
import '../providers/home_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clockTimer;
  String _timeStr = '';
  String _dateStr = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    );
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeStr = DateFormat('HH:mm:ss').format(now);
        _dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Prayer times hero ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PrayerTimesHero(
                isDark: isDark,
                timeStr: _timeStr,
                dateStr: _dateStr,
              ),
            ),

            // ── Prayer times strip ────────────────────────────────────────
            SliverToBoxAdapter(child: _PrayerTimesStrip(isDark: isDark)),

            // ── Continue Reading ──────────────────────────────────────────
            SliverToBoxAdapter(child: _ContinueReadingCard(isDark: isDark)),

            // ── Daily Wird ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _DailyWirdCard(isDark: isDark)),

            // ── Hadith RGB Card ───────────────────────────────────────────
            SliverToBoxAdapter(child: _HadithCard(isDark: isDark)),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Prayer times hero ─────────────────────────────────────────────────────────

class _PrayerTimesHero extends ConsumerWidget {
  final bool isDark;
  final String timeStr;
  final String dateStr;

  const _PrayerTimesHero({
    required this.isDark,
    required this.timeStr,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerAsync = ref.watch(prayerTimesProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Stack(
        children: [
          // Background gradient
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppColors.darkSurface, AppColors.darkBackground] 
                    : [AppColors.primaryBlue, const Color(0xFF0A2A45)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Stars / decorative pattern
          Positioned.fill(child: CustomPaint(painter: _StarPainter())),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left controls: Settings, Theme
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            ref.read(currentTabProvider.notifier).state = 5; // Go to More Settings
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'الإعدادات',
                        ),
                        IconButton(
                          onPressed: () {
                            ref.read(themeProvider.notifier).toggleTheme();
                          },
                          icon: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: Colors.white,
                          ),
                          tooltip: 'تغيير المظهر',
                        ),
                        // Note: Language/RGB toggle can be added here later
                      ],
                    ),
                    // Gregorian (Right in RTL)
                    Expanded(
                      child: Text(
                        dateStr,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    // Clock (Center)
                    Expanded(
                      flex: 2,
                      child: Text(
                        timeStr,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: GoogleFonts.amiri(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    // Hijri (Left in RTL)
                    Expanded(
                      child: prayerAsync.when(
                        data: (pt) => Text(
                          pt.hijriDate,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.amiri(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Upcoming Prayer
                prayerAsync.when(
                  data: (pt) {
                    final next = PrayerTimesService().getNextPrayer(pt);
                    return GestureDetector(
                      onTap: () {
                        // Navigate to Prayer Settings Screen (Index 1)
                        ref.read(currentTabProvider.notifier).state = 1;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'الصلاة القادمة',
                              style: GoogleFonts.amiri(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              next,
                              style: GoogleFonts.amiri(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final diff = PrayerTimesService().getTimeUntilNextPrayer(pt);
                                if (diff == null) return const SizedBox.shrink();
                                
                                // Format without seconds: - h:m -
                                final h = diff.inHours.toString().padLeft(2, '0');
                                final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
                                
                                return Text(
                                  'بعد $h س $m د',
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 1,
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // City name
                prayerAsync.when(
                  data: (pt) => pt.city.isNotEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.accentGold,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pt.city,
                              style: GoogleFonts.amiri(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Star decorator ────────────────────────────────────────────────────────────

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (int i = 0; i < 30; i++) {
      final x = (i * 73.13) % size.width;
      final y = (i * 47.71) % size.height;
      final r = (i % 3 == 0) ? 2.5 : 1.5;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Prayer times strip ────────────────────────────────────────────────────────

class _PrayerTimesStrip extends ConsumerWidget {
  final bool isDark;
  const _PrayerTimesStrip({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerAsync = ref.watch(prayerTimesProvider);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: prayerAsync.when(
        data: (pt) {
          final nextPrayer = PrayerTimesService().getNextPrayer(pt);
          final prayers = [
            ('الفجر', pt.fajr, AppColors.fajrColor),
            ('الشروق', pt.sunrise, AppColors.sunriseColor),
            ('الظهر', pt.dhuhr, AppColors.dhuhrColor),
            ('العصر', pt.asr, AppColors.asrColor),
            ('المغرب', pt.maghrib, AppColors.maghribColor),
            ('العشاء', pt.isha, AppColors.ishaColor),
          ];

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: prayers.map((p) {
                final isNext = p.$1 == nextPrayer;
                return _PrayerTimeChip(
                  name: p.$1,
                  time: p.$2,
                  color: p.$3,
                  isNext: isNext,
                  isDark: isDark,
                  onTap: () => ref.read(currentTabProvider.notifier).state = 1,
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_rounded,
                color: AppColors.lightSubtext,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'تعذّر الحصول على مواقيت الصلاة',
                style: GoogleFonts.amiri(
                  fontSize: 13,
                  color: AppColors.lightSubtext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerTimeChip extends StatefulWidget {
  final String name;
  final String time;
  final Color color;
  final bool isNext;
  final bool isDark;
  final VoidCallback onTap;

  const _PrayerTimeChip({
    required this.name,
    required this.time,
    required this.color,
    required this.isNext,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PrayerTimeChip> createState() => _PrayerTimeChipState();
}

class _PrayerTimeChipState extends State<_PrayerTimeChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => _controller.forward(),
      onPanEnd: (_) => _controller.reverse(),
      onPanCancel: () => _controller.reverse(),
      onTap: () {
        // Navigate to Prayer settings (Index 1)
        widget.onTap();
        _controller.forward().then((_) => _controller.reverse());
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isNext ? widget.color : widget.color.withValues(alpha: widget.isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: widget.isNext ? Border.all(color: widget.color, width: 2) : Border.all(color: widget.color.withValues(alpha: 0.2), width: 1),
            boxShadow: widget.isNext ? [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                style: GoogleFonts.amiri(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.isNext ? Colors.white : widget.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.time,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isNext
                      ? Colors.white
                      : (widget.isDark
                            ? AppColors.darkOnSurface
                            : AppColors.lightOnSurface),
                ),
              ),
              if (widget.isNext)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'القادمة',
                    style: GoogleFonts.amiri(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Continue reading card ─────────────────────────────────────────────────────

class _ContinueReadingCard extends ConsumerWidget {
  final bool isDark;
  const _ContinueReadingCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRead = ref.watch(lastReadProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahReadingScreen(
              surahId: lastRead.surahId,
              surahNameAr: lastRead.surahNameAr,
              surahNameEn: lastRead.surahNameEn,
              startPage: lastRead.pageNumber,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.primaryBlue,
          gradient: isDark ? const LinearGradient(
            colors: [Color(0xFF0F1714), Color(0xFF14251D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative icon
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.menu_book_rounded,
                size: 130,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.import_contacts_rounded,
                      color: AppColors.accentGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'متابعة القراءة',
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lastRead.surahNameAr,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'آية ${lastRead.ayahNumber} • صفحة ${lastRead.pageNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'استمر في القراءة',
                    style: GoogleFonts.amiri(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkBackground : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Wird card ───────────────────────────────────────────────────────────

class _DailyWirdCard extends ConsumerWidget {
  final bool isDark;
  const _DailyWirdCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wird = ref.watch(dailyWirdProvider);
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,

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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Icon(
                Icons.track_changes_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'متابعة الختمة',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '${wird.morningCompleted + wird.eveningCompleted}/${wird.morningTotal + wird.eveningTotal}',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Morning
              Expanded(
                child: _WirdProgress(
                  label: 'أذكار الصباح',
                  completed: wird.morningCompleted,
                  total: wird.morningTotal,
                  progress: wird.morningProgress,
                  color: const Color(0xFFE17055),
                  icon: Icons.wb_sunny_rounded,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(dailyWirdProvider.notifier).incrementMorning(),
                ),
              ),
              const SizedBox(width: 12),
              // Evening
              Expanded(
                child: _WirdProgress(
                  label: 'أذكار المساء',
                  completed: wird.eveningCompleted,
                  total: wird.eveningTotal,
                  progress: wird.eveningProgress,
                  color: const Color(0xFF6C5CE7),
                  icon: Icons.nights_stay_rounded,
                  isDark: isDark,
                  onTap: () =>
                      ref.read(dailyWirdProvider.notifier).incrementEvening(),
                ),
              ),
            ],
          ),
          if (wird.morningDone && wird.eveningDone) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'أحسنت! أكملت ورد اليوم 🌟',
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WirdProgress extends StatelessWidget {
  final String label;
  final int completed;
  final int total;
  final double progress;
  final Color color;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _WirdProgress({
    required this.label,
    required this.completed,
    required this.total,
    required this.progress,
    required this.color,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completed/$total',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.amiri(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkOnSurface
                    : AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hadith Card (Islamic Ornamental & Animated) ───────────────────────────────

class _HadithCard extends StatefulWidget {
  final bool isDark;
  const _HadithCard({required this.isDark});

  @override
  State<_HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<_HadithCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _hadithText = 'جاري التحميل...';
  String _hadithSource = 'صحيح البخاري';
  bool _isLoading = true;

  static const List<({String id, String nameAr, String path})> _nineBooks = [
    (id: 'bukhari', nameAr: 'صحيح البخاري', path: 'assets/data/hadith/bukhari.json'),
    (id: 'muslim', nameAr: 'صحيح مسلم', path: 'assets/data/hadith/muslim.json'),
    (id: 'abudawud', nameAr: 'سنن أبي داود', path: 'assets/data/hadith/abudawud.json'),
    (id: 'tirmidhi', nameAr: 'جامع الترمذي', path: 'assets/data/hadith/tirmidhi.json'),
    (id: 'nasai', nameAr: 'سنن النسائي', path: 'assets/data/hadith/nasai.json'),
    (id: 'ibnmajah', nameAr: 'سنن ابن ماجه', path: 'assets/data/hadith/ibnmajah.json'),
    (id: 'malik', nameAr: 'موطأ مالك', path: 'assets/data/hadith/malik.json'),
    (id: 'nawawi', nameAr: 'الأربعون النووية', path: 'assets/data/hadith/nawawi.json'),
    (id: 'qudsi', nameAr: 'الأحاديث القدسية', path: 'assets/data/hadith/qudsi.json'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadRandomHadith();
  }

  Future<void> _loadRandomHadith() async {
    setState(() => _isLoading = true);
    final random = Random();
    final shuffledBooks = List<({String id, String nameAr, String path})>.from(_nineBooks)..shuffle(random);

    for (final book in shuffledBooks) {
      try {
        final jsonString = await rootBundle.loadString(book.path);
        final Map<String, dynamic> data = jsonDecode(jsonString);
        final List<dynamic> hadiths = data['hadiths'] ?? [];
        if (hadiths.isNotEmpty) {
          // Try a few random samples in case some hadith entry has empty text
          for (int attempt = 0; attempt < 5; attempt++) {
            final randomHadith = hadiths[random.nextInt(hadiths.length)];
            final rawText = (randomHadith['text'] ?? '').toString().trim();
            if (rawText.isNotEmpty && rawText.length > 15) {
              final hadithNumber = randomHadith['hadithnumber'] ??
                  randomHadith['arabicnumber'] ??
                  randomHadith['number'] ??
                  '';
              if (mounted) {
                setState(() {
                  _hadithText = rawText;
                  _hadithSource = hadithNumber != ''
                      ? '${book.nameAr} • رقم $hadithNumber'
                      : book.nameAr;
                  _isLoading = false;
                });
              }
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('HadithCard: error loading ${book.nameAr}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _hadithText = 'عن عُمَرَ بْنِ الْخَطَّابِ رَضِيَ اللَّهُ عَنْهُ قَالَ: سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَقُولُ: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى، فَمَنْ كَانَتْ هِجْرَتُهُ إِلَى دُنْيَا يُصِيبُهَا، أَوْ إِلَى امْرَأَةٍ يَنْكِحُهَا، فَهِجْرَتُهُ إِلَى مَا هَاجَرَ إِلَيْهِ".';
        _hadithSource = 'متفق عليه • صحيح البخاري';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold1 = Color(0xFFD4AF37);
    const gold2 = Color(0xFFF3E5AB);
    const emerald1 = Color(0xFF1B4D3E);
    const emerald2 = Color(0xFF0C2B22);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: SweepGradient(
              center: FractionalOffset.center,
              startAngle: 0.0,
              endAngle: 3.14159 * 2,
              colors: [
                gold1,
                emerald1,
                gold2,
                widget.isDark ? emerald2 : const Color(0xFF1A365D),
                gold1,
              ],
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isDark ? gold1 : emerald1).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF121B18)
                  : const Color(0xFFFAF8F2),
              borderRadius: BorderRadius.circular(23.5),
            ),
            child: Stack(
              children: [
                // Islamic ornamental corner painter
                Positioned.fill(
                  child: CustomPaint(
                    painter: _IslamicCornerPainter(
                      color: gold1.withValues(alpha: widget.isDark ? 0.25 : 0.2),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with Islamic styling
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 1,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, gold1.withValues(alpha: 0.8)],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star_rate_rounded,
                            color: gold1,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'حديث شريف',
                            style: GoogleFonts.amiri(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark ? gold2 : const Color(0xFF8C6B14),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.star_rate_rounded,
                            color: gold1,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 1,
                            width: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [gold1.withValues(alpha: 0.8), Colors.transparent],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Opening quote symbol
                      Text(
                        '❝',
                        style: GoogleFonts.amiri(
                          fontSize: 28,
                          color: gold1.withValues(alpha: 0.7),
                          height: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Hadith Text (Full height, no truncation)
                      _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(color: gold1, strokeWidth: 3),
                            )
                          : Text(
                              _hadithText,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: GoogleFonts.amiri(
                                fontSize: 18.5,
                                height: 2.0,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : const Color(0xFF1E293B),
                              ),
                            ),

                      const SizedBox(height: 8),
                      // Closing quote symbol
                      Text(
                        '❞',
                        style: GoogleFonts.amiri(
                          fontSize: 28,
                          color: gold1.withValues(alpha: 0.7),
                          height: 0.6,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action bar: Source badge + Copy button + Shuffle button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: gold1.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: gold1.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmark_added_rounded, color: gold1, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  _hadithSource,
                                  style: GoogleFonts.amiri(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? gold2 : const Color(0xFF785B0C),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action Buttons: Copy and Shuffle
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Copy Button
                              IconButton(
                                tooltip: 'نسخ الحديث',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: '$_hadithText\n\n[$_hadithSource - تطبيق رفيق الدرب]',
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'تم نسخ الحديث الشريف',
                                            style: GoogleFonts.amiri(fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: emerald1,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.copy_rounded,
                                  size: 19,
                                  color: widget.isDark ? gold2 : const Color(0xFF64748B),
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: gold1.withValues(alpha: 0.08),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Shuffle / Refresh Button
                              IconButton(
                                tooltip: 'حديث آخر',
                                onPressed: _loadRandomHadith,
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: gold1,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: gold1.withValues(alpha: 0.12),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Islamic Pattern Painter for Hadith Card ────────────────────────────────────

class _IslamicCornerPainter extends CustomPainter {
  final Color color;
  const _IslamicCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Center star pattern
    _drawCenterStar(canvas, paint, fillPaint, size.width / 2, size.height / 2, size.width * 0.3);

    const cornerSize = 40.0;
    const offset = 12.0;

    // Top-Left Corner
    _drawCorner(canvas, paint, offset, offset, cornerSize, 1, 1);
    // Top-Right Corner
    _drawCorner(canvas, paint, size.width - offset, offset, cornerSize, -1, 1);
    // Bottom-Left Corner
    _drawCorner(canvas, paint, offset, size.height - offset, cornerSize, 1, -1);
    // Bottom-Right Corner
    _drawCorner(canvas, paint, size.width - offset, size.height - offset, cornerSize, -1, -1);
  }

  void _drawCenterStar(Canvas canvas, Paint paint, Paint fill, double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);

      // Inner point for 8-pointed star
      final innerAngle = angle + 3.14159 / 8;
      final ix = cx + (r * 0.4) * cos(innerAngle);
      final iy = cy + (r * 0.4) * sin(innerAngle);
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, paint);
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double length,
    double dx,
    double dy,
  ) {
    final path = Path();
    
    // Outer Arabesque border
    path.moveTo(x, y + length * dy);
    path.lineTo(x, y);
    path.lineTo(x + length * dx, y);

    // Intricate inner arcs
    path.moveTo(x + 10 * dx, y);
    path.quadraticBezierTo(x + 10 * dx, y + 10 * dy, x, y + 10 * dy);
    
    path.moveTo(x + 20 * dx, y);
    path.quadraticBezierTo(x + 20 * dx, y + 20 * dy, x, y + 20 * dy);

    path.moveTo(x + 30 * dx, y);
    path.quadraticBezierTo(x + 30 * dx, y + 30 * dy, x, y + 30 * dy);

    canvas.drawPath(path, paint);

    // Corner decorative dots
    canvas.drawCircle(Offset(x + 5 * dx, y + 5 * dy), 2, paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(x + 15 * dx, y + 15 * dy), 1.5, paint);
    canvas.drawCircle(Offset(x + 25 * dx, y + 25 * dy), 1.0, paint);
    
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(covariant _IslamicCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
