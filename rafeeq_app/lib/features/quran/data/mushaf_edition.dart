import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// Carries the Hafs/Madinah ayah polygons onto a printing that sets the *same*
/// line grid at a different scale and offset.
///
/// The KFQC vector edition ships the only real polygon layer this app has. A
/// scan that typesets the identical Madinah page differs from it by a uniform
/// scale plus an offset — its decorative border eats margin, nothing else
/// moves — so one axis-aligned affine per page group maps every polygon onto
/// it, and the scan gets real ayah highlighting and tap-to-sciences without a
/// coordinate layer of its own.
///
/// This is only legitimate where the layouts really do match, and that has to
/// be measured, not assumed. `scripts/fit_mushaf_polygon_transform.py` fits it
/// and then renders the mapped polygons over the real scans to be looked at.
/// For the Tajweed printing the fit lands every ring within a median 3.9 px of
/// its printed line on a page whose lines are 84 px apart. The other three
/// raster printings paginate their own way — `madinah_gold` sets 6 lines on
/// its page 2 where the Madinah mushaf sets 15 — and no transform can fix a
/// different typesetting, so they honestly ship with no polygon layer at all.
class AyahPolygonFit {
  /// x' = [sx] · x + [dx], y' = [sy] · y + [dy], both in normalized page space.
  final double sx;
  final double dx;
  final double sy;
  final double dy;

  /// Width / height of the scans in this page group, so the overlay can be
  /// drawn in a box of exactly the page's shape rather than guessing where
  /// `BoxFit.contain` put the image.
  final double pageAspect;

  const AyahPolygonFit({
    required this.sx,
    required this.dx,
    required this.sy,
    required this.dy,
    required this.pageAspect,
  });

  factory AyahPolygonFit.fromJson(Map<String, dynamic> j) => AyahPolygonFit(
        sx: (j['sx'] as num).toDouble(),
        dx: (j['dx'] as num).toDouble(),
        sy: (j['sy'] as num).toDouble(),
        dy: (j['dy'] as num).toDouble(),
        pageAspect: (j['page_aspect'] as num).toDouble(),
      );

  /// Hafs polygon space → this printing's page space.
  Offset apply(Offset p) => Offset(p.dx * sx + dx, p.dy * sy + dy);

  /// This printing's page space → Hafs polygon space. Used for hit testing:
  /// mapping the one tap point back is far cheaper than mapping every polygon
  /// on the page forward, and it is exact rather than approximately so.
  Offset invert(double nx, double ny) =>
      Offset((nx - dx) / sx, (ny - dy) / sy);
}

/// One printed mushaf the reader can choose.
///
/// Every edition ships its own ayah polygons, so tapping and highlighting work
/// the same in all of them. What differs is verse numbering: the bundled
/// sciences database (tafsir, i'rab, translations) is keyed to Hafs, which
/// Shu'bah matches exactly, while Warsh, Qalun and Duri split verses
/// differently in many surahs. [sciencesAvailableFor] is what keeps the app
/// from confidently showing the wrong commentary in those surahs.
class MushafEdition {
  final String id;

  /// Upstream folder for the vector (SVG) editions, e.g. 'hafs/kfqc'.
  /// Unused (empty) for raster editions — see [imagePath].
  final String sourcePath;

  final String nameAr;
  final String nameEn;
  final String riwayahAr;
  final String riwayahEn;

  /// Ayah-polygon asset. Empty for a printing with no hit layer, and then
  /// tap-to-highlight and the sciences sheet do not apply to it.
  ///
  /// A raster edition can share the vector edition's asset when it sets the
  /// same page — the Tajweed printing does — in which case [polygonFit] says
  /// how to map it. Several editions naming the same asset parse it once:
  /// [AyahCoordsRepository] is keyed by the asset path, not by edition id.
  final String polygonsAsset;

  /// How [polygonsAsset] maps onto this printing, when it is not this
  /// printing's own layer. Null for an edition whose polygons are its own
  /// (the vector edition) or which has none at all.
  final AyahPolygonFit? polygonFit;

  /// Pages that need their own fit because they are set differently from the
  /// rest of the printing — the Tajweed mushaf's two illuminated opening
  /// pages carry a different frame, a different text block and a different
  /// pixel size from the 602 body pages.
  final Map<int, AyahPolygonFit> polygonFitPages;

  /// P3‑53: raster (image-scan) editions — the folder under `mushaf/` on the
  /// R2 content bucket that holds `NNN.<ext>` page scans (e.g. 'tajweed').
  /// Null for the vector SVG editions. [isRaster] keys the whole
  /// render/download path off this one field.
  final String? imagePath;

  /// File extension of this edition's page scans, without the dot. Defaults
  /// to `jpg`; the Warsh/Qalun scans are palette PNGs (see
  /// [AppConfig.mushafImageUrl]) and set `"image_ext": "png"`.
  final String imageExt;

  /// Bundled JPEG of this edition's real cover (or title page), e.g.
  /// `assets/mushaf_covers/shamarly.jpg`. Empty when the edition has none, and
  /// [QuranBookCoverThumbnail] then falls back to its drawn leather board.
  final String coverAsset;

  final int pages;
  final int ayahs;

  /// True when this edition's verse numbering matches the sciences database
  /// for the whole mushaf.
  final bool sciencesAligned;

  /// Surahs whose numbering differs from the sciences database.
  final Set<int> divergingSurahs;

  final bool isDefault;

  /// Whether this printing uses the Madinah/Hafs 604-page layout that the
  /// bundled sciences DB's page->surah and page->juz mapping was built from.
  ///
  /// False for every printing that paginates its own way (Shamarly's 521
  /// pages, the Indo-Pak 564, and the Warsh/Qalun printings, whose 604 pages
  /// do not line up verse-for-verse with Hafs either). On those, that mapping
  /// would confidently name the wrong surah — page 521 of Shamarly is
  /// al-Ikhlas/al-Falaq/an-Nas, while Hafs page 521 is adh-Dhariyat — so the
  /// running header is hidden rather than shown wrong.
  final bool hafsPagination;

  const MushafEdition({
    required this.id,
    required this.sourcePath,
    required this.nameAr,
    required this.nameEn,
    required this.riwayahAr,
    required this.riwayahEn,
    required this.polygonsAsset,
    this.polygonFit,
    this.polygonFitPages = const {},
    required this.pages,
    required this.ayahs,
    required this.sciencesAligned,
    required this.divergingSurahs,
    required this.isDefault,
    this.hafsPagination = true,
    this.imagePath,
    this.imageExt = 'jpg',
    this.coverAsset = '',
  });

  factory MushafEdition.fromJson(Map<String, dynamic> j) {
    final fit = j['polygon_fit'] as Map<String, dynamic>?;
    return MushafEdition(
        id: j['id'] as String,
        sourcePath: j['source_path'] as String? ?? '',
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String,
        riwayahAr: j['riwayah_ar'] as String? ?? '',
        riwayahEn: j['riwayah_en'] as String? ?? '',
        polygonsAsset: j['polygons_asset'] as String? ?? '',
        polygonFit: fit == null
            ? null
            : AyahPolygonFit.fromJson(fit['default'] as Map<String, dynamic>),
        polygonFitPages: {
          for (final e in ((fit?['pages'] as Map<String, dynamic>?) ?? const {})
              .entries)
            int.parse(e.key):
                AyahPolygonFit.fromJson(e.value as Map<String, dynamic>)
        },
        imagePath: j['image_path'] as String?,
        imageExt: j['image_ext'] as String? ?? 'jpg',
        coverAsset: j['cover_asset'] as String? ?? '',
        pages: j['pages'] as int,
        ayahs: j['ayahs'] as int,
        sciencesAligned: j['sciences_aligned'] as bool? ?? false,
        divergingSurahs: {
          for (final s in (j['diverging_surahs'] as List<dynamic>? ?? const []))
            s as int
        },
        isDefault: j['is_default'] as bool? ?? false,
        hafsPagination: j['hafs_pagination'] as bool? ?? true,
      );
  }

  /// A raster (image-scan) edition — rendered from `NNN.jpg` page images
  /// rather than the vector SVG path. Says nothing about whether it has an
  /// ayah layer; [hasAyahLayer] does.
  bool get isRaster => imagePath != null && imagePath!.isNotEmpty;

  /// Whether this printing can highlight an ayah and open the sciences sheet.
  /// True for the vector edition and for a scan that has been fitted to the
  /// Hafs polygons; false for a printing that paginates its own way.
  bool get hasAyahLayer => polygonsAsset.isNotEmpty;

  /// The transform for [page], or null when the polygons are already in this
  /// edition's own space.
  AyahPolygonFit? fitForPage(int page) =>
      polygonFitPages[page] ?? polygonFit;

  /// Whether tafsir / translation / i'rab can be trusted for this surah.
  /// Raster editions have no tappable ayah layer, so this is moot there.
  bool sciencesAvailableFor(int surah) =>
      sciencesAligned || !divergingSurahs.contains(surah);

  String pageUrl(int page) => AppConfig.mushafPageUrl(sourcePath, page);

  /// The R2 URL for [page]'s scan (raster editions only).
  String imagePageUrl(int page) =>
      AppConfig.mushafImageUrl(imagePath!, page, ext: imageExt);
}

/// The editions bundled with the app, newest catalog wins.
final mushafEditionsProvider =
    FutureProvider<List<MushafEdition>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/mushaf/editions.json');
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final e in doc['editions'] as List<dynamic>)
      MushafEdition.fromJson(e as Map<String, dynamic>)
  ];
});

const _kSelectedEditionKey = 'mushaf.selected_edition';

/// The edition currently being read, persisted across launches.
class SelectedMushafEdition extends StateNotifier<String> {
  SelectedMushafEdition() : super(AppConfig.defaultMushafEdition) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kSelectedEditionKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> select(String editionId) async {
    if (editionId == state) return;
    state = editionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedEditionKey, editionId);
  }
}

final selectedMushafEditionProvider =
    StateNotifierProvider<SelectedMushafEdition, String>(
        (ref) => SelectedMushafEdition());

/// The resolved edition object, falling back to the default if the stored id
/// no longer exists (an edition can disappear between app versions).
final currentMushafEditionProvider =
    FutureProvider<MushafEdition>((ref) async {
  final editions = await ref.watch(mushafEditionsProvider.future);
  final id = ref.watch(selectedMushafEditionProvider);
  return editions.firstWhere(
    (e) => e.id == id,
    orElse: () => editions.firstWhere(
      (e) => e.isDefault,
      orElse: () => editions.first,
    ),
  );
});
