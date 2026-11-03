import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rafeeq_app/core/utils/disk_scan.dart';

/// The background scans that replaced the UI-isolate `listSync` loops
/// (owner 2026-11-02: the app slowed down holding 40-50 GB). They must give
/// the same answers the old loops did.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('disk_scan_test');
    final a = Directory(p.join(root.path, 'a'))..createSync();
    File(p.join(a.path, '001.mp3')).writeAsBytesSync(List.filled(10, 1));
    File(p.join(a.path, '002.mp3')).writeAsBytesSync(const []); // died at 0 B
    File(p.join(a.path, 'library.json')).writeAsStringSync('[]');
    final deep = Directory(p.join(a.path, 'sub'))..createSync();
    File(p.join(deep.path, '003.MP3')).writeAsBytesSync(List.filled(5, 1));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('bytes: recursive, filtered by extension, case-insensitive', () async {
    final a = p.join(root.path, 'a');
    expect(await diskBytes(a), 10 + 2 + 5);
    expect(await diskBytes(a, extensions: const {'.mp3'}), 15);
    expect(await diskBytes(a, recursive: false), 12);
    expect(await diskBytes(p.join(root.path, 'missing')), 0);
  });

  test('names: direct files only, zero-byte ones left out on request',
      () async {
    final a = p.join(root.path, 'a');
    final missing = p.join(root.path, 'missing');
    final all = await fileNamesIn([a, missing]);
    expect(all[a]!..sort(), ['001.mp3', '002.mp3', 'library.json']);
    expect(all[missing], isEmpty);
    final nonEmpty = await fileNamesIn([a], nonEmptyOnly: true);
    expect(nonEmpty[a]!..sort(), ['001.mp3', 'library.json']);
  });
}
