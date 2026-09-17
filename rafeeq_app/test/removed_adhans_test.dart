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
/// `azan13` (الشيخ ربيع القاضي) was removed on 2026-09-17 **temporarily**. Its
/// mp3, measured loudness and phrase timings are deliberately left in place so
/// restoring it needs no re-measuring — which is exactly why a test is needed
/// to prove it is actually out of the picker.
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

  test('azan13 is out of the picker', () {
    expect(catalogue().any((r) => r['id'] == 'azan13'), isFalse);
    expect(removedAdhanIds.contains('azan13'), isTrue,
        reason: 'it is out of the catalogue but a saved choice could still '
            'point at it');
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
