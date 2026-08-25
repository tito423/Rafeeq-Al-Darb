import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../services/download_manager.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String title;
  final String pdfUrl;

  const BookReaderScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.pdfUrl,
  });

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfViewerController;
  late SharedPreferences _prefs;
  bool _isLoading = true;

  bool _isLocal = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Check if downloaded
    final manager = ref.read(downloadManagerProvider.notifier);
    final isDownloaded = await manager.isBookPdfDownloaded(widget.bookId);
    if (isDownloaded) {
      _localPath = await manager.getBookPdfPath(widget.bookId);
      _isLocal = true;
    }

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
          // Download Button
          if (!widget.pdfUrl.startsWith('assets/') && !_isLocal)
            Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(downloadManagerProvider);
                final taskId = 'book_${widget.bookId}';
                final task = state.tasks[taskId];
                final isDownloading = task?.isDownloading ?? false;

                if (isDownloading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: task?.progress,
                          color: AppColors.accentGold,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  );
                }

                if (task?.isCompleted == true) {
                  return const IconButton(
                    icon: Icon(Icons.download_done_rounded, color: AppColors.accentGold),
                    onPressed: null,
                  );
                }

                return IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'تنزيل الكتاب',
                  onPressed: () {
                    ref.read(downloadManagerProvider.notifier).downloadBookPdf(
                          widget.bookId,
                          widget.pdfUrl,
                          widget.title,
                        );
                  },
                );
              },
            ),
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
        : (_isLocal
            ? SfPdfViewer.file(
                File(_localPath!),
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
            : widget.pdfUrl.startsWith('assets/')
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
                : widget.pdfUrl.startsWith('E:\\') || widget.pdfUrl.startsWith('C:\\') || widget.pdfUrl.startsWith('/') || widget.pdfUrl.startsWith('D:\\')
                  ? SfPdfViewer.file(
                      File(widget.pdfUrl),
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
