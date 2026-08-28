import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../quran/data/datasources/quran_db_helper.dart';
import '../../../quran/domain/models/zikr.dart';
import '../providers/azkar_settings_provider.dart';

// ── Azkar detail — card-based swipeable reader ────────────────────────────────

class AzkarDetailScreen extends ConsumerStatefulWidget {
  final String categoryKey;
  final String categoryName;
  final List<Color> gradientColors;

  const AzkarDetailScreen({
    super.key,
    required this.categoryKey,
    required this.categoryName,
    required this.gradientColors,
  });

  @override
  ConsumerState<AzkarDetailScreen> createState() => _AzkarDetailScreenState();
}

class _AzkarDetailScreenState extends ConsumerState<AzkarDetailScreen>
    with TickerProviderStateMixin {
  List<Zikr> _azkar = [];
  bool _loading = true;
  int _currentIndex = 0;

  // Per-zikr counters
  final Map<int, int> _counters = {};

  late final PageController _pageCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadAzkar();
  }

  Future<void> _loadAzkar() async {
    final rawList = await QuranDbHelper().getAzkarByCategory(widget.categoryKey);
    
    // Remove duplicates based on normalized content (ignoring tashkeel, spaces, punctuation)
    String normalize(String s) {
      return s
          .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
          .replaceAll(RegExp(r'[أإآ]'), 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll('ة', 'ه')
          .replaceAll(RegExp(r'[^\s\u0600-\u06FF0-9]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final seen = <String>{};
    final list = <Zikr>[];
    for (final z in rawList) {
      final key = normalize(z.content);
      final uniqueKey = key.length > 30 ? key.substring(0, 30) : key;
      if (uniqueKey.isNotEmpty && seen.add(uniqueKey)) {
        list.add(z);
      }
    }

    if (mounted) {
      setState(() {
        _azkar = list;
        _loading = false;
        // Initialize counters
        for (final z in list) {
          _counters[z.id] = 0;
        }
      });
    }
  }

  void _increment() {
    if (_azkar.isEmpty) return;
    final zikr = _azkar[_currentIndex];
    final current = _counters[zikr.id] ?? 0;

    if (ref.read(azkarSettingsProvider).hapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());

    setState(() => _counters[zikr.id] = current + 1);

    // Auto-advance when count is reached
    if (current + 1 >= zikr.countInt) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _currentIndex < _azkar.length - 1) {
          _pageCtrl.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    final zikr = _azkar[_currentIndex];
    setState(() => _counters[zikr.id] = 0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Custom AppBar ─────────────────────────────────────────────
          _AzkarAppBar(
            categoryName: widget.categoryName,
            gradientColors: widget.gradientColors,
            currentIndex: _currentIndex,
            total: _azkar.length,
            isDark: isDark,
            onBack: () => Navigator.pop(context),
          ),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.gradientColors.first,
                      strokeWidth: 2.5,
                    ),
                  )
                : _azkar.isEmpty
                    ? _EmptyState(gradientColors: widget.gradientColors)
                    : PageView.builder(
                        controller: _pageCtrl,
                        itemCount: _azkar.length,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemBuilder: (_, i) => _ZikrCard(
                          zikr: _azkar[i],
                          counter: _counters[_azkar[i].id] ?? 0,
                          isDark: isDark,
                          gradientColors: widget.gradientColors,
                          pulseAnim: _pulseAnim,
                          onTap: _increment,
                          onReset: _reset,
                          isActive: i == _currentIndex,
                        ),
                      ),
          ),

          // ── Fast Navigation Slider ──────────────────────────────────────
          if (_azkar.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: widget.gradientColors.first,
                  inactiveTrackColor: widget.gradientColors.first.withValues(alpha: 0.2),
                  thumbColor: widget.gradientColors.first,
                  overlayColor: widget.gradientColors.first.withValues(alpha: 0.1),
                  trackHeight: 4.0,
                ),
                child: Slider(
                  value: _currentIndex.toDouble(),
                  min: 0,
                  max: (_azkar.length - 1).toDouble(),
                  divisions: _azkar.length > 1 ? _azkar.length - 1 : 1,
                  onChanged: (val) {
                    final index = val.toInt();
                    if (index != _currentIndex) {
                      setState(() => _currentIndex = index);
                      _pageCtrl.jumpToPage(index);
                    }
                  },
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _AzkarAppBar extends StatelessWidget {
  final String categoryName;
  final List<Color> gradientColors;
  final int currentIndex;
  final int total;
  final bool isDark;
  final VoidCallback onBack;

  const _AzkarAppBar({
    required this.categoryName,
    required this.gradientColors,
    required this.currentIndex,
    required this.total,
    required this.isDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (currentIndex + 1) / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          categoryName,
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (total > 0)
                          Text(
                            '${currentIndex + 1} / $total',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final hapticEnabled = ref.watch(azkarSettingsProvider).hapticFeedbackEnabled;
                      return IconButton(
                        icon: Icon(
                          hapticEnabled ? Icons.notifications_active : Icons.notifications_off,
                          color: Colors.white,
                        ),
                        onPressed: () => ref.read(azkarSettingsProvider.notifier).toggleHapticFeedback(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Zikr card ─────────────────────────────────────────────────────────────────

class _ZikrCard extends StatelessWidget {
  final Zikr zikr;
  final int counter;
  final bool isDark;
  final List<Color> gradientColors;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final bool isActive;

  const _ZikrCard({
    required this.zikr,
    required this.counter,
    required this.isDark,
    required this.gradientColors,
    required this.pulseAnim,
    required this.onTap,
    required this.onReset,
    required this.isActive,
  });

  bool get isComplete => counter >= zikr.countInt;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // ── Zikr text card ────────────────────────────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Description
                    if (zikr.description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: gradientColors.first.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          zikr.description,
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            color: gradientColors.first,
                            fontWeight: FontWeight.w600,
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Arabic text — main zikr
                    Text(
                      zikr.content,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.scheherazadeNew(
                        fontSize: 24,
                        height: 2.0,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),

                    // Virtue text
                    if (zikr.fadl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '✦ ${zikr.fadl}',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(
                          fontSize: 13,
                          color: gradientColors.first,
                          fontStyle: FontStyle.italic,
                          height: 1.7,
                        ),
                      ),
                    ],

                    // Reference
                    if (zikr.reference.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(color: subtext.withValues(alpha: 0.2)),
                      const SizedBox(height: 4),
                      Text(
                        zikr.reference,
                        style: GoogleFonts.amiri(
                          fontSize: 12,
                          color: subtext,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Counter row ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset
              GestureDetector(
                onTap: onReset,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subtext.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: subtext,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Tap counter button
              GestureDetector(
                onTap: isComplete ? null : onTap,
                child: AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: isActive ? pulseAnim.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: isComplete
                          ? LinearGradient(
                              colors: [AppColors.success, const Color(0xFF00CEC9)],
                            )
                          : LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isComplete ? AppColors.success : gradientColors.first)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isComplete)
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 32)
                          else
                            Text(
                              '$counter',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          Text(
                            isComplete ? 'تم!' : '/ ${zikr.countInt}',
                            style: GoogleFonts.amiri(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Count target
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gradientColors.first.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${zikr.countInt}×',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: gradientColors.first,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Navigation dots ───────────────────────────────────────────────────────────

class _NavigationDots extends StatelessWidget {
  final int count;
  final int current;
  final Color color;
  final bool isDark;

  const _NavigationDots({
    required this.count,
    required this.current,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final visible = count > 1;
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count.clamp(0, 20), // max 20 dots
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current
                  ? color
                  : color.withValues(alpha: isDark ? 0.3 : 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final List<Color> gradientColors;
  const _EmptyState({required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: gradientColors.first),
          const SizedBox(height: 16),
          Text(
            'لا توجد أذكار في هذه الفئة حالياً',
            style: GoogleFonts.amiri(fontSize: 16, color: gradientColors.first),
          ),
        ],
      ),
    );
  }
}
