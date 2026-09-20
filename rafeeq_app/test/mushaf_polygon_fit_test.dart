import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';

/// ONE paper mushaf, and its highlight is exact.
///
/// Until 2026-09-20 the catalogue carried five printings. Four were SCANS with
/// no ayah coordinates of their own — the coloured Tajweed mushaf, the
/// illuminated "gold" printing, Mushaf Qatar and Mushaf Kuwait — each
/// borrowing the Madinah polygons through a per-page affine. Printings do not
/// break their lines at the same words and do not put their surah banners on
/// the same lines (Qatar sets al-Nisa's banner at the foot of page 76 where
/// Madinah opens page 77 with it), so a borrowed highlight could sit a word,
/// or a whole line, away from the printed marker. The fifth was `hafs_kfqc`,
/// correct but 286 MB of SVG.
///
/// The owner's ruling: «انا معنديش اي مشكلة انه يكون عندي مصحف نصي ومصحف واحد
/// ورقي، بس يكون التظليل فيه تمام». What ships now is `madinah_qc`: the same
/// 604-page Madinah pagination as page images at 1260x2038 (71 MB), whose
/// publisher ships the ayah coordinates WITH the pages — 88,246 word boxes
/// merged into 13,766 per-line rings over all 6,236 ayahs. Nothing is fitted,
/// measured or guessed, which is the only way «تمام» is true rather than
/// hoped for.
///
/// What this file guards is that state: one printing, its own coordinates,
/// covering every ayah, named in every locale, with a cover on disk.
void main() {
  final doc = jsonDecode(File('assets/data/mushaf/editions.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final editions = [
    for (final e in doc['editions'] as List<dynamic>)
      MushafEdition.fromJson(e as Map<String, dynamic>)
  ];

  test('the catalogue is exactly one printing: the vector Madinah Hafs', () {
    expect([for (final e in editions) e.id], ['madinah_qc']);
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

  test('the printing carries its own coordinates, not a fitted borrowing', () {
    // The fit it does carry is the IDENTITY — the polygons already ARE this
    // printing's own space, and an identity entry is what lets the existing
    // raster drawing path use them with no arithmetic at all. Anything other
    // than identity would mean the coordinates came from somewhere else.
    final e = editions.single;
    for (final page in [1, 2, 50, 77, 300, 604]) {
      final fit = e.fitForPage(page)!;
      expect(fit.sx, 1.0, reason: 'p$page sx');
      expect(fit.dx, 0.0, reason: 'p$page dx');
      expect(fit.sy, 1.0, reason: 'p$page sy');
      expect(fit.dy, 0.0, reason: 'p$page dy');
      // Every one of the 604 PNGs measured 1260x2038.
      expect(fit.pageAspect, closeTo(1260 / 2038, 1e-5), reason: 'p$page');
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
    // Every ayah of the mushaf, and every ring inside the page.
    var ayahs = 0;
    for (final entry in pages.values) {
      for (final a in entry as List<dynamic>) {
        ayahs++;
        for (final ring in (a as List<dynamic>)[2] as List<dynamic>) {
          for (final pt in ring as List<dynamic>) {
            final x = (pt as List<dynamic>)[0] as num;
            final y = pt[1] as num;
            expect(x >= 0 && x <= 1, isTrue, reason: 'x $x out of the page');
            expect(y >= 0 && y <= 1, isTrue, reason: 'y $y out of the page');
          }
        }
      }
    }
    expect(ayahs, 6236);
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
