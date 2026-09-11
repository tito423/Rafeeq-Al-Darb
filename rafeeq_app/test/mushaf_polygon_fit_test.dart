import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';

/// The Tajweed printing has no polygon layer of its own. It borrows the Hafs
/// vector edition's, through an affine fitted by
/// `scripts/fit_mushaf_polygon_transform.py` and then checked by rendering the
/// mapped polygons over the real scans.
///
/// These are not tests of the arithmetic — they pin the fit to positions
/// MEASURED on the printed pages, so a future edit to `editions.json` that
/// drifts the highlight off the text fails here instead of shipping.
///
/// The measurements (all from the scans themselves, 2026-09-09):
///   * page 50 is 861x1317; its 13 printed Quran lines run from y 0.1746 to
///     y 0.9749, and line 1 — which carries Al Imran 1-3 — occupies
///     y 0.1746-0.2202.
///   * pages 1-2 are 901x1476 and set their own text block inside a heavier
///     frame, so they carry their own fit.
void main() {
  final doc = jsonDecode(
      File('assets/data/mushaf/editions.json').readAsStringSync()) as Map<String, dynamic>;
  final editions = [
    for (final e in doc['editions'] as List<dynamic>)
      MushafEdition.fromJson(e as Map<String, dynamic>)
  ];
  MushafEdition byId(String id) => editions.firstWhere((e) => e.id == id);

  final polygons = jsonDecode(
          File('assets/data/mushaf/hafs_kfqc_polygons.json').readAsStringSync())
      as Map<String, dynamic>;

  /// The vertical band of the first ayah region listed on a Hafs page.
  (double, double) hafsFirstBand(int page) {
    final ring = ((polygons['pages'] as Map<String, dynamic>)['$page']
        as List<dynamic>)[0] as List<dynamic>;
    final pts = (ring[2] as List<dynamic>).first as List<dynamic>;
    final ys = [for (final p in pts) (p as List<dynamic>)[1] as num];
    return (ys.reduce((a, b) => a < b ? a : b).toDouble(),
        ys.reduce((a, b) => a > b ? a : b).toDouble());
  }

  test('EVERY printing in the catalogue can highlight an ayah', () {
    // The owner's ruling, 2026-09-11: «اي مصحف مصور مش محدد اجزاء الايات عشان
    // التظليل شيله من التطبيق كله». A printing that cannot show you where the
    // ayah is has no place in the list, so this is now an invariant over the
    // whole catalogue rather than a list of known-good ids.
    //
    // Removed in v3.16.0 for failing it: shamarly (521 pages),
    // indopak_tajweed (564), madinah_nastaleeq (611). Each paginates its own
    // way and no affine maps the Hafs polygons onto a different typesetting.
    expect(editions, isNotEmpty);
    for (final e in editions) {
      expect(e.hasAyahLayer, isTrue,
          reason: '${e.id} is in the catalogue with no ayah layer');
    }
    // And the layer has to be one that actually exists.
    for (final e in editions) {
      expect(File(e.polygonsAsset).existsSync(), isTrue,
          reason: '${e.id} points at ${e.polygonsAsset}');
    }
  });

  test('a printing that paginates its own way is not in the list', () {
    final ids = [for (final e in editions) e.id];
    for (final gone in [
      'shamarly',
      'indopak_tajweed',
      'madinah_nastaleeq',
    ]) {
      expect(ids, isNot(contains(gone)), reason: gone);
    }
  });

  test('every printing names itself in all seven app locales', () {
    // A fresh install in Spanish used to list every printing under its ARABIC
    // title. `localizedName` must return something in the reader's own script
    // for every locale the app ships — and must not fall back to Arabic for a
    // locale that has a name of its own.
    const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];
    final arabicLetters = RegExp(r'[؀-ۿ]');
    for (final e in editions) {
      for (final loc in locales) {
        final name = e.localizedName(loc);
        final riwayah = e.localizedRiwayah(loc);
        expect(name.trim(), isNotEmpty, reason: '${e.id} name/$loc');
        expect(riwayah.trim(), isNotEmpty, reason: '${e.id} riwayah/$loc');
        if (loc == 'ar' || loc == 'ur') {
          // Both are Arabic-script locales, so both should read in it.
          expect(arabicLetters.hasMatch(name), isTrue,
              reason: '${e.id}: $loc name is not in Arabic script: $name');
        } else {
          expect(name, isNot(e.nameAr),
              reason: '${e.id}: $loc fell back to the Arabic title');
        }
      }
      // Urdu is a different language, not a copy of the Arabic row.
      expect(e.localizedName('ur'), isNot(e.nameAr), reason: e.id);
    }
  });

  test('page 2 of a Madinah printing sets six lines, not fifteen', () {
    // The fact that kept `madinah_gold` unfitted for three sessions. Page 2 of
    // ANY Madinah printing is al-Baqarah's illuminated opening: six lines of
    // text under a gold basmalah that is not itself an ayah. Fifteen is what a
    // BODY page sets. So «it sets 6 lines on page 2» was never evidence of a
    // different typesetting — it is what the reference edition does too.
    //
    // Asserted against the Hafs polygon layer itself rather than a comment, so
    // the claim cannot rot again: the number of distinct line bands the
    // polygons occupy on page 2, and on page 50 for contrast.
    // Counted exactly as `scripts/fit_mushaf_polygon_per_page.py:hafs_lines`
    // counts it: collect every ring's top and bottom edge, merge edges closer
    // than a hair, then split each band by the shortest ring on the page —
    // an ayah that runs over two lines contributes one tall ring, not two.
    int linesOnPage(int page) {
      final rows = (polygons['pages'] as Map<String, dynamic>)['$page']
          as List<dynamic>;
      final edges = <double>{};
      final heights = <double>[];
      for (final row in rows) {
        for (final ring in (row as List<dynamic>)[2] as List<dynamic>) {
          final ys = [
            for (final q in ring as List<dynamic>)
              ((q as List<dynamic>)[1] as num).toDouble()
          ];
          final lo = ys.reduce((a, b) => a < b ? a : b);
          final hi = ys.reduce((a, b) => a > b ? a : b);
          edges..add(lo)..add(hi);
          heights.add(hi - lo);
        }
      }
      final sorted = edges.toList()..sort();
      final merged = <double>[sorted.first];
      for (final v in sorted.skip(1)) {
        if (v - merged.last > 0.004) merged.add(v);
      }
      final unit = heights.where((h) => h > 0.02).reduce((a, b) => a < b ? a : b);
      var n = 0;
      for (var i = 0; i + 1 < merged.length; i++) {
        final span = merged[i + 1] - merged[i];
        n += (span / unit).round().clamp(1, 20);
      }
      return n;
    }

    expect(linesOnPage(2), 6,
        reason: 'al-Baqarah opens on six lines in the reference edition too, '
            'so «madinah_gold sets 6 lines on page 2» was never evidence of a '
            'different typesetting');
    expect(linesOnPage(1), 7, reason: 'al-Fatiha sets seven');
    // Page 3 is a full body page: fifteen lines, every one of them Quran, so
    // the polygon layer covers all fifteen slots of the Madinah grid.
    expect(linesOnPage(3), 15, reason: 'a body page is the fifteen-line grid');
    // Page 50 also sets fifteen slots, but two of them are آل عمران's header
    // band and its basmalah, which carry no ayah polygon — which is precisely
    // why the per-page fitter matches printed ink runs against the GLOBAL
    // 15-slot grid on a body page rather than against that page's own rings.
    expect(linesOnPage(50), 13,
        reason: '15 slots minus the surah header and the basmalah');
  });

  test('the Hafs edition needs no fit; the Tajweed one has its own per group',
      () {
    expect(byId('hafs_kfqc').fitForPage(50), isNull);

    final tj = byId('tajweed_color');
    expect(tj.polygonsAsset, byId('hafs_kfqc').polygonsAsset,
        reason: 'the Tajweed printing reuses the Hafs layer, and the coords '
            'repository is keyed by asset so it is parsed once');

    // Two page groups, measured from every one of the 604 scans' JPEG headers:
    // 602 body pages at 861x1317 and the two opening pages at 901x1476.
    expect(tj.fitForPage(50)!.pageAspect, closeTo(861 / 1317, 0.0001));
    expect(tj.fitForPage(1)!.pageAspect, closeTo(901 / 1476, 0.0001));
    expect(tj.fitForPage(2)!.pageAspect, closeTo(901 / 1476, 0.0001));
    expect(tj.fitForPage(3)!.pageAspect, tj.fitForPage(604)!.pageAspect);
  });

  test('a tap maps back to exactly where the polygon maps forward', () {
    final fit = byId('tajweed_color').fitForPage(50)!;
    for (final p in [
      const Offset(0.0, 0.0),
      const Offset(0.5, 0.5),
      const Offset(0.9928, 0.9954),
    ]) {
      final there = fit.apply(p);
      final back = fit.invert(there.dx, there.dy);
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    }
  });

  /// What has to hold for a highlight to read correctly: the band sits on the
  /// printed line's centre, and it covers nearly all of that line's ink.
  ///
  /// Not "the band contains the ink exactly". The Hafs line box is tight and
  /// Arabic descenders overshoot it, so a correct band can still clip a few
  /// pixels of a tail — measured on page 50 it covers 93% of the ink and ends
  /// 3 px above the lowest descender, which is what the rendered overlays
  /// show and is invisible in use.
  void expectBandOnLine(
    AyahPolygonFit fit,
    (double, double) hafsBand,
    (double, double) printedInk, {
    required String page,
  }) {
    final top = fit.apply(Offset(0, hafsBand.$1)).dy;
    final bottom = fit.apply(Offset(0, hafsBand.$2)).dy;
    const pitch = 0.0639;               // the printed line pitch, measured

    final drift = ((top + bottom) / 2 - (printedInk.$1 + printedInk.$2) / 2).abs();
    expect(drift, lessThan(pitch / 3),
        reason: '$page: the band centre drifted ${(drift / pitch).toStringAsFixed(2)} '
            'of a line off the printed line');

    final overlap = (bottom < printedInk.$2 ? bottom : printedInk.$2) -
        (top > printedInk.$1 ? top : printedInk.$1);
    final covered = overlap / (printedInk.$2 - printedInk.$1);
    expect(covered, greaterThan(0.85),
        reason: '$page: the band covers only '
            '${(covered * 100).toStringAsFixed(0)}% of the printed line');
  }

  test('page 50 line 1 maps onto the line the scan actually prints there', () {
    // Measured on 050.jpg: the first Quran line's ink — which carries
    // Al Imran 1-3 — spans y 0.1746-0.2202.
    expectBandOnLine(byId('tajweed_color').fitForPage(50)!, hafsFirstBand(50),
        (0.1746, 0.2202), page: 'page 50');
  });

  test('the per-page printings carry an affine for the pages they claim', () {
    // Leaves cropped one by one, so there is no edition-wide affine that
    // would do and every page carries its own.
    for (final row in [
      ('qatar', 604, 604),
      ('madinah_night', 604, 604),
      ('madinah_gold', 604, 604),
      // Kuwait's two illuminated openings shipped unfitted at v3.8.0 because
      // no luminance threshold separated their seven lines. Darkness was the
      // wrong test: the illumination is coloured and the ink is neutral, so
      // a saturation mask does it, and both openings are fitted now.
      ('kuwait', 604, 604),
    ]) {
      final (id, pages, fitted) = row;
      final e = byId(id);
      expect(e.polygonsAsset, byId('hafs_kfqc').polygonsAsset, reason: id);
      expect(e.polygonFit, isNull,
          reason: '$id: a per-page printing must not carry an edition-wide '
              'default — a page with no fit should get no highlight');
      expect(e.polygonFitPages.length, fitted, reason: id);
      expect(e.pages, pages, reason: id);

      // Neighbouring pages must differ. If every entry were identical the
      // per-page fit would be a fiction and one affine would have done.
      final shifts = <double>[];
      for (var p = 3; p < pages; p++) {
        final a = e.fitForPage(p), b = e.fitForPage(p + 1);
        if (a != null && b != null) shifts.add((a.dx - b.dx).abs());
      }
      shifts.sort();
      expect(shifts.last, greaterThan(0.004),
          reason: '$id: no page-to-page variation');
    }

    // Every per-page printing's illuminated openings carry their OWN affine,
    // not the body one — they set a smaller text block inside a heavy frame,
    // so an entry equal to page 3's would mean the opening was never measured.
    for (final id in ['qatar', 'kuwait', 'madinah_night', 'madinah_gold']) {
      final e = byId(id);
      for (final p in [1, 2]) {
        final f = e.fitForPage(p);
        expect(f, isNotNull, reason: '$id page $p');
        expect(f!.sy, isNot(closeTo(e.fitForPage(3)!.sy, 0.001)),
            reason: '$id page $p uses the body affine');
      }
    }
  });

  test('every remaining printing is on the Madinah page', () {
    // Once the three own-pagination printings were removed, this stopped
    // being a property of a hand-written list and became true of the whole
    // catalogue: every edition left sets the 604-page Madinah layout, which
    // is the layout the surah and juz indexes navigate by.
    for (final e in editions) {
      expect(e.hafsPagination, isTrue, reason: e.id);
      expect(e.pages, 604, reason: e.id);
    }
  });

  test('every edition ships a real cover asset', () {
    for (final e in editions) {
      expect(e.coverAsset, isNotEmpty, reason: e.id);
      expect(File(e.coverAsset).existsSync(), isTrue,
          reason: '${e.id}: ${e.coverAsset} is not on disk');
    }
  });

  test('page 1 uses its own fit, not the body one', () {
    final tj = byId('tajweed_color');
    // Measured on 001.jpg: al-Fatiha's first line (the basmalah, which IS
    // ayah 1 here) spans y 0.2791-0.3211.
    expectBandOnLine(tj.fitForPage(1)!, hafsFirstBand(1), (0.2791, 0.3211),
        page: 'page 1');

    // The body fit on this page would land more than a line away — which is
    // exactly why the two opening pages get their own.
    final (top, _) = hafsFirstBand(1);
    expect((tj.fitForPage(50)!.apply(Offset(0, top)).dy - 0.2791).abs(),
        greaterThan(0.0639));
  });
}
