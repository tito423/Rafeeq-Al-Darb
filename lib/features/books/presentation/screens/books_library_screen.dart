import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';
import 'book_reader_screen.dart';
import 'text_book_reader_screen.dart';

class BooksLibraryScreen extends ConsumerStatefulWidget {
  const BooksLibraryScreen({super.key});

  @override
  ConsumerState<BooksLibraryScreen> createState() => _BooksLibraryScreenState();
}

class _BooksLibraryScreenState extends ConsumerState<BooksLibraryScreen> {
  List<dynamic> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final jsonString = await rootBundle.loadString('lib/features/books/data/books_catalog.json');
      setState(() {
        _books = json.decode(jsonString);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading books catalog: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadState = ref.watch(downloadManagerProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'المكتبة الإسلامية',
          style: GoogleFonts.amiri(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.accentGold,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _books.isEmpty
              ? Center(
                  child: Text(
                    'لم يتم العثور على كتب',
                    style: GoogleFonts.amiri(fontSize: 18, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return _buildBookCard(book, isDark, downloadState);
                  },
                ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, bool isDark, DownloadState downloadState) {
    final coverUrl = book['cover_url'] as String?;
    final title = book['title'] as String;
    final author = book['author'] as String;
    final bookId = book['id'] ?? '';
    final downloadUrl = book['download_url'] ?? '';
    final format = book['format'] ?? 'text';
    
    final taskId = 'book_$bookId';
    final task = downloadState.tasks[taskId];
    final isDownloaded = ref.read(downloadManagerProvider.notifier).isDownloadedLocally(taskId);
    final isDownloading = task?.isDownloading ?? false;
    final progress = task?.progress ?? 0.0;

    return GestureDetector(
      onTap: () {
        if (!isDownloaded && !downloadUrl.startsWith('assets/')) {
          if (!isDownloading) {
            if (format == 'pdf') {
              ref.read(downloadManagerProvider.notifier).downloadBookPdf(
                bookId,
                downloadUrl,
                title,
              );
            } else {
              ref.read(downloadManagerProvider.notifier).downloadBook(
                bookId: bookId, 
                downloadUrl: downloadUrl,
              );
            }
          }
          return;
        }

        if (format == 'text') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TextBookReaderScreen(
                bookId: bookId,
                title: title,
                bookUrl: downloadUrl,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookReaderScreen(
                bookId: bookId,
                title: title,
                pdfUrl: downloadUrl,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDownloaded ? AppColors.primaryBlue : AppColors.accentGold.withValues(alpha: 0.3),
            width: isDownloaded ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _buildPlaceholderCover(),
                          )
                        : _buildPlaceholderCover(),
                  ),
                  if (isDownloading)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        color: AppColors.accentGold,
                      ),
                    ),
                  if (!isDownloaded && !isDownloading && !downloadUrl.startsWith('assets/'))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  if (isDownloaded)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
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
  }

  Widget _buildPlaceholderCover() {
    return Container(
      color: AppColors.primaryBlue.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 48,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}
