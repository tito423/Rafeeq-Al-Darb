import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/hero_surface.dart';
import 'islamic_pattern.dart';

/// A card that opens as its own screen.
///
/// The problem this solves is a real one the owner hit: a card that expands
/// *in place* inside a scrolling page fights the page. It pushes everything
/// below it down, the scroll position jumps, the reader loses where they were,
/// and on a small screen the controls they just revealed are off-screen. The
/// carousel editor on Home and the clock gallery both did exactly that.
///
/// So an "expanded card" here is a route, not an inline `AnimatedSize`. It
/// floats above the page it came from — the page stays exactly where it was,
/// visible and blurred behind — and it is sized to its own content rather than
/// stretched to the full screen. It opens by scaling up out of nothing while
/// the backdrop blurs in behind it, and closes by reversing that, faster.
///
/// Every card screen in the app goes through this, so they all move the same
/// way. If the transition should change, it changes here once.
class CardRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;

  /// Where the card appears to grow from, in global coordinates — normally the
  /// centre of the widget that was tapped. The card scales out of that point,
  /// so the motion reads as "this card became that screen" instead of an
  /// unrelated dialog appearing in the middle. Null grows from centre.
  final Offset? origin;

  /// Honour the OS "remove animations" setting: no scale, no blur ramp, just a
  /// short fade. Decided at push time by [showCardScreen].
  final bool reduceMotion;

  CardRoute({
    required this.builder,
    this.origin,
    this.reduceMotion = false,
  });

  @override
  Color? get barrierColor => null; // painted in the transition, so it can blur

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration =>
      reduceMotion ? const Duration(milliseconds: 120) : const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? const Duration(milliseconds: 100) : const Duration(milliseconds: 280);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion) {
      return Container(
        color: Colors.black.withValues(alpha: 0.62 * animation.value),
        alignment: Alignment.center,
        child: FadeTransition(opacity: animation, child: child),
      );
    }

    // Opening and closing are deliberately not the same curve. Opening
    // overshoots slightly and settles (easeOutQuint reads as "arriving");
    // closing is a plain accelerating fall, because a card that bounces on its
    // way out feels indecisive.
    final opening = animation.status != AnimationStatus.reverse;
    final curved = CurvedAnimation(
      parent: animation,
      curve: opening ? Curves.easeOutQuint : Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final size = MediaQuery.sizeOf(context);

        // The card starts small at the tap point and travels to the centre.
        // `Alignment` wants -1..1 across the screen, so map the global origin
        // into that space; a null origin just starts at the centre.
        Alignment from = Alignment.center;
        if (origin != null && size.width > 0 && size.height > 0) {
          from = Alignment(
            (origin!.dx / size.width) * 2 - 1,
            (origin!.dy / size.height) * 2 - 1,
          );
        }
        final align = Alignment.lerp(from, Alignment.center, t)!;

        return Stack(
          children: [
            // Scrim + blur. The page behind stays legible but clearly
            // out of focus, which is what tells the reader it is still there
            // and they have not navigated away from it.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.58 * t),
                  ),
                ),
              ),
            ),
            Align(
              alignment: align,
              child: Transform.scale(
                scale: 0.78 + 0.22 * t,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Opens [child] as a card screen. See [CardRoute] for why this is a route.
///
/// [originContext] is the widget that was tapped; the card grows out of it.
/// Pass it whenever you have it — it is what makes the motion feel connected
/// to the tap rather than arbitrary.
Future<T?> showCardScreen<T>({
  required BuildContext context,
  required Widget child,
  BuildContext? originContext,
}) {
  Offset? origin;
  final box = originContext?.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    origin = box.localToGlobal(box.size.center(Offset.zero));
  }
  return Navigator.of(context).push(
    CardRoute<T>(
      builder: (_) => child,
      origin: origin,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    ),
  );
}

/// The card itself: a content-sized panel with an illuminated Islamic ground.
///
/// It is deliberately not a full-screen `Scaffold`. The owner asked for
/// «كارت حجمه مناسب للخيارات اللي فيه» — a card the size of what it holds —
/// so the body shrink-wraps and only starts scrolling once it would exceed
/// [maxHeightFraction] of the screen.
class CardScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tints the header, the border and the pattern. Normally the colour the
  /// caller already uses for this thing (a prayer's colour, a section's).
  final Color accent;
  final Widget child;

  /// Pinned under the scrolling body — for a primary action that must stay
  /// reachable however long the content is.
  final Widget? footer;

  final double maxWidth;
  final double maxHeightFraction;

  /// Whether the card scrolls its own body. True (the default) shrink-wraps
  /// the content and starts scrolling only once it would outgrow the card.
  ///
  /// Pass false when the child scrolls itself — a `TabBarView` over grids, for
  /// instance, needs a bounded height and cannot live inside a scroll view.
  /// The child is then given the leftover space and is responsible for it.
  final bool scrollable;

  const CardScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.accent = AppColors.primarySoft,
    this.footer,
    this.maxWidth = 480,
    this.maxHeightFraction = 0.86,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = media.size.height * maxHeightFraction;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: media.padding.vertical + 24,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      // Follows the theme, like the cards that open it.
                      Color.lerp(
                          HeroSurface.of(context).gradient.first, accent,
                          0.22)!,
                      HeroSurface.of(context).gradient.last,
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 40,
                      spreadRadius: -8,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // The same painted khātim lattice the rest of the app
                    // uses, so a card screen belongs to the app rather than
                    // looking like a system dialog dropped on top of it.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: IslamicPatternPainter(
                            tile: 58,
                            color: accent.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      // A self-scrolling child (a TabBarView over grids) has
                      // no intrinsic height, so `Flexible` can only bound it
                      // if the column fills the card. A shrink-wrapping body
                      // keeps `min`, which is what sizes the card to its
                      // content.
                      mainAxisSize:
                          scrollable ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        _CardHeader(
                          title: title,
                          subtitle: subtitle,
                          icon: icon,
                          accent: accent,
                        ),
                        Flexible(
                          child: scrollable
                              ? SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 18),
                                  child: child,
                                )
                              : child,
                        ),
                        if (footer != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: footer!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;

  const _CardHeader({
    required this.title,
    required this.accent,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(icon,
                  size: 20, color: HeroSurface.of(context).accent(accent)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: HeroSurface.of(context).onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: HeroSurface.of(context).onSurfaceFaint,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded,
                color: HeroSurface.of(context).onSurfaceMuted, size: 22),
          ),
        ],
      ),
    );
  }
}
