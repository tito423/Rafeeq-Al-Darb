import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_settings_provider.dart';

/// An adhan taken out of the picker must also be unreachable from a saved
/// choice, and one still on offer must never be listed as removed.
///
/// THE DEFECT THIS GUARDS. `adhan_choice_v1_<prayer>` stores an adhan id in
/// preferences. Drop the adhan from `adhans.json` and that stored id points at
/// nothing: the scheduler falls back to the first adhan, but the settings
/// dropdown asserts on a value that is not among its items. `removedAdhanIds`
/// is what turns a stale id into «no choice» instead — so the two files have
/// to agree, and nothing checked that they did.
///
/// `azan13` was removed on 2026-09-17 and restored the same day — «رجع اذان
/// الشيخ ربيع القاضي … انا استئذنته خلاص» — which is the round trip this file
/// now pins from the other side: it is back in the catalogue AND out of the
/// removed set, because being in both is the state that crashes the sheet.
///
/// The three adhans the owner supplied himself are labelled «أذان ١/٢/٣» at
/// his request. That is a display choice, not a provenance one: each entry's
/// `source` still records where the file came from.
void main() {
  List<Map<String, dynamic>> catalogue() {
    final raw = jsonDecode(
        File('assets/data/catalogs/adhans.json').readAsStringSync());
    final rows = raw is List ? raw : (raw as Map)['adhans'] as List;
    return rows.cast<Map<String, dynamic>>();
  }

  test('no removed adhan is still on offer', () {
    final ids = catalogue().map((r) => r['id'] as String).toSet();
    final stillListed = removedAdhanIds.where(ids.contains).toList();
    expect(stillListed, isEmpty,
        reason: 'these are marked removed but still in adhans.json, so the '
            'picker offers them: $stillListed');
  });

  test('azan13 is back in the picker and no longer declared removed', () {
    expect(catalogue().any((r) => r['id'] == 'azan13'), isTrue,
        reason: 'it was restored on 2026-09-17');
    expect(removedAdhanIds.contains('azan13'), isFalse,
        reason: 'listed as removed while it is in the catalogue: a saved '
            'choice for it would be silently read as «no choice»');
  });

  test("the owner's three adhans carry the neutral labels he asked for", () {
    final byId = {for (final r in catalogue()) r['id'] as String: r};
    const want = {'azan11': 'أذان ١', 'azan12': 'أذان ٢', 'azan13': 'أذان ٣'};
    want.forEach((id, label) {
      expect(byId[id], isNotNull, reason: '$id is missing from the catalogue');
      expect(byId[id]!['name'], label);
    });
  });

  test('no adhan entry names a person the owner asked to keep unnamed', () {
    // He asked for these two names off the picker on 2026-09-17. A rename
    // that leaves the old name in a neighbouring field is the same defect as
    // «Крепости мусульманина» — the string survives where nobody looks.
    const gone = ['تامر شعبان', 'ربيع القاضي'];
    final blob = File('assets/data/catalogs/adhans.json').readAsStringSync();
    for (final name in gone) {
      expect(blob.contains(name), isFalse,
          reason: 'adhans.json still contains «$name»');
    }
  });

  test('every adhan still on offer has a file behind it', () {
    // A picker entry whose asset is missing is silence at the adhan.
    for (final row in catalogue()) {
      final asset = row['asset'] as String?;
      expect(asset, isNotNull, reason: '${row['id']} has no asset');
      expect(File(asset!).existsSync(), isTrue,
          reason: '${row['id']} points at $asset, which is not there');
    }
  });
}
