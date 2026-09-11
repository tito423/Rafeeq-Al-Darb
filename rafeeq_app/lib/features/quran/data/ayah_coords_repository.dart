import 'dart:convert';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/services.dart' show rootBundle;

import 'ayah_highlight_rects.dart';

/// One ayah's tap/highlight region on a mushaf page.
///
/// An ayah normally spans several lines, so its region is a *list of rings*
/// (one closed polygon per line fragment), not a single rectangle. Collapsing
/// those fragments into one bounding box would highlight the entire text block
/// instead of the ayah: 4,221 of the Quran's 6,236 ayahs (68%) occupy more
/// than one line.
class AyahRegion {
  final int surah;
  final int ayah;

  /// Closed polygons in normalized page space: 0..1 of the page box,
  /// y growing downward.
  final List<List<Offset>> rings;

  /// Axis-aligned bounds over every ring, used as a cheap pre-filter.
  final Rect bounds;

  /// What the highlight is actually drawn from: one rectangle per printed
  /// line, inset clear of the lines above and below. Empty until the page's
  /// line grid is known, which is why [withGrid] exists — see
  /// `ayah_highlight_rects.dart` for why the rings themselves cannot be used.
  final List<Rect> highlightRects;

  const AyahRegion._(
    this.surah,
    this.ayah,
    this.rings,
    this.bounds,
    this.highlightRects,
  );

  /// The same ayah with its highlight rectangles resolved against [grid].
  AyahRegion withGrid(PageLineGrid grid) => AyahRegion._(
        surah,
        ayah,
        rings,
        bounds,
        highlightRectsFor(rings, grid),
      );

  factory AyahRegion(int surah, int ayah, List<List<Offset>> rings) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final ring in rings) {
      for (final p in ring) {
        if (p.dx < left) left = p.dx;
        if (p.dy < top) top = p.dy;
        if (p.dx > right) right = p.dx;
        if (p.dy > bottom) bottom = p.dy;
      }
    }
    return AyahRegion._(
      surah,
      ayah,
      rings,
      rings.isEmpty ? Rect.zero : Rect.fromLTRB(left, top, right, bottom),
      const <Rect>[],
    );
  }

  bool isSameAyah(AyahRegion? other) =>
      other != null && other.surah == surah && other.ayah == ayah;

  /// True when the normalized point falls inside any of this ayah's fragments.
  bool contains(double nx, double ny) {
    if (nx < bounds.left ||
        nx > bounds.right ||
        ny < bounds.top ||
        ny > bounds.bottom) {
      return false;
    }
    for (final ring in rings) {
      if (_pointInRing(ring, nx, ny)) return true;
    }
    return false;
  }

  /// Standard even-odd ray cast.
  static bool _pointInRing(List<Offset> ring, double x, double y) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].dx;
      final yi = ring[i].dy;
      final xj = ring[j].dx;
      final yj = ring[j].dy;
      if ((yi > y) != (yj > y) &&
          x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// Real ayah tap regions for the mushaf pages, one set per polygon asset.
///
/// Source: the `ayahPolygon` hit layer shipped inside the quranpedia/quran-svg
/// pages (CC0-1.0), rebuilt by `scripts/build_mushaf_svg.py` into normalized
/// page space. The Hafs set is verified against the bundled `quran_local.db`:
/// 6,236 / 6,236 ayahs. Nothing here is estimated or hand-drawn.
///
/// Keyed by ASSET PATH rather than edition id, because more than one printing
/// can share a layer: the Tajweed scan sets the same Madinah page as the
/// vector edition and reuses its polygons through an `AyahPolygonFit`. Keying
/// by edition would parse the same 0.7 MB file twice and hold two copies of
/// 6,236 regions.
class AyahCoordsRepository {
  AyahCoordsRepository._();
  static final AyahCoordsRepository instance = AyahCoordsRepository._();

  final Map<String, Map<int, List<AyahRegion>>> _byAsset = {};
  final Map<String, Future<void>> _loading = {};

  bool isLoaded(String assetPath) => _byAsset.containsKey(assetPath);

  /// Parses a polygon asset. Concurrent callers share a single future, so
  /// several page widgets building at once cannot each kick off a duplicate
  /// decode of the ~0.7 MB asset.
  Future<void> ensureLoaded(String assetPath) {
    if (assetPath.isEmpty || _byAsset.containsKey(assetPath)) {
      return Future.value();
    }
    return _loading[assetPath] ??= _load(assetPath);
  }

  Future<void> _load(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final pages = doc['pages'] as Map<String, dynamic>;
      final parsed = <int, List<AyahRegion>>{};
      for (final entry in pages.entries) {
        final page = int.tryParse(entry.key);
        if (page == null) continue;
        final regions = <AyahRegion>[];
        for (final item in entry.value as List<dynamic>) {
          final row = item as List<dynamic>;
          final rings = <List<Offset>>[];
          for (final ring in row[2] as List<dynamic>) {
            final pts = <Offset>[];
            for (final pt in ring as List<dynamic>) {
              final p = pt as List<dynamic>;
              pts.add(Offset(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ));
            }
            if (pts.length >= 3) rings.add(pts);
          }
          if (rings.isEmpty) continue;
          regions.add(AyahRegion(row[0] as int, row[1] as int, rings));
        }
        // The line grid is a property of the PAGE, so it can only be built
        // once every ayah on it has been read — an ayah alone does not carry
        // enough edges to say where the lines are.
        final grid = PageLineGrid.fromRings(
          regions.expand((r) => r.rings),
        );
        parsed[page] = [for (final r in regions) r.withGrid(grid)];
      }
      _byAsset[assetPath] = parsed;
    } finally {
      _loading.remove(assetPath);
    }
  }

  List<AyahRegion> regionsForPage(String assetPath, int page) =>
      _byAsset[assetPath]?[page] ?? const [];

  /// The ayah under a normalized tap point, or null when the tap lands in a
  /// margin, a surah header, or between lines.
  ///
  /// [nx]/[ny] are already in the polygon layer's own space — a printing that
  /// borrows the layer maps the tap back with `AyahPolygonFit.invert` first,
  /// which is one multiply instead of transforming every polygon on the page.
  AyahRegion? hitTest(String assetPath, int page, double nx, double ny) {
    for (final region in regionsForPage(assetPath, page)) {
      if (region.contains(nx, ny)) return region;
    }
    return null;
  }
}
