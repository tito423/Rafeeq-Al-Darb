import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';
import '../../../../core/models/mushaf_style.dart';
import '../providers/page_verse_provider.dart';

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
          return _LocalPageImage(
            filePath: snapshot.data!,
            isDark: isDark,
            pageNumber: pageNumber,
          );
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

// ── Local image display with Quranflash-style verse highlighting ──────────────

class _LocalPageImage extends ConsumerStatefulWidget {
  final String filePath;
  final bool isDark;
  final int pageNumber;

  const _LocalPageImage({
    required this.filePath,
    required this.isDark,
    required this.pageNumber,
  });

  @override
  ConsumerState<_LocalPageImage> createState() => _LocalPageImageState();
}

class _LocalPageImageState extends ConsumerState<_LocalPageImage>
    with SingleTickerProviderStateMixin {
  // Standard Mushaf Uthmani: pages 1-2 special, rest have 15 lines
  static const int _linesPerPage = 15;

  VerseInfo? _selectedVerse;
  late AnimationController _cardAnimCtrl;
  late Animation<double> _cardAnim;

  // Track image rendered bounds for accurate line calculation
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cardAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _cardAnim = CurvedAnimation(parent: _cardAnimCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _cardAnimCtrl.dispose();
    super.dispose();
  }

  void _onTapImage(TapDownDetails details, PageVerseMap verseMap) {
    // Get the rendered size of the image widget
    final RenderBox? box =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final localY = details.localPosition.dy;

    // Calculate which line was tapped (1-indexed, top to bottom)
    final double lineHeight = size.height / _linesPerPage;
    final int tappedLine = (localY / lineHeight).floor() + 1;

    final VerseInfo? verse = verseMap.lineToVerse[tappedLine];

    if (verse == null) {
      // Tap on empty area — dismiss
      if (_selectedVerse != null) {
        setState(() => _selectedVerse = null);
        _cardAnimCtrl.reverse();
      }
      return;
    }

    if (_selectedVerse?.verseKey == verse.verseKey) {
      // Same verse tapped — toggle off
      setState(() => _selectedVerse = null);
      _cardAnimCtrl.reverse();
    } else {
      setState(() => _selectedVerse = verse);
      _cardAnimCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verseMapAsync = ref.watch(pageVerseMapProvider(widget.pageNumber));

    return verseMapAsync.when(
      loading: () => _buildImageOnly(),
      error: (_, __) => _buildImageOnly(),
      data: (verseMap) => _buildInteractiveImage(verseMap),
    );
  }

  Widget _buildImageOnly() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Image.file(
        File(widget.filePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _ImageErrorWidget(),
      ),
    );
  }

  Widget _buildInteractiveImage(PageVerseMap verseMap) {
    return Stack(
      children: [
        // ── Zoomable / Pannable mushaf image ──────────────────────────────
        InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: GestureDetector(
            onTapDown: (details) => _onTapImage(details, verseMap),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Mushaf image
                    SizedBox(
                      key: _imageKey,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image.file(
                        File(widget.filePath),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => const _ImageErrorWidget(),
                      ),
                    ),

                    // ── Golden highlight overlay ──────────────────────────
                    if (_selectedVerse != null)
                      _buildHighlightOverlay(constraints, verseMap),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Verse card (bottom sheet style) ──────────────────────────────
        if (_selectedVerse != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: _cardAnim,
              alignment: Alignment.bottomCenter,
              child: _VerseCard(
                verse: _selectedVerse!,
                isDark: widget.isDark,
                onClose: () {
                  setState(() => _selectedVerse = null);
                  _cardAnimCtrl.reverse();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightOverlay(
      BoxConstraints constraints, PageVerseMap verseMap) {
    final double lineHeight = constraints.maxHeight / _linesPerPage;
    final verse = _selectedVerse!;

    // Find all lines belonging to this verse
    final List<int> highlightedLines = verseMap.lineToVerse.entries
        .where((e) => e.value.verseKey == verse.verseKey)
        .map((e) => e.key)
        .toList();

    if (highlightedLines.isEmpty) return const SizedBox.shrink();

    final minLine = highlightedLines.reduce((a, b) => a < b ? a : b);
    final maxLine = highlightedLines.reduce((a, b) => a > b ? a : b);

    final double top = (minLine - 1) * lineHeight;
    final double height = (maxLine - minLine + 1) * lineHeight;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Verse info card ───────────────────────────────────────────────────────────

class _VerseCard extends StatelessWidget {
  final VerseInfo verse;
  final bool isDark;
  final VoidCallback onClose;

  const _VerseCard({
    required this.verse,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F1714), const Color(0xFF14251D)]
              : [const Color(0xFF1B4D3E), const Color(0xFF102118)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'الآية ${verse.verseNumber} • سورة ${verse.surahNumber}',
                    style: GoogleFonts.amiri(
                      fontSize: 13,
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Arabic Text ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              verse.textUthmani,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 22,
                color: Colors.white,
                height: 2.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ── Translation ───────────────────────────────────────────────
          if (verse.translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  verse.translation,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageErrorWidget extends StatelessWidget {
  const _ImageErrorWidget();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.orange),
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
