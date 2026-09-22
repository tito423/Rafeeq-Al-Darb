import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// The authors list groups books by `authorAr` and prints one death year per
/// group. «مختصر منهاج القاصدين» (Najm al-Din Ibn Qudamah, d. 689) carried
/// Muwaffaq al-Din's name, and when al-Mughni (d. 620) landed under that name
/// the list said «موفق الدين … توفي ٦٨٩» (2026-09-23). One name, one man.
void main() {
  test('every author name has exactly one death year', () {
    final years = <String, Set<int>>{};
    for (final b in libraryBookCatalog) {
      final y = b.deathYearAh;
      if (y == null) continue;
      years.putIfAbsent(b.authorAr, () => {}).add(y);
    }
    final clashes = {
      for (final e in years.entries)
        if (e.value.length > 1) e.key: e.value,
    };
    expect(clashes, isEmpty);
  });
}
