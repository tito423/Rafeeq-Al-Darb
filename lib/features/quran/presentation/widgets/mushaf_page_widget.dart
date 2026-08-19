import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';
import '../../../../core/models/mushaf_style.dart';

class MushaafPageWidget extends ConsumerWidget {
  final int pageNumber;
  final bool isDark;

  const MushaafPageWidget({
    super.key,
    required this.pageNumber,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleInfo = ref.watch(mushafStyleInfoProvider);
    final downloadManager = ref.read(downloadManagerProvider.notifier);
    final taskId = 'page_${styleInfo.style.name}_$pageNumber';
    final taskAsync = ref.watch(pageDownloadTaskProvider(taskId));
    return FutureBuilder<String?>(
      future: downloadManager.getLocalPagePath(
        pageNumber,
        styleInfo.style.name,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.accentGold),
          );
        }

        // If file exists locally, show it
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return _LocalPageImage(filePath: snapshot.data!, isDark: isDark);
        }

        // If currently downloading, show progress
        if (taskAsync != null && taskAsync.isDownloading) {
          return _DownloadProgressView(
            pageNumber: pageNumber,
            progress: taskAsync.progress,
            isDark: isDark,
          );
        }

        // If error
        if (taskAsync != null && taskAsync.hasError) {
          return _DownloadErrorView(
            pageNumber: pageNumber,
            isDark: isDark,
            onRetry: () => ref
                .read(downloadManagerProvider.notifier)
                .downloadMushaafPage(pageNumber, styleInfo: styleInfo),
          );
        }

        // Not downloaded yet — show download prompt
        return _DownloadPromptView(
          pageNumber: pageNumber,
          isDark: isDark,
          onDownload: () => ref
              .read(downloadManagerProvider.notifier)
              .downloadMushaafPage(pageNumber, styleInfo: styleInfo),
        );
      },
    );
  }
}

// ── Local image display ───────────────────────────────────────────────────────

class _LocalPageImage extends StatelessWidget {
  final String filePath;
  final bool isDark;

  const _LocalPageImage({required this.filePath, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Image.file(
        File(filePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                Text(
                  'خطأ في تحميل الصورة، يرجى إعادة المحاولة',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Download progress ─────────────────────────────────────────────────────────

class _DownloadProgressView extends StatelessWidget {
  final int pageNumber;
  final double progress;
  final bool isDark;

  const _DownloadProgressView({
    required this.pageNumber,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'جارٍ تحميل الصفحة $pageNumber',
            style: GoogleFonts.amiri(
              fontSize: 16,
              color: isDark
                  ? AppColors.darkOnSurface
                  : AppColors.lightOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Download prompt ───────────────────────────────────────────────────────────

class _DownloadPromptView extends StatelessWidget {
  final int pageNumber;
  final bool isDark;
  final VoidCallback onDownload;

  const _DownloadPromptView({
    required this.pageNumber,
    required this.isDark,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 48,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'صفحة المصحف',
              style: GoogleFonts.scheherazadeNew(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الصفحة $pageNumber غير محملة بعد.\nاضغط لتحميل صورة المصحف.',
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 15,
                color: subtext,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
              label: Text(
                'تحميل الصفحة',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _DownloadErrorView extends StatelessWidget {
  final int pageNumber;
  final bool isDark;
  final VoidCallback onRetry;

  const _DownloadErrorView({
    required this.pageNumber,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'فشل تحميل الصفحة $pageNumber',
            style: GoogleFonts.amiri(fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
