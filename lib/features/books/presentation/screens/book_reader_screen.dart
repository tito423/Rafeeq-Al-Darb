import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';

class BookReaderScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;

  const BookReaderScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  late SharedPreferences _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoading = false;
    });
  }

  void _saveCurrentPage(int page) {
    _prefs.setInt('book_page_${widget.title}', page);
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F0),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.amiri(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryBlue,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        centerTitle: true,
        elevation: 1,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.primaryBlue,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              _pdfViewerKey.currentState?.openBookmarkView();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Note: Syncfusion PDF Viewer provides built-in search.
              // To hook it up fully, we would add a SearchToolbar.
              // We leave this simple for now.
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
        : (widget.pdfUrl.startsWith('assets/')
            ? SfPdfViewer.asset(
                widget.pdfUrl,
                key: _pdfViewerKey,
                controller: _pdfViewerController,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                enableDoubleTapZooming: true,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  final savedPage = _prefs.getInt('book_page_${widget.title}');
                  if (savedPage != null && savedPage > 1) {
                    _pdfViewerController.jumpToPage(savedPage);
                  }
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  _saveCurrentPage(details.newPageNumber);
                },
              )
            : SfPdfViewer.network(
                widget.pdfUrl,
                key: _pdfViewerKey,
                controller: _pdfViewerController,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                enableDoubleTapZooming: true,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  final savedPage = _prefs.getInt('book_page_${widget.title}');
                  if (savedPage != null && savedPage > 1) {
                    _pdfViewerController.jumpToPage(savedPage);
                  }
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  _saveCurrentPage(details.newPageNumber);
                },
              )),
    );
  }
}
