@Tags(['export'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/ayah_coords_repository.dart';
import 'package:rafeeq_app/features/quran/data/mushaf_edition.dart';

/// Writes build/hl/rects.json: for every edition with an ayah layer, every
/// page, every ayah, the highlight rectangles in the PAGE BOX's own 0..1
/// space - exactly what `_AyahHighlightPainter` draws (fit applied). Input
/// for scripts/audit_highlight.py, which lays them over the real scans.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export', () async {
    // EDITIONS lets the pipeline export the BORROWED layer (the editions.json
    // from before the per-printing maps) that build_printing_map.py takes its
    // first guess of the line grid from; OUT names the file.
    final env = Platform.environment;
    final doc = jsonDecode(File(env['EDITIONS'] ?? 'assets/data/mushaf/editions.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final eds = [
      for (final e in doc['editions'] as List)
        MushafEdition.fromJson(e as Map<String, dynamic>)
    ];
    final repo = AyahCoordsRepository.instance;
    final out = <String, Object>{};
    for (final e in eds) {
      if (!e.hasAyahLayer) continue;
      await repo.ensureLoaded(e.polygonsAsset);
      final pages = <String, Object>{};
      for (var p = 1; p <= 604; p++) {
        final f = e.fitForPage(p);
        if (e.isRaster && f == null) continue;
        Offset at(Offset o) => f == null ? o : f.apply(o);
        pages['$p'] = {
          'aspect': f?.pageAspect ?? 345 / 550,
          'ayahs': [
            for (final r in repo.regionsForPage(e.polygonsAsset, p))
              {
                's': r.surah,
                'a': r.ayah,
                'r': [
                  for (final q in r.highlightRects)
                    () {
                      final a = at(q.topLeft), b = at(q.bottomRight);
                      return [a.dx, a.dy, b.dx, b.dy];
                    }()
                ],
              }
          ],
        };
      }
      out[e.id] = {
        'raster': e.isRaster,
        'url': e.isRaster ? e.imagePageUrl(1) : e.pageUrl(1),
        'pages': pages,
      };
    }
    Directory('build/hl').createSync(recursive: true);
    File(env['OUT'] ?? 'build/hl/rects.json').writeAsStringSync(jsonEncode(out));
  });
}
