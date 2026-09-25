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

  // «الشاشات الرئيسيه سبع ثمان شاشات ... مش كل سمة صغيرة» (owner,
  // 2026-09-25): each stop is one main screen, shown whole.
  test('the quick tour shows each main screen once, whole', () {
    expect(quickTutorialChapters.first.key, 'welcome');
    final stops = quickTutorialChapters.skip(1).toList();
    expect(stops.length, 8);
    expect(stops.every((c) => c.whole && c.anchor == null), isTrue);
    // Stops in the More tab are told apart by the screen they draw.
    final screens = stops.map((c) => c.screen ?? c.tab).toList();
    expect(screens.toSet().length, screens.length, reason: 'one stop per screen');
  });
}
