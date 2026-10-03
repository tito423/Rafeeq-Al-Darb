import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/book_category.dart';
import 'package:rafeeq_app/features/library/data/library_featured.dart';

/// «ابدأ بها» lists (library_featured.dart): a featured book sits on the
/// shelf it is featured on, and no shelf lists one twice. A book featured on
/// the wrong shelf would vanish from both lists on screen — the tab groups a
/// shelf's own books only.
void main() {
  final byId = {for (final b in libraryBookCatalog) b.id: b};

  test('each featured book is on the shelf that features it', () {
    featuredBookIds.forEach((cat, ids) {
      expect(ids.toSet().length, ids.length, reason: '$cat repeats a book');
      for (final id in ids) {
        final b = byId[id];
        if (b == null) continue; // not catalogued (yet): skipped by the tab
        expect(b.category, cat, reason: id);
      }
    });
  });

  test('التزكية والرقائق and طالب العلم have no featured list', () {
    expect(featuredBookIds.containsKey(BookCategory.tazkiyah), isFalse,
        reason: 'owner 2026-10-03: «ماعدا الزهد والرقائق سيبه»');
    expect(featuredBookIds.containsKey(BookCategory.talibIlm), isFalse,
        reason: 'that shelf is shown by stage');
  });

  test('every shelf with a list already opens on catalogued books', () {
    featuredBookIds.forEach((cat, ids) {
      expect(ids.where(byId.containsKey), isNotEmpty, reason: '$cat');
    });
  });
}
