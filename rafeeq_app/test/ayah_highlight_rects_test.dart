import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/ayah_highlight_rects.dart';

/// THE DEFECT THIS FILE WAS WRITTEN FOR IS GONE, AND THAT IS WHAT IT NOW
/// GUARDS.
///
/// The owner once photographed a highlight covering most of a page instead of
/// one ayah. The cause was in the shipped layer: `hafs_kfqc_polygons.json` was
/// a TAP layer, so a ring spanned a whole line pitch with no gap above or
/// below (two marked lines composited into one slab), and where an ayah ran
/// through whole intermediate lines the exporter emitted ONE tall rectangle —
/// 1,054 of its 11,386 rings were taller than 1.4 line pitches, the worst
/// 8.59 lines. `highlightRectsFor` existed to cut those apart.
///
/// The paper mushaf is `madinah_qc` now (2026-09-20), and its layer is built
/// per line by `scripts/build_madinah_qc_polygons.py` from the publisher's own
/// word boxes. Measured over the real asset here rather than quoted: 604
/// pages, 6,236 ayahs, 13,766 rings, and **not one** ring taller than 1.4×
/// the median — the defect cannot recur unless the generator changes.
///
/// `highlightRectsFor` stays, and is still exercised below. It costs nothing
/// on a layer that needs no cutting, and it is the guard that a future layer
/// with the old shape would still be drawn one line at a time.
void main() {
  final doc = jsonDecode(
    File('assets/data/mushaf/madinah_qc_polygons.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final pages = doc['pages'] as Map<String, dynamic>;

  List<List<Offset>> ringsOf(dynamic row) => [
        for (final ring in (row as List)[2] as List)
          [
            for (final p in ring as List)
              Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
      ];

  test('the asset is the one that was measured', () {
    expect(pages.length, 604);
    var ayahs = 0;
    var rings = 0;
    for (final page in pages.values) {
      for (final row in page as List) {
        ayahs++;
        rings += ringsOf(row).length;
      }
    }
    expect(ayahs, 6236, reason: 'every ayah of the mushaf');
    expect(rings, 13766);
  });

  test('no ring covers more than its own line', () {
    // This is the old defect, stated as a property. The layer is built one
    // ring per printed line, so the tallest ring on the whole mushaf is
    // 1.33x the median and nothing is near the 1.4 the cutter was written
    // for.
    final heights = <double>[];
    for (final page in pages.values) {
      for (final row in page as List) {
        for (final ring in ringsOf(row)) {
          final ys = ring.map((p) => p.dy);
          heights.add(ys.reduce((a, b) => a > b ? a : b) -
              ys.reduce((a, b) => a < b ? a : b));
        }
      }
    }
    heights.sort();
    final median = heights[heights.length ~/ 2];
    final tall = heights.where((h) => h > 1.4 * median).length;
    expect(tall, 0, reason: 'the old layer had 1,054 of these');
    expect(heights.last / median, lessThan(1.4));
  });

  test('drawing never makes a band taller than the line it came from', () {
    // The old test compared against the page's derived PITCH, because the old
    // rings were a full pitch tall by construction. These rings are tight to
    // the ink, so the pitch a page derives from them is not the right ruler —
    // the honest property is that drawing only ever shrinks a ring, never
    // grows or merges one.
    var drawn = 0;
    final offenders = <String>[];
    for (final entry in pages.entries) {
      final rows = entry.value as List;
      final grid = PageLineGrid.fromRings(rows.expand(ringsOf));
      for (final row in rows) {
        final rings = ringsOf(row);
        var tallest = 0.0;
        for (final ring in rings) {
          final ys = ring.map((p) => p.dy);
          final h = ys.reduce((a, b) => a > b ? a : b) -
              ys.reduce((a, b) => a < b ? a : b);
          if (h > tallest) tallest = h;
        }
        for (final r in highlightRectsFor(rings, grid)) {
          drawn++;
          if (r.height > tallest + 1e-9) {
            offenders.add('page ${entry.key} ${row[0]}:${row[1]} '
                'drawn=${r.height.toStringAsFixed(4)} '
                'tallest ring=${tallest.toStringAsFixed(4)}');
          }
        }
      }
    }
    expect(drawn, greaterThanOrEqualTo(13766));
    expect(offenders, isEmpty);
  });

  test('two lines of the same ayah never touch', () {
    // Al-Baqarah 2:31 on page 6 runs over two lines. In the old layer the two
    // rings SHARED an edge, which is what made a slab; here they are already
    // 0.0093 of the page apart, and the drawn rectangles keep a gap too.
    final row = (pages['6'] as List).firstWhere(
      (r) => (r as List)[0] == 2 && r[1] == 31,
    );
    final rings = ringsOf(row);
    expect(rings.length, 2);

    final bottom = rings[0].map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    final top = rings[1].map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    expect(top - bottom, greaterThan(0.005),
        reason: 'the source rings do not touch to begin with');

    final grid = PageLineGrid.fromRings((pages['6'] as List).expand(ringsOf));
    final rects = highlightRectsFor(rings, grid);
    expect(rects.length, 2,
        reason: 'two printed lines are two marks, not four');
    expect(rects[1].top - rects[0].bottom, greaterThan(0.004),
        reason: 'paper has to show between two marked lines');
  });

  test('madinah_qc: the highlight holds every mark and descender', () {
    // The owner's photo of page 7 (2026-09-26): waqf marks and harakat above
    // the line and descenders below it stood OUTSIDE the recited-ayah
    // highlight. This layer's rings are tight to the ink (page 7, line 1:
    // ring rows 30-150, ink 31-148), so the drawn band must contain the
    // whole ring - and, 0.22 pitch of paper away, still not touch the next.
    expect(doc['edition'], 'madinah_qc');
    for (final entry in pages.entries) {
      final grid =
          PageLineGrid.fromRings((entry.value as List).expand(ringsOf));
      for (final row in entry.value as List) {
        final rings = ringsOf(row);
        final rects = highlightRectsFor(rings, grid, inkTight: true);
        for (final ring in rings) {
          final top = ring.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
          final bottom =
              ring.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
          final left = ring.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
          final covering = rects.where((r) =>
              r.left <= left + 1e-9 && r.top <= top && r.bottom >= bottom);
          expect(covering, isNotEmpty,
              reason: 'page ${entry.key} ${(row as List)[0]}:${row[1]}: a '
                  'ring left outside its own highlight');
        }
      }
    }
    final row = (pages['6'] as List).firstWhere(
      (r) => (r as List)[0] == 2 && r[1] == 31,
    );
    final grid = PageLineGrid.fromRings((pages['6'] as List).expand(ringsOf));
    final rects = highlightRectsFor(ringsOf(row), grid, inkTight: true);
    expect(rects[1].top - rects[0].bottom, greaterThan(0.004),
        reason: 'paper still shows between two marked lines');
  });

  test('every rectangle stays on the page', () {
    for (final entry in pages.entries) {
      final rows = entry.value as List;
      final grid = PageLineGrid.fromRings(rows.expand(ringsOf));
      for (final row in rows) {
        for (final r in highlightRectsFor(ringsOf(row), grid)) {
          expect(r.left, greaterThanOrEqualTo(-0.001), reason: entry.key);
          expect(r.right, lessThanOrEqualTo(1.001), reason: entry.key);
          expect(r.top, greaterThanOrEqualTo(-0.001), reason: entry.key);
          expect(r.bottom, lessThanOrEqualTo(1.001), reason: entry.key);
        }
      }
    }
  });
}
