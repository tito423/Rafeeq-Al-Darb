import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../data/ayah_coords_repository.dart';

/// Renders the real Madani page raster image with the official ayah
/// coordinate overlay (quran.com QCF data). Pinch-zoom + tap-an-ayah.
class MushafImagePage extends StatefulWidget {
  final int page;
  final AyahRect? highlight;
  final void Function(AyahRect rect) onAyahTap;
  final VoidCallback? onLoadFailed;

  const MushafImagePage({
    super.key,
    required this.page,
    required this.highlight,
    required this.onAyahTap,
    this.onLoadFailed,
  });

  @override
  State<MushafImagePage> createState() => _MushafImagePageState();
}

class _MushafImagePageState extends State<MushafImagePage> {
  final TransformationController _transform = TransformationController();
  final AyahCoordsRepository _coords = AyahCoordsRepository.instance;
  static const _imgW = 1242.0;
  static const _imgH = 1754.0;

  @override
  void initState() {
    super.initState();
    _coords.ensureLoaded();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = AppConfig.mushafImageUrl(widget.page);
    final rects = _coords.rectsForPage(widget.page);

    return CachedNetworkImage(
      imageUrl: url,
      maxWidthDiskCache: _imgW.round(),
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (c, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('quran.loading_page'.tr()),
          ],
        ),
      ),
      errorWidget: (c, _, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text('errors.offline'.tr()),
            if (widget.onLoadFailed != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onLoadFailed,
                child: Text('quran.text_mode'.tr()),
              ),
            ],
          ],
        ),
      ),
      imageBuilder: (context, imageProvider) {
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 0.8,
            maxScale: 4,
            alignment: Alignment.center,
            child: GestureDetector(
              onTapUp: (d) => _handleTap(d, imageProvider),
              child: SizedBox(
                // fitted to the page aspect ratio
                width: _imgW / 2,
                height: _imgH / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: imageProvider,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                    ...rects.map((r) {
                      // faint hover-style trim for every ayah (subtle),
                      // strong fill for the highlighted one.
                      final isSel = widget.highlight != null &&
                          widget.highlight!.surah == r.surah &&
                          widget.highlight!.ayah == r.ayah;
                      return Positioned(
                        left: r.x1 * _imgW / 2,
                        top: r.y1 * _imgH / 2,
                        width: (r.x2 - r.x1) * _imgW / 2,
                        height: (r.y2 - r.y1) * _imgH / 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: isSel
                                ? Border.all(
                                    color: Colors.amberAccent, width: 2)
                                : null,
                            color: isSel
                                ? Colors.amberAccent.withValues(alpha: 0.18)
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(TapUpDetails details, ImageProvider imageProvider) {
    // Map the viewport tap into the (scaled) child coordinate space.
    final scene = _transform.toScene(details.localPosition);
    if (scene.dx < 0 || scene.dy < 0) return;
    final nx = (scene.dx / (_imgW / 2)).clamp(0.0, 1.0);
    final ny = (scene.dy / (_imgH / 2)).clamp(0.0, 1.0);
    final hit = _coords.hitTest(widget.page, nx, ny);
    if (hit != null) widget.onAyahTap(hit);
  }
}