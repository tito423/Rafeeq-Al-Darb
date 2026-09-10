import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/hadith_repository.dart';

/// «لما بفتح سنن النسائي بتحمل على الفاضي ومش بتنزل حاجة».
///
/// Reproduced on emulator-5554 and traced to a single row. In Sunan an-Nasa'i,
/// «كتاب المزارعة» is numbered **35.2** — a real sub-book sitting between
/// «كتاب الأيمان والنذور» (35) and «كتاب عشرة النساء» (36), carrying 83
/// hadiths. SQLite stores it as a REAL. `HadithChapter.fromRow` did
/// `r['chapter_no'] as int`, which throws a `TypeError` on a double, and
/// because the cast runs while mapping the result set it took **all 52** of
/// the collection's books down with it — not just the odd one.
///
/// Measured across the bundled database: 1,482 chapters in nine collections,
/// exactly one of them fractional. One row, one whole collection.
///
/// The maps below are the real column shapes, with the real values.
void main() {
  Map<String, Object?> chapterRow(Object? no) => {
        'book_id': 5,
        'chapter_no': no,
        'name_ar': 'كتاب المزارعة',
        'name_en': 'The Book of Sharecropping',
      };

  test('a fractional chapter number does not throw', () {
    // This is the line that used to fail. `as int` on 35.2 is a TypeError.
    final c = HadithChapter.fromRow(chapterRow(35.2));
    expect(c.chapterNo, 35.2);
    expect(c.nameAr, 'كتاب المزارعة');
  });

  test('whole numbers still read and still print without a decimal point', () {
    expect(HadithChapter.fromRow(chapterRow(35)).chapterLabel, '35');
    // A REAL that happens to be whole — SQLite can hand back either.
    expect(HadithChapter.fromRow(chapterRow(35.0)).chapterLabel, '35');
  });

  test('the fractional one prints as the source writes it', () {
    // Not rounded to 35, not renumbered to 36: renumbering would push every
    // later book out of step with the printed edition.
    expect(HadithChapter.fromRow(chapterRow(35.2)).chapterLabel, '35.2');
  });

  test('a missing chapter number is a zero, not a crash', () {
    expect(HadithChapter.fromRow(chapterRow(null)).chapterNo, 0);
  });

  test('the hadith rows carry the same fractional number', () {
    // 83 of them do, so this cast had to widen as well.
    final h = HadithItem.fromRow({
      'id': 1,
      'book_id': 5,
      'chapter_no': 35.2,
      'number_in_book': 3901,
      'arabic': 'نص',
    });
    expect(h.chapterNo, 35.2);
    expect(h.numberInBook, 3901);
  });
}
