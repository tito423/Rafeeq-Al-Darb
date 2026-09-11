import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// «وفّر في أي حاجة في التطبيق فيها اسكرولينج عمودي اسكرول بار عمودي في جنب
/// الشاشة، وسهم فوق في بدايته وسهم تحت في نهايته؛ لو سحبته يسحب ولو ضغط على
/// الأسهم تسحب لتحت أو فوق».
///
/// Installed once, as the app's scroll behaviour, so every vertical list and
/// page gets it without each screen remembering to — including ones written
/// after this. A horizontal list is left alone, and so is a list too short to
/// scroll or a viewport too small to hold the arrows (a dropdown menu).
class ArrowScrollBehavior extends MaterialScrollBehavior {
  const ArrowScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    return ArrowScrollbar(controller: details.controller, child: child);
  }
}

class ArrowScrollbar extends StatefulWidget {
  final ScrollController? controller;
  final Widget child;

  const ArrowScrollbar({super.key, required this.controller, required this.child});

  @override
  State<ArrowScrollbar> createState() => _ArrowScrollbarState();
}

class _ArrowScrollbarState extends State<ArrowScrollbar> {
  ScrollMetrics? _metrics;

  bool _remember(ScrollMetrics m) {
    final old = _metrics;
    if (old == null ||
        old.maxScrollExtent != m.maxScrollExtent ||
        old.viewportDimension != m.viewportDimension) {
      // Metrics arrive during layout; the rebuild waits for the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _metrics = m);
      });
    }
    return false;
  }

  ScrollPosition? get _position {
    final c = widget.controller;
    if (c == null || c.positions.length != 1) return null;
    return c.position;
  }

  void _step(int direction) {
    final pos = _position;
    if (pos == null) return;
    final target = (pos.pixels + direction * pos.viewportDimension * 0.8)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    pos.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    final scrollable = m != null &&
        m.maxScrollExtent > 0 &&
        m.viewportDimension >= 220 &&
        widget.controller != null;
    final color = AppColors.gold.withValues(alpha: 0.6);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => n.depth == 0 ? _remember(n.metrics) : false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 ? _remember(n.metrics) : false,
        child: Stack(
          children: [
            RawScrollbar(
              controller: widget.controller,
              thumbVisibility: scrollable,
              interactive: true,
              thickness: 6,
              radius: const Radius.circular(3),
              thumbColor: color,
              mainAxisMargin: 30,
              crossAxisMargin: 3,
              child: widget.child,
            ),
            if (scrollable) ...[
              PositionedDirectional(
                end: 0,
                top: 2,
                child: _Arrow(icon: Icons.keyboard_arrow_up_rounded, color: color, onTap: () => _step(-1)),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 2,
                child: _Arrow(icon: Icons.keyboard_arrow_down_rounded, color: color, onTap: () => _step(1)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 22,
          height: 26,
          child: Icon(icon, size: 20, color: color),
        ),
      );
}
