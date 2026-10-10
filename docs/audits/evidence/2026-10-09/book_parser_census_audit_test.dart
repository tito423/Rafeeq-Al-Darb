import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/text_corrections.dart';

void main() {
  test('all289 downloaded books parse with production model; corrections do not affect marked ayahs', () {
    final evidence = Directory('../docs/audits/evidence/2026-10-09');
    final census = jsonDecode(File('${evidence.path}/content-structure.json').readAsStringSync()) as Map;
    final rootCache = Directory('${Directory.systemTemp.path}/rafeeq_audit_content_20261009');
    // Wire SHA comes from the actual fetched bytes, not a generated book fixture.
    final cacheBySha = <String, File>{};
    // The full comparison keeps the primary URL SHA filename explicitly derivable
    // from its cache; use its metadata in the manifest written by this proof setup.
    final manifest = jsonDecode(File('${evidence.path}/book-cache-paths.json').readAsStringSync()) as List;
    for (final record in manifest) {
      cacheBySha[record['id'] as String] = File('${rootCache.path}/${record['filename']}');
    }
    final results = <Map<String, Object?>>[];
    for (final record in census['books'] as List) {
      final book = BookText.fromBytes(cacheBySha[record['id']]!.readAsBytesSync());
      expect(book.pages, isNotEmpty, reason: record['id'] as String);
      expect(book.meta.pageCount, book.pages.length);
      expect(book.toc.every((s) => s.pageIndex >= 0 && s.pageIndex < book.pages.length), isTrue,
        reason: '${record['id']} production-resolved TOC');
      results.add({'id': record['id'], 'pages': book.pages.length,
        'sections': book.toc.length, 'printReliable': book.meta.printReliable});
    }
    final corrections = <Map<String, Object?>>[];
    for (final id in tajweedTextCorrections.keys) {
      final book = BookText.fromBytes(File('assets/data/builtin_books/$id.json').readAsBytesSync());
      final corrected = correctedBookText(id, book);
      final changes = <Map<String, Object?>>[];
      for (var pi = 0; pi < book.pages.length; pi++) {
        for (var ai = 0; ai < book.pages[pi].paras.length; ai++) {
          final before = book.pages[pi].paras[ai];
          final after = corrected.pages[pi].paras[ai];
          if (before.text != after.text) {
            changes.add({'pageIndex': pi, 'printedPage': book.pages[pi].printedPage,
              'kind': before.kind, 'ref': before.ref});
            expect(before.kind, isNot('aya'), reason: '$id page$pi scripture exclusion');
          }
        }
      }
      corrections.add({'id': id, 'changedParagraphs': changes});
    }
    File('${evidence.path}/book-parser-census.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'books': results, 'corrections': corrections,
        'scope': 'Actual production parser on all289 fetched primary files. No correctness claim for unmarked scripture or transcription against print.'}));
    print('AUDIT_BOOK_PARSER: ${results.length} actual files parsed; all nonempty; '
      'every resolved TOC index in range. Correction changes recorded by kind/reference.');
  });
}
