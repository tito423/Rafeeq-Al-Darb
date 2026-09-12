/// The scrubber that drags through all 604 pages at once.
library;


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.

/// P3‑43 #4/#5: replaces the old surah-name strip (P3‑8) *and* the ‹ ›
/// page-arrow buttons with one real drag-to-scrub scrollbar — the owner's
/// actual, twice-repeated ask ("my request was only fast scroll bar not
/// putting suras names", P3‑41; "delete the arrows, make scroll bar, when
/// I move it scroll quickly", this round). Dragging anywhere jumps
/// immediately (no animation — a scrub should feel instant, not
/// throttled by a 320ms page-turn tween), and the thumb tracks the real
/// current page live while dragging, not just on release.
///
/// **Direction: follows the app's own text direction.** P3‑43 originally
/// shipped this as a plain always-left-to-right value (matching every
/// other slider in the app) since there was no confirmed signal either
/// way. P3‑44's real-device round gave a direct one: real feedback asked
/// for RTL specifically "in arabic locale selection state" — so in an
/// RTL locale, page 1 now sits at the physical right (like a printed
/// Arabic mushaf's spine) and dragging left increases the page number;
/// in an LTR locale it stays the original plain left-to-right mapping.
class FastPageScrollBar extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const FastPageScrollBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  State<FastPageScrollBar> createState() => FastPageScrollBarState();
}

class FastPageScrollBarState extends State<FastPageScrollBar> {
  /// 0 = page 1 (physical left), 1 = page [totalPages] (physical right).
  /// Non-null only while a drag is actively in progress, so the thumb
  /// reflects the real `currentPage` (from the parent, once it's actually
  /// jumped) the rest of the time rather than a stale local guess.
  double? _dragFraction;

  /// `fraction` is always plain screen-space left(0)-to-right(1) — the RTL
  /// flip lives entirely in these two conversions, so `thumbX`/`Positioned`
  /// below never has to think about direction itself. Each must stay the
  /// exact inverse of the other for a given `isRtl`.
  double _fractionOf(int page, bool isRtl) {
    if (widget.totalPages <= 1) return isRtl ? 1.0 : 0.0;
    final t = (page - 1) / (widget.totalPages - 1);
    return isRtl ? 1 - t : t;
  }

  int _pageOf(double fraction, bool isRtl) {
    final t = isRtl ? 1 - fraction : fraction;
    return 1 + (t * (widget.totalPages - 1)).round();
  }

  void _handleDragAt(double dx, double width, bool isRtl) {
    final fraction = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = fraction);
    widget.onChanged(_pageOf(fraction, isRtl));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRtl = context.locale.languageCode == 'ar';
    final fraction = _dragFraction ?? _fractionOf(widget.currentPage, isRtl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbSize = 26.0;
        final thumbX = (fraction * width).clamp(
          thumbSize / 2,
          width - thumbSize / 2,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handleDragAt(d.localPosition.dx, width, isRtl),
          onHorizontalDragUpdate: (d) =>
              _handleDragAt(d.localPosition.dx, width, isRtl),
          onHorizontalDragEnd: (_) => setState(() => _dragFraction = null),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: thumbX - thumbSize / 2,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// P3‑34's `_ToolbarAction` moved to `core/widgets/toolbar_action.dart`
// (P3‑29) so `book_text_reader_screen.dart` can reuse the exact same
// widget instead of a second copy — see `ToolbarAction` there.


/// The Qur'an toolbar's two shapes.
///
/// Portrait keeps the captioned `Wrap` — every action visible at once, which
/// is what P3‑41's device feedback asked for. Landscape cannot afford it (see
/// the `bottom:` comment above), so the same actions become one compact,
/// horizontally-scrolling row.
///
/// The children arrive as ordinary [ToolbarAction]s and are rebuilt compact
/// here rather than each of the thirteen call sites having to pass a flag —
/// a flag that would then be possible to forget on the fourteenth.
