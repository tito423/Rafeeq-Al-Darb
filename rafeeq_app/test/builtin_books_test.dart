import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/library/data/builtin_books.dart';

/// Every book that ships inside the app has its asset, declared in
/// pubspec, byte-for-byte the size the catalogue records - the size
/// `isBookDownloaded` checks. A mismatch would install a book and then
/// report it as not downloaded, for ever.
void main() {
  test('each built-in book has an asset of the catalogued size', () {
    expect(builtinBookIds.length, greaterThanOrEqualTo(32));
    for (final id in builtinBookIds) {
      final f = File('assets/data/builtin_books/$id.json');
      expect(f.existsSync(), isTrue, reason: '$id has no asset');
      final bytes = f.readAsBytesSync();
      expect(bytes.sublist(0, 2), [0x1f, 0x8b], reason: '$id is not gzip');
      final want = bookById(id)?.textEdition?.sizeBytes ?? 0;
      if (want != 0) expect(bytes.length, want, reason: id);
    }
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('assets/data/builtin_books/'));
  });
}
