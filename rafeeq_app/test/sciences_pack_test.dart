import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/app_config.dart';

/// علوم القرآن left the APK in 3.45.0: 131.68 MB of bundled asset became a
/// 33,239,511-byte pack the ayah card downloads.
///
/// Two ways that goes wrong, both of which it DID here before these tests:
///
///  1. **Trap #27.** `DownloadManager._unzipToDatabases` names its output
///     after the ZIP (`basename(zip) + '.db'`), not after the entry inside,
///     so `sciences.zip` would become `sciences.db` while the repository
///     opened `quran_sciences.db` - the HadeethEnc failure exactly.
///  2. **The gate never closing.** Seen on emulator-5554: the pack
///     downloaded, the 138,080,256-byte file and its version stamp were on
///     disk, and the card still showed «تحميل». `ref.watch` had already
///     resolved the provider to null and nothing asked it again. The listener
///     invalidates it now; the same hole exists for the storage hub's «تفريغ»
///     button in the other direction, so that is pinned too.
///
/// These read the source because the failure is in the wiring, not in a pure
/// function - and because the wiring is what shipped broken.
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f.readAsStringSync();
  }

  test('the pack is named after the database it unzips to', () {
    expect(AppConfig.sciencesDbUrl, endsWith('/quran_sciences.zip'),
        reason: 'trap #27: the archive basename becomes the .db filename');

    final sheet = read('lib/features/quran/presentation/widgets/'
        'ayah_sciences_sheet.dart');
    expect(sheet, contains("fileName: 'quran_sciences.zip'"));
    expect(sheet, contains('unzipToDatabases: true'));

    final repo = read('lib/core/db/sciences_repository.dart');
    expect(repo, contains("openDownloaded('quran_sciences.db'"),
        reason: 'the repository must open the name the unzip produces');
  });

  test('the card stops asking once the pack has arrived', () {
    final sheet = read('lib/features/quran/presentation/widgets/'
        'ayah_sciences_sheet.dart');
    final listener = sheet.substring(
        sheet.indexOf('DownloadManager.instance.stream.listen'));
    final body = listener.substring(0, listener.indexOf('setState'));
    expect(body, contains('ref.invalidate(sciencesRepositoryProvider)'),
        reason: 'without this the gate survives its own download - the pack '
            'is on disk and the button still says «تحميل»');
    expect(body, contains('DownloadStatus.completed'),
        reason: 'invalidate on completion, not on every progress tick');
  });

  test('freeing the bucket puts the gate back', () {
    final controller =
        read('lib/features/downloads/data/downloads_controller.dart');
    expect(controller, contains("DownloadCategory.quranSciences => const ['sciences']"),
        reason: 'an unclaimed category is disk the storage hub cannot free - '
            'downloads_categories_test.dart guards the general case');
    final free = controller.substring(controller.indexOf('Future<void> freeCategory'));
    expect(free, contains("deleteDownloaded('quran_sciences.db')"));
    expect(free, contains('ref.invalidate(sciencesRepositoryProvider)'));
  });

  test('the size on the gate is the size on the bucket', () {
    // 32,146,611 bytes: the v2 pack (al-Da'as i'rab), `head_object` on
    // 2026-09-26 and range-checked over the public endpoint and the GitHub
    // mirror. A figure typed into the sentence instead drifted 39% low for
    // hadith.zip before anyone measured it.
    expect(AppConfig.sciencesDbBytes, 32146611);
    for (final loc in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final json = read('assets/translations/$loc.json');
      expect(json, contains('"sciences_pack"'), reason: '$loc lacks the title');
      expect(json, contains('"sciences_pack_hint"'),
          reason: '$loc lacks the hint');
      expect(json, contains('"cat_quran_sciences"'),
          reason: '$loc lacks the storage-bucket label');
    }
  });

  test('the database is not bundled any more', () {
    final spec = read('pubspec.yaml');
    final assets = spec.split('  assets:')[1].split('\n  fonts:')[0];
    final listed = assets
        .split('\n')
        .where((l) => l.trimLeft().startsWith('- '))
        .map((l) => l.trim().substring(2).trim())
        .toList();
    expect(listed, isNot(contains('assets/data/quran_sciences.db')),
        reason: 'bundling it again puts 131.68 MB back into the install');
    expect(listed, contains('assets/data/azkar.db'),
        reason: 'the adhkar stay bundled - they are 48 KB and used daily');
  });
}
