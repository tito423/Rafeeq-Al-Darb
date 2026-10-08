import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/caravan/data/caravan_world.dart';

/// Every leg of «قافلة الدرب» opens its gate with a question from the
/// verified quiz bank - never one written into the game - and that question
/// carries all six translations, a quote and a page, so the arrival card
/// always has a real source to show. Every leg's own text is in all seven
/// locales.
void main() {
  final bank =
      jsonDecode(File('assets/data/quiz/history_quiz.json').readAsStringSync())
          as Map<String, dynamic>;
  final byId = {
    for (final q in bank['questions'] as List)
      (q as Map<String, dynamic>)['id'] as String: q,
  };

  test('each gate question is in the bank, sourced and translated', () {
    for (final leg in CaravanLeg.all) {
      final q = byId[leg.gateQuestionId];
      expect(q, isNotNull, reason: 'leg ${leg.number}');
      expect((q!['quote'] as String).trim(), isNotEmpty);
      expect(q['p'] as int, greaterThan(0));
      final t = q['t'] as Map<String, dynamic>;
      for (final l in ['en', 'fr', 'es', 'pt', 'ru', 'ur']) {
        expect(t[l], isNotNull, reason: 'leg ${leg.number} $l');
      }
    }
  });

  test('legs are numbered in order and gates are distinct', () {
    for (var i = 0; i < CaravanLeg.all.length; i++) {
      expect(CaravanLeg.all[i].number, i + 1);
    }
    expect(
      CaravanLeg.all.map((l) => l.gateQuestionId).toSet().length,
      CaravanLeg.all.length,
    );
  });

  test('every leg key is in all seven locales', () {
    for (final lang in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final tr =
          jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
              as Map;
      final caravan = tr['caravan'] as Map;
      for (final leg in CaravanLeg.all) {
        for (final k in [
          leg.fromKey,
          leg.toKey,
          leg.titleKey,
          leg.wonKey,
          leg.midKey,
          leg.hardKey,
          'caravan.next_leg',
        ]) {
          final v = caravan[k.substring('caravan.'.length)];
          expect(v is String && v.isNotEmpty, isTrue, reason: '$lang $k');
        }
      }
    }
  });
}
