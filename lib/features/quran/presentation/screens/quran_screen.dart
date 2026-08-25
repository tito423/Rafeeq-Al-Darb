import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/quran_provider.dart';
import '../widgets/mushaf_page_widget.dart';
import 'mushaf_browser_screen.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  late final PageController _pageController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    // Load last read page
    final lastRead = ref.read(lastReadProvider);
    _currentPage = lastRead.pageNumber;
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'المصحف الشريف',
          style: GoogleFonts.scheherazadeNew(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.accentGold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'معرض المصاحف',
            icon: const Icon(Icons.download_rounded, color: AppColors.primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MushafBrowserScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Page strip
          Container(
            height: 32,
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الصفحة $_currentPage من ٦٠٤',
                  style: GoogleFonts.amiri(
                    fontSize: 13,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                ),
                LinearProgressIndicator(
                  value: _currentPage / 604,
                  minHeight: 3,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  color: AppColors.accentGold,
                ),
              ],
            ),
          ),
          // Direct Mushaf Gallery (PageView)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 604,
              reverse: true, // Right to left scrolling
              onPageChanged: (index) {
                setState(() => _currentPage = index + 1);
                ref.read(lastReadProvider.notifier).save(
                      surahId: 1, // Placeholder
                      surahNameAr: 'المصحف',
                      surahNameEn: 'Mushaf',
                      ayahNumber: 1,
                      pageNumber: _currentPage,
                    );
              },
              itemBuilder: (context, index) {
                return MushaafPageWidget(
                  pageNumber: index + 1,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
