import 'dart:convert';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/services.dart' show rootBundle;

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

  const AyahRegion._(this.surah, this.ayah, this.rings, this.bounds);

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

/// Real ayah tap regions for the mushaf pages.
///
/// Source: the `ayahPolygon` hit layer shipped inside the quranpedia/quran-svg
/// pages (CC0-1.0), rebuilt by `scripts/build_mushaf_svg.py` into normalized
/// page space. Coverage is verified against the bundled `quran_local.db`:
/// 6,236 / 6,236 ayahs. Nothing here is estimated or hand-drawn.
class AyahCoordsRepository {
  AyahCoordsRepository._();
  static final AyahCoordsRepository instance = AyahCoordsRepository._();

  static const String assetPath =
      'assets/data/mushaf/hafs_kfqc_polygons.json';

  final Map<int, List<AyahRegion>> _byPage = {};
  Future<void>? _loading;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Parses the polygon asset once. Concurrent callers share one future, so
  /// several page widgets building at the same time cannot each kick off a
  /// duplicate decode of the ~0.7 MB asset.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final pages = doc['pages'] as Map<String, dynamic>;
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
        _byPage[page] = regions;
      }
      _loaded = true;
    } finally {
      _loading = null;
    }
  }

  List<AyahRegion> regionsForPage(int page) => _byPage[page] ?? const [];

  /// The ayah under a normalized tap point, or null when the tap lands in a
  /// margin, a surah header, or between lines.
  AyahRegion? hitTest(int page, double nx, double ny) {
    for (final region in regionsForPage(page)) {
      if (region.contains(nx, ny)) return region;
    }
    return null;
  }

  /// First page carrying the given ayah, or null when it is not indexed.
  int? pageOf(int surah, int ayah) {
    for (final entry in _byPage.entries) {
      for (final r in entry.value) {
        if (r.surah == surah && r.ayah == ayah) return entry.key;
      }
    }
    return null;
  }
}
