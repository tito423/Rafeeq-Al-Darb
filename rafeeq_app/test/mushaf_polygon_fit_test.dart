import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';

/// ONE paper mushaf, and its highlight is exact.
///
/// Until 2026-09-20 the catalogue carried four SCANNED printings — the
/// coloured Tajweed mushaf, the illuminated "gold" printing, Mushaf Qatar and
/// Mushaf Kuwait. None of them had ayah coordinates of its own: each borrowed
/// the Madinah (`hafs_kfqc`) polygons through a per-page affine. The printings
/// do not break their lines at the same words and do not put their surah
/// banners on the same lines — Qatar sets al-Nisa's banner at the foot of page
/// 76 where Madinah opens page 77 with it — so a borrowed highlight could sit
/// a word, or a whole line, away from the printed marker.
///
/// The owner's ruling: «انا معنديش اي مشكلة انه يكون عندي مصحف نصي ومصحف واحد
/// ورقي، بس يكون التظليل فيه تمام». So the four scans are gone and the vector
/// Madinah edition is the whole list. Its polygons are published WITH the
/// pages by quran-ws/quran-svg, page by page, so nothing is fitted, measured
/// or guessed — which is the only way «تمام» is true rather than hoped for.
///
/// What this file guards is that state: one printing, carrying a real ayah
/// layer, named in every locale, with a cover on disk.
void main() {
  final doc = jsonDecode(File('assets/data/mushaf/editions.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final editions = [
    for (final e in doc['editions'] as List<dynamic>)
      MushafEdition.fromJson(e as Map<String, dynamic>)
  ];

  test('the catalogue is exactly one printing: the vector Madinah Hafs', () {
    expect([for (final e in editions) e.id], ['hafs_kfqc']);
  });

  test('no printing that borrows another printing\'s coordinates is back', () {
    // Each of these was removed for a reason recorded above (the four scans)
    // or in v3.16.0 (the three that paginate their own way). Re-adding any of
    // them means re-introducing a highlight that is fitted rather than known.
    final ids = [for (final e in editions) e.id];
    for (final gone in [
      'tajweed_color',
      'madinah_gold',
      'qatar',
      'kuwait',
      'madinah_night',
      'shamarly',
      'indopak_tajweed',
      'madinah_nastaleeq',
    ]) {
      expect(ids, isNot(contains(gone)), reason: gone);
    }
  });

  test('EVERY printing in the catalogue can highlight an ayah', () {
    // The owner's ruling, 2026-09-11: «اي مصحف مصور مش محدد اجزاء الايات عشان
    // التظليل شيله من التطبيق كله». An invariant over the whole catalogue
    // rather than a list of known-good ids.
    expect(editions, isNotEmpty);
    for (final e in editions) {
      expect(e.hasAyahLayer, isTrue,
          reason: '${e.id} is in the catalogue with no ayah layer');
      expect(File(e.polygonsAsset).existsSync(), isTrue,
          reason: '${e.id} points at ${e.polygonsAsset}');
    }
  });

  test('the remaining printing needs no fit of its own', () {
    // `fitForPage` returning null is the point: the page's polygons are the
    // page's own, so there is nothing to map them through.
    final e = editions.single;
    for (final page in [1, 2, 50, 77, 300, 604]) {
      expect(e.fitForPage(page), isNull,
          reason: '${e.id} p$page should not need an affine');
    }
  });

  test('its polygon layer really covers the whole mushaf', () {
    final polygons = jsonDecode(File(editions.single.polygonsAsset)
        .readAsStringSync()) as Map<String, dynamic>;
    final pages = polygons['pages'] as Map<String, dynamic>;
    expect(pages.length, 604);
    for (final page in ['1', '2', '50', '187', '604']) {
      final rings = pages[page] as List<dynamic>;
      expect(rings, isNotEmpty, reason: 'page $page carries no ayah region');
    }
  });

  test('every printing names itself in all seven app locales', () {
    // A fresh install in Spanish used to list every printing under its ARABIC
    // title. `localizedName` must return something in the reader's own script
    // for every locale the app ships.
    const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];
    final arabicLetters = RegExp(r'[؀-ۿ]');
    for (final e in editions) {
      for (final loc in locales) {
        final name = e.localizedName(loc);
        final riwayah = e.localizedRiwayah(loc);
        expect(name.trim(), isNotEmpty, reason: '${e.id} name/$loc');
        expect(riwayah.trim(), isNotEmpty, reason: '${e.id} riwayah/$loc');
        if (loc == 'ar' || loc == 'ur') {
          expect(arabicLetters.hasMatch(name), isTrue,
              reason: '${e.id}: $loc name is not in Arabic script: $name');
        } else {
          expect(name, isNot(e.nameAr),
              reason: '${e.id}: $loc fell back to the Arabic title');
        }
      }
      expect(e.localizedName('ur'), isNot(e.nameAr), reason: e.id);
    }
  });

  test('every edition ships a real cover asset', () {
    for (final e in editions) {
      final f = File('assets/mushaf_covers/${e.id}.jpg');
      expect(f.existsSync(), isTrue, reason: '${e.id} has no cover');
      expect(f.lengthSync(), greaterThan(1000), reason: '${e.id} cover is tiny');
    }
  });
}
