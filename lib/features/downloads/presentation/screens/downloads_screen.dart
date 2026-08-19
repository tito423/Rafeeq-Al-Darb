import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/models/tafseer.dart';
import '../../../../core/services/tafseer_service.dart';
import '../../../../core/models/mushaf_style.dart';

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
                          'التنزيلات',
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

            // ── Mushaaf section ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _MushaafDownloadSection(
                isDark: isDark,
                downloadState: downloadState,
                cardBg: cardBg,
                textColor: textColor,
                subtext: subtext,
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

// ── Mushaaf section ───────────────────────────────────────────────────────────

class _MushaafDownloadSection extends ConsumerWidget {
  final bool isDark;
  final DownloadManagerState downloadState;
  final Color cardBg;
  final Color textColor;
  final Color subtext;

  const _MushaafDownloadSection({
    required this.isDark,
    required this.downloadState,
    required this.cardBg,
    required this.textColor,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBulk = downloadState.isBulkDownloading;
    final progress = downloadState.bulkProgress;
    final completed = downloadState.bulkCompleted;
    final total = downloadState.bulkTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.accentGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المصحف الشريف',
                    style: GoogleFonts.scheherazadeNew(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '٦٠٤ صفحة بجودة عالية',
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isBulk) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: AppColors.accentGold,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => ref
                      .read(downloadManagerProvider.notifier)
                      .cancelBulkDownload(),
                  icon: const Icon(
                    Icons.stop_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'إيقاف',
                    style: GoogleFonts.amiri(color: Colors.white),
                  ),
                ),
                Text(
                  '$completed / $total صفحة',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Download all button
                ElevatedButton.icon(
                  onPressed: () {
                    final styleInfo = ref.read(mushafStyleInfoProvider);
                    ref
                        .read(downloadManagerProvider.notifier)
                        .downloadAllMushaafPages(styleInfo: styleInfo);
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'تحميل الكل',
                    style: GoogleFonts.amiri(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Text(
                  'حجم تقريبي: ~300MB',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
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
          const SizedBox(height: 16),
          Text(
            'اختر القارئ والسورة لتحميل التلاوة للاستماع بدون إنترنت',
            style: GoogleFonts.amiri(fontSize: 14, color: subtext, height: 1.7),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          ...kReciters.map(
            (reciter) => _ReciterDownloadRow(
              reciter: reciter,
              isDark: isDark,
              textColor: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterDownloadRow extends ConsumerStatefulWidget {
  final Reciter reciter;
  final bool isDark;
  final Color textColor;

  const _ReciterDownloadRow({
    required this.reciter,
    required this.isDark,
    required this.textColor,
  });

  @override
  ConsumerState<_ReciterDownloadRow> createState() =>
      _ReciterDownloadRowState();
}

class _ReciterDownloadRowState extends ConsumerState<_ReciterDownloadRow> {
  int _selectedSurah = 1;

  @override
  Widget build(BuildContext context) {
    final subtext = widget.isDark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Download button
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(downloadManagerProvider.notifier)
                  .downloadSurahAudio(
                    surahNumber: _selectedSurah,
                    reciterId: widget.reciter.id,
                    mp3quranBaseUrl: widget.reciter.mp3quranIdentifier,
                  );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'بدأ تحميل سورة $_selectedSurah — ${widget.reciter.nameAr}',
                    style: GoogleFonts.amiri(),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
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

          // Surah number picker
          SizedBox(
            width: 88,
            child: DropdownButtonFormField<int>(
              value: _selectedSurah,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                isDense: true,
              ),
              items: List.generate(
                114,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _selectedSurah = v!),
            ),
          ),
          const SizedBox(width: 12),

          // Reciter name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.reciter.nameAr,
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  widget.reciter.nameEn,
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
