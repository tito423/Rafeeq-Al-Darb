// «كل الموجودين … المفروض ان النص يتعرض فيهم بمزامنة» (owner, 2026-10-07).
//
// Every bundled adhan must carry a checked, breath-by-breath timeline for
// the prayer it is played at (Fajr recordings only at Fajr, the rest at the
// other four), or the adhan screen shows no text at all. A recording may
// be missing one only if it is named below with the reason.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/azan_subtitle.dart';

/// Bundled recordings with no confirmed timeline, and why.
const _noTimeline = {
  // Muhammad Siddiq al-Minshawi, archive recording: Whisper large-v3 reads
  // only the two «محمد رسول الله» breaths and the closing lines; the four
  // hay'ala breaths each have two candidate onsets 6-9 s apart that nothing
  // here can decide (docs/reports/_azan3_silences.json). No text rather than
  // text that runs ahead of the muezzin.
  'azan3.mp3',
};

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

  test('every bundled adhan follows its text, except the named ones', () {
    final missing = <String>[];
    for (final a in catalog) {
      final file = (a['asset'] as String).split('/').last;
      if (_noTimeline.contains(file)) continue;
      final entry = timings[file] as Map<String, dynamic>?;
      final fajr = a['fajr'] == true;
      final ok =
          entry != null &&
          AdhanTimings.fromJson(entry).followsAdhan(isFajr: fajr);
      if (!ok) missing.add('$file (${a['name']})');
    }
    expect(missing, isEmpty);
  });

  test('a named exception is still a bundled adhan without a timeline', () {
    for (final file in _noTimeline) {
      final entry = timings[file] as Map<String, dynamic>?;
      expect(entry, isNotNull, reason: file);
      expect(
        AdhanTimings.fromJson(entry!).breaths,
        isNull,
        reason: '$file now has a timeline: take it off the exception list',
      );
    }
  });
}
