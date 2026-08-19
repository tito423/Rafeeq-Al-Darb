import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/github_config_service.dart';
import 'hadith_reader_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);
    final textColor = isDark ? Colors.white : Colors.black87;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'المكتبة الإسلامية',
            style: GoogleFonts.amiri(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: AppColors.lightSubtext,
            labelStyle: GoogleFonts.amiri(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'كتب الحديث'),
              Tab(text: 'مواقع إسلامية'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BooksTab(),
            _WebsitesTab(),
          ],
        ),
      ),
    );
  }
}

class _BooksTab extends ConsumerWidget {
  const _BooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configAsync = ref.watch(githubConfigProvider);

    return configAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (error, stack) => Center(
        child: Text(
          'حدث خطأ في تحميل البيانات',
          style: GoogleFonts.amiri(color: Colors.red),
        ),
      ),
      data: (config) {
        final books = config.library.books;

        if (books.isEmpty) {
          return Center(
            child: Text(
              'لا توجد كتب حالياً',
              style: GoogleFonts.amiri(
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                leading: const Icon(Icons.book, color: AppColors.primaryBlue),
                title: Text(
                  book.title,
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  book.description.isNotEmpty ? book.description : book.author,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.lightSubtext),
                ),
                trailing: Icon(Icons.download_rounded, color: AppColors.accentGold.withValues(alpha: 0.7)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HadithReaderScreen(
                        bookId: book.id,
                        bookTitle: book.title,
                        downloadUrl: book.downloadUrl,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _WebsitesTab extends ConsumerWidget {
  const _WebsitesTab();

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configAsync = ref.watch(githubConfigProvider);

    return configAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (error, stack) => Center(
        child: Text(
          'حدث خطأ في تحميل البيانات',
          style: GoogleFonts.amiri(color: Colors.red),
        ),
      ),
      data: (config) {
        final websites = config.library.websites;

        if (websites.isEmpty) {
          return Center(
            child: Text(
              'لا توجد مواقع حالياً',
              style: GoogleFonts.amiri(
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: websites.length,
          itemBuilder: (context, index) {
            final site = websites[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                leading: const Icon(Icons.language_rounded, color: AppColors.primaryBlue),
                title: Text(
                  site.name,
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: const Icon(Icons.open_in_browser_rounded, color: AppColors.accentGold),
                onTap: () => _launchUrl(site.url),
              ),
            );
          },
        );
      },
    );
  }
}
