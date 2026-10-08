import 'package:flutter/services.dart';

import '../../library/data/book_text.dart';
import 'text_corrections.dart';

/// The three tajweed mutoon the course levels are built on - تحفة الأطفال،
/// متن الجزرية، التمهيد - ship inside the app: «حط … المتون built-in في
/// التطبيق لأن تحميلهم بيفشل لما التطبيق بيروح في الخلفية» (2026-09-19).
/// The files under `assets/data/builtin_books/` are the bytes R2 serves at
/// `books/text/<id>.json`, verbatim (gzip, sniffed by [BookText.fromBytes]);
/// the typing errors listed in `text_corrections.dart` are corrected on read.
Future<BookText> bundledMatn(String id) async {
  final d = await rootBundle.load('assets/data/builtin_books/$id.json');
  return correctedBookText(
    id,
    BookText.fromBytes(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)),
  );
}
