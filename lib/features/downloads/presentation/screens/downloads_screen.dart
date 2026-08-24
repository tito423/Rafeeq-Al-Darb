import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/models/tafseer.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/services/translation_service.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;

    final downloadState = ref.watch(downloadManagerProvider);

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مدير التنزيلات',
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'صفحات المصحف والتلاوات',
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            color: subtext,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE17055).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: Color(0xFFE17055),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Tafseer section ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _TafseerDownloadSection(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtext: subtext,
              ),
            ),

            // ── Translation section ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _TranslationDownloadSection(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtext: subtext,
              ),
            ),

            // ── Audio section ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _AudioDownloadSection(
                isDark: isDark,
                cardBg: cardBg,
                textColor: textColor,
                subtext: subtext,
              ),
            ),

            // ── Active downloads ──────────────────────────────────────────
            if (downloadState.activeTasks.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    'تنزيلات نشطة',
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final task = downloadState.activeTasks[i];
                  return _ActiveTaskTile(
                    task: task,
                    isDark: isDark,
                    cardBg: cardBg,
                  );
                }, childCount: downloadState.activeTasks.length),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ── Audio download section ────────────────────────────────────────────────────

class _AudioDownloadSection extends ConsumerWidget {
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subtext;

  const _AudioDownloadSection({
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                Icons.headphones_rounded,
                color: Color(0xFF6C5CE7),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'تنزيل التلاوات',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اختر قارئاً لتحميل تلاوته للاستماع بدون إنترنت',
            style: GoogleFonts.amiri(fontSize: 14, color: subtext, height: 1.7),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          ...kReciters.map(
            (reciter) => _ReciterCard(
              reciter: reciter,
              isDark: isDark,
              textColor: textColor,
              subtext: subtext,
            ),
          ),
        ],
      ),
    );
  }
}

const _surahNames = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال',
  'التوبة', 'يونس', 'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء',
  'الكهف', 'مريم', 'طه', 'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء',
  'النمل', 'القصص', 'العنكبوت', 'الروم', 'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر', 'فصلت', 'الشورى', 'الزخرف', 'الدخان',
  'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق', 'الذاريات', 'الطور', 'النجم',
  'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة', 'الصف',
  'الجمعة', 'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة',
  'المعارج', 'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات',
  'النبأ', 'النازعات', 'عبس', 'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد', 'الشمس', 'الليل', 'الضحى',
  'الشرح', 'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات', 'القارعة',
  'التكاثر', 'العصر', 'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون',
  'النصر', 'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

class _ReciterCard extends ConsumerStatefulWidget {
  final Reciter reciter;
  final bool isDark;
  final Color textColor;
  final Color subtext;

  const _ReciterCard({
    required this.reciter,
    required this.isDark,
    required this.textColor,
    required this.subtext,
  });

  @override
  ConsumerState<_ReciterCard> createState() => _ReciterCardState();
}

class _ReciterCardState extends ConsumerState<_ReciterCard> {
  int _selectedSurah = 1;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? AppColors.darkBackground : const Color(0xFFF5F0E8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            // ── Header row ─────────────────────────────────────────────────
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: Text(
                widget.reciter.nameAr,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: widget.textColor,
                ),
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                widget.reciter.nameEn,
                style: GoogleFonts.outfit(fontSize: 12, color: widget.subtext),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick full-archive download
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref.read(downloadManagerProvider.notifier).downloadFullReciterArchive(
                        reciterId: widget.reciter.id,
                        mp3quranBaseUrl: widget.reciter.mp3quranIdentifier,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          'بدأ تحميل التلاوة كاملة — ${widget.reciter.nameAr}',
                          style: GoogleFonts.amiri(),
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    icon: const Icon(
                      Icons.download_for_offline_rounded,
                      color: AppColors.accentGold,
                      size: 26,
                    ),
                    tooltip: 'تحميل المصحف كاملاً',
                  ),
                  const SizedBox(width: 4),
                  // Expand for single-surah download
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryBlue,
                      size: 26,
                    ),
                    tooltip: 'تحميل سورة محددة',
                  ),
                ],
              ),
            ),

            // ── Expanded surah picker ───────────────────────────────────────
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    // Surah dropdown
                    DropdownButton<int>(
                      value: _selectedSurah,
                      isExpanded: true,
                      underline: Container(
                        height: 1,
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      ),
                      items: List.generate(114, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(
                          '${i + 1}. ${_surahNames[i]}',
                          style: GoogleFonts.scheherazadeNew(fontSize: 16),
                        ),
                      )),
                      onChanged: (v) => setState(() => _selectedSurah = v!),
                    ),
                    const SizedBox(height: 10),
                    // Download surah button
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(downloadManagerProvider.notifier).downloadSurahAudio(
                          surahNumber: _selectedSurah,
                          reciterId: widget.reciter.id,
                          mp3quranBaseUrl: widget.reciter.mp3quranIdentifier,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            'تحميل سورة ${_surahNames[_selectedSurah - 1]} — ${widget.reciter.nameAr}',
                            style: GoogleFonts.amiri(),
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ));
                        setState(() => _isExpanded = false);
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'تحميل سورة ${_surahNames[_selectedSurah - 1]}',
                        style: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

// ── Translation download section ──────────────────────────────────────────────

class _TranslationDownloadSection extends ConsumerWidget {
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subtext;

  const _TranslationDownloadSection({
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                Icons.g_translate_rounded,
                color: Color(0xFF00B894),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'تنزيل التراجم',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'حمّل تراجم معاني القرآن للوصول إليها بدون إنترنت',
            style: GoogleFonts.amiri(fontSize: 14, color: subtext, height: 1.7),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          ...kTranslations.values.map(
            (t) => _TranslationDownloadRow(
              translation: t,
              isDark: isDark,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationDownloadRow extends ConsumerWidget {
  final TranslationConfig translation;
  final bool isDark;
  final Color textColor;

  const _TranslationDownloadRow({
    required this.translation,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translationDownloadProvider);
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final isDownloading = state.isDownloading[translation.edition] == true;
    final isCompleted = state.isCompleted[translation.edition] == true;
    final progress = state.progress[translation.edition] ?? 0.0;
    final error = state.errors[translation.edition];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Action button
          if (isDownloading)
            SizedBox(
              width: 90,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primaryBlue,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => ref.read(translationDownloadProvider.notifier).cancelDownload(translation.edition),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.amiri(fontSize: 12, color: AppColors.error),
                    ),
                  )
                ],
              ),
            )
          else if (isCompleted)
            ElevatedButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text('محمل', style: GoogleFonts.amiri(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold.withValues(alpha: 0.1),
                foregroundColor: AppColors.accentGold,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                ref.read(translationDownloadProvider.notifier).startDownload(translation.edition);
              },
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('تنزيل', style: GoogleFonts.amiri(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),

          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  translation.languageName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      error,
                      style: GoogleFonts.amiri(fontSize: 12, color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'حذف الترجمة',
            style: GoogleFonts.amiri(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Text(
            'هل أنت متأكد من حذف ${translation.languageName}؟',
            style: GoogleFonts.amiri(fontSize: 16),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.amiri(color: AppColors.primaryBlue)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                ref.read(translationDownloadProvider.notifier).deleteTranslation(translation.edition);
                Navigator.pop(ctx);
              },
              child: Text('حذف', style: GoogleFonts.amiri(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// ── Active task tile ──────────────────────────────────────────────────────────

class _ActiveTaskTile extends ConsumerWidget {
  final DownloadTask task;
  final bool isDark;
  final Color cardBg;

  const _ActiveTaskTile({
    required this.task,
    required this.isDark,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Cancel button
          GestureDetector(
            onTap: () =>
                ref.read(downloadManagerProvider.notifier).cancelTask(task.id),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Progress & filename
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  task.filename,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  color: AppColors.primaryBlue,
                  minHeight: 4,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(task.progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(fontSize: 11, color: subtext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tafseer download section ───────────────────────────────────────────────────

class _TafseerDownloadSection extends ConsumerWidget {
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subtext;

  const _TafseerDownloadSection({
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                Icons.menu_book_rounded,
                color: Color(0xFF0984E3),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'تنزيل التفاسير',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'حمّل التفاسير المتوفرة للوصول إليها بدون إنترنت',
            style: GoogleFonts.amiri(fontSize: 14, color: subtext, height: 1.7),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          ...kTafseers.map(
            (t) => _TafseerDownloadRow(
              tafseer: t,
              isDark: isDark,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TafseerDownloadRow extends ConsumerWidget {
  final TafseerBook tafseer;
  final bool isDark;
  final Color textColor;

  const _TafseerDownloadRow({
    required this.tafseer,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tafseerDownloadProvider);
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final isDownloading = state.isDownloading[tafseer.id] == true;
    final isCompleted = state.isCompleted[tafseer.id] == true;
    final progress = state.progress[tafseer.id] ?? 0.0;
    final error = state.errors[tafseer.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Action button
          if (isDownloading)
            SizedBox(
              width: 90,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primaryBlue,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => ref.read(tafseerDownloadProvider.notifier).cancelDownload(tafseer.id),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.amiri(fontSize: 12, color: AppColors.error),
                    ),
                  )
                ],
              ),
            )
          else if (isCompleted)
            ElevatedButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text('محمل', style: GoogleFonts.amiri(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold.withValues(alpha: 0.1),
                foregroundColor: AppColors.accentGold,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                ref.read(tafseerDownloadProvider.notifier).startDownload(tafseer.id);
              },
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text('تحميل', style: GoogleFonts.amiri(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tafseer.nameAr,
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  error ?? tafseer.author,
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    color: error != null ? AppColors.error : subtext,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف ${tafseer.nameAr}؟', style: GoogleFonts.amiri(fontSize: 18), textDirection: TextDirection.rtl),
        content: Text('هل أنت متأكد أنك تريد حذف هذا التفسير؟', style: GoogleFonts.amiri(), textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.amiri()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tafseerDownloadProvider.notifier).deleteTafseer(tafseer.id);
            },
            child: Text('حذف', style: GoogleFonts.amiri()),
          ),
        ],
      ),
    );
  }
}
