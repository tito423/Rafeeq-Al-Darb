import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/khatma_plan.dart';
import '../providers/khatma_provider.dart';

// ── Juz → page lookup (standard Uthmani mushaf) ──────────────────────────────
const _juzStartPage = [
  1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
  201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
  402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];

// Popular Surahs and their approximate starting page
const _popularSurahs = [
  (1,  'الفاتحة',        1),
  (2,  'البقرة',         2),
  (18, 'الكهف',        293),
  (36, 'يس',           440),
  (55, 'الرحمن',        531),
  (56, 'الواقعة',       534),
  (67, 'الملك',         562),
  (78, 'النبأ',          582),
];

// Daily quantity options
const _qtyOptions = [
  (DailyQtyType.pages,   1,  'صفحة واحدة / يوم'),
  (DailyQtyType.quarter, 1,  'ربع حزب / يوم — 2 صفحات'),
  (DailyQtyType.hizb,    1,  'حزب واحد / يوم — 4 صفحات'),
  (DailyQtyType.pages,   5,  '5 صفحات / يوم'),
  (DailyQtyType.pages,   10, '10 صفحات / يوم'),
  (DailyQtyType.half,    1,  'نصف جزء / يوم — 10 صفحات'),
  (DailyQtyType.juz,     1,  'جزء واحد / يوم — 20 صفحة'),
  (DailyQtyType.juz,     2,  'جزءان / يوم — 40 صفحة'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Khatma Setup Screen — Multi-step onboarding
// ─────────────────────────────────────────────────────────────────────────────

class KhatmaSetupScreen extends ConsumerStatefulWidget {
  const KhatmaSetupScreen({super.key});

  @override
  ConsumerState<KhatmaSetupScreen> createState() => _KhatmaSetupScreenState();
}

class _KhatmaSetupScreenState extends ConsumerState<KhatmaSetupScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _step = 0; // 0 = starting point, 1 = duration & qty

  // ── Step 1 state ───────────────────────────────────────────────────────────
  KhatmaStartType _startType = KhatmaStartType.beginning;
  int _selectedJuz = 1;
  int _selectedSurahPage = 1;
  int _customPage = 1;

  // ── Step 2 state ───────────────────────────────────────────────────────────
  int _targetDays = 30;
  int _qtyOptionIndex = 4; // default: 10 pages / day

  // ── computed ───────────────────────────────────────────────────────────────
  int get _resolvedStartPage {
    switch (_startType) {
      case KhatmaStartType.beginning: return 1;
      case KhatmaStartType.juz:       return _juzStartPage[_selectedJuz - 1];
      case KhatmaStartType.surah:     return _selectedSurahPage;
      case KhatmaStartType.page:      return _customPage.clamp(1, 604);
    }
  }

  int get _dailyPagesPreview {
    final opt = _qtyOptions[_qtyOptionIndex];
    switch (opt.$1) {
      case DailyQtyType.juz:     return opt.$2 * 20;
      case DailyQtyType.half:    return opt.$2 * 10;
      case DailyQtyType.hizb:    return opt.$2 * 4;
      case DailyQtyType.quarter: return opt.$2 * 2;
      case DailyQtyType.pages:   return opt.$2;
    }
  }

  void _nextStep() {
    if (_step == 0) {
      setState(() => _step = 1);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _startKhatma();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step = 0);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _startKhatma() async {
    final opt = _qtyOptions[_qtyOptionIndex];
    final plan = KhatmaPlan(
      id: 'khatma_${DateTime.now().millisecondsSinceEpoch}',
      name: 'ختمتي',
      targetDays: _targetDays,
      dailyQtyType: opt.$1,
      dailyQtyValue: opt.$2,
      startType: _startType,
      startPage: _resolvedStartPage,
      currentPage: _resolvedStartPage,
      currentJuz: ((_resolvedStartPage - 1) ~/ 20) + 1,
      startDate: DateTime.now(),
      completedDays: 0,
    );
    await ref.read(khatmaProvider.notifier).startNewKhatma(plan);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        leading: _step > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: Icon(Icons.close_rounded, color: textColor, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
        centerTitle: true,
        title: Text(
          'إعداد الختمة',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Step indicator ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: Row(
              children: List.generate(2, (i) {
                final isActive = i == _step;
                final isDone = i < _step;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDone || isActive
                          ? AppColors.accentGold
                          : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نقطة البداية',
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    color: _step == 0 ? AppColors.accentGold : subtext,
                    fontWeight: _step == 0 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                Text(
                  'المدة والورد اليومي',
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    color: _step == 1 ? AppColors.accentGold : subtext,
                    fontWeight: _step == 1 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Page view ───────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(isDark, surface, textColor, subtext),
                _buildStep2(isDark, surface, textColor, subtext),
              ],
            ),
          ),

          // ── Bottom CTA ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _step == 0 ? 'التالي' : 'ابدأ الختمة',
                      style: GoogleFonts.scheherazadeNew(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_step == 0 ? Icons.arrow_forward_ios_rounded : Icons.auto_stories_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Starting point ─────────────────────────────────────────────────
  Widget _buildStep1(bool isDark, Color surface, Color textColor, Color subtext) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'من أين تبدأ الختمة؟',
            style: GoogleFonts.scheherazadeNew(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // ── Option cards ──────────────────────────────────────────────────
          _StartOptionCard(
            icon: Icons.menu_book_rounded,
            title: 'من البداية',
            subtitle: 'تبدأ من سورة الفاتحة — الصفحة 1',
            isSelected: _startType == KhatmaStartType.beginning,
            isDark: isDark,
            surface: surface,
            onTap: () => setState(() => _startType = KhatmaStartType.beginning),
          ),
          const SizedBox(height: 10),
          _StartOptionCard(
            icon: Icons.format_list_numbered_rtl_rounded,
            title: 'من جزء بعينه',
            subtitle: 'الجزء $_selectedJuz',
            isSelected: _startType == KhatmaStartType.juz,
            isDark: isDark,
            surface: surface,
            onTap: () => setState(() => _startType = KhatmaStartType.juz),
            child: _startType == KhatmaStartType.juz
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_selectedJuz > 1) setState(() => _selectedJuz--);
                          },
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.accentGold),
                        ),
                        Expanded(
                          child: Text(
                            'الجزء $_selectedJuz',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.scheherazadeNew(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_selectedJuz < 30) setState(() => _selectedJuz++);
                          },
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.accentGold),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _StartOptionCard(
            icon: Icons.bookmark_rounded,
            title: 'من سورة محددة',
            subtitle: 'اختر سورة شهيرة',
            isSelected: _startType == KhatmaStartType.surah,
            isDark: isDark,
            surface: surface,
            onTap: () => setState(() => _startType = KhatmaStartType.surah),
            child: _startType == KhatmaStartType.surah
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularSurahs.map((s) {
                        final isSelected = _selectedSurahPage == s.$3;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSurahPage = s.$3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentGold
                                  : AppColors.accentGold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.$2,
                              style: GoogleFonts.scheherazadeNew(
                                fontSize: 15,
                                color: isSelected ? Colors.black87 : AppColors.accentGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _StartOptionCard(
            icon: Icons.insert_page_break_rounded,
            title: 'من صفحة بعينها',
            subtitle: 'صفحة $_customPage',
            isSelected: _startType == KhatmaStartType.page,
            isDark: isDark,
            surface: surface,
            onTap: () => setState(() => _startType = KhatmaStartType.page),
            child: _startType == KhatmaStartType.page
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_customPage > 1) setState(() => _customPage--);
                          },
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.accentGold),
                        ),
                        Expanded(
                          child: Text(
                            'ص $_customPage',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentGold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_customPage < 604) setState(() => _customPage++);
                          },
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.accentGold),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── STEP 2: Duration & daily qty ───────────────────────────────────────────
  Widget _buildStep2(bool isDark, Color surface, Color textColor, Color subtext) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المدة والورد اليومي',
            style: GoogleFonts.scheherazadeNew(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Days counter card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'مدة الختمة',
                  style: GoogleFonts.amiri(fontSize: 16, color: subtext),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CounterButton(
                      icon: Icons.remove_rounded,
                      onPressed: () {
                        if (_targetDays > 1) setState(() => _targetDays--);
                      },
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          '$_targetDays',
                          style: GoogleFonts.outfit(
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGold,
                          ),
                        ),
                        Text(
                          'يوم',
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 16,
                            color: subtext,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    _CounterButton(
                      icon: Icons.add_rounded,
                      onPressed: () {
                        if (_targetDays < 365) setState(() => _targetDays++);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick preset days
                Wrap(
                  spacing: 8,
                  children: [7, 10, 30, 60, 90, 365].map((d) {
                    return GestureDetector(
                      onTap: () => setState(() => _targetDays = d),
                      child: Chip(
                        label: Text(
                          '$d يوم',
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            color: _targetDays == d ? Colors.black87 : AppColors.accentGold,
                          ),
                        ),
                        backgroundColor: _targetDays == d
                            ? AppColors.accentGold
                            : AppColors.accentGold.withValues(alpha: 0.12),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily qty selector
          Text(
            'الورد اليومي',
            style: GoogleFonts.amiri(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_qtyOptions.length, (i) {
            final opt = _qtyOptions[i];
            final isSelected = i == _qtyOptionIndex;
            return GestureDetector(
              onTap: () => setState(() => _qtyOptionIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.15)
                      : surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.accentGold : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        opt.$3,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 17,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.accentGold : textColor,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 18),
                  ],
                ),
              ),
            );
          }),

          // Summary
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.4 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملخص الختمة',
                  style: GoogleFonts.amiri(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'البداية',
                  value: 'صفحة $_resolvedStartPage',
                ),
                _SummaryRow(
                  label: 'المدة',
                  value: '$_targetDays يوم',
                ),
                _SummaryRow(
                  label: 'الورد اليومي',
                  value: '$_dailyPagesPreview صفحة / يوم',
                ),
                _SummaryRow(
                  label: 'موعد الإتمام',
                  value: _computeFinishDate(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _computeFinishDate() {
    final finish = DateTime.now().add(Duration(days: _targetDays));
    final months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${finish.day} ${months[finish.month]} ${finish.year}';
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StartOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final Color surface;
  final VoidCallback onTap;
  final Widget? child;

  const _StartOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.surface,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentGold.withValues(alpha: 0.14)
              : surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.transparent,
            width: 1.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accentGold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.accentGold
                              : (isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.amiri(
                          fontSize: 13,
                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.accentGold, size: 22),
              ],
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _CounterButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentGold.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: AppColors.accentGold, size: 22),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.amiri(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSubtext
                  : AppColors.lightSubtext,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}
