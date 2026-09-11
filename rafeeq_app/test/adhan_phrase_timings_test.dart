import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/azan_subtitle.dart';

/// The adhan text follows what the muezzin recites, from times measured with
/// ffmpeg (`scripts/measure_adhan_phrases.py`) — not from letters shared over
/// the whole file, which ran «يقدّم أو يتأخر عن الأذان نفسه».
void main() {
  final catalog = jsonDecode(File('assets/data/catalogs/adhans.json').readAsStringSync()) as List<dynamic>;
  final timings = jsonDecode(File('assets/data/catalogs/adhan_phrase_timings.json').readAsStringSync())
      as Map<String, dynamic>;

  test('every bundled adhan was measured', () {
    for (final a in catalog) {
      final name = (a['asset'] as String).split('/').last;
      expect(timings.containsKey(name), isTrue, reason: '$name has no timings');
    }
  });

  test('measured line starts are inside the recording and in order', () {
    for (final e in timings.entries) {
      final t = AdhanTimings.fromJson(e.value as Map<String, dynamic>);
      expect(t.firstSpeechMs, lessThan(t.lastSpeechMs), reason: e.key);
      expect(t.lastSpeechMs, lessThanOrEqualTo(t.totalMs), reason: e.key);
      final lines = t.lines ?? const <int>[];
      if (lines.isEmpty) continue;
      expect(lines.length, t.linesAreFajr ? 8 : 7, reason: e.key);
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i], greaterThan(lines[i - 1]), reason: '${e.key} line $i');
      }
      expect(lines.last, lessThan(t.totalMs), reason: e.key);
    }
  });

  test('the text does not start over the opening silence', () {
    final t = AdhanTimings.fromJson(timings['azan1.mp3'] as Map<String, dynamic>);
    final subs = buildAzanSubtitlesMeasured(
      isFajr: false,
      total: Duration(milliseconds: t.totalMs),
      timings: t,
    );
    expect(subs.first.startTime.inMilliseconds, greaterThanOrEqualTo(t.firstSpeechMs - 1));
    expect(subs.length, 7);
  });

  test('a Fajr text over a non-Fajr recording falls back to the spoken span', () {
    final t = AdhanTimings.fromJson(timings['azan1.mp3'] as Map<String, dynamic>);
    final subs = buildAzanSubtitlesMeasured(
      isFajr: true,
      total: Duration(milliseconds: t.totalMs),
      timings: t,
    );
    expect(subs.length, 8);
    expect(subs.first.startTime.inMilliseconds, t.firstSpeechMs);
    expect(subs.last.endTime.inMilliseconds, t.lastSpeechMs);
  });
}
