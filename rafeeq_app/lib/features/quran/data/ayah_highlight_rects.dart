import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Turns an ayah's TAP rectangles into the rectangles the highlight is drawn
/// from — one per printed line, inset so neighbouring lines stay apart.
///
/// Why this exists at all: the shipped polygon layer is a **hit** layer. Its
/// rectangles are sized to make tapping forgiving, so each one spans a full
/// line pitch with no gap above or below, and where an ayah runs through whole
/// intermediate lines the exporter emitted ONE tall rectangle instead of one
/// per line. Measured over the real asset — `hafs_kfqc_polygons.json`, 604
/// pages, 11,386 rings:
///
/// * every ring is already a 4-point axis-aligned rectangle;
/// * a single-line ring is 0.86–0.99 of the line pitch, i.e. it touches both
///   its neighbours, so two highlighted lines composite into one solid slab;
/// * **1,054 rings (9.3%) are taller than 1.4 × pitch**, the worst covering
///   8.59 lines (page 353, an-Nur 31). Filling that is the "block over half
///   the page" the owner photographed.
///
/// So the fix is arithmetic on data the app already owns, not image analysis:
/// recover each page's line grid from the rectangles' own edges, cut every
/// rectangle at those lines, and inset each band. The rings themselves are
/// left exactly as they are — hit testing WANTS the forgiving full-pitch box.
class PageLineGrid {
  /// Line edges in normalized page space, ascending.
  final List<double> boundaries;

  /// Distance between two consecutive printed lines.
  final double pitch;

  const PageLineGrid(this.boundaries, this.pitch);

  /// Median line pitch over all 604 pages of the Hafs layer: 0.06705, which is
  /// the Madinah mushaf's 15 lines (1/15 = 0.0667) measured rather than
  /// assumed. Used when one page carries too few rectangles to derive its own
  /// grid — a page whose every ayah runs the full width contributes almost no
  /// interior edges.
  static const double medianPitch = 0.06705;

  /// Guard rails for a per-page pitch. Measured range over the same asset was
  /// 0.0522 … (one degenerate page at 0.994, where a single gap was all there
  /// was); anything outside this falls back to [medianPitch] rather than
  /// producing one band the height of the page.
  static const double _minPitch = 0.045;
  static const double _maxPitch = 0.095;

  /// Two edges closer together than this are the same printed line's edge
  /// seen from the rectangle above and the one below.
  static const double _edgeTolerance = 0.004;

  /// Derives the grid from every rectangle on one page.
  factory PageLineGrid.fromRings(Iterable<List<Offset>> rings) {
    final edges = <double>[];
    for (final ring in rings) {
      if (ring.length < 3) continue;
      var top = double.infinity;
      var bottom = -double.infinity;
      for (final p in ring) {
        if (p.dy < top) top = p.dy;
        if (p.dy > bottom) bottom = p.dy;
      }
      edges..add(top)..add(bottom);
    }
    if (edges.isEmpty) return const PageLineGrid(<double>[], medianPitch);
    edges.sort();

    final merged = <double>[];
    var group = <double>[edges.first];
    for (var i = 1; i < edges.length; i++) {
      if (edges[i] - group.last < _edgeTolerance) {
        group.add(edges[i]);
      } else {
        merged.add(group.reduce((a, b) => a + b) / group.length);
        group = <double>[edges[i]];
      }
    }
    merged.add(group.reduce((a, b) => a + b) / group.length);

    // Only gaps that could be a printed line count towards the pitch; the
    // small ones are a rectangle that starts slightly inside its line.
    final gaps = <double>[];
    for (var i = 1; i < merged.length; i++) {
      final g = merged[i] - merged[i - 1];
      if (g > 0.02) gaps.add(g);
    }
    var pitch = medianPitch;
    if (gaps.isNotEmpty) {
      gaps.sort();
      final mid = gaps[gaps.length ~/ 2];
      if (mid >= _minPitch && mid <= _maxPitch) pitch = mid;
    }
    return PageLineGrid(merged, pitch);
  }
}

/// How much of the pitch is shaved off the top and the bottom of every band,
/// so two highlighted lines read as two marks rather than one slab. 9% each
/// side leaves 82% of the line covered — enough to sit behind the tallest
/// ascender on the page and still show paper between the lines.
const double _kVerticalInsetFactor = 0.09;

/// A band this narrow is an artefact of a line ending, not text worth marking.
const double _kMinWidth = 0.012;

/// The rectangles to fill for one ayah, in the same normalized page space the
/// rings use.
///
/// [inkTight]: the rings were drawn tight to the ink, marks included, so the
/// band is NOT shaved. The 9 % inset below was written for the old tap
/// layer, whose rings span the whole pitch; applied to `madinah_qc`'s rings
/// it cut ~12 px off the top and the bottom of every line - the waqf marks,
/// the harakat above and the descenders below stood outside the highlight
/// (owner's photo, page 7, 2026-09-26: «التظليل يغطي الآية بالتشكيل بتاعها
/// والعلامات»). Measured on page 7's image: line 1's ring spans rows 30-150
/// and its ink 31-148; line 2 167-281 against 168-279 - the ring already
/// holds every mark, and the gap to the next line is ~22 % of the pitch.
List<Rect> highlightRectsFor(
  List<List<Offset>> rings,
  PageLineGrid grid, {
  bool inkTight = false,
}) {
  final out = <Rect>[];
  for (final ring in rings) {
    if (ring.length < 3) continue;
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final p in ring) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    if (right - left < _kMinWidth) continue;

    // A ring that is already one line tall is NOT cut. The layer shipped
    // before 2026-09-20 was a tap layer whose rings ran over several lines at
    // once, and cutting them is the whole reason this file exists; the
    // `madinah_qc` layer is built one ring per printed line, and its rings
    // are tight to the ink rather than to the line pitch. Cutting those at
    // the page's merged edges split a single line into two half-height bands
    // with a gap through the middle of the words — the edges of a SHORT ring
    // on the same line land inside a longer one. Measured on the real asset:
    // Al-Baqarah 2:31 on page 6 came back as four rectangles for two lines.
    // An ink-tight layer is one ring per printed line by construction (see
    // its test «no ring covers more than its own line»); a tall one is a
    // line with tall marks - 21:50 on page 326 is 0.0687 of the page - and
    // cutting it would drop the marks this flag exists to keep.
    final bands = inkTight || (bottom - top) <= 1.35 * grid.pitch
        ? <(double, double)>[(top, bottom)]
        : _bands(top, bottom, grid);

    for (final band in bands) {
      if (inkTight) {
        // A hair outside the ring, so anti-aliased edges are inside too;
        // far less than the ~0.22-pitch gap to the neighbouring line.
        final pad = grid.pitch * 0.012;
        out.add(Rect.fromLTRB(left, band.$1 - pad, right, band.$2 + pad));
        continue;
      }
      final inset = math.min(
        grid.pitch * _kVerticalInsetFactor,
        (band.$2 - band.$1) * 0.25,
      );
      final y0 = band.$1 + inset;
      final y1 = band.$2 - inset;
      if (y1 <= y0) continue;
      out.add(Rect.fromLTRB(left, y0, right, y1));
    }
  }
  return out;
}

/// Splits [top]..[bottom] into one span per printed line.
///
/// First at the page's own line edges — those are exact. A span that is still
/// more than 1.4 pitches tall afterwards belongs to a page whose grid could
/// not be recovered, and is divided evenly into the number of lines its height
/// implies; that is an estimate, and it is only ever reached where the exact
/// answer is not in the data.
List<(double, double)> _bands(double top, double bottom, PageLineGrid grid) {
  const eps = 0.006;
  final cuts = <double>[top];
  for (final b in grid.boundaries) {
    if (b > top + eps && b < bottom - eps) cuts.add(b);
  }
  cuts.add(bottom);

  final bands = <(double, double)>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final a = cuts[i];
    final b = cuts[i + 1];
    final lines = (b - a) / grid.pitch;
    if (lines > 1.4) {
      final n = math.max(2, lines.round());
      final step = (b - a) / n;
      for (var k = 0; k < n; k++) {
        bands.add((a + step * k, a + step * (k + 1)));
      }
    } else {
      bands.add((a, b));
    }
  }
  return bands;
}
