import 'book_catalog.dart';
import 'book_category.dart';

/// The books that ship inside the app (see
/// `LibraryApiService.installBuiltinBooks`): the hadith category - «كتب
/// ومتون الحديث» - the three mutoon the tajweed course is built on, and the Hajj manual.
/// `test/builtin_books_test.dart` holds each id to an asset of exactly the
/// size the catalogue records for it.
final List<String> builtinBookIds = [
  for (final b in libraryBookCatalog)
    if (b.category == BookCategory.hadith && !hostedHadithBooks.contains(b.id))
      b.id,
  'tuhfat_al_atfal',
  'al_muqaddimah_al_jazariyyah_matn',
  'at_tamhid_fi_ilm_at_tajwid',
  // «الحج والعمرة» from الفقه المنهجي, which the Hajj screen is read from
  // (2026-09-23; before that al-Nawawi's «الإيضاح», now in the library).
  'al_fiqh_al_manhaji_hajj',
];

/// Hadith-shelf books that are downloaded on demand instead of shipped. The
/// 36 built-in books come to 8.1 MB together, the largest 0.9 MB; فتح الباري
/// is 12.6 MB on its own (2026-09-23) and would more than double the APK's
/// share of books. It sits on the same shelf and downloads like the other
/// encyclopaedias. تهذيب الكمال (6.6 MB) joined it the same day.
const Set<String> hostedHadithBooks = {'fath_al_bari', 'tahdhib_al_kamal'};
