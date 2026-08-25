import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/text_book_model.dart';
import 'package:provider/provider.dart';
import '../providers/reader_settings_provider.dart';

class BookIndexDrawer extends StatelessWidget {
  final TextBookModel book;
  final int currentIndex;
  final Function(int) onChapterSelected;
  final List<String> bookmarks;

  const BookIndexDrawer({
    super.key,
    required this.book,
    required this.currentIndex,
    required this.onChapterSelected,
    this.bookmarks = const [],
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettingsProvider>();
    final isDark = settings.isNightMode;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.3 : 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'الفهرس',
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: book.chapters.length,
              itemBuilder: (context, index) {
                final chapter = book.chapters[index];
                final isSelected = index == currentIndex;
                final isBookmarked = bookmarks.contains(index.toString());

                return ListTile(
                  title: Text(
                    chapter.title,
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      color: isSelected ? AppColors.accentGold : textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isBookmarked ? const Icon(Icons.bookmark, color: AppColors.accentGold, size: 20) : null,
                  selected: isSelected,
                  selectedTileColor: AppColors.accentGold.withValues(alpha: 0.1),
                  onTap: () => onChapterSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
