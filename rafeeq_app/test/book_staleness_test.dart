import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// A book already on the device must not keep text the catalogue has replaced.
///
/// THE DEFECT THIS EXISTS FOR. On 2026-09-17, 47 hosted books were rebuilt
/// with a modern muhaqqiq's apparatus filtered out and uploaded over the same
/// R2 keys. Nothing told a device. `book_meta` carried no version — `hadith.db`
/// has `AppConfig.hadithDbVersion` for exactly this and books had no equivalent
/// — so a reader who had downloaded one of those books before that day would
/// have kept the old text for ever, and the whole rights fix would never have
/// reached the one person who uses this app. The card said «تمّ التنزيل», which
/// was true and useless.
///
/// `isBookDownloaded` now compares the local file's byte length with the
/// catalogue's `sizeBytes`. That only works while every `sizeBytes` really is
/// what the bucket holds, so this pins the invariant the check leans on. The
/// live half — do the numbers match the bucket today — is
/// `py -3 scripts/verify_catalog_sizes.py`, which returned **0 mismatches over
/// all 248** once two entries that had drifted by 7 and 14 bytes were
/// corrected from the bucket's own readback.
void main() {
  test('every book carries a real measured size for the check to lean on', () {
    // A 0 means «unknown», and `isBookDownloaded` deliberately leaves those
    // alone rather than guessing. None should exist: a book with no size also
    // shows no size on its card.
    final unsized = [
      for (final b in libraryBookCatalog)
        if ((b.textEdition?.sizeBytes ?? 0) == 0 && b.textEdition != null) b.id,
    ];
    expect(unsized, isEmpty,
        reason: 'these books have no measured size, so a stale copy on a '
            'device can never be detected for them: $unsized');
  });

  test('no size is a suspiciously round guess', () {
    // Every card once claimed a hardcoded «1.0 MB». A real gzip length is not
    // a power of ten, and a run of identical sizes would mean somebody typed
    // one number into many entries.
    final sizes = [
      for (final b in libraryBookCatalog)
        if (b.textEdition != null) b.textEdition!.sizeBytes,
    ];
    expect(sizes, isNotEmpty);
    for (final s in sizes) {
      expect(s % 100000 == 0, isFalse, reason: 'suspiciously round: $s');
    }
    // 248 independently measured gzip lengths should be almost all distinct.
    final repeated = sizes.length - sizes.toSet().length;
    expect(repeated, lessThan(3),
        reason: '$repeated books share a size with another — measured lengths '
            'do not collide like that, so somebody copied a number.');
  });

  test('bookById resolves every catalogued id, and nothing else', () {
    for (final b in libraryBookCatalog) {
      expect(bookById(b.id), same(b), reason: b.id);
    }
    expect(bookById('a_book_that_does_not_exist'), isNull);
  });
}
