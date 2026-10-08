/// Makes room on the page for the floating controls, so they never sit on
/// a word of the Qur'an.
///
/// Owner, 2026-10-08, with a screen recording: when the controls came up in
/// full screen, the panel covered the page's first line, the app's bar the
/// last one, and the page-number badge sat on the line above it - in the
/// paper mushaf and the text one alike. Moving the bars could not fix it:
/// the panel is about twice as tall as the free margin above the page.
///
/// So the page itself gives way. While the controls are up, the whole page
/// shrinks smoothly into the band between the panel and the badge, and
/// grows back when they go. It is a scale, not a new layout: the text page
/// is not re-paginated, nothing reflows, nothing jumps - the page the
/// reader was on simply becomes a little smaller, whole, with every line
/// visible. A smaller page is also the safe direction for trap #48 (words
/// dropped from a page drawn too LARGE).
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/stable_insets.dart';

/// The panel's height, published by `MushafChrome` once it has laid out.
final chromePanelHeight = ValueNotifier<double>(0);

class ChromeFit extends StatelessWidget {
  /// Whether the controls are up.
  final bool active;

  /// Whether the page-number badge shows under the page with them.
  final bool badge;
  final Widget child;

  const ChromeFit({
    super.key,
    required this.active,
    required this.badge,
    required this.child,
  });

  /// The badge (40) and the gap under it (10), with a little air above it.
  static const _badgeBand = 56.0;

  @override
  Widget build(BuildContext context) {
    // The body's bottom padding grows by the app's bar while it floats over
    // the page (`extendBody`); the stable inset is what the page already
    // keeps clear, so only the difference is new.
    final under =
        (MediaQuery.paddingOf(context).bottom -
                stableSystemInsets(context).bottom)
            .clamp(0.0, double.infinity);
    return ValueListenableBuilder<double>(
      valueListenable: chromePanelHeight,
      builder: (context, panel, child) => LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          final top = panel + 6;
          final bottom = under + (badge ? _badgeBand : 6);
          final fit = h.isFinite && h > 0
              ? ((h - top - bottom) / h).clamp(0.55, 1.0)
              : 1.0;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: active && panel > 0 ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            // Clipped at the band's foot too: a page taller than the
            // screen (landscape, where the scale stops at [fit]'s floor)
            // would otherwise run on under the badge and the app's bar -
            // seen on emulator-5554 sideways, the badge on a line of text.
            builder: (context, t, page) => ClipRect(
              clipper: _Above(bottom * t),
              child: Transform.translate(
                offset: Offset(0, top * t),
                child: Transform.scale(
                  scale: 1 - (1 - fit) * t,
                  alignment: Alignment.topCenter,
                  child: page,
                ),
              ),
            ),
            child: child,
          );
        },
      ),
      child: child,
    );
  }
}

/// Everything but a strip of [bottom] pixels at the foot.
class _Above extends CustomClipper<Rect> {
  final double bottom;
  const _Above(this.bottom);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width, size.height - bottom);

  @override
  bool shouldReclip(_Above old) => old.bottom != bottom;
}
