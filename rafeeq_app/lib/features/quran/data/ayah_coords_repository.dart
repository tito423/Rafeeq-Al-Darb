import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One ayah's rectangle on a mushaf page (normalized 0..1 over the page image).
class AyahRect {
  final int surah;
  final int ayah;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const AyahRect(this.surah, this.ayah, this.x1, this.y1, this.x2, this.y2);

  bool contains(double nx, double ny) =>
      nx >= x1 && nx <= x2 && ny >= y1 && ny <= y2;
}

/// Real ayah coordinates for the mushaf page images.
///
/// Data source: the official quran.com QCF `glyph_ayah_bbox` database
/// (https://github.com/quran/quran.com-images) — each glyph cluster's pixel
/// box joined to its (surah, ayah) and rebuilt in `scripts/build_ayah_coords.py`.
/// Nothing here is fabricated.
class AyahCoordsRepository {
  AyahCoordsRepository._();
  static final AyahCoordsRepository instance = AyahCoordsRepository._();

  final Map<int, List<AyahRect>> _byPage = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/ayah_coords.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final pages = json['pages'] as Map<String, dynamic>;
    for (final entry in pages.entries) {
      final page = int.parse(entry.key);
      final rects = <AyahRect>[];
      for (final r in entry.value as List<dynamic>) {
        final v = r as List<dynamic>;
        rects.add(AyahRect(
          v[0] as int,
          v[1] as int,
          (v[2] as num).toDouble(),
          (v[3] as num).toDouble(),
          (v[4] as num).toDouble(),
          (v[5] as num).toDouble(),
        ));
      }
      _byPage[page] = rects;
    }
    _loaded = true;
  }

  List<AyahRect> rectsForPage(int page) => _byPage[page] ?? const [];

  /// Returns the ayah rectangle whose box contains the normalized tap point,
  /// or null when the tap falls outside every ayah.
  AyahRect? hitTest(int page, double nx, double ny) {
    final rects = _byPage[page];
    if (rects == null) return null;
    for (final r in rects) {
      if (r.contains(nx, ny)) return r;
    }
    return null;
  }
}