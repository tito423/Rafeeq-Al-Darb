import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/mushaf_edition.dart';
import 'quran_book_cover_thumbnail.dart';

/// A real page-image thumbnail for a mushaf edition, showing the actual first
/// page of that edition (e.g. the Fatiha) instead of a generic icon.
///
/// - For the bundled default edition (`hafs_kfqc`): loads instantly from
///   `assets/mushaf/hafs_kfqc/001.svg`.
/// - For other SVG editions: loads from the network via [MushafPageService].
/// - For raster editions (Tajweed): uses [CachedNetworkImage] with the
///   edition's own image URL.
///
/// While loading (or on error), falls back to the existing
/// [QuranBookCoverThumbnail] luxury leather cover so the tile never looks
/// broken.
class MushafPageThumbnail extends StatefulWidget {
  final MushafEdition edition;

  /// Width in logical px. Height follows a 3:4 page ratio.
  final double width;

  /// Which page to preview (1-indexed). Defaults to 1 (Fatiha).
  final int page;

  const MushafPageThumbnail({
    super.key,
    required this.edition,
    this.width = 52,
    this.page = 1,
  });

  @override
  State<MushafPageThumbnail> createState() => _MushafPageThumbnailState();
}

class _MushafPageThumbnailState extends State<MushafPageThumbnail> {
  late Future<String?> _svgFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.edition.isRaster) {
      _svgFuture = _loadSvg();
    }
  }

  @override
  void didUpdateWidget(covariant MushafPageThumbnail old) {
    super.didUpdateWidget(old);
    if (old.edition.id != widget.edition.id || old.page != widget.page) {
      if (!widget.edition.isRaster) {
        _svgFuture = _loadSvg();
      }
    }
  }

  Future<String?> _loadSvg() async {
    try {
      return await MushafPageService.instance.svgForPage(
        editionId: widget.edition.id,
        sourcePath: widget.edition.sourcePath,
        page: widget.page,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * 4 / 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.paperDark : AppColors.ink;

    // Fallback: the existing luxury leather cover.
    final fallback = QuranBookCoverThumbnail(
      edition: widget.edition,
      width: widget.width,
    );

    if (widget.edition.isRaster) {
      return _RasterThumb(
        edition: widget.edition,
        page: widget.page,
        width: widget.width,
        height: height,
        fallback: fallback,
      );
    }

    return FutureBuilder<String?>(
      future: _svgFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || snap.data == null) {
          return fallback;
        }
        return Container(
          width: widget.width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppColors.nightSurface : AppColors.paper,
            borderRadius: BorderRadius.circular(widget.width * 0.06),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: widget.width * 0.1,
                offset: Offset(0, widget.width * 0.04),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SvgPicture.string(
            snap.data!,
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
          ),
        );
      },
    );
  }
}

/// Raster (scan) thumbnail — streams the JPG page image with a placeholder
/// leather cover until it loads.
class _RasterThumb extends StatelessWidget {
  final MushafEdition edition;
  final int page;
  final double width;
  final double height;
  final Widget fallback;

  const _RasterThumb({
    required this.edition,
    required this.page,
    required this.width,
    required this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.06),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: width * 0.1,
            offset: Offset(0, width * 0.04),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: edition.imagePageUrl(page),
        fit: BoxFit.cover,
        memCacheWidth: (width * 2).round(),
        placeholder: (_, _) => SizedBox(width: width, height: height, child: fallback),
        errorWidget: (_, _, _) => SizedBox(width: width, height: height, child: fallback),
      ),
    );
  }
}
