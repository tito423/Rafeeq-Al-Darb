import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/github_config_service.dart';
import '../../../books/presentation/screens/book_reader_screen.dart';
import '../../../books/presentation/screens/text_book_reader_screen.dart';
import 'hadith_reader_screen.dart';
import 'hadith_search_screen.dart';
import '../../data/datasources/hadith_db_helper.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFFAF7F0);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'المكتبة الإسلامية',
            style: GoogleFonts.scheherazadeNew(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.accentGold : AppColors.primaryBlue,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              color: AppColors.accentGold,
              tooltip: 'بحث في الأحاديث',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HadithSearchScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            labelStyle: GoogleFonts.amiri(fontSize: 15, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'الكتب الإسلامية'),
              Tab(text: 'كتب الحديث'),
              Tab(text: 'المواقع الإسلامية'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _IslamicBooksTab(),
            _HadithBooksTab(),
            _WebsitesTab(),
          ],
        ),
      ),
    );
  }
}

// ── Islamic Books Catalog Tab ────────────────────────────────────────────────
class _IslamicBooksTab extends StatefulWidget {
  const _IslamicBooksTab();

  @override
  State<_IslamicBooksTab> createState() => _IslamicBooksTabState();
}

class _IslamicBooksTabState extends State<_IslamicBooksTab> {
  List<dynamic> _books = [];
  String _selectedCategory = 'الكل';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonString = await rootBundle.loadString('lib/features/books/data/books_catalog.json');
      if (mounted) {
        setState(() {
          _books = json.decode(jsonString);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }

    final categories = ['الكل', ..._books.map((b) => b['category'] as String? ?? '').toSet().where((c) => c.isNotEmpty)];
    final filtered = _selectedCategory == 'الكل'
        ? _books
        : _books.where((b) => b['category'] == _selectedCategory).toList();

    return Column(
      children: [
        // Category Pills
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final cat = categories[idx];
              final isSel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.accentGold : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? AppColors.accentGold : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Grid of Books
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('لا توجد كتب في هذا القسم', style: GoogleFonts.amiri(color: subtext)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final book = filtered[index];
                    return GestureDetector(
                      onTap: () {
                        final isText = book['format'] == 'text' || (book['download_url']?.endsWith('.json') ?? false);
                        
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => isText
                                ? TextBookReaderScreen(
                                    bookId: book['id'] ?? '',
                                    title: book['title'] ?? '',
                                    bookUrl: book['download_url'] ?? '',
                                  )
                                : BookReaderScreen(
                                    bookId: book['id'] ?? '',
                                    title: book['title'] ?? '',
                                    pdfUrl: book['download_url'] ?? '',
                                  ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryBlue.withValues(alpha: 0.8),
                                      AppColors.primaryBlue2.withValues(alpha: 0.9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 42,
                                    color: AppColors.accentGold.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      book['title'] ?? '',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.scheherazadeNew(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      book['author'] ?? '',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.amiri(
                                        fontSize: 12,
                                        color: AppColors.accentGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Hadith Books Tab ──────────────────────────────────────────────────────────
class _HadithBooksTab extends StatefulWidget {
  const _HadithBooksTab();

  @override
  State<_HadithBooksTab> createState() => _HadithBooksTabState();
}

class _HadithBooksTabState extends State<_HadithBooksTab> {
  final _dbHelper = HadithDbHelper();
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;

  static const _collectionNamesAr = {
    'bukhari': 'صحيح البخاري',
    'muslim': 'صحيح مسلم',
    'tirmidhi': 'جامع الترمذي',
    'abudawud': 'سنن أبي داود',
    'nasai': 'سنن النسائي',
    'ibnmajah': 'سنن ابن ماجه',
    'malik': 'موطأ مالك',
    'nawawi': 'الأربعون النووية',
    'qudsi': 'الأحاديث القدسية',
  };

  static const _collectionIcons = {
    'bukhari': '📗',
    'muslim': '📘',
    'tirmidhi': '📙',
    'abudawud': '📕',
    'nasai': '📓',
    'ibnmajah': '📔',
    'malik': '📒',
    'nawawi': '🌟',
    'qudsi': '✨',
  };

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final data = await _dbHelper.getCollections();
      if (mounted) {
        setState(() {
          _collections = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading hadith collections: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }

    if (_collections.isEmpty) {
      return Center(
        child: Text(
          'لا توجد كتب حديث حالياً',
          style: GoogleFonts.amiri(fontSize: 18, color: textColor),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final c = _collections[index];
        final id = c['id'] as String? ?? '';
        final nameAr = _collectionNamesAr[id] ?? (c['name'] as String? ?? id);
        final total = c['total_hadiths'] as int? ?? 0;
        final icon = _collectionIcons[id] ?? '📖';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            title: Text(
              nameAr,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            subtitle: Text(
              '$total حديث',
              style: GoogleFonts.amiri(fontSize: 13, color: subtext),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.accentGold),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HadithReaderScreen(
                    bookId: id,
                    bookTitle: nameAr,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Islamic Websites Tab ──────────────────────────────────────────────────────
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
    final cardBg = isDark ? AppColors.darkCardBackground : Colors.white;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final configAsync = ref.watch(githubConfigProvider);

    return configAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accentGold),
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
              style: GoogleFonts.amiri(fontSize: 18, color: textColor),
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
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.language_rounded, color: AppColors.accentGold),
                ),
                title: Text(
                  site.name,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.accentGold, size: 20),
                onTap: () => _launchUrl(site.url),
              ),
            );
          },
        );
      },
    );
  }
}
