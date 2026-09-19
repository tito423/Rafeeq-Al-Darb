import 'book_catalog.dart';
import 'book_category.dart';

/// The books that ship inside the app (see
/// `LibraryApiService.installBuiltinBooks`): the hadith category - «كتب
/// ومتون الحديث» - the three mutoon the tajweed course is built on, and the Hajj manual.
/// `test/builtin_books_test.dart` holds each id to an asset of exactly the
/// size the catalogue records for it.
final List<String> builtinBookIds = [
  for (final b in libraryBookCatalog)
    if (b.category == BookCategory.hadith) b.id,
  'tuhfat_al_atfal',
  'al_muqaddimah_al_jazariyyah_matn',
  'at_tamhid_fi_ilm_at_tajwid',
  // «الإيضاح في مناسك الحج والعمرة», which the Hajj screen is read from.
  'al_idah_fi_manasik_al_hajj_wal_umrah',
];
