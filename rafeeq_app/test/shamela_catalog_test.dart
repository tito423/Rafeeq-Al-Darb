import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/shamela/data/shamela_catalog.dart';
import 'package:rafeeq_app/features/shamela/data/shamela_catalogue_ids.dart';

/// Against a copy of Shamela's real catalogue (`/ajax/books/`, fetched
/// 2026-09-26: 8,598 books).
void main() {
  final cat = ShamelaCatalog.instance;
  setUpAll(() => cat.loadForTest(gzip.decode(
      File('test/fixtures/shamela_books_2026-09-26.json.gz')
          .readAsBytesSync())));

  test('the whole catalogue, placeholder dropped', () {
    expect(cat.count, 8598); // 8,599 items less the «جميع الكتب» placeholder
  });

  test('a title finds its book first, with or without the article', () {
    expect(cat.search('صيد الخاطر').first.id, 12028);
    expect(cat.search('الفقه المنهجي').first.id, 6369);
    // Harakat and hamza forms do not matter.
    expect(cat.search('صَيْد الخاطِر').first.id, 12028);
  });

  test('a pasted link or a bare id finds that book', () {
    expect(cat.search('https://shamela.ws/book/9632/2').single.id, 9632);
    expect(cat.search('12028').single.id, 12028);
    expect(cat.search('999999999'), isEmpty);
  });

  test('nonsense finds nothing, and results are capped', () {
    expect(cat.search('قثقثقث'), isEmpty);
    expect(cat.search('في', limit: 80).length, lessThanOrEqualTo(80));
  });

  test('every library book mapped to Shamela exists in its catalogue', () {
    // shamela_catalogue_ids.dart, read from each book's own meta: 238 of
    // the 239 (al_fiqh_al_manhaji_hajj is only part of 6369, left out).
    expect(shamelaIdOfLibraryBook.length, 238);
    final missing = [
      for (final e in shamelaIdOfLibraryBook.entries)
        if (cat.search('${e.value}').isEmpty) e.key,
    ];
    expect(missing, isEmpty, reason: 'ids not in Shamela: $missing');
  });
}

