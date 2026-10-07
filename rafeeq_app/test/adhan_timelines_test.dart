// «كل الموجودين … المفروض ان النص يتعرض فيهم بمزامنة» (owner, 2026-10-07).
//
// Every bundled adhan must carry a checked, breath-by-breath timeline for
// the prayer it is played at (Fajr recordings only at Fajr, the rest at the
// other four), or the adhan screen shows no text at all. No exceptions:
// owner, 2026-10-07, «شيل الاذان اللي من غير نص» - al-Minshawi (azan3),
// whose breaths could not be confirmed, was taken out of the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/azan_subtitle.dart';

void main() {
  final catalog =
      (jsonDecode(File('assets/data/catalogs/adhans.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final timings =
      jsonDecode(
            File(
              'assets/data/catalogs/adhan_phrase_timings.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('every bundled adhan follows its text', () {
    final missing = <String>[];
    for (final a in catalog) {
      final file = (a['asset'] as String).split('/').last;
      final entry = timings[file] as Map<String, dynamic>?;
      final fajr = a['fajr'] == true;
      final ok =
          entry != null &&
          AdhanTimings.fromJson(entry).followsAdhan(isFajr: fajr);
      if (!ok) missing.add('$file (${a['name']})');
    }
    expect(missing, isEmpty);
  });
}
