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

  test('only printings whose layout was verified carry an ayah layer', () {
    expect(byId('hafs_kfqc').hasAyahLayer, isTrue);
    expect(byId('tajweed_color').hasAyahLayer, isTrue);
    for (final id in ['qatar', 'kuwait', 'madinah_night']) {
      expect(byId(id).hasAyahLayer, isTrue, reason: id);
    }
    // These ship without a highlight rather than with a wrong one. shamarly
    // (521 pages), indopak_tajweed (564) and madinah_nastaleeq (611) paginate
    // their own way; madinah_gold sets 6 lines on its page 2 where the
    // Madinah mushaf sets 15. No affine can map the Hafs polygons onto them.
    for (final id in [
      'shamarly',
      'madinah_gold',
      'indopak_tajweed',
      'madinah_nastaleeq',
    ]) {
      expect(byId(id).hasAyahLayer, isFalse, reason: id);
      expect(byId(id).fitForPage(1), isNull, reason: id);
    }
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
      // Kuwait's two illuminated openings are deliberately unfitted: the
      // warm cream ground and brown ink defeated every panel measurement,
      // and one line out on al-Fatiha is worse than no highlight.
      ('kuwait', 604, 602),
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

    // Kuwait pages 1-2 really do come back with nothing.
    expect(byId('kuwait').fitForPage(1), isNull);
    expect(byId('kuwait').fitForPage(2), isNull);
    expect(byId('kuwait').fitForPage(3), isNotNull);
  });

  test('only a printing on the Madinah page claims the running header', () {
    for (final id in ['hafs_kfqc', 'tajweed_color', 'qatar', 'kuwait',
                      'madinah_night']) {
      expect(byId(id).hafsPagination, isTrue, reason: id);
      expect(byId(id).pages, 604, reason: id);
    }
    for (final row in [('shamarly', 521), ('indopak_tajweed', 564),
                       ('madinah_nastaleeq', 611)]) {
      final (id, pages) = row;
      expect(byId(id).hafsPagination, isFalse, reason: id);
      expect(byId(id).pages, pages, reason: id);
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
