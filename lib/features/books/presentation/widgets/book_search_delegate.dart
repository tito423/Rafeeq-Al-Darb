import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/text_book_model.dart';

class BookSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final TextBookModel book;

  BookSearchDelegate({required this.book}) : super(
    searchFieldLabel: 'ابحث في الكتاب...',
    searchFieldStyle: GoogleFonts.amiri(fontSize: 18),
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().length < 3) {
      return Center(
        child: Text(
          'أدخل 3 أحرف على الأقل للبحث',
          style: GoogleFonts.amiri(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return const SizedBox.shrink();

    // Find all chapters containing the query
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < book.chapters.length; i++) {
      final chapter = book.chapters[i];
      if (chapter.content.toLowerCase().contains(lowerQuery) || 
          chapter.title.toLowerCase().contains(lowerQuery)) {
        
        // Find snippet
        String snippet = chapter.content;
        int matchIdx = snippet.toLowerCase().indexOf(lowerQuery);
        if (matchIdx != -1) {
          int start = (matchIdx - 50).clamp(0, snippet.length);
          int end = (matchIdx + lowerQuery.length + 50).clamp(0, snippet.length);
          snippet = '...${snippet.substring(start, end).replaceAll('\n', ' ')}...';
        } else {
          snippet = 'تطابق في العنوان';
        }

        results.add({
          'index': i,
          'title': chapter.title,
          'snippet': snippet,
          'query': lowerQuery,
        });
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'لم يتم العثور على نتائج',
          style: GoogleFonts.amiri(fontSize: 18, color: textColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final res = results[index];
        return ListTile(
          title: Text(
            res['title'],
            style: GoogleFonts.amiri(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          subtitle: Text(
            res['snippet'],
            style: GoogleFonts.amiri(fontSize: 14, color: textColor),
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            close(context, res);
          },
        );
      },
    );
  }
}
