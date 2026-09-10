import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The adhan is an alarm, and these are the measurements that decide whether
/// it works as one. Taken with ffmpeg and written to
/// `adhan_audio_measured.json` — trap #36's rule applied to audio: catalogue
/// nothing you have not measured, and keep the measurement where a test can
/// read it.
///
/// What was wrong before, and what these numbers now hold in place:
///
///  * **Six of the ten were encoded at 16 kb/s** — telephone quality, enough
///    on its own to make a familiar voice unrecognisable, which is what the
///    owner reported. The source archive turned out to hold better takes of
///    the same muezzin for five of them (and its `mansur-al-zahrane-hq.mp3`
///    is 32 kb/s while the plain `mansur-al-zahrane.mp3` is 128 — the "hq" in
///    the name is not a measurement).
///  * **The loudness spread was 21 dB**, from −5.1 dB to −26.1 dB. Pick one
///    end and the adhan is jarring; pick the other and it may not wake anyone.
void main() {
  final measured = (jsonDecode(
    File('assets/data/catalogs/adhan_audio_measured.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  final catalog = (jsonDecode(
    File('assets/data/catalogs/adhans.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  test('every catalogued adhan has been measured', () {
    final measuredIds = {for (final m in measured) m['id'] as String};
    final catalogIds = {for (final c in catalog) c['id'] as String};
    expect(catalogIds.difference(measuredIds), isEmpty,
        reason: 'catalogued but never measured — run scripts/ffmpeg over it '
            'before shipping it');
    expect(measuredIds.difference(catalogIds), isEmpty);
  });

  test('every bundled file exists in both places it ships', () {
    for (final m in measured) {
      final id = m['id'] as String;
      expect(File('assets/audio/adhan/$id.mp3').existsSync(), isTrue,
          reason: id);
      expect(
        File('android/app/src/main/res/raw/$id.mp3').existsSync(),
        isTrue,
        reason: '$id is missing from res/raw, which is what the native alarm '
            'player prefers',
      );
    }
  });

  test('nothing ships below 48 kb/s any more', () {
    final poor = [
      for (final m in measured)
        if ((m['kbps'] as int) < 48) '${m['id']} @ ${m['kbps']} kb/s',
    ];
    expect(poor, isEmpty, reason: poor.join(', '));
  });

  test('every clip is adhan-length, not a fragment', () {
    for (final m in measured) {
      expect(m['seconds'] as int, greaterThanOrEqualTo(100), reason: '${m['id']}');
      expect(m['seconds'] as int, lessThanOrEqualTo(420), reason: '${m['id']}');
    }
  });

  test('the loudness spread stays small enough for an alarm', () {
    final levels =
        measured.map((m) => (m['mean_volume_db'] as num).toDouble()).toList();
    final spread = levels.reduce((a, b) => a > b ? a : b) -
        levels.reduce((a, b) => a < b ? a : b);
    // It was 21.0 dB. Anything approaching that again means an adhan was
    // added without being levelled with the rest.
    expect(spread, lessThan(9.0),
        reason: 'spread is ${spread.toStringAsFixed(1)} dB');
  });
}
