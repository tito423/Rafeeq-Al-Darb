import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../data/book_catalog.dart';

/// Reads a downloaded book's real PDF file offline — no network involved
/// once the file is on disk. `path` is the file [DownloadManager] wrote to
/// (see `library_screen.dart`'s book-catalog tab).
class BookReaderScreen extends StatelessWidget {
  final LibraryBook book;
  final String path;

  const BookReaderScreen({super.key, required this.book, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.titleAr)),
      body: SfPdfViewer.file(
        File(path),
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
