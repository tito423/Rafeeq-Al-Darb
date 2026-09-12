import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// An archive entry's name is content, not a path you may trust.
///
/// `DownloadManager._unzipToDatabases` wrote every entry to
/// `p.join(outDir.path, entry.name)`. `p.join` resolves `..` like any other
/// path segment, so an entry called `../../databases/hadith.db` lands on the
/// bundled hadith database and one called `../../shared_prefs/…` on the app's
/// own settings — the classic "zip slip". These archives come from this
/// project's own bucket over HTTPS, so this was not being exploited; it was
/// simply one line away from not mattering at all.
///
/// The method is private and needs a real download to reach, so this test
/// pins the RULE against the real `package:archive` decoder rather than
/// mocking the manager: an entry that escapes its directory must not be
/// written. `_unzipToDatabases` applies exactly the check below —
/// `p.normalize` then `p.isWithin`.
void main() {
  test('an archive entry cannot be written outside its own directory', () {
    final archive = Archive()
      ..addFile(ArchiveFile('ok.txt', 2, [0x68, 0x69]))
      ..addFile(ArchiveFile('nested/ok.txt', 2, [0x68, 0x69]))
      ..addFile(ArchiveFile('../escaped.txt', 2, [0x68, 0x69]))
      ..addFile(ArchiveFile('../../databases/hadith.db', 2, [0x68, 0x69]));

    final bytes = ZipEncoder().encode(archive);
    final decoded = ZipDecoder().decodeBytes(bytes);

    final outDir = Directory.systemTemp
        .createTempSync('rafeeq_unzip_test')
        .path;
    final written = <String>[];
    final refused = <String>[];
    for (final entry in decoded) {
      if (!entry.isFile) continue;
      final target = p.normalize(p.join(outDir, entry.name));
      if (!p.isWithin(outDir, target)) {
        refused.add(entry.name);
        continue;
      }
      written.add(p.relative(target, from: outDir).replaceAll(r'\', '/'));
    }

    expect(written, ['ok.txt', 'nested/ok.txt'],
        reason: 'the two honest entries must still be written');
    expect(refused, ['../escaped.txt', '../../databases/hadith.db'],
        reason: 'an entry whose name climbs out of the directory must be '
            'refused — this is the check that stops a downloaded archive '
            'overwriting a bundled database');

    Directory(outDir).deleteSync(recursive: true);
  });

  test('the unzip routine actually applies that check', () {
    // The guard is one line and easy to drop in a later edit; a test that
    // only proves `p.isWithin` works would not notice.
    final source =
        File('lib/core/services/download_manager.dart').readAsStringSync();
    expect(source.contains('p.isWithin(outDir.path, target)'), isTrue,
        reason: 'the zip-slip guard is gone from _unzipToDatabases');
  });
}
