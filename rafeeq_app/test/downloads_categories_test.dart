import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/downloads/data/downloads_controller.dart';

/// The storage hub can only show — and only free — a download whose
/// `DownloadManager` category some bucket claims.
///
/// Two shipped unclaimed. `hadeethenc` (the per-language hadith packs) and
/// `ruqyah` (audio) were both being enqueued under category strings that
/// appeared in no `managerCategories` list, so they sat on disk while the
/// Downloads screen reported zero for them and its "free space" button walked
/// straight past them. Nothing failed; the bytes were simply invisible.
///
/// This reads the enqueue sites back out of the source, so the next screen that
/// invents a category string fails here instead of shipping the same hole.
void main() {
  test('every enqueued category belongs to a bucket', () {
    final enqueued = <String, String>{};
    final pattern = RegExp(r"category:\s*'([a-z_]+)'");
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        enqueued[m.group(1)!] = f.path;
      }
    }
    expect(enqueued, isNotEmpty,
        reason: 'the regex stopped matching the enqueue sites');

    final claimed = <String>{
      for (final c in DownloadCategory.values) ...c.managerCategories,
    };
    final orphans = <String>[
      for (final e in enqueued.entries)
        if (!claimed.contains(e.key)) '${e.key}  (${e.value})',
    ];
    expect(orphans, isEmpty,
        reason: 'these downloads occupy disk that the storage hub can neither '
            'count nor free: ${orphans.join(", ")}');
  });

  test('no two buckets claim the same category', () {
    final seen = <String, DownloadCategory>{};
    for (final c in DownloadCategory.values) {
      for (final s in c.managerCategories) {
        expect(seen.containsKey(s), isFalse,
            reason: '"$s" is claimed by both ${seen[s]} and $c, so its bytes '
                'would be counted twice and freed by either button');
        seen[s] = c;
      }
    }
  });

  test('a bucket listed twice is a build error, not a wrong number', () {
    // The headline read 696.2 MB over a single 348.1 MB row, because the
    // mushafs bucket was added once by its own service and again by the
    // artifact loop. Nothing threw; the total was just wrong.
    expect(
      () => StorageSummary(const [
        CategoryUsage(DownloadCategory.mushafs, 348, 1),
        CategoryUsage(DownloadCategory.mushafs, 348, 1),
      ]),
      throwsA(isA<AssertionError>()),
    );
    expect(
      StorageSummary(const [
        CategoryUsage(DownloadCategory.mushafs, 348, 1),
        CategoryUsage(DownloadCategory.hadith, 4, 2),
      ]).totalBytes,
      352,
    );
  });
}
