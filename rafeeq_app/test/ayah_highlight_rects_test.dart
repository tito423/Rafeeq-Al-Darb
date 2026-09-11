import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/ayah_highlight_rects.dart';

/// The owner photographed a highlight that covered most of a page instead of
/// the ayah. The cause is in the shipped tap layer, and it is measurable:
///
///   * a ring spans a whole line pitch with no gap, so two marked lines
///     composite into one slab;
///   * 1,054 of 11,386 rings (9.3%) are ONE rectangle over several lines, the
///     worst 8.59 lines tall.
///
/// Both numbers are re-measured here from the real asset rather than quoted,
/// so this test fails the day the asset changes — and the first two
/// expectations are the proof that the defect is real, not a guess about it.
/// Then the same rings go through [highlightRectsFor] and the same page is
/// measured again.
void main() {
  final doc = jsonDecode(
    File('assets/data/mushaf/hafs_kfqc_polygons.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final pages = doc['pages'] as Map<String, dynamic>;

  List<List<Offset>> ringsOf(dynamic row) => [
        for (final ring in (row as List)[2] as List)
          [
            for (final p in ring as List)
              Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
      ];

  test('the defect is in the asset: rings run whole lines and merge them', () {
    var total = 0;
    var tall = 0;
    for (final entry in pages.entries) {
      final rows = entry.value as List;
      final grid = PageLineGrid.fromRings(rows.expand(ringsOf));
      for (final row in rows) {
        for (final ring in ringsOf(row)) {
          final ys = ring.map((p) => p.dy);
          final h = ys.reduce((a, b) => a > b ? a : b) -
              ys.reduce((a, b) => a < b ? a : b);
          total++;
          if (h > 1.4 * grid.pitch) tall++;
        }
      }
    }
    expect(total, 11386, reason: 'the asset is the one that was measured');
    expect(tall, greaterThan(1000),
        reason: 'rings covering several lines at once are what put a slab '
            'over the page; measured 1,054');
  });

  test('every drawn rectangle is one line tall, on all 604 pages', () {
    var drawn = 0;
    final offenders = <String>[];
    for (final entry in pages.entries) {
      final rows = entry.value as List;
      final grid = PageLineGrid.fromRings(rows.expand(ringsOf));
      for (final row in rows) {
        final rects = highlightRectsFor(ringsOf(row), grid);
        for (final r in rects) {
          drawn++;
          if (r.height > 1.15 * grid.pitch) {
            offenders.add('page ${entry.key} ${row[0]}:${row[1]} '
                'h=${r.height.toStringAsFixed(4)} '
                'pitch=${grid.pitch.toStringAsFixed(4)}');
          }
        }
      }
    }
    expect(drawn, greaterThan(11386),
        reason: 'splitting the tall rings can only produce more rectangles');
    expect(offenders, isEmpty);
  });

  test('two lines of the same ayah never touch', () {
    // Al-Baqarah 2:32 on page 6 is the screenshot the owner sent: two lines,
    // which used to be drawn as two rectangles sharing an edge at y=0.3350.
    final row = (pages['6'] as List).firstWhere(
      (r) => (r as List)[0] == 2 && r[1] == 32,
    );
    final rings = ringsOf(row);
    final grid = PageLineGrid.fromRings(
      (pages['6'] as List).expand(ringsOf),
    );

    expect(rings.length, 2);
    expect(rings[0].map((p) => p.dy).reduce((a, b) => a > b ? a : b),
        closeTo(rings[1].map((p) => p.dy).reduce((a, b) => a < b ? a : b), 1e-9),
        reason: 'the rings themselves share an edge — that is the slab');

    final rects = highlightRectsFor(rings, grid);
    expect(rects.length, 2);
    final gap = rects[1].top - rects[0].bottom;
    expect(gap, greaterThan(0.006),
        reason: 'paper has to show between two marked lines');
  });

  test('the worst page in the asset is cut into its real lines', () {
    // Page 353, an-Nur 31 — one rectangle 8.59 pitches tall.
    final row = (pages['353'] as List).firstWhere(
      (r) => (r as List)[0] == 24 && r[1] == 31,
    );
    final grid = PageLineGrid.fromRings(
      (pages['353'] as List).expand(ringsOf),
    );
    final rings = ringsOf(row);
    final tallest = rings
        .map((ring) {
          final ys = ring.map((p) => p.dy);
          return ys.reduce((a, b) => a > b ? a : b) -
              ys.reduce((a, b) => a < b ? a : b);
        })
        .reduce((a, b) => a > b ? a : b);
    expect(tallest / grid.pitch, greaterThan(8));

    final rects = highlightRectsFor(rings, grid);
    expect(rects.length, greaterThanOrEqualTo(8));
    for (final r in rects) {
      expect(r.height, lessThan(1.15 * grid.pitch));
    }
  });

  test('nothing is lost: the marks still cover the ayah', () {
    // A line's mark is inset vertically, so the covered area is smaller by
    // construction — but it must not be a sliver. Checked as area, over a
    // whole page rather than one favourable ayah.
    final rows = pages['3'] as List;
    final grid = PageLineGrid.fromRings(rows.expand(ringsOf));
    var ringArea = 0.0;
    var rectArea = 0.0;
    for (final row in rows) {
      final rings = ringsOf(row);
      for (final ring in rings) {
        final xs = ring.map((p) => p.dx);
        final ys = ring.map((p) => p.dy);
        ringArea += (xs.reduce((a, b) => a > b ? a : b) -
                xs.reduce((a, b) => a < b ? a : b)) *
            (ys.reduce((a, b) => a > b ? a : b) -
                ys.reduce((a, b) => a < b ? a : b));
      }
      for (final r in highlightRectsFor(rings, grid)) {
        rectArea += r.width * r.height;
      }
    }
    expect(rectArea / ringArea, greaterThan(0.72));
    expect(rectArea / ringArea, lessThan(1.0));
  });

  test('a page with no usable grid falls back to the measured pitch', () {
    // One rectangle, alone, with nothing to derive a grid from: the fallback
    // is the median pitch measured over all 604 pages, not the rectangle's
    // own height — otherwise a full-page ring would stay a full-page mark.
    final ring = [
      const Offset(0.05, 0.10),
      const Offset(0.95, 0.10),
      const Offset(0.95, 0.70),
      const Offset(0.05, 0.70),
    ];
    final grid = PageLineGrid.fromRings([ring]);
    expect(grid.pitch, PageLineGrid.medianPitch);

    final rects = highlightRectsFor([ring], grid);
    expect(rects.length, 9, reason: '0.60 / 0.06705 rounds to 9 lines');
    for (final r in rects) {
      expect(r.height, lessThan(1.15 * grid.pitch));
    }
  });

  test('a sliver of a line ending is not marked', () {
    final ring = [
      const Offset(0.900, 0.20),
      const Offset(0.904, 0.20),
      const Offset(0.904, 0.26),
      const Offset(0.900, 0.26),
    ];
    expect(
      highlightRectsFor([ring], const PageLineGrid(<double>[], 0.06705)),
      isEmpty,
    );
  });
}
