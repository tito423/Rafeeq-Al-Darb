import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/services/mushaf_page_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/mushaf_edition.dart';

/// Renders page 1 of a mushaf edition, small — the real "cover thumbnail"
/// P3‑28 asked for on every edition card, satisfied honestly: this is the
/// edition's own actual first page (already-licensed content, the exact
/// same KFQC page-render pipeline the reader itself pages through — see
/// `editions.json`'s `license` field), not a separately-sourced cover image
/// that would need its own licensing pass. Falls back to a neutral
/// placeholder while loading or when the page can't be fetched, so every
/// card stays usable offline.
///
/// Extracted from `MushafEditionSheet`'s own `_FirstPagePreview` (P3‑39) so
/// `MushafDownloadTile` — used by both the onboarding picker and the
/// Downloads screen's Mushafs tab — gets the same real thumbnail instead
/// of a second, thinner copy of this widget.
class MushafFirstPagePreview extends StatelessWidget {
  final MushafEdition edition;
  final bool isDark;
  final double width;
  final double height;

  const MushafFirstPagePreview({
    super.key,
    required this.edition,
    required this.isDark,
    this.width = 62,
    this.height = 62 * 550 / 345,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        color: isDark ? AppColors.nightSurface : AppColors.paper,
        child: FutureBuilder<String>(
          future: MushafPageService.instance.svgForPage(
            editionId: edition.id,
            sourcePath: edition.sourcePath,
            page: 1,
          ),
          builder: (context, snap) {
            if (snap.hasData) {
              return SvgPicture.string(
                snap.data!,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  isDark ? AppColors.paperDark : AppColors.ink,
                  BlendMode.srcIn,
                ),
              );
            }
            return Center(
              child: snap.hasError
                  ? Icon(Icons.menu_book_outlined,
                      size: 22, color: gold.withValues(alpha: 0.6))
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            );
          },
        ),
      ),
    );
  }
}
