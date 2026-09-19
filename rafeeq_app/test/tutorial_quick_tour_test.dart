import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tutorial/data/tutorial_chapters.dart';

void main() {
  test('every stop of both tours has its title and body in every locale', () {
    for (final loc in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur']) {
      final t = (jsonDecode(File('assets/translations/$loc.json')
          .readAsStringSync()) as Map)['tutorial'] as Map;
      for (final c in [...tutorialChapters, ...quickTutorialChapters]) {
        expect(t['${c.key}_title'], isNotNull, reason: '$loc ${c.key}_title');
        expect(t['${c.key}_body'], isNotNull, reason: '$loc ${c.key}_body');
      }
    }
  });

  test('the quick tour visits each screen once, framing something on each', () {
    expect(quickTutorialChapters.first.key, 'welcome');
    final tabs = quickTutorialChapters.skip(1).map((c) => c.tab).toList();
    expect(tabs.toSet().length, tabs.length, reason: 'one stop per screen');
    expect(quickTutorialChapters.skip(1).every((c) => c.anchor != null), isTrue);
  });
}
