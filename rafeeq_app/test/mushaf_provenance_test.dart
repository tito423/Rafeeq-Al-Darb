import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A mushaf printing cannot ship without saying where it came from.
///
/// Until 2026-09-17 `editions.json` recorded no per-edition provenance at all.
/// One top-level `license` string covered every printing, and it had gone
/// stale: it still named Warsh and Qalun, deleted on 2026-09-09, and described
/// the illuminated edition only as «archive.org public scans» without naming
/// its licence — which is CC BY-NC-ND 4.0, the one printing here with a
/// restriction worth knowing about.
///
/// Where each scan came from survived nowhere in the repository. It lived in a
/// session's memory note, and on 2026-09-17 that note was found to be **wrong**
/// — it said nine printings ship, and six do. A fact that lives only in a note
/// nobody can check is not a record.
///
/// So each entry now carries `source`, `license` and `license_note`, and this
/// fails the build if one is added without them. «none stated» is a permitted
/// value and an honest one; an empty string is not.
void main() {
  final file = File('assets/data/mushaf/editions.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final editions = (data['editions'] as List).cast<Map<String, dynamic>>();

  test('every printing records its source and its licence', () {
    expect(editions, isNotEmpty);
    for (final e in editions) {
      final id = e['id'];
      for (final field in ['source', 'license', 'license_note']) {
        final v = e[field] as String?;
        expect(v, isNotNull, reason: '$id has no `$field`');
        expect(v!.trim(), isNotEmpty, reason: '$id has an empty `$field`');
      }
    }
  });

  test('the top-level licence line does not name a deleted printing', () {
    // The stale one named warsh and qaloon long after their 1,208 page images
    // were deleted from R2. A line that describes editions that no longer
    // exist is worse than no line.
    final top = (data['license'] as String).toLowerCase();
    final ids = editions.map((e) => (e['id'] as String).toLowerCase()).toSet();
    for (final gone in ['warsh', 'qaloon', 'qalun', 'shamarly', 'nastaleeq']) {
      if (ids.any((id) => id.contains(gone))) continue;
      expect(top.contains(gone) && !top.contains('deleted'), isFalse,
          reason: 'the top-level license line mentions «$gone», which no '
              'longer ships, without saying it was removed');
    }
  });

  test('a restrictive licence is spelled out, not left as a bare code', () {
    // CC BY-NC-ND is the only one here that restricts what may be done with
    // the pages, so the note beside it has to say how the app stays inside it
    // — otherwise the field is a label nobody acted on.
    for (final e in editions) {
      final lic = (e['license'] as String).toUpperCase();
      if (!lic.contains('ND')) continue;
      final note = e['license_note'] as String;
      expect(note.length, greaterThan(80),
          reason: '${e['id']} carries an ND licence with no explanation of '
              'how this app stays within it');
    }
  });
}
