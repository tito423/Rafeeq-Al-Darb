import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/app_config.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// Every book's download URL must be a real absolute URL.
///
/// This exists because eleven of them were not. `add_seerah_catalog_entries.py`
/// generated `'\${AppConfig.contentBaseUrl}/books/text/x.json'` — and in Dart a
/// backslash-dollar inside a string is an **escaped** dollar, so the string was
/// never interpolated. Every one of those books failed on the device with
/// «لا يوجد اتصال بالإنترنت … Invalid argument(s): No host specified in URI
/// ${AppConfig.contentBaseUrl}/books/text/…», and eight of them shipped that
/// way in v3.6.0, because the previous session verified that the *upload*
/// worked and never opened the app.
///
/// `flutter analyze` cannot see this: the escaped form is a perfectly valid
/// string literal. Only running it, or this test, catches it.
void main() {
  test('every book URL is absolute and points at the content bucket', () {
    expect(libraryBookCatalog, isNotEmpty);
    for (final book in libraryBookCatalog) {
      final url = book.textEdition?.url;
      if (url == null) continue;

      expect(url.contains(r'${'), isFalse,
          reason: '${book.id}: the URL still contains an un-interpolated '
              'template — it is being shipped as literal text: $url');
      expect(url.startsWith(AppConfig.contentBaseUrl), isTrue,
          reason: '${book.id}: URL does not start with the content base: $url');

      final uri = Uri.tryParse(url);
      expect(uri, isNotNull, reason: '${book.id}: unparseable URL: $url');
      expect(uri!.hasAuthority, isTrue,
          reason: '${book.id}: no host in URI — this is exactly the failure '
              'the device reported: $url');
      expect(uri.scheme, anyOf('http', 'https'), reason: '${book.id}: $url');
      expect(uri.path.endsWith('.json'), isTrue, reason: '${book.id}: $url');
    }
  });

  test('every book has a real measured size and a source label', () {
    for (final book in libraryBookCatalog) {
      final edition = book.textEdition;
      if (edition == null) continue;
      // Every card once claimed a hardcoded «1.0 MB». Sizes are measured on
      // the bucket with head_object; 0 would mean unknown, and none are.
      expect(edition.sizeBytes, greaterThan(0), reason: book.id);
      expect(edition.sourceLabel.trim(), isNotEmpty, reason: book.id);
    }
  });

  test('no book is missing its author or title', () {
    // sahih_as_seerah_albani shipped with an empty authorAr, because Shamela's
    // card for that book names al-Albani on a «لَخّصه … وعَلّق عليه:» line
    // rather than a «المؤلف:» one, and the crawler found nothing. It rendered
    // as a blank row in the "المؤلفون" list.
    for (final book in libraryBookCatalog) {
      expect(book.titleAr.trim(), isNotEmpty, reason: book.id);
      expect(book.authorAr.trim(), isNotEmpty, reason: book.id);
      expect(book.descriptionAr.trim(), isNotEmpty, reason: book.id);
    }
  });

  test('book ids are unique', () {
    final ids = libraryBookCatalog.map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
