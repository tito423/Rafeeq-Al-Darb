import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/name_match.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

void main() {
  test('ابن القيم finds the catalogue\'s «ابن قيّم الجوزية»', () {
    expect(nameMatches('الإمام ابن قيّم الجوزية', 'ابن القيم'), isTrue);
    expect(nameMatches('الإمام ابن قيّم الجوزية', 'ابن قيم الجوزيه'), isTrue);
    expect(nameMatches('الإمام ابن قيّم الجوزية', 'القيم'), isTrue);
  });

  test('ابن / بن, any order, partial words', () {
    expect(nameMatches('أبو الفداء، إسماعيل بن كثير', 'ابن كثير'), isTrue);
    expect(nameMatches('الحافظ ابن حجر العسقلاني', 'العسقلاني ابن حجر'),
        isTrue);
    expect(nameMatches('الإمام أبو الفرج ابن الجوزي', 'ابن الجوز'), isTrue);
  });

  test('unrelated names do not match', () {
    expect(nameMatches('الإمام ابن قيّم الجوزية', 'ابن كثير'), isFalse);
    expect(nameMatches('الإمام محيي الدين النووي', 'ابن القيم'), isFalse);
    expect(nameMatches('anything', ''), isFalse);
  });

  test('the real catalogue answers «ابن القيم» with his books only', () {
    final hits = [
      for (final b in libraryBookCatalog)
        if (nameMatches(b.authorAr, 'ابن القيم')) b.authorAr,
    ];
    expect(hits.length, greaterThanOrEqualTo(30));
    expect(hits.every((a) => a.contains('قيّم')), isTrue);
  });
}
