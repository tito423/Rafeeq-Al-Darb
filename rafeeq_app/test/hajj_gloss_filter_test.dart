import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hajj/data/hajj_guide.dart';

/// Real paragraphs from the hosted «الإيضاح»: two of the annotator's (shown
/// as an-Nawawi's text until 2026-09-19) and two of an-Nawawi's own, which
/// must stay.
void main() {
  final s = (jsonDecode(File('test/fixtures/idah_gloss_samples.json')
          .readAsStringSync()) as Map)
      .cast<String, String>();

  test('the annotator\'s paragraphs are dropped', () {
    expect(isHajjGuideNote(s['gloss_396']!), isTrue, reason: 'قال المحشي');
    expect(isHajjGuideNote(s['gloss_49']!), isTrue, reason: 'a gloss opening «أي»');
  });

  test('an-Nawawi\'s own text is kept', () {
    expect(isHajjGuideNote(s['nawawi_378']!), isFalse);
    expect(isHajjGuideNote(s['nawawi_386']!), isFalse);
  });

  test('the Umrah track opens on the Umrah chapter', () {
    expect(hajjStepsFor(HajjTrack.umrah).first.key, 'umrah');
    expect(hajjStepsFor(HajjTrack.hajj).first.key, 'preparation');
  });
}
