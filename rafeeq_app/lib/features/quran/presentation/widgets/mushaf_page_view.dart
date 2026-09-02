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

  const MushafPageView({
    super.key,
    required this.edition,
    required this.page,
    required this.highlight,
    required this.onAyahTap,
    this.onLoadFailed,
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

  @override
  void initState() {
    super.initState();
    _ready = _load();
  }

  @override
  void didUpdateWidget(covariant MushafPageView old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page || old.edition.id != widget.edition.id) {
      _transform.value = Matrix4.identity();
      _ready = _load();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<String> _load() async {
    await _coords.ensureLoaded(
        widget.edition.id, widget.edition.polygonsAsset);
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

    // The mushaf glyphs are monochrome, so a single srcIn recolour carries the
    // whole page into the active theme.
    final ink = isDark ? AppColors.paperDark : AppColors.ink;

    return FutureBuilder<String>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _Centered(children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('quran.loading_page'.tr()),
          ]);
        }
        if (snapshot.hasError) {
          return _Centered(children: [
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
          ]);
        }

        final svg = snapshot.data!;
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: _pageAspect,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _handleTap(d.localPosition, w, h),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SvgPicture.string(
                            svg,
                            fit: BoxFit.fill,
                            colorFilter:
                                ColorFilter.mode(ink, BlendMode.srcIn),
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
                    );
                  },
                ),
              ),
            ),
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
    final hit = _coords.hitTest(widget.edition.id, widget.page, nx, ny);
    if (hit != null) widget.onAyahTap(hit);
  }
}

/// Fills every fragment of the selected ayah. An ayah that wraps across lines
/// has one ring per line, so the highlight follows the text instead of
/// blanketing the rectangle that encloses it.
class _AyahHighlightPainter extends CustomPainter {
  final AyahRegion region;

  const _AyahHighlightPainter({required this.region});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.ayahHighlight;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.gold.withValues(alpha: 0.7);

    final path = Path();
    for (final ring in region.rings) {
      if (ring.length < 3) continue;
      path.moveTo(ring.first.dx * size.width, ring.first.dy * size.height);
      for (var i = 1; i < ring.length; i++) {
        path.lineTo(ring[i].dx * size.width, ring[i].dy * size.height);
      }
      path.close();
    }
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _AyahHighlightPainter old) =>
      old.region != region;
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
