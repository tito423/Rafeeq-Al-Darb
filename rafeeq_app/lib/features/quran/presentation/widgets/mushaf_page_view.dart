import '../../../../core/widgets/mirrored_network_image.dart';
import '../../data/inked_svg.dart';
import '../../data/mushaf_paper_provider.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart' show RenderingStrategy;

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/ayah_coords_repository.dart';
import '../../data/mushaf_edition.dart';
import '../../data/quran_zoom_provider.dart';

/// One mushaf page: the authentic KFQC page as vector art, with the real ayah
/// polygons layered on top for tap and highlight.
///
/// Vector rather than a raster scan buys three things at once: the page stays
/// sharp at any zoom, the glyph colour can follow the app theme (so night mode
/// is a real night mode rather than a white sheet), and the ayah regions come
/// from the very same file the page is drawn from, so a highlight can never
/// drift out of alignment with the text.
class MushafPageView extends ConsumerStatefulWidget {
  final MushafEdition edition;
  final int page;
  final AyahRegion? highlight;
  /// A long press on a verse: select it and open its card.
  final void Function(AyahRegion region) onAyahLongPress;
  final VoidCallback? onLoadFailed;

  /// A tap anywhere on the page, verse or not. «ضغطة واحدة خفيفة على الصفحة
  /// في أي مكان أو آية = ملء الشاشة أو خروج منه» — the reader toggles full
  /// screen with it; the verse card is the long press.
  final VoidCallback? onBackgroundTap;

  const MushafPageView({
    super.key,
    required this.edition,
    required this.page,
    required this.highlight,
    required this.onAyahLongPress,
    this.onLoadFailed,
    this.onBackgroundTap,
  });

  @override
  ConsumerState<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends ConsumerState<MushafPageView> {
  /// Every KFQC page shares this box, so the aspect ratio is constant even
  /// though a few pages carry a shifted viewBox origin.
  static const double _pageAspect = 345.0 / 550.0;

  final TransformationController _transform = TransformationController();
  final AyahCoordsRepository _coords = AyahCoordsRepository.instance;

  late Future<String> _ready;

  /// The last few pages' SVG, so a page the `PageView` builds again — the
  /// neighbour that appears the moment a turn begins — paints on its first
  /// frame instead of showing «جارٍ تحميل الصفحة» while a Future that is
  /// already answered resolves. That one frame of spinner, on every turn,
  /// was part of the flicker the owner filmed.
  static final Map<String, String> _svgMemo = {};
  static const int _svgMemoMax = 8;
  String get _memoKey => '${widget.edition.id}/${widget.page}';

  /// Raster editions only: the on-disk scan if it's already cached (offline),
  /// else null → stream from the network with `cached_network_image`.
  late Future<File?> _rasterReady;

  Offset _doubleTapAt = Offset.zero;

  /// A tap on the page. «الرجوع للحجم الطبيعي بضغطة»: while the page is
  /// pinched in, one tap puts it back at its own size, and does NOT also
  /// toggle full screen — leaving the zoom is what the reader asked for, and
  /// hiding the toolbar at the same time would be a second, unasked answer.
  void _tap() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    widget.onBackgroundTap?.call();
  }

  /// Double tap: 2x around the finger, or back to the whole page.
  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const s = 2.0;
    final p = _doubleTapAt;
    _transform.value = Matrix4.diagonal3Values(s, s, 1)
      ..setTranslationRaw(-p.dx * (s - 1), -p.dy * (s - 1), 0);
  }

  /// True while the page is pinched in. Kept locally so the viewer can turn
  /// its own pan on and off, and mirrored into `quranPageZoomedProvider` so
  /// the `PageView` above can stop competing for the same drag.
  bool _zoomed = false;

  /// Reads the scale straight off the matrix on every frame of a pinch.
  /// A tolerance rather than `> 1`: the controller lands on 1.0000000002
  /// after a pinch-out, and a page that thinks it is still zoomed never
  /// gives the swipe back.
  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    ref.read(quranPageZoomedProvider.notifier).state = zoomed;
  }

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
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
      _zoomed = false;
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
    _transform.removeListener(_onTransform);
    // The page is leaving; whatever it last said about zoom is no longer
    // true, and a `PageView` left frozen because a disposed page said
    // «zoomed» is a mushaf that cannot be turned.
    if (_zoomed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(quranPageZoomedProvider.notifier).state = false;
      });
    }
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
      // «مفيش زوم في وضع الأورينتيشن … بحيث مش يتعارض مع حركة نص الصفحة
      // لفوق أو لتحت». At rest the page scrolls up and down as before and
      // the viewer only listens for a pinch or a double tap; once zoomed,
      // the scroll stands still and a drag pans the enlarged page, and the
      // PageView is frozen (quranPageZoomedProvider) so a pan never turns
      // the page. Double tap again, or pinch back out, to return.
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w / aspect;
          return GestureDetector(
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              panEnabled: _zoomed,
              minScale: 1,
              maxScale: 4,
              child: SingleChildScrollView(
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: SizedBox(width: w, height: h, child: build(w, h)),
              ),
            ),
          );
        },
      );
    }
    return ClipRect(
      child: InteractiveViewer(
        transformationController: _transform,
        // PAN ONLY WHILE ZOOMED. At rest the `PageView` above owns the
        // horizontal drag outright, so a swipe starts turning the page on
        // the first frame instead of after the gesture arena has resolved —
        // which is the «تحسها تقيلة» the owner reported. Zoomed in, the pan
        // is the point, and `QuranScreen` freezes the `PageView` instead.
        panEnabled: _zoomed,
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
    final key = _memoKey;
    await _coords.ensureLoaded(widget.edition.polygonsAsset);
    final svg = await MushafPageService.instance.svgForPage(
      editionId: widget.edition.id,
      sourcePath: widget.edition.sourcePath,
      page: widget.page,
    );
    _svgMemo.remove(key);
    _svgMemo[key] = svg;
    while (_svgMemo.length > _svgMemoMax) {
      _svgMemo.remove(_svgMemo.keys.first);
    }
    return svg;
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
    final paper = ref.watch(mushafPaperProvider);
    // The page's own ground under warm paper and night — the whole viewport,
    // so the letterbox around a scan is the page's colour and not the app's,
    // and a page turning over another is opaque (see `PageTurn`).
    final ground = widget.edition.darkPage
        ? null
        : switch (paper) {
            MushafPaper.normal => const Color(0xFFFFFFFF),
            MushafPaper.warm => warmPaper,
            MushafPaper.night => nightPaper,
          };
    final page = _buildPage(context, paper);
    return ground == null
        ? page
        : ColoredBox(color: ground, child: SizedBox.expand(child: page));
  }

  Widget _buildPage(BuildContext context, MushafPaper paper) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.edition.isRaster) return _buildRaster(theme, paper);

    // The mushaf glyphs are monochrome, so a single srcIn recolour carries the
    // whole page into the active theme — or into warm paper or night.
    final ink = switch (paper) {
      MushafPaper.warm => warmInk,
      MushafPaper.night => nightInk,
      MushafPaper.normal => isDark ? AppColors.paperDark : AppColors.ink,
    };

    return FutureBuilder<String>(
      future: _ready,
      key: ValueKey(_memoKey),
      initialData: _svgMemo[_memoKey],
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
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
            onTap: _tap,
            onLongPressStart: (d) => _handleLongPress(d.localPosition, w, h),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.string(
                  inkedSvg(svg, ink),
                  fit: BoxFit.fill,
                  // Drawn ONCE into an image at the page's own size, then
                  // that image is shown - never the vector paths redrawn
                  // at whatever size a zoom or a wide landscape screen asks
                  // for. Redrawn huge, Impeller dropped the words' paths
                  // and kept only the small ayah markers: reproduced on
                  // emulator-5554 by zooming page 316 two-fold, the same
                  // blank-where-text-was shape the owner photographed.
                  renderingStrategy: RenderingStrategy.raster,
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
  Widget _buildRaster(ThemeData theme, MushafPaper paper) {
    // `sizeOf`, not `MediaQuery.of`: the full query also carries the keyboard
    // inset, so every frame of a keyboard sliding up (the «الانتقال إلى»
    // field) rebuilt and re-decoded the page behind the dialog — the flicker
    // the owner filmed.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memCacheWidth =
        (MediaQuery.sizeOf(context).width * dpr).clamp(360, 1400).round();

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
        // Night and warm paper recolour the scan AS IT IS DRAWN - the filter
        // rides on the image's own paint (`DecorationImage.colorFilter`) - and
        // not through a `ColorFiltered` layer over it. A layer is an offscreen
        // pass with bounds the renderer computes, and a wrong bound is what
        // cut words off a Hafs page on the owner's phone (see `inkedSvg`).
        final filter = scanFilter(paper, darkPage: widget.edition.darkPage);
        Widget painted(ImageProvider provider) => DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: provider,
                  fit: BoxFit.contain,
                  colorFilter: filter,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              child: const SizedBox.expand(),
            );

        Widget image = localFile != null
            ? painted(ResizeImage(FileImage(localFile), width: memCacheWidth))
            : MirroredNetworkImage(
                url: widget.edition.imagePageUrl(widget.page),
                fit: BoxFit.contain,
                memCacheWidth: memCacheWidth,
                imageBuilder: (_, provider) => painted(provider),
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
              onTap: _tap,
              onLongPressStart: (d) => _handleLongPress(d.localPosition, w, h),
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
          onTap: _tap,
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
            // See the vector branch above: pan only while zoomed, so the
            // `PageView` is not fighting the viewer for every swipe.
            panEnabled: _zoomed,
            minScale: 1,
            maxScale: 5,
            child: tappable,
          ),
        );
      },
    );
  }

  void _handleLongPress(Offset local, double width, double height) {
    if (width <= 0 || height <= 0) return;
    final nx = local.dx / width;
    final ny = local.dy / height;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return;
    final fit = widget.edition.fitForPage(widget.page);
    final p = fit == null ? Offset(nx, ny) : fit.invert(nx, ny);
    final hit = _coords.hitTest(
        widget.edition.polygonsAsset, widget.page, p.dx, p.dy);
    if (hit != null) widget.onAyahLongPress(hit);
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
