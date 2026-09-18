/// «كاني ماسك مصحف حقيقي واقلب بيه» — the page turns on its spine.
///
/// WHAT THIS IS. A `PageView` slides its children sideways; a book does not.
/// This wraps each page in a perspective rotation about the edge the reader
/// is turning from, so the leaving page swings away like paper and the
/// arriving one swings in behind it.
///
/// IT IS NOT A PAGE CURL, and the difference is deliberate rather than a
/// shortcut. A true curl needs the page rasterised into a texture and bent
/// along a cylinder every frame; on a 604-page mushaf whose pages are live
/// SVG or justified Arabic text, that means a repaint of the whole page on
/// every frame of every turn. A rotation about the spine reads as a book to
/// the eye, costs one `Transform` in the paint phase, and — the reason that
/// matters here — leaves the text a real widget, so an ayah stays tappable
/// and selectable right through the animation.
///
/// RTL IS NOT AN AFTERTHOUGHT. A mushaf is bound on the right: turning
/// forward swings the page away to the RIGHT, the mirror of an English book.
/// The hinge therefore sits on the trailing edge under RTL and the leading
/// one under LTR, and the sign of the rotation flips with it. Getting this
/// backwards would have produced an animation that is smooth, plausible and
/// the wrong way round — the kind of wrong that is easy to ship.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/page_turn_provider.dart';

/// How the mushaf moves from one page to the next.
enum PageTurnStyle {
  /// The `PageView`'s own horizontal slide. Unchanged behaviour, and still
  /// the right choice on a slow device or for a reader who finds motion
  /// distracting.
  slide,

  /// Rotates about the spine, like paper.
  book;

  static PageTurnStyle fromName(String? n) => PageTurnStyle.values.firstWhere(
    (v) => v.name == n,
    orElse: () => PageTurnStyle.book,
  );
}

/// Wraps one page of a `PageView` in the turn.
///
/// [offset] is the page's distance from the viewport centre in pages: 0 when
/// it fills the screen, −1 when it is one page behind, +1 one page ahead. It
/// is derived from the controller rather than from an `AnimationController`,
/// so the page follows the reader's thumb exactly — drag half way and the
/// paper stands half open, let go and it completes or falls back with the
/// `PageView`'s own physics.
class PageTurn extends StatelessWidget {
  final double offset;
  final Widget child;

  /// True when the app is laid out right-to-left, i.e. the book is bound on
  /// the right and turns the other way.
  final bool rtl;

  const PageTurn({
    super.key,
    required this.offset,
    required this.rtl,
    required this.child,
  });

  /// Past this the page is edge-on and contributes nothing but cost.
  static const double _maxTurn = math.pi / 2;

  @override
  Widget build(BuildContext context) {
    // ONE TREE SHAPE, ALWAYS. This used to `return child` at rest and a
    // `Transform` while turning. Swapping the widget type at that slot makes
    // Flutter throw the whole page subtree away and build it again, so the
    // page REMOUNTED at the end of every turn — `MushafPageView` started a
    // fresh load and showed «جارٍ تحميل الصفحة» for a frame. That was the
    // flicker in the owner's video. An identity transform costs nothing.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    // Portrait only — «خليه في الوضع العمودي بس». On its side the page is
    // laid out at full width and scrolls, and a turn about a 900-px spine
    // is not a book any more.
    final turning = !landscape && offset.abs() >= 0.001 && offset.abs() <= 1;

    // The page being turned AWAY is the one the reader is leaving, i.e. the
    // one with a negative offset in LTR. Clamped so a fling that overshoots
    // cannot invert the paper.
    final t = offset.clamp(-1.0, 1.0);
    final angle = turning ? t * _maxTurn * (rtl ? 1 : -1) : 0.0;

    // Perspective scaled to the page's own width. A fixed 0.0012 puts the
    // eye 833 px away: fine for a 400-px phone, but a page wider than that
    // swings its far edge THROUGH the eye at 90° and the projection inverts —
    // the black shards in the landscape half of the owner's video.
    final depth = 0.48 / math.max(size.width, 1);

    return Transform(
      alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, turning ? depth : 0.0)
        ..rotateY(angle),
      // Opaque while it turns. The mushaf page is drawn as ink on a
      // transparent ground, so the page arriving behind showed straight
      // through the one leaving — two pages of script on top of each other.
      child: ColoredBox(
        color: turning ? _paper(context) : Colors.transparent,
        child: child,
      ),
    );
  }

  static Color _paper(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    return (bg.a >= 1 ? bg : theme.colorScheme.surface).withValues(alpha: 1);
  }
}

/// [PageTurn] driven by a live `PageController`.
///
/// The offset is read off the controller on every frame rather than from an
/// `AnimationController`, so the paper follows the reader's thumb: drag half
/// way and it stands half open, let go and it completes or falls back with
/// the `PageView`'s own physics. A canned animation cannot do that.
///
/// It lives here rather than in `quran_screen.dart` because it is all about
/// the turn and nothing about the screen — and because that screen is
/// grandfathered at 1,047 lines and may not grow.
/// It reads the style and the text direction itself rather than taking them
/// as parameters: both are ambient, and threading them through the call site
/// only made `quran_screen.dart` longer for no one's benefit.
class TurningPage extends ConsumerWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const TurningPage({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(pageTurnProvider) == PageTurnStyle.slide) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, c) {
        // `page` is null until the controller has a viewport — the very
        // first frame — so fall back to where it started rather than
        // snapping every page to 0.
        final at = controller.hasClients && controller.page != null
            ? controller.page!
            : controller.initialPage.toDouble();
        return PageTurn(offset: index - at, rtl: rtl, child: c!);
      },
    );
  }
}
