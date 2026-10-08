import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/caravan/data/caravan_world.dart';

/// Every leg of «قافلة الدرب» opens its gate with a question from the
/// verified quiz bank - never one written into the game - and each of those
/// questions carries all six translations, a quote and a page, so the
/// arrival card always has a real source to show. Every key the journey
/// shows is in all seven locales.
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
      expect(leg.gateIds, isNotEmpty, reason: 'leg ${leg.number}');
      for (final id in leg.gateIds) {
        final q = byId[id];
        expect(q, isNotNull, reason: 'leg ${leg.number} $id');
        expect((q!['quote'] as String).trim(), isNotEmpty);
        expect(q['p'] as int, greaterThan(0));
        final t = q['t'] as Map<String, dynamic>;
        for (final l in ['en', 'fr', 'es', 'pt', 'ru', 'ur']) {
          expect(t[l], isNotNull, reason: 'leg ${leg.number} $id $l');
        }
      }
    }
  });

  test('legs run in order, city to city, and no gate is reused', () {
    for (var i = 0; i < CaravanLeg.all.length; i++) {
      final leg = CaravanLeg.all[i];
      expect(leg.number, i + 1);
      if (i > 0) expect(leg.fromKey, CaravanLeg.all[i - 1].toKey);
    }
    final ids = [for (final l in CaravanLeg.all) ...l.gateIds];
    expect(ids.toSet().length, ids.length);
  });

  test('every key the journey shows is in all seven locales', () {
    final keys = {
      for (final leg in CaravanLeg.all) ...[
        leg.fromKey,
        leg.toKey,
        leg.midKey,
        leg.hardKey,
      ],
      for (final k in [
        'title',
        'subtitle',
        'map_hint',
        'to_map',
        'won_to',
        'won_lanterns',
        'next_leg',
        'ev_birds',
        'ev_boulder',
        'ev_dates',
        'ev_star',
        'shield_on',
        'shielded',
      ])
        'caravan.$k',
    };
    for (final lang in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final tr =
          jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
              as Map;
      final caravan = tr['caravan'] as Map;
      for (final k in keys) {
        final v = caravan[k.substring('caravan.'.length)];
        expect(v is String && v.isNotEmpty, isTrue, reason: '$lang $k');
      }
    }
  });
}
