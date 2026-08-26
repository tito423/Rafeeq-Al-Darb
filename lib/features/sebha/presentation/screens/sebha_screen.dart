import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

// ── Presets ───────────────────────────────────────────────────────────────────

class _Preset {
  final String arabic;
  final int target;
  final Color color;
  const _Preset(this.arabic, this.target, this.color);
}

const _presets = [
  _Preset('سُبْحَانَ اللَّهِ', 33, Color(0xFF0984E3)),
  _Preset('الْحَمْدُ لِلَّهِ', 33, Color(0xFF00B894)),
  _Preset('اللَّهُ أَكْبَرُ', 34, Color(0xFF6C5CE7)),
  _Preset('لَا إِلَهَ إِلَّا اللَّهُ', 100, Color(0xFFE5A93C)),
  _Preset('اسْتَغْفِرُ اللَّهَ', 100, Color(0xFFE17055)),
];

// ── State ─────────────────────────────────────────────────────────────────────

class _SebhaState {
  final int presetIndex;
  final int count;
  final int sessionTotal;

  const _SebhaState({
    this.presetIndex = 0,
    this.count = 0,
    this.sessionTotal = 0,
  });

  _Preset get preset => _presets[presetIndex];
  double get progress =>
      preset.target > 0 ? (count % preset.target) / preset.target : 0;
  bool get isRoundComplete => count > 0 && count % preset.target == 0;

  _SebhaState copyWith({int? presetIndex, int? count, int? sessionTotal}) =>
      _SebhaState(
        presetIndex: presetIndex ?? this.presetIndex,
        count: count ?? this.count,
        sessionTotal: sessionTotal ?? this.sessionTotal,
      );
}

class _SebhaNotifier extends StateNotifier<_SebhaState> {
  _SebhaNotifier() : super(const _SebhaState());

  void increment() {
    HapticFeedback.lightImpact();
    final newCount = state.count + 1;
    final newTotal = state.sessionTotal + 1;
    if (newCount % state.preset.target == 0) {
      HapticFeedback.heavyImpact();
    }
    state = state.copyWith(count: newCount, sessionTotal: newTotal);
  }

  void reset() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(count: 0);
  }

  void resetAll() {
    HapticFeedback.heavyImpact();
    state = const _SebhaState();
  }

  void setPreset(int index) {
    state = _SebhaState(presetIndex: index);
  }
}

final _sebhaProvider =
    StateNotifierProvider<_SebhaNotifier, _SebhaState>((_) => _SebhaNotifier());

// ─────────────────────────────────────────────────────────────────────────────
// Sebha Screen
// ─────────────────────────────────────────────────────────────────────────────

class SebhaScreen extends ConsumerWidget {
  const SebhaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sebha = ref.watch(_sebhaProvider);
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final accentColor = sebha.preset.color;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _showResetConfirm(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded,
                          color: AppColors.error, size: 22),
                    ),
                  ),
                  Text(
                    'المسبحة الرقمية',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'المجموع: ${sebha.sessionTotal}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Preset selector (Full names & PageView indicators) ────────
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isSelected = i == sebha.presetIndex;
                  return GestureDetector(
                    onTap: () => ref.read(_sebhaProvider.notifier).setPreset(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _presets[i].color
                            : _presets[i].color.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _presets[i].color
                              : _presets[i].color.withValues(alpha: isDark ? 0.50 : 0.40),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        _presets[i].arabic,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? _presets[i].color : _presets[i].color),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Main ring with PageView (Swipe interaction) ─────────────
            Expanded(
              child: PageView.builder(
                itemCount: _presets.length,
                onPageChanged: (i) => ref.read(_sebhaProvider.notifier).setPreset(i),
                controller: PageController(initialPage: sebha.presetIndex, viewportFraction: 0.85),
                itemBuilder: (context, i) {
                  final isSelected = i == sebha.presetIndex;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isSelected ? () => ref.read(_sebhaProvider.notifier).increment() : null,
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1.0 : 0.85,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 300),
                          child: _SebhaRing(
                            progress: isSelected ? sebha.progress : 0,
                            count: isSelected ? sebha.count : 0,
                            target: _presets[i].target,
                            color: _presets[i].color,
                            arabic: _presets[i].arabic,
                            isDark: isDark,
                            isRoundComplete: isSelected ? sebha.isRoundComplete : false,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Rounds ───────────────────────────────────────────────────
            Text(
              'عدد الجولات: ${sebha.count ~/ sebha.preset.target}',
              style: GoogleFonts.amiri(fontSize: 16, color: subtext),
            ),

            // ── Reset ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => ref.read(_sebhaProvider.notifier).reset(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardBackground : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.restart_alt, color: subtext, size: 26),
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

  void _showResetConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('إعادة التعيين',
            style: GoogleFonts.amiri(fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl),
        content: Text('هل تريد إعادة تعيين العداد الكامل؟',
            style: GoogleFonts.amiri(), textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.amiri()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              ref.read(_sebhaProvider.notifier).resetAll();
              Navigator.pop(context);
            },
            child: Text('تأكيد', style: GoogleFonts.amiri(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Animated ring ─────────────────────────────────────────────────────────────

class _SebhaRing extends StatefulWidget {
  final double progress;
  final int count;
  final int target;
  final Color color;
  final String arabic;
  final bool isDark;
  final bool isRoundComplete;

  const _SebhaRing({
    required this.progress,
    required this.count,
    required this.target,
    required this.color,
    required this.arabic,
    required this.isDark,
    required this.isRoundComplete,
  });

  @override
  State<_SebhaRing> createState() => _SebhaRingState();
}

class _SebhaRingState extends State<_SebhaRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late Animation<double> _progressAnim;
  double _prevProgress = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(_anim);
  }

  @override
  void didUpdateWidget(_SebhaRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _progressAnim = Tween<double>(begin: _prevProgress, end: widget.progress)
          .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
      _prevProgress = widget.progress;
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgCard = widget.isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor =
        widget.isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext =
        widget.isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, __) => Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgCard,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3),
              blurRadius: 35,
              spreadRadius: 8,
              offset: const Offset(0, 10),
            ),
            // RGB style inner glow
            BoxShadow(
              color: widget.isRoundComplete ? AppColors.success.withValues(alpha: 0.4) : widget.color.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _RingPainter(
            progress: _progressAnim.value,
            color: widget.color,
            isDark: widget.isDark,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.arabic,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark
                        // Dark mode: use a bright, legible version of the preset color
                        ? Color.lerp(widget.color, Colors.white, 0.45)!
                        // Light mode: use a dark, legible version of the preset color
                        : Color.lerp(widget.color, Colors.black, 0.50)!,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Text(
                    '${widget.count}',
                    key: ValueKey(widget.count),
                    style: GoogleFonts.outfit(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: widget.isRoundComplete
                          ? AppColors.success
                          : textColor,
                    ),
                  ),
                ),
                Text(
                  'اضغط للتسبيح',
                  style: GoogleFonts.amiri(fontSize: 12, color: subtext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _RingPainter(
      {required this.progress, required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.15 : 0.08)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Ornamental dots
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * pi / 180;
      final r = radius + 16;
      canvas.drawCircle(
        Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)),
        i % 5 == 0 ? 2.5 : 1.2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
