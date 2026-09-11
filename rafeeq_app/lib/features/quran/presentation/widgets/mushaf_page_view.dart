import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ayah_coords_repository.dart';
import '../../data/mushaf_edition.dart';

/// One mushaf page: the authentic KFQC page as vector art, with the real ayah
/// polygons layered on top for tap and highlight.
///
/// Vector rather than a raster scan buys three things at once: the page stays
/// sharp at any zoom, the glyph colour can follow the app theme (so night mode
/// is a real night mode rather than a white sheet), and the ayah regions come
/// from the very same file the page is drawn from, so a highlight can never
/// drift out of alignment with the text.
class MushafPageView extends StatefulWidget {
  final MushafEdition edition;
  final int page;
  final AyahRegion? highlight;
  final void Function(AyahRegion region) onAyahTap;
  final VoidCallback? onLoadFailed;

  /// P3‑43 #6: fires on a tap that didn't land on any real ayah polygon —
  /// the closest honest equivalent this mode has to `MushafTextPage`'s
  /// "background tap", since here every point on the page is a candidate
  /// ayah hit-test rather than there being a separate non-text area.
  /// Currently only used to exit full-screen mode.
  final VoidCallback? onBackgroundTap;

  const MushafPageView({
    super.key,
    required this.edition,
    required this.page,
    required this.highlight,
    required this.onAyahTap,
    this.onLoadFailed,
    this.onBackgroundTap,
  });

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  /// Every KFQC page shares this box, so the aspect ratio is constant even
  /// though a few pages carry a shifted viewBox origin.
  static const double _pageAspect = 345.0 / 550.0;

  final TransformationController _transform = TransformationController();
  final AyahCoordsRepository _coords = AyahCoordsRepository.instance;

  late Future<String> _ready;

  /// Raster editions only: the on-disk scan if it's already cached (offline),
  /// else null → stream from the network with `cached_network_image`.
  late Future<File?> _rasterReady;

  @override
  void initState() {
    super.initState();
    if (widget.edition.isRaster) {
      _rasterReady = _loadRaster();
    } else {
      _ready = _load();
    }
  }

  @override
  void didUpdateWidget(covariant MushafPageView old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page || old.edition.id != widget.edition.id) {
      _transform.value = Matrix4.identity();
      if (widget.edition.isRaster) {
        _rasterReady = _loadRaster();
      } else {
        _ready = _load();
      }
    }
  }

  /// A raster edition that borrows the Hafs polygon layer needs it parsed
  /// before the first highlight can be painted, exactly as the vector path
  /// does. `ensureLoaded` is a no-op for a printing with no layer.
  Future<File?> _loadRaster() async {
    await _coords.ensureLoaded(widget.edition.polygonsAsset);
    return MushafPageService.instance.cachedImageFile(
        widget.edition.id, widget.page,
        ext: widget.edition.imageExt);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Lays one page out and calls [build] with the box it was drawn in, so the
  /// overlay and the tap arithmetic always use the same numbers as the pixels.
  ///
  /// Portrait fits the whole page on screen and lets the reader pinch into it.
  /// **Landscape does not, and must not.** A phone on its side leaves roughly
  /// 200 logical pixels of height under the toolbar; fitting a 0.63-ratio page
  /// into that draws it about 130 pixels wide in the middle of an empty
  /// screen, which is the photograph the owner sent of pages 4 and 417. So
  /// landscape lays the page out at the **full width** of the screen and
  /// scrolls it vertically.
  ///
  /// The cost, stated rather than hidden: pinch-zoom is off in landscape. A
  /// vertical scroll and an `InteractiveViewer` cannot both own the drag, and
  /// full width is already the largest this page can be drawn — zooming past
  /// it is what portrait is for.
  ///
  /// NOTE, v3.16.0: the landscape branch is currently **unreachable** from the
  /// app, because `QuranScreen` locks the image mode to portrait — the owner's
  /// «خلي الاورينتيشن بس على النص». It is kept because that lock is a single
  /// list in `_applyOrientationLock`, and the day it changes this is what the
  /// page needs in order not to be drawn the size of a stamp again.
  Widget _stage({
    required double aspect,
    required Widget Function(double w, double h) build,
  }) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w / aspect;
          return SingleChildScrollView(
            child: SizedBox(width: w, height: h, child: build(w, h)),
          );
        },
      );
    }
    return ClipRect(
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  build(constraints.maxWidth, constraints.maxHeight),
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _load() async {
    await _coords.ensureLoaded(widget.edition.polygonsAsset);
    return MushafPageService.instance.svgForPage(
      editionId: widget.edition.id,
      sourcePath: widget.edition.sourcePath,
      page: widget.page,
    );
  }

  // A block body, not `=> _ready = _load()` — that arrow form returns the
  // assignment's value (a Future), and setState() asserts its callback must
  // return void. Pre-existing bug caught this session while chasing an
  // identical one in library_screen.dart: retrying a failed mushaf page
  // load would have thrown "setState() callback argument returned a Future."
  void _retry() => setState(() {
    _ready = _load();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.edition.isRaster) return _buildRaster(theme);

    // The mushaf glyphs are monochrome, so a single srcIn recolour carries the
    // whole page into the active theme.
    final ink = isDark ? AppColors.paperDark : AppColors.ink;

    return FutureBuilder<String>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _Centered(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('quran.loading_page'.tr()),
            ],
          );
        }
        if (snapshot.hasError) {
          return _Centered(
            children: [
              Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.outline),
              const SizedBox(height: 10),
              Text('errors.offline'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: _retry,
                    child: Text('common.retry'.tr()),
                  ),
                  if (widget.onLoadFailed != null)
                    TextButton(
                      onPressed: widget.onLoadFailed,
                      child: Text('quran.text_mode'.tr()),
                    ),
                ],
              ),
            ],
          );
        }

        final svg = snapshot.data!;
        return _stage(
          aspect: _pageAspect,
          build: (w, h) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _handleTap(d.localPosition, w, h),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.string(
                  svg,
                  fit: BoxFit.fill,
                  colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                  placeholderBuilder: (_) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                if (widget.highlight != null)
                  CustomPaint(
                    painter: _AyahHighlightPainter(
                      region: widget.highlight!,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Raster (scan) rendering: the finished coloured page as an image, disk-
  /// first for offline then streamed + cached from R2. A capped
  /// `memCacheWidth` keeps a ~1 MB JPEG from being decoded at full size into
  /// memory (P3‑53 perf).
  ///
  /// A printing that has been fitted to the Hafs polygon layer (the Tajweed
  /// mushaf) gets the same tap and highlight the vector edition has. Its image
  /// is laid out inside an [AspectRatio] of the page's own measured shape so
  /// the overlay box is exactly the drawn page — with `BoxFit.contain` alone
  /// the drawn rect depends on the surrounding box and the highlight would
  /// float free of the text. A printing with no layer keeps the plain centred
  /// image and a tap that only forwards to [onBackgroundTap].
  Widget _buildRaster(ThemeData theme) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memCacheWidth =
        (MediaQuery.of(context).size.width * dpr).clamp(360, 1400).round();

    return FutureBuilder<File?>(
      future: _rasterReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _Centered(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('quran.loading_page'.tr()),
            ],
          );
        }

        final localFile = snapshot.data;
        final Widget image = localFile != null
            ? Image.file(
                localFile,
                fit: BoxFit.contain,
                cacheWidth: memCacheWidth,
                gaplessPlayback: true,
              )
            : CachedNetworkImage(
                imageUrl: widget.edition.imagePageUrl(widget.page),
                fit: BoxFit.contain,
                memCacheWidth: memCacheWidth,
                placeholder: (_, _) => _Centered(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('quran.loading_page'.tr()),
                  ],
                ),
                errorWidget: (_, _, _) => _Centered(
                  children: [
                    Icon(Icons.cloud_off,
                        size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 10),
                    Text('errors.offline'.tr(), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: () => setState(() {
                        _rasterReady = _loadRaster();
                      }),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              );

        final fit = widget.edition.fitForPage(widget.page);
        if (fit != null) {
          return _stage(
            aspect: fit.pageAspect,
            build: (w, h) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _handleTap(d.localPosition, w, h),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (widget.highlight != null)
                    CustomPaint(
                      painter: _AyahHighlightPainter(
                        region: widget.highlight!,
                        fit: fit,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // A printing with no fitted layer — Shamarly, Indo-Pak, Nastaleeq —
        // paginates its own way, so there is nothing to overlay and nothing
        // whose aspect ratio we have measured. Landscape still has to fill the
        // width rather than shrink the page into the leftover height: giving
        // `Image` a width and no height makes it take its own picture's
        // ratio, which is the one thing here that is always right.
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final tappable = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onBackgroundTap?.call(),
          child: landscape
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: image,
                    ),
                  ),
                )
              : Center(child: image),
        );
        if (landscape) return tappable;
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            child: tappable,
          ),
        );
      },
    );
  }

  void _handleTap(Offset local, double width, double height) {
    if (width <= 0 || height <= 0) return;
    final nx = local.dx / width;
    final ny = local.dy / height;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return;
    final fit = widget.edition.fitForPage(widget.page);
    final p = fit == null ? Offset(nx, ny) : fit.invert(nx, ny);
    final hit = _coords.hitTest(
        widget.edition.polygonsAsset, widget.page, p.dx, p.dy);
    if (hit != null) {
      widget.onAyahTap(hit);
    } else {
      widget.onBackgroundTap?.call();
    }
  }
}

/// Marks the selected ayah one printed line at a time.
///
/// It draws [AyahRegion.highlightRects], not the tap rings. The rings are
/// sized for a forgiving tap: each spans a whole line pitch, and 9.3% of them
/// are a single rectangle covering several lines at once — filling those put a
/// slab over half the page. `ayah_highlight_rects.dart` carries the
/// measurement and the arithmetic that cuts them back to the lines.
class _AyahHighlightPainter extends CustomPainter {
  final AyahRegion region;

  /// Null when the polygons are already in this page's own space (the vector
  /// edition); set when a printing borrows the Hafs layer.
  final AyahPolygonFit? fit;

  const _AyahHighlightPainter({required this.region, this.fit});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.ayahHighlight;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.gold.withValues(alpha: 0.7);

    final f = fit;
    Offset at(Offset p) => f == null ? p : f.apply(p);

    // Each line is its own rounded mark. Drawing them as one path would let
    // two adjacent lines merge back into the slab this exists to avoid, and a
    // rounded corner reads as a marker pen rather than a selection box.
    for (final r in region.highlightRects) {
      final tl = at(r.topLeft);
      final br = at(r.bottomRight);
      final px = Rect.fromLTRB(
        tl.dx * size.width,
        tl.dy * size.height,
        br.dx * size.width,
        br.dy * size.height,
      );
      if (px.width <= 0 || px.height <= 0) continue;
      final rr = RRect.fromRectAndRadius(
        px,
        Radius.circular(math.min(4, px.height * 0.22)),
      );
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _AyahHighlightPainter old) =>
      old.region != region || old.fit != fit;
}

class _Centered extends StatelessWidget {
  final List<Widget> children;
  const _Centered({required this.children});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    ),
  );
}
