import 'dart:math' as math;

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

class _ToolbarActionState extends State<ToolbarAction>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  /// «اعملي أنيميشن جميل في شكل أيقونات خيارات القرآن». A tap gives the icon
  /// a short springy wiggle; a change of icon (play → stop, the layout that
  /// comes next) turns the old one out and the new one in.
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.active ? AppColors.gold : scheme.onSurface;
    // Focusable, and OK on a remote presses it (TV): the mushaf's whole
    // toolbar is made of these, and a bare GestureDetector takes no focus.
    void press() {
      _wiggle.forward(from: 0);
      widget.onPressed();
    }

    final child = FocusableActionDetector(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            press();
            return null;
          },
        ),
      },
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: press,
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: Duration(milliseconds: _pressed ? 110 : 420),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.active
                ? AppColors.gold.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // «خليها شكلها جميلة احترافية»: in the captioned form the icon
              // sits in the same round gold badge as the settings sections —
              // tinted at rest, filled when active — so the app has one look.
              // 28 + 3 + caption + 8 of padding stays inside [captionedHeight].
              _Badge(
                enabled: !widget.compact,
                active: widget.active,
                child: AnimatedBuilder(
                  animation: _wiggle,
                  builder: (context, icon) {
                    final t = _wiggle.value;
                    final decay = 1 - t;
                    return Transform.rotate(
                      angle: math.sin(t * math.pi * 3) * 0.28 * decay,
                      child: Transform.scale(
                        scale: 1 + 0.22 * math.sin(t * math.pi) * decay,
                        child: icon,
                      ),
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween<double>(begin: -0.25, end: 0).animate(anim),
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Icon(
                      widget.icon,
                      key: ValueKey(widget.icon.codePoint),
                      size: widget.compact ? 24 : 18,
                      color: widget.compact
                          ? color
                          : (widget.active ? Colors.white : AppColors.gold),
                    ),
                  ),
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.active
                        ? AppColors.gold
                        : scheme.onSurfaceVariant,
                    fontWeight: widget.active
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
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

class _Badge extends StatelessWidget {
  final bool enabled;
  final bool active;
  final Widget child;
  const _Badge({
    required this.enabled,
    required this.active,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFE2C15A), AppColors.gold],
              )
            : null,
        color: active ? null : AppColors.gold.withValues(alpha: 0.13),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}
