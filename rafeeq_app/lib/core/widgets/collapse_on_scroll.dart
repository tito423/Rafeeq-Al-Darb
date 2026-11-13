import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [header] over a [body] that slides away while the reader scrolls the
/// body down and comes back on the first scroll up (or at the top).
///
/// Owner, 2026-11-13, on the library: the strips above the lists «واكلة
/// الشاشة تماما» on a phone, sideways above all; on a big tablet they may
/// stay. So the header collapses only on a window whose short side is under
/// 600 dp (a phone, either way up); on a tablet it stays put.
///
/// It listens to the body's own scroll notifications rather than turning the
/// screen into one sliver list, so it works over a `TabBarView` of separate
/// lists without touching them. Horizontal scrolls (a tab swipe) are ignored.
class CollapseOnScroll extends StatefulWidget {
  final Widget header;
  final Widget body;

  const CollapseOnScroll({super.key, required this.header, required this.body});

  static bool collapsesOn(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < 600;

  @override
  State<CollapseOnScroll> createState() => _CollapseOnScrollState();
}

class _CollapseOnScrollState extends State<CollapseOnScroll> {
  bool _shown = true;

  void _show(bool v) {
    if (v != _shown) setState(() => _shown = v);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    // The direction first: a drag down from the very top reports `reverse`
    // while the list is still at 0, and the at-the-top rule below ate it
    // (seen on API 24 - the strips never left).
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) _show(false);
      if (n.direction == ScrollDirection.forward) _show(true);
    } else if (n is ScrollUpdateNotification &&
        n.metrics.pixels <= n.metrics.minScrollExtent) {
      _show(true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!CollapseOnScroll.collapsesOn(context)) {
      return Column(
        children: [
          widget.header,
          Expanded(child: widget.body),
        ],
      );
    }
    return Column(
      children: [
        ClipRect(
          child: AnimatedAlign(
            alignment: Alignment.bottomCenter,
            heightFactor: _shown ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: widget.header,
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.body,
          ),
        ),
      ],
    );
  }
}
