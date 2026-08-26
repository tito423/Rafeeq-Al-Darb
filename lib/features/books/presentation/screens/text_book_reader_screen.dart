import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/text_book_model.dart';
import '../providers/reader_settings_provider.dart';
import '../widgets/book_index_drawer.dart';

class TextBookReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String title;
  final String bookUrl; // URL or local asset path for the JSON file

  const TextBookReaderScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.bookUrl,
  });

  @override
  ConsumerState<TextBookReaderScreen> createState() => _TextBookReaderScreenState();
}

class _TextBookReaderScreenState extends ConsumerState<TextBookReaderScreen> {
  TextBookModel? _book;
  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  String _searchQuery = '';
  List<String> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  Future<void> _loadBookData() async {
    try {
      // If it's a network URL, we would use http.get. 
      // For now, assuming it's a local asset or handling both.
      String jsonString;
      if (widget.bookUrl.startsWith('http')) {
        // Implement HTTP fetching if needed. Using rootBundle for sample.
        throw Exception("Network fetching not implemented yet. Use local asset for testing.");
      } else {
        jsonString = await rootBundle.loadString(widget.bookUrl);
      }
      
      final Map<String, dynamic> data = json.decode(jsonString);
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('book_page_${widget.title}');
      final savedBookmarks = prefs.getStringList('bookmarks_${widget.title}') ?? [];

      setState(() {
        _book = TextBookModel.fromJson(data);
        _bookmarks = savedBookmarks;
        _isLoading = false;
        if (savedPage != null && savedPage < _book!.chapters.length) {
          _currentPageIndex = savedPage;
        }
      });
      
      if (_currentPageIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentPageIndex);
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _saveCurrentPage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('book_page_${widget.title}', index);
  }

  bool _isBookmarked(int index) {
    return _bookmarks.contains(index.toString());
  }

  void _toggleBookmark(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_isBookmarked(index)) {
        _bookmarks.remove(index.toString());
      } else {
        _bookmarks.add(index.toString());
      }
    });
    await prefs.setStringList('bookmarks_${widget.title}', _bookmarks);
  }

  void _goToChapter(int index) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
    Navigator.of(context).pop(); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final bgColor = settings.isNightMode ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = settings.isNightMode ? Colors.white70 : Colors.black87;
    final appBarColor = settings.isNightMode ? AppColors.darkSurface : Colors.white;

    return Scaffold(
            backgroundColor: bgColor,
            endDrawer: _book != null 
                ? BookIndexDrawer(
                    book: _book!,
                    currentIndex: _currentPageIndex,
                    onChapterSelected: _goToChapter,
                    bookmarks: _bookmarks,
                  )
                : null,
            appBar: AppBar(
              backgroundColor: appBarColor,
              elevation: 0,
              iconTheme: IconThemeData(color: AppColors.accentGold),
              title: Text(
                widget.title,
                style: GoogleFonts.amiri(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [
                if (_book != null)
                  IconButton(
                    icon: Icon(
                      _isBookmarked(_currentPageIndex) ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: () {
                      _toggleBookmark(_currentPageIndex);
                    },
                  ),
                if (_book != null)
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final result = await showSearch<Map<String, dynamic>?>(
                        context: context,
                        delegate: BookSearchDelegate(book: _book!),
                      );
                      if (result != null) {
                        setState(() {
                          _searchQuery = result['query'] as String;
                        });
                        _goToChapter(result['index'] as int);
                      }
                    },
                  ),
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_book),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                _buildSettingsBar(settings, appBarColor),
                Expanded(
                  child: _buildReaderBody(textColor, settings),
                ),
              ],
            ),
          );
  }

  Widget _buildSettingsBar(ReaderSettings notifier, Color bgColor) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(notifier.isNightMode ? Icons.wb_sunny : Icons.nightlight_round,
                color: AppColors.accentGold),
            onPressed: () => ref.read(readerSettingsProvider.notifier).toggleNightMode(),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.accentGold),
                onPressed: () => ref.read(readerSettingsProvider.notifier).decreaseFontSize(),
              ),
              Text(
                'A',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.accentGold),
                onPressed: () => ref.read(readerSettingsProvider.notifier).increaseFontSize(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody(Color textColor, ReaderSettings settings) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
    }

    if (_error != null) {
      return Center(
        child: Text(
          'خطأ في تحميل الكتاب: $_error',
          style: TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_book == null || _book!.chapters.isEmpty) {
      return Center(
        child: Text(
          'الكتاب فارغ',
          style: GoogleFonts.amiri(fontSize: 20, color: textColor),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
        _saveCurrentPage(index);
      },
      itemCount: _book!.chapters.length,
      itemBuilder: (context, index) {
        final chapter = _book!.chapters[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                chapter.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.getFont(
                  settings.fontFamily,
                  fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(height: 24),
              _buildHighlightedText(
                chapter.content,
                textColor,
                settings,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, Color textColor, ReaderSettingsProvider settings) {
    if (_searchQuery.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.getFont(
          settings.fontFamily,
          fontSize: settings.fontSize,
          color: textColor,
          height: 1.8,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final matches = lowerText.split(_searchQuery);
    
    if (matches.length == 1) {
      return Text(
        text,
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.getFont(
          settings.fontFamily,
          fontSize: settings.fontSize,
          color: textColor,
          height: 1.8,
        ),
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (int i = 0; i < matches.length; i++) {
      if (matches[i].isNotEmpty) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, currentIndex + matches[i].length),
          style: GoogleFonts.getFont(
            settings.fontFamily,
            fontSize: settings.fontSize,
            color: textColor,
            height: 1.8,
          ),
        ));
        currentIndex += matches[i].length;
      }
      if (i < matches.length - 1) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, currentIndex + _searchQuery.length),
          style: GoogleFonts.getFont(
            settings.fontFamily,
            fontSize: settings.fontSize,
            color: Colors.black, // Dark text for highlight
            backgroundColor: AppColors.accentGold, // Highlight color
            fontWeight: FontWeight.bold,
            height: 1.8,
          ),
        ));
        currentIndex += _searchQuery.length;
      }
    }

    return RichText(
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }
}
