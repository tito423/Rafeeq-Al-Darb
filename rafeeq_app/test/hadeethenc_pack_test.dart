import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hadeethenc/data/hadeethenc_providers.dart';

/// The bug this pins was invisible to everything except a device.
///
/// `DownloadManager._unzipToDatabases` names the extracted database after the
/// **zip's own basename**, not after the entry inside the archive. Saving a
/// pack as `ar.zip` therefore produced `ar.db` while
/// `HadeethEncRepository` opened `hadeethenc_ar.db`: the download reported
/// success, the unzip reported success, and the Encyclopedia tab sat on its
/// download button for ever. `flutter analyze` was clean, 66 tests passed,
/// and every pack had been range-checked on the bucket.
///
/// So the invariant is asserted here rather than remembered: whatever a pack
/// is saved as, stripping `.zip` has to give the database the repository asks
/// for. And the catalogue is checked against it — a language added to the
/// JSON with no pack, or a size of 0, would ship a tab that offers a download
/// that cannot arrive (CLAUDE.md §1.1).
void main() {
  final doc = jsonDecode(
    File('assets/data/catalogs/hadeethenc.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final packs = [
    for (final e in doc['languages'] as List<dynamic>)
      HadeethEncPack.fromJson(e as Map<String, dynamic>)
  ];

  test('the catalogue covers every locale the app ships', () {
    expect(packs.map((p) => p.lang).toSet(),
        {'ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'});
  });

  test('a pack unzips to the file the repository opens', () {
    for (final p in packs) {
      expect(p.zipFileName.endsWith('.zip'), isTrue, reason: p.lang);
      // This is the whole bug: basename(zip) + '.db' == the opened database.
      final stem = p.zipFileName.substring(0, p.zipFileName.length - 4);
      expect('$stem.db', p.fileName,
          reason: '${p.lang}.zip would unpack to $stem.db, but the '
              'repository opens ${p.fileName}');
    }
  });

  test('every pack carries measured, non-zero numbers', () {
    for (final p in packs) {
      expect(p.bytes, greaterThan(0), reason: '${p.lang} has no size');
      expect(p.dbBytes, greaterThan(p.bytes),
          reason: '${p.lang}: the unpacked db should exceed the zip');
      expect(p.hadeeths, greaterThan(0), reason: '${p.lang} has no hadiths');
      expect(p.categories, 7, reason: '${p.lang} is missing a section');
      expect(p.name.trim(), isNotEmpty);
    }
  });

  test('Arabic and Urdu are laid out right-to-left, the rest are not', () {
    for (final p in packs) {
      expect(p.isRtl, p.lang == 'ar' || p.lang == 'ur', reason: p.lang);
    }
  });

  test('the source is credited in the catalogue itself', () {
    final source = doc['source'] as Map<String, dynamic>;
    expect(source['url'], 'https://hadeethenc.com');
    expect((source['title_ar'] as String).trim(), isNotEmpty);
    expect((source['title_en'] as String).trim(), isNotEmpty);
  });
}
