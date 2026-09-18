import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/models/adhan_mode.dart';
import 'package:rafeeq_app/core/models/adhan_option.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_scheduler.dart';
import 'package:rafeeq_app/features/adhan/data/adhan_settings_provider.dart';

/// «ممكن يضيف أي أذان مع الفجر اللي مختلف أصلاً في الصلاة خير من النوم —
/// كارثة». Fajr sounded whatever adhan was chosen; the default is an ordinary
/// one, so Fajr played without its Fajr line. These pin that Fajr only ever
/// gets a Fajr recording and the other four never do.
void main() {
  final catalog = [
    for (final e in jsonDecode(
            File('assets/data/catalogs/adhans.json').readAsStringSync())
        as List<dynamic>)
      AdhanOption.bundled(e as Map<String, dynamic>),
  ];

  AdhanSettings settings({String def = 'azan1', Map<String, String?>? per}) =>
      AdhanSettings(
        defaultAdhanId: def,
        modeByPrayer: {for (final k in adhanPrayerKeys) k: AdhanMode.full},
        adhanIdByPrayer: per ?? {for (final k in adhanPrayerKeys) k: null},
        calculationMethod: 4,
        reminderBeforeMinutes: 0,
        reminderAfterMinutes: 0,
        reminderIqamaMinutes: 0,
        asrMadhab: adhan.Madhab.shafi,
        highLatitudeRule: adhan.HighLatitudeRule.twilight_angle,
        autoLocationUpdate: false,
        locationUpdateMinutes: 60,
      );

  test('the catalogue has Fajr recordings, and every pair points at one', () {
    expect(catalog.where((o) => o.isFajr), isNotEmpty);
    for (final o in catalog.where((o) => o.fajrPair != null)) {
      final pair = catalog.where((p) => p.id == o.fajrPair).single;
      expect(pair.isFajr, isTrue, reason: '${o.id} pairs with ${pair.id}');
      expect(o.isFajr, isFalse, reason: '${o.id} is Fajr and has a pair');
    }
  });

  test('whatever the default, Fajr gets a Fajr recording', () {
    for (final o in catalog.where((o) => !o.isFajr)) {
      final r = resolveAdhanFor(catalog, settings(def: o.id), 'fajr');
      expect(r.isFajr, isTrue, reason: 'default ${o.id} gave ${r.id} at Fajr');
      if (o.fajrPair != null) expect(r.id, o.fajrPair);
    }
  });

  test('an ordinary adhan chosen for Fajr itself still yields a Fajr one', () {
    final r = resolveAdhanFor(
        catalog, settings(per: {'fajr': 'azan1'}), 'fajr');
    expect(r.isFajr, isTrue);
  });

  test('a Fajr recording never sounds at the other four prayers', () {
    final fajr = catalog.firstWhere((o) => o.isFajr);
    for (final k in adhanPrayerKeys.where((k) => k != 'fajr')) {
      final r = resolveAdhanFor(
          catalog, settings(def: fajr.id, per: {k: fajr.id}), k);
      expect(r.isFajr, isFalse, reason: '$k got ${r.id}');
    }
  });

  test('a custom file is the user\'s to place, at any prayer', () {
    final custom = AdhanOption.custom(
        id: 'custom_1', name: 'x', filePath: '/nonexistent.mp3');
    final all = [...catalog, custom];
    for (final k in adhanPrayerKeys) {
      expect(
          resolveAdhanFor(all, settings(per: {k: 'custom_1'}), k).id, 'custom_1');
    }
  });
}
