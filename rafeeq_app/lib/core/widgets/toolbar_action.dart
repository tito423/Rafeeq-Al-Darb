import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One toolbar action — icon + a short caption underneath, with a small
/// scale-down "press" animation instead of a plain flat `IconButton`.
/// [active] highlights it gold for a toggle-style action (e.g. "tashkeel
/// is currently shown", "this page is bookmarked") without needing a
/// second widget. Originally built for the Quran tab's toolbar (P3‑34),
/// pulled out to a shared location so `book_text_reader_screen.dart`
/// (P3‑29) can reuse the exact same look instead of a second copy.
///
/// [compact] drops the caption and shrinks the target, for the one place a
/// caption cannot be afforded: **landscape**. A phone in landscape is about
/// 393 logical pixels tall in total, and the captioned form needs 116 of them
/// for its two wrapped rows — which left the Qur'an text roughly 80 pixels to
/// live in, the defect the owner reported as «في الأورينتيشن المصاحف النصية مش
/// بتشتغل». In compact form the label moves to the tooltip: still reachable by
/// long-press and by a screen reader, just not spending vertical space that
/// the page needs more.
class ToolbarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool compact;

  const ToolbarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.compact = false,
  });

  /// Height this action occupies, so a `PreferredSize` can be derived from the
  /// same numbers the widget actually lays out with rather than guessed at.
  /// The guessed constant is what shipped, and it was wrong in landscape.
  static const double captionedHeight = 55;
  static const double compactHeight = 44;

  @override
  State<ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<ToolbarAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? AppColors.gold : scheme.onSurface;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.active
                ? AppColors.gold.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: widget.compact ? 24 : 22, color: color),
              if (!widget.compact) ...[
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        widget.active ? AppColors.gold : scheme.onSurfaceVariant,
                    fontWeight:
                        widget.active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    // The caption is the label in the normal form; in compact form the tooltip
    // is the only place it survives, so it is not optional there.
    return widget.compact
        ? Tooltip(message: widget.label, child: child)
        : child;
  }
}
