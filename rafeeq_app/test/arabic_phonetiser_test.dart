import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/tts/arabic_phonetiser.dart';

/// The Dart port must give the open voice exactly the ids the Python gives
/// it — the model learned from the Python's behaviour, quirks included.
/// The vectors are 300 real diacritised hadith openings plus four sentences
/// with the divine name, run through tts_arabic's own arabic_to_tokens.
void main() {
  final vectors = (jsonDecode(File('test/fixtures/tts_phonetiser_vectors.json')
          .readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('${vectors.length} sentences tokenise exactly as the Python does', () {
    var mismatches = 0;
    String? first;
    for (final v in vectors) {
      final got = tokensToIds(arabicToTokens(v['text'] as String));
      final want = (v['ids'] as List).cast<int>();
      if (got.join(',') != want.join(',')) {
        mismatches++;
        first ??= '${v['text']}\n got  $got\n want $want';
      }
    }
    expect(mismatches, 0, reason: '$mismatches mismatches; first:\n$first');
  });
}
