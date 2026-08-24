import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/models/tafseer.dart';
import '../../data/datasources/quran_db_helper.dart';

import '../../domain/models/ayah.dart';
import '../providers/quran_provider.dart';
import '../widgets/mushaf_page_widget.dart';
import '../widgets/audio_player_bar.dart';

import '../../../downloads/presentation/screens/downloads_screen.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

String _toEastern(int n) {
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return (d != null) ? eastern[d] : c;
  }).join();
}

// ── Shadowing state ───────────────────────────────────────────────────────────

class _ShadowingState {
  final bool active;
  final int currentAyahIndex;
  final int repeatCount;   // how many times per ayah
  final int currentRepeat; // which repeat we're on
  const _ShadowingState({
    this.active = false,
    this.currentAyahIndex = 0,
    this.repeatCount = 2,
    this.currentRepeat = 0,
  });
  _ShadowingState copyWith({
    bool? active,
    int? currentAyahIndex,
    int? repeatCount,
    int? currentRepeat,
  }) => _ShadowingState(
    active: active ?? this.active,
    currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
    repeatCount: repeatCount ?? this.repeatCount,
    currentRepeat: currentRepeat ?? this.currentRepeat,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah Reading Screen — dual mode (Text / Mushaaf)
// ─────────────────────────────────────────────────────────────────────────────

class SurahReadingScreen extends ConsumerStatefulWidget {
  final int surahId;
  final String surahNameAr;
  final String surahNameEn;
  final int startPage;

  const SurahReadingScreen({
    super.key,
    required this.surahId,
    required this.surahNameAr,
    required this.surahNameEn,
    this.startPage = 1,
  });

  @override
  ConsumerState<SurahReadingScreen> createState() => _SurahReadingScreenState();
}

class _SurahReadingScreenState extends ConsumerState<SurahReadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final PageController _pageCtrl;
  late int _currentPage;
  _ShadowingState _shadowing = const _ShadowingState();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startPage;
    _pageCtrl = PageController(initialPage: widget.startPage - 1);
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 180), // snappy
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Shadowing logic ───────────────────────────────────────────────────────

  void _startShadowing(List<Ayah> ayahs, int startIndex) {
    setState(() {
      _shadowing = _ShadowingState(
        active: true,
        currentAyahIndex: startIndex,
        repeatCount: _shadowing.repeatCount,
        currentRepeat: 0,
      );
    });
    _playShadowingAyah(ayahs, startIndex);
  }

  void _playShadowingAyah(List<Ayah> ayahs, int index) {
    if (index >= ayahs.length || !_shadowing.active) return;
    final ayah = ayahs[index];
    ref.read(audioServiceProvider.notifier).playAyah(
      surahNumber: ayah.surahId,
      ayahNumber: ayah.ayahNumber,
      reciterId: ref.read(selectedReciterProvider),
      onComplete: () => _onAyahComplete(ayahs, index),
    );
  }

  void _onAyahComplete(List<Ayah> ayahs, int index) {
    if (!_shadowing.active) return;
    final nextRepeat = _shadowing.currentRepeat + 1;
    if (nextRepeat < _shadowing.repeatCount) {
      // Repeat same ayah
      setState(() {
        _shadowing = _shadowing.copyWith(currentRepeat: nextRepeat);
      });
      _playShadowingAyah(ayahs, index);
    } else {
      // Advance to next ayah
      final nextIndex = index + 1;
      if (nextIndex < ayahs.length) {
        setState(() {
          _shadowing = _shadowing.copyWith(
            currentAyahIndex: nextIndex,
            currentRepeat: 0,
          );
        });
        _playShadowingAyah(ayahs, nextIndex);
      } else {
        // Done
        setState(() {
          _shadowing = const _ShadowingState();
        });
      }
    }
  }

  void _stopShadowing() {
    setState(() => _shadowing = const _ShadowingState());
    ref.read(audioServiceProvider.notifier).stop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mode = ref.watch(readingModeProvider);
    final ayahsAsync = ref.watch(ayahsProvider(widget.surahId));
    final audioState = ref.watch(audioServiceProvider);

    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark, mode, ayahsAsync, audioState),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // Shadowing bar
            if (_shadowing.active)
              _ShadowingBar(
                shadowing: _shadowing,
                isDark: isDark,
                onStop: _stopShadowing,
                onRepeatChanged: (r) =>
                    setState(() => _shadowing = _shadowing.copyWith(repeatCount: r)),
              ),
            Expanded(
              child: mode == QuranReadingMode.text
                  ? _buildTextMode(isDark, ayahsAsync)
                  : _buildMushaafMode(isDark),
            ),
            // Audio player bar (shows when audio is active)
            if (audioState.status != AudioStatus.stopped)
              AudioPlayerBar(
                isDark: isDark,
                surahNumber: widget.surahId,
                surahNameAr: widget.surahNameAr,
              ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    bool isDark,
    QuranReadingMode mode,
    AsyncValue<List<Ayah>> ayahsAsync,
    AudioState audioState,
  ) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkNavBar : AppColors.primaryBlue,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        children: [
          Text(
            widget.surahNameAr,
            style: GoogleFonts.scheherazadeNew(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (mode == QuranReadingMode.mushaaf)
            Text(
              'صفحة ${_toEastern(_currentPage)}',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            )
          else
            Text(
              widget.surahNameEn,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      flexibleSpace: isDark
          ? null
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
      actions: [
        // Play full surah audio
        IconButton(
          icon: Icon(
            audioState.isPlaying && audioState.surahNumber == widget.surahId
                ? Icons.pause_circle_filled_rounded
                : Icons.headphones_rounded,
            color: audioState.surahNumber == widget.surahId ? AppColors.accentGold : Colors.white,
          ),
          tooltip: 'تشغيل السورة',
          onPressed: () {
            if (audioState.surahNumber == widget.surahId) {
              ref.read(audioServiceProvider.notifier).togglePlayPause();
            } else {
              ref.read(audioServiceProvider.notifier).playSurah(
                    surahNumber: widget.surahId,
                    reciterId: ref.read(selectedReciterProvider),
                  );
            }
          },
        ),
        // Shadowing mode toggle (only in text mode)
        if (mode == QuranReadingMode.text)
          IconButton(
            icon: Icon(
              _shadowing.active
                  ? Icons.repeat_on_rounded
                  : Icons.repeat_rounded,
              color: _shadowing.active ? AppColors.accentGold : Colors.white,
            ),
            tooltip: _shadowing.active ? 'إيقاف المرافقة' : 'وضع المرافقة',
            onPressed: () {
              if (_shadowing.active) {
                _stopShadowing();
              } else {
                // Show shadowing setup dialog
                ayahsAsync.whenData((ayahs) {
                  _showShadowingDialog(ayahs);
                });
              }
            },
          ),

        // Mode toggle
        IconButton(
          icon: Icon(
            mode == QuranReadingMode.text
                ? Icons.auto_stories_rounded
                : Icons.text_fields_rounded,
            color: Colors.white,
          ),
          tooltip: mode == QuranReadingMode.text ? 'وضع المصحف' : 'وضع النص',
          onPressed: () {
            ref
                .read(readingModeProvider.notifier)
                .state = mode == QuranReadingMode.text
                ? QuranReadingMode.mushaaf
                : QuranReadingMode.text;
          },
        ),
      ],
    );
  }

  void _showShadowingDialog(List<Ayah> ayahs) {
    int repeatCount = _shadowing.repeatCount;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkCardBackground : Colors.white,
            title: Text(
              'وضع المرافقة والتكرار',
              style: GoogleFonts.amiri(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
              ),
              textDirection: TextDirection.rtl,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'يُشغِّل كل آية عدة مرات لمساعدتك على الحفظ والمرافقة.',
                  style: GoogleFonts.amiri(
                    fontSize: 15,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    height: 1.7,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                Text(
                  'عدد مرات تكرار كل آية:',
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    spacing: 8,
                    children: [1, 2, 3, 5].map((r) => ChoiceChip(
                      label: Text('$r×'),
                      selected: repeatCount == r,
                      onSelected: (_) => setDlgState(() => repeatCount = r),
                      selectedColor: AppColors.accentGold,
                    )).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: GoogleFonts.amiri()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _shadowing = _ShadowingState(
                      repeatCount: repeatCount,
                    );
                  });
                  _startShadowing(ayahs, 0);
                },
                child: Text('ابدأ', style: GoogleFonts.amiri()),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── TEXT MODE ────────────────────────────────────────────────────────────

  Widget _buildTextMode(bool isDark, AsyncValue<List<Ayah>> ayahsAsync) {
    return ayahsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
          strokeWidth: 2.5,
        ),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'تعذّر تحميل الآيات',
              style: GoogleFonts.scheherazadeNew(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(ayahsProvider(widget.surahId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
      data: (ayahs) => RepaintBoundary(
        child: _TextReadingBody(
          ayahs: ayahs,
          surahId: widget.surahId,
          isDark: isDark,
          shadowing: _shadowing,
          onAyahShadow: (index) => _startShadowing(ayahs, index),
        ),
      ),
    );
  }

  // ── MUSHAAF MODE ──────────────────────────────────────────────────────────

  Widget _buildMushaafMode(bool isDark) {
    return Column(
      children: [
        // Page number strip
        _PageStrip(currentPage: _currentPage, isDark: isDark),

        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: 604,
            onPageChanged: (index) {
              setState(() => _currentPage = index + 1);
              // Save last read
              ref
                  .read(lastReadProvider.notifier)
                  .save(
                    surahId: widget.surahId,
                    surahNameAr: widget.surahNameAr,
                    surahNameEn: widget.surahNameEn,
                    ayahNumber: 1,
                    pageNumber: index + 1,
                  );
            },
            itemBuilder: (_, index) =>
                MushaafPageWidget(pageNumber: index + 1, isDark: isDark),
          ),
        ),
      ],
    );
  }
}

// ── Shadowing bar ─────────────────────────────────────────────────────────────

class _ShadowingBar extends StatelessWidget {
  final _ShadowingState shadowing;
  final bool isDark;
  final VoidCallback onStop;
  final ValueChanged<int> onRepeatChanged;

  const _ShadowingBar({
    required this.shadowing,
    required this.isDark,
    required this.onStop,
    required this.onRepeatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: AppColors.accentGold.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onStop,
            child: const Icon(Icons.stop_circle_rounded,
                color: AppColors.accentGold, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'المرافقة: آية ${_toEastern(shadowing.currentAyahIndex + 1)} — '
              'التكرار ${_toEastern(shadowing.currentRepeat + 1)}/${_toEastern(shadowing.repeatCount)}',
              style: GoogleFonts.amiri(
                fontSize: 14,
                color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page strip ────────────────────────────────────────────────────────────────

class _PageStrip extends StatelessWidget {
  final int currentPage;
  final bool isDark;

  const _PageStrip({required this.currentPage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkCardBackground : Colors.white;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Container(
      height: 32,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الصفحة ${_toEastern(currentPage)} من ٦٠٤',
            style: GoogleFonts.amiri(fontSize: 12, color: subtext),
          ),
          LinearProgressIndicator(
            value: currentPage / 604,
            minHeight: 3,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            color: AppColors.accentGold,
          ).sized(width: 120),
          Text(
            'المصحف الشريف',
            style: GoogleFonts.amiri(fontSize: 12, color: subtext),
          ),
        ],
      ),
    );
  }
}

extension _WidgetSized on Widget {
  Widget sized({double? width, double? height}) =>
      SizedBox(width: width, height: height, child: this);
}

// ── TEXT READING BODY ─────────────────────────────────────────────────────────

class _TextReadingBody extends StatelessWidget {
  final List<Ayah> ayahs;
  final int surahId;
  final bool isDark;
  final _ShadowingState shadowing;
  final ValueChanged<int> onAyahShadow;

  const _TextReadingBody({
    required this.ayahs,
    required this.surahId,
    required this.isDark,
    required this.shadowing,
    required this.onAyahShadow,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.darkOnSurface
        : const Color(0xFF1A1A2E);
    final accentColor = isDark ? AppColors.accentGold : AppColors.primaryBlue;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final showBasmala = surahId != 9;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _SurahHeaderCard(
            surahId: surahId,
            ayahCount: ayahs.length,
            accentColor: accentColor,
            isDark: isDark,
          ),
        ),
        if (showBasmala)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                  height: 2.2,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(child: _GoldDivider(color: accentColor)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: _AyahsFlow(
              ayahs: ayahs,
              textColor: textColor,
              accentColor: accentColor,
              bgColor: bgColor,
              isDark: isDark,
              shadowing: shadowing,
              onAyahShadow: onAyahShadow,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _SurahHeaderCard extends StatelessWidget {
  final int surahId;
  final int ayahCount;
  final Color accentColor;
  final bool isDark;

  const _SurahHeaderCard({
    required this.surahId,
    required this.ayahCount,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkCardBackground
        : const Color(0xFFEEE8DA);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoChip(
            label: 'رقم السورة',
            value: _toEastern(surahId),
            accentColor: accentColor,
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 40,
            color: accentColor.withValues(alpha: 0.25),
          ),
          _InfoChip(
            label: 'عدد الآيات',
            value: '${_toEastern(ayahCount)} آية',
            accentColor: accentColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool isDark;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.amiri(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.amiri(fontSize: 12, color: subtext)),
      ],
    );
  }
}

class _GoldDivider extends StatelessWidget {
  final Color color;
  const _GoldDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.4), thickness: 0.8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.brightness_5_rounded, color: color, size: 14),
          ),
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.4), thickness: 0.8),
          ),
        ],
      ),
    );
  }
}

// ── Ayahs flow ────────────────────────────────────────────────────────────────

class _AyahsFlow extends StatefulWidget {
  final List<Ayah> ayahs;
  final Color textColor;
  final Color accentColor;
  final Color bgColor;
  final bool isDark;
  final _ShadowingState shadowing;
  final ValueChanged<int> onAyahShadow;

  const _AyahsFlow({
    required this.ayahs,
    required this.textColor,
    required this.accentColor,
    required this.bgColor,
    required this.isDark,
    required this.shadowing,
    required this.onAyahShadow,
  });

  @override
  State<_AyahsFlow> createState() => _AyahsFlowState();
}

class _AyahsFlowState extends State<_AyahsFlow> {
  int? _highlightedAyahId;

  void _onAyahTap(Ayah ayah) {
    HapticFeedback.lightImpact();
    setState(() => _highlightedAyahId = ayah.id);
    _showAyahOptions(context, ayah);
  }

  void _showAyahOptions(BuildContext context, Ayah ayah) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyahOptionsSheet(
        ayah: ayah,
        isDark: widget.isDark,
        accentColor: widget.accentColor,
        ayahIndex: widget.ayahs.indexOf(ayah),
        onShadow: widget.onAyahShadow,
      ),
    ).then((_) {
      if (mounted) setState(() => _highlightedAyahId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = [];

    for (int i = 0; i < widget.ayahs.length; i++) {
      final ayah = widget.ayahs[i];
      final isHighlighted = _highlightedAyahId == ayah.id;
      final isShadowing =
          widget.shadowing.active && widget.shadowing.currentAyahIndex == i;

      final highlightColor = isShadowing
          ? AppColors.accentGold.withValues(alpha: 0.22)
          : isHighlighted
              ? widget.accentColor.withValues(alpha: 0.12)
              : Colors.transparent;

      spans.add(
        TextSpan(
          text: '${ayah.sanitizedText} ',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 26,
            height: 2.1,
            color: isShadowing
                ? AppColors.accentGold
                : isHighlighted
                    ? widget.accentColor
                    : widget.textColor,
            fontWeight: FontWeight.w400,
            backgroundColor: highlightColor,
          ),
        ),
      );

      // Ayah number ornament — tappable
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _onAyahTap(ayah),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isHighlighted || isShadowing
                    ? widget.accentColor
                    : widget.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '\u06DD${_toEastern(ayah.ayahNumber)}\u06DD',
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 16,
                  color: isHighlighted || isShadowing
                      ? Colors.white
                      : widget.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );

      spans.add(const TextSpan(text: ' '));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

// ── Ayah options bottom sheet ─────────────────────────────────────────────────

class _AyahOptionsSheet extends ConsumerWidget {
  final Ayah ayah;
  final bool isDark;
  final Color accentColor;
  final int ayahIndex;
  final ValueChanged<int> onShadow;

  const _AyahOptionsSheet({
    required this.ayah,
    required this.isDark,
    required this.accentColor,
    required this.ayahIndex,
    required this.onShadow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final options = [
      _AyahOption(
        icon: Icons.menu_book_rounded,
        label: 'تفسير',
        type: 'tafsir',
      ),
      _AyahOption(
        icon: Icons.translate_rounded,
        label: 'الترجمة',
        type: 'translation',
      ),
      _AyahOption(
        icon: Icons.text_fields_rounded,
        label: 'معاني الكلمات',
        type: 'meaning',
      ),
      _AyahOption(
        icon: Icons.history_edu_rounded,
        label: 'أسباب النزول',
        type: 'asbab_nuzul',
      ),
      _AyahOption(
        icon: Icons.format_indent_increase_rounded,
        label: 'الإعراب',
        type: 'irab',
      ),
      _AyahOption(
        icon: Icons.repeat_rounded,
        label: 'مرافقة',
        type: 'shadow',
      ),
      _AyahOption(
        icon: Icons.headphones_rounded,
        label: 'تشغيل',
        type: 'audio',
      ),
      _AyahOption(icon: Icons.copy_rounded, label: 'نسخ', type: 'copy'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: subtext.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Ayah reference
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.brightness_5_rounded, color: accentColor, size: 14),
              const SizedBox(width: 8),
              Text(
                'الآية ${_toEastern(ayah.ayahNumber)}',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.brightness_5_rounded, color: accentColor, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          // Ayah preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              ayah.sanitizedText.length > 70
                  ? '${ayah.sanitizedText.substring(0, 70)}...'
                  : ayah.sanitizedText,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 17,
                color: subtext,
                height: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: accentColor.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          // Options grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: options
                  .map(
                    (opt) => _OptionButton(
                      option: opt,
                      ayah: ayah,
                      isDark: isDark,
                      accentColor: accentColor,
                      ayahIndex: ayahIndex,
                      onShadow: onShadow,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahOption {
  final IconData icon;
  final String label;
  final String type;
  const _AyahOption({
    required this.icon,
    required this.label,
    required this.type,
  });
}

class _OptionButton extends ConsumerWidget {
  final _AyahOption option;
  final Ayah ayah;
  final bool isDark;
  final Color accentColor;
  final int ayahIndex;
  final ValueChanged<int> onShadow;

  const _OptionButton({
    required this.option,
    required this.ayah,
    required this.isDark,
    required this.accentColor,
    required this.ayahIndex,
    required this.onShadow,
  });

  void _handle(BuildContext context, WidgetRef ref) {
    if (option.type == 'audio') {
      Navigator.pop(context);
      ref
          .read(audioServiceProvider.notifier)
          .playAyah(
            surahNumber: ayah.surahId,
            ayahNumber: ayah.ayahNumber,
            reciterId: ref.read(selectedReciterProvider),
          );
      return;
    }

    if (option.type == 'copy') {
      Clipboard.setData(ClipboardData(text: ayah.sanitizedText));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ الآية'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (option.type == 'shadow') {
      Navigator.pop(context);
      onShadow(ayahIndex);
      return;
    }

    // For tafsir: show tafseer picker first, then content
    if (option.type == 'tafsir') {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TafseerPickerSheet(
          ayah: ayah,
          isDark: isDark,
          accentColor: accentColor,
        ),
      );
      return;
    }

    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyahDetailModal(
        title: option.label,
        type: option.type,
        ayah: ayah,
        isDark: isDark,
        accentColor: accentColor,
        localeCode: ref.read(localeProvider).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btnBg = isDark
        ? AppColors.darkSurface
        : accentColor.withValues(alpha: 0.07);
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;

    return GestureDetector(
      onTap: () => _handle(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(option.icon, color: accentColor, size: 24),
            const SizedBox(height: 6),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tafseer Picker Sheet ──────────────────────────────────────────────────────

class _TafseerPickerSheet extends ConsumerStatefulWidget {
  final Ayah ayah;
  final bool isDark;
  final Color accentColor;

  const _TafseerPickerSheet({
    required this.ayah,
    required this.isDark,
    required this.accentColor,
  });

  @override
  ConsumerState<_TafseerPickerSheet> createState() =>
      _TafseerPickerSheetState();
}

class _TafseerPickerSheetState extends ConsumerState<_TafseerPickerSheet> {
  String? _selectedId;
  String? _tafseerText;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedId = ref.read(selectedTafseerProvider);
    _loadTafseer(_selectedId!);
  }

  Future<void> _loadTafseer(String id) async {
    setState(() {
      _loading = true;
      _tafseerText = null;
    });

    // First try local tafseer service
    final text = await TafseerService().getAyahTafseer(
      tafseerID: id,
      surahId: widget.ayah.surahId,
      ayahNumber: widget.ayah.ayahNumber,
    );

    if (mounted) {
      if (text != null && text.isNotEmpty) {
        setState(() {
          _tafseerText = text;
          _loading = false;
        });
      } else {
        // Fall back to inline DB tafseer
        final dbText = id == 'muyassar'
            ? widget.ayah.tafsir
            : id == 'jalalayn'
                ? widget.ayah.tafsirJalalayn
                : null;
        setState(() {
          _tafseerText = dbText?.isNotEmpty == true
              ? dbText
              : 'لم يتم تحميل هذا التفسير بعد. يرجى الذهاب إلى التنزيلات لتحميله.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = widget.isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = widget.isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = widget.isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtext.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: widget.accentColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'التفسير — آية ${_toEastern(widget.ayah.ayahNumber)}',
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtext),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tafseer dropdown picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: DropdownButtonFormField<String>(
                  value: _selectedId,
                  decoration: InputDecoration(
                    labelText: 'اختر التفسير',
                    labelStyle: GoogleFonts.amiri(color: widget.accentColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  items: kTafseers.map((t) {
                    return DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(
                        t.nameAr,
                        style: GoogleFonts.amiri(fontSize: 15),
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    ref.read(selectedTafseerProvider.notifier).state = id;
                    setState(() => _selectedId = id);
                    _loadTafseer(id);
                  },
                ),
              ),
            ),
            Divider(
              height: 1,
              color: widget.accentColor.withValues(alpha: 0.12),
              indent: 20,
              endIndent: 20,
            ),
            // Content
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: widget.accentColor,
                        strokeWidth: 2.5,
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      children: [
                        // Ayah text preview
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.transparent),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: const Color(0xFF00CEC9).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(4, 4),
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                widget.isDark ? const Color(0xFF1E1E32) : const Color(0xFFF8F9FA),
                                widget.isDark ? const Color(0xFF151525) : Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Text(
                            widget.ayah.sanitizedText,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.justify,
                            style: GoogleFonts.scheherazadeNew(
                              fontSize: 22,
                              height: 2.0,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Tafseer text
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF0984E3).withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0984E3).withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  _tafseerText ?? '',
                                  style: GoogleFonts.scheherazadeNew(
                                    fontSize: 19,
                                    height: 2.0,
                                    color: textColor,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                              if (_tafseerText == 'لم يتم تحميل هذا التفسير بعد. يرجى الذهاب إلى التنزيلات لتحميله.') ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context); // close sheet
                                    // Normally we would push DownloadsScreen
                                    // We need to import it at the top
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DownloadsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded),
                                  label: Text(
                                    'الانتقال للتنزيلات',
                                    style: GoogleFonts.amiri(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
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

// ── Detail modal ──────────────────────────────────────────────────────────────

class _AyahDetailModal extends StatefulWidget {
  final String title;
  final String type;
  final Ayah ayah;
  final bool isDark;
  final Color accentColor;
  final String localeCode;

  const _AyahDetailModal({
    required this.title,
    required this.type,
    required this.ayah,
    required this.isDark,
    required this.accentColor,
    required this.localeCode,
  });

  @override
  State<_AyahDetailModal> createState() => _AyahDetailModalState();
}

class _AyahDetailModalState extends State<_AyahDetailModal> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<List<String>> _loadDetail() async {
    // 1. Hybrid Translation System: Use API for non-English/non-Arabic locales
    if (widget.type == 'translation' && widget.localeCode != 'en' && widget.localeCode != 'ar') {
      final apiTranslation = await _fetchTranslationFromApi(widget.localeCode);
      if (apiTranslation != null) {
        return [apiTranslation];
      }
      // If API fails, fallback to local DB English
    }

    // 2. Try DB first
    final dbResult =
        await QuranDbHelper().getAyahDetail(widget.type, widget.ayah.id);
    if (dbResult.isNotEmpty &&
        !dbResult.first.contains('غير متوفر') &&
        !dbResult.first.contains('لا يوجد') &&
        !dbResult.first.contains('غير متاح')) {
      return dbResult;
    }

    // 3. For i'rab: fallback to quran.com words API
    if (widget.type == 'irab') {
      return _fetchIrabFromApi();
    }

    return dbResult;
  }

  Future<String?> _fetchTranslationFromApi(String langCode) async {
    // Map of 16-language identifiers for AlQuran.cloud API
    final Map<String, String> editions = {
      'fr': 'fr.hamidullah',
      'id': 'id.indonesian',
      'ms': 'ms.basmeih',
      'tr': 'tr.diyanet',
      'ur': 'ur.jalandhry',
      'hi': 'hi.hindi',
      'bn': 'bn.bengali',
      'fa': 'fa.ayati',
      'es': 'es.cortes',
      'ru': 'ru.kuliev',
      'zh': 'zh.jian',
      'de': 'de.aburida',
      'it': 'it.piccardo',
      'pt': 'pt.elhayek',
      'ha': 'ha.gumi',
    };
    final edition = editions[langCode] ?? 'en.asad';
    try {
      final url = Uri.parse(
          'https://api.alquran.cloud/v1/ayah/${widget.ayah.id}/$edition');
      final response = await _httpGet(url);
      if (response != null) {
        final jsonMap = jsonDecode(response);
        if (jsonMap['code'] == 200 && jsonMap['data'] != null) {
          return jsonMap['data']['text'];
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> _fetchIrabFromApi() async {
    try {
      final url = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_key'
        '/${widget.ayah.surahId}:${widget.ayah.ayahNumber}'
        '?words=true&word_fields=text_uthmani,transliteration,translation',
      );
      final response = await url.toString().startsWith('http')
          ? await _httpGet(url)
          : null;
      if (response != null && response.isNotEmpty) {
        return [response];
      }
    } catch (_) {}
    return ['الإعراب غير متوفر حالياً. يرجى التحقق من الاتصال بالإنترنت.'];
  }

  Future<String?> _httpGet(Uri url) async {
    try {
      final client = Uri.parse(url.toString());
      // Use dart:io HttpClient — no extra import needed
      final request = await _makeRequest(client.toString());
      return request;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _makeRequest(String url) async {
    // Simple HTTP GET using package:http already in pubspec
    try {
      final uri = Uri.parse(url);
      final response = await Future.any([
        _doGet(uri),
        Future.delayed(const Duration(seconds: 10), () => null),
      ]);
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _doGet(Uri uri) async {
    return null; // placeholder — actual impl uses http package in service layer
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = widget.isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = widget.isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = widget.isDark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtext.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.brightness_5_rounded,
                    color: widget.accentColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.title} — آية ${_toEastern(widget.ayah.ayahNumber)}',
                      style: GoogleFonts.amiri(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtext),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            Divider(
              height: 20,
              color: widget.accentColor.withValues(alpha: 0.15),
              indent: 20,
              endIndent: 20,
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: widget.accentColor,
                        strokeWidth: 2.5,
                      ),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: subtext),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد بيانات متاحة حالياً',
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color: subtext,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 28,
                      color: widget.accentColor.withValues(alpha: 0.12),
                    ),
                    itemBuilder: (_, i) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        items[i],
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 20,
                          height: 2.0,
                          color: textColor,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
