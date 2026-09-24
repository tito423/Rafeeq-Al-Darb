import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_summary.dart';

/// Every line of «ملخص العمرة» / «ملخص الحج» must be the book's own words.
///
/// The summary is cut from «الفقه المنهجي», never written by the app
/// (CLAUDE.md §1.2). This reads the same bundled chapter the step cards read
/// and fails if any piece of any line - the parts a « … » joins - is not in
/// it character for character.
void main() {
  final raw = File(
    'assets/data/builtin_books/al_fiqh_al_manhaji_hajj.json',
  ).readAsBytesSync();
  final doc =
      jsonDecode(utf8.decode(gzip.decode(raw))) as Map<String, dynamic>;
  // Paragraphs in reading order, joined as they run on across pages.
  final book = [
    for (final page in doc['pages'] as List<dynamic>)
      for (final para in (page as Map<String, dynamic>)['paras'] as List)
        (para as Map<String, dynamic>)['t'] as String,
  ].join(' ');

  for (final (name, stages) in [
    ('umrah', umrahSummary),
    ('hajj', hajjSummary),
  ]) {
    test('$name summary is verbatim from the book', () {
      var pieces = 0;
      for (final stage in stages) {
        expect(stage.lines, isNotEmpty, reason: stage.title);
        for (final line in stage.lines) {
          if (line.kind == SummaryKind.ayah) {
            expect(line.surah, inInclusiveRange(1, 114));
            expect(line.fromAyah, lessThanOrEqualTo(line.toAyah));
            continue;
          }
          for (final piece in line.pieces) {
            expect(piece, isNotEmpty, reason: '${stage.title}: empty piece');
            expect(
              book.contains(piece),
              isTrue,
              reason: '${stage.title}: not in the book: «$piece»',
            );
            pieces++;
          }
        }
      }
      expect(pieces, greaterThan(20));
    });
  }
}
