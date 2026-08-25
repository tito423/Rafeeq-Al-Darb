import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/mushaf_style.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';

class MushafBrowserScreen extends ConsumerStatefulWidget {
  const MushafBrowserScreen({super.key});

  @override
  ConsumerState<MushafBrowserScreen> createState() => _MushafBrowserScreenState();
}

class _MushafBrowserScreenState extends ConsumerState<MushafBrowserScreen> {
  late PageController _pageController;
  double _currPageValue = 0.0;
  final availableStyles = MushafStyle.values;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.65);
    _pageController.addListener(() {
      setState(() {
        _currPageValue = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadManagerProvider);
    final downloadNotifier = ref.read(downloadManagerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0),
      appBar: AppBar(
        title: Text(
          'معرض المصاحف',
          style: GoogleFonts.scheherazadeNew(
              fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.accentGold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Column(
        children: [
          // Bulk download progress indicator
          if (downloadState.isBulkDownloading)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جاري التنزيل...',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                      Text(
                        '${downloadState.bulkCompleted} / ${downloadState.bulkTotal}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.accentGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: downloadState.bulkProgress,
                      minHeight: 8,
                      color: AppColors.accentGold,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => downloadNotifier.cancelBulkDownload(),
                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 18),
                      label: const Text('إلغاء التنزيل', style: TextStyle(color: Colors.redAccent)),
                    ),
                  )
                ],
              ),
            ),

          // Interactive 3D Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: availableStyles.length,
              itemBuilder: (context, index) {
                final style = availableStyles[index];
                final info = getMushafStyleInfo(style);

                // Math for 3D scale and rotation effect
                double transformValue = 0.0;
                if (_pageController.position.haveDimensions) {
                  transformValue = index - _currPageValue;
                }
                
                final scale = max(0.8, (1 - (transformValue.abs() * 0.3)));
                final fade = max(0.4, (1 - (transformValue.abs() * 0.6)));

                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: fade,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cover Image with Shadow
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 15),
                                )
                              ],
                              image: DecorationImage(
                                image: AssetImage(info.localThumbCover),
                                fit: BoxFit.cover,
                              ),
                            ),
                            // If local asset missing, fallback to nice gold box
                            child: Image.asset(
                              info.localThumbCover,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(
                                decoration: BoxDecoration(
                                  color: AppColors.darkNavBar,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(Icons.menu_book_rounded, size: 60, color: AppColors.accentGold),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Metadata
                        Text(
                          info.nameAr,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                              fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${info.riwayah} • ${info.totalPages} صفحة',
                          style: GoogleFonts.cairo(
                              fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        const SizedBox(height: 20),
                        // Action Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: downloadState.isBulkDownloading ? null : () {
                            downloadNotifier.downloadAllMushaafPages(styleInfo: info, concurrency: 5);
                          },
                          icon: const Icon(Icons.download_rounded, size: 22),
                          label: Text(
                            'تنزيل المصحف',
                            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
