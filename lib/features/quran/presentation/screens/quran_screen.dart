import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/quran_provider.dart';
import '../widgets/mushaf_page_widget.dart';
import 'mushaf_browser_screen.dart';
import 'surah_reading_screen.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final TabController _tabController;
  int _imageCurrentPage = 1;
  int _textCurrentSurahId = 1;
  int _textCurrentPage = 1;

  @override
  void initState() {
    super.initState();
    final lastRead = ref.read(lastReadProvider);
    _textCurrentSurahId = lastRead.surahId;
    _textCurrentPage = lastRead.pageNumber;
    _imageCurrentPage = lastRead.pageNumber;
    _pageController = PageController(initialPage: _imageCurrentPage - 1);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _goToSuraOrPage(int surahId, int pageNumber) {
    final activeTabIndex = _tabController.index;
    setState(() {
      if (activeTabIndex == 0) { // Text Mushaf
        _textCurrentSurahId = surahId;
        _textCurrentPage = pageNumber;
      } else { // Image Mushaf
        _imageCurrentPage = pageNumber;
        _pageController.jumpToPage(pageNumber - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return Scaffold(
      backgroundColor: bgColor,
      drawer: _buildDrawer(isDark),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          indicatorColor: AppColors.accentGold,
          tabs: const [
            Tab(text: 'مصحف نصي'),
            Tab(text: 'مصحف مصور'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Text Mushaf
          SurahReadingScreen(
            surahId: _textCurrentSurahId,
            startPage: _textCurrentPage,
            showAppBar: false,
          ),
          
          // Image Mushaf
          Column(
            children: [
              Container(
                height: 32,
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الصفحة $_imageCurrentPage من ٦٠٤',
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                      ),
                    ),
                    LinearProgressIndicator(
                      value: _imageCurrentPage / 604,
                      minHeight: 3,
                      backgroundColor: AppColors.primaryBlue.withAlpha(25),
                      color: AppColors.accentGold,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 604,
                  reverse: true, // Right to left scrolling
                  onPageChanged: (index) {
                    setState(() => _imageCurrentPage = index + 1);
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
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    final surahsAsync = ref.watch(surahsProvider);
    
    return Drawer(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Text(
                'فهرس السور',
                style: GoogleFonts.reemKufi(
                  fontSize: 24,
                  color: AppColors.accentGold,
                ),
              ),
            ),
            Expanded(
              child: surahsAsync.when(
                data: (surahs) => ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return ListTile(
                      leading: Text(
                        '${surah.id}',
                        style: GoogleFonts.amiri(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        surah.nameAr,
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                        ),
                      ),
                      subtitle: Text(
                        'الصفحة ${surah.pageNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        _goToSuraOrPage(surah.id, surah.pageNumber);
                      },
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('خطأ في تحميل الفهرس')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
