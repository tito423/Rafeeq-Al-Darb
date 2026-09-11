import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// «وفّر في أي حاجة في التطبيق فيها اسكرولينج عمودي اسكرول بار عمودي في جنب
/// الشاشة، وسهم فوق في بدايته وسهم تحت في نهايته؛ لو سحبته يسحب ولو ضغط على
/// الأسهم تسحب لتحت أو فوق».
///
/// Installed once, as the app's scroll behaviour, so every vertical list and
/// page gets it — including screens written after this. A horizontal list is
/// left alone, and so is a list too short to scroll or a viewport too small to
/// hold the arrows (a dropdown menu).
///
/// The first version wrapped the list in a `RawScrollbar` and rebuilt the
/// whole wrapper whenever the list's size changed. A lazily-built list
/// re-estimates its length as it scrolls, so that was a rebuild on nearly
/// every frame — «الاسكرول بار بيعطل ويعمل للشاشة فليكر» — and its six-pixel
/// thumb and 22-pixel arrows were too small to catch with a thumb: on the
/// emulator a drag along it did not move the list at all. This one draws its
/// own rail. Only the rail repaints, the list under it is never rebuilt, the
/// thumb follows the finger wherever it lands on the track, and a tap on the
/// track pages up or down.
class ArrowScrollBehavior extends MaterialScrollBehavior {
  const ArrowScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (axisDirectionToAxis(details.direction) != Axis.vertical ||
        controller == null) {
      return child;
    }
    return ArrowScrollbar(controller: controller, child: child);
  }
}

class ArrowScrollbar extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const ArrowScrollbar({super.key, required this.controller, required this.child});

  @override
  State<ArrowScrollbar> createState() => _ArrowScrollbarState();
}

class _ArrowScrollbarState extends State<ArrowScrollbar> {
  static const double _railWidth = 26;
  static const double _arrowHeight = 30;
  static const double _minThumb = 44;

  /// Bumped when the list's extent changes. Pixel changes arrive through the
  /// controller itself.
  final ValueNotifier<int> _extent = ValueNotifier(0);
  bool _bumpPending = false;
  bool _dragging = false;

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  /// Metrics notifications fire during layout, where nothing may be marked
  /// for rebuild; coalesce them into one bump after the frame.
  bool _onMetrics(ScrollNotification n) {
    if (n.depth != 0 || _bumpPending) return false;
    _bumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bumpPending = false;
      if (mounted) _extent.value++;
    });
    return false;
  }

  bool _onMetricsChanged(ScrollMetricsNotification n) {
    if (n.depth != 0 || _bumpPending) return false;
    _bumpPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bumpPending = false;
      if (mounted) _extent.value++;
    });
    return false;
  }

  ScrollPosition? get _position {
    final c = widget.controller;
    if (!c.hasClients || c.positions.length != 1) return null;
    final p = c.position;
    if (!p.hasContentDimensions || !p.hasPixels || !p.hasViewportDimension) {
      return null;
    }
    return p;
  }

  void _step(int direction) {
    final pos = _position;
    if (pos == null) return;
    final target = (pos.pixels + direction * pos.viewportDimension * 0.8)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    pos.animateTo(target,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _toEnd(int direction) {
    final pos = _position;
    if (pos == null) return;
    pos.animateTo(direction < 0 ? pos.minScrollExtent : pos.maxScrollExtent,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  /// Puts the thumb's centre under the finger.
  void _dragTo(double dy, double trackHeight, double thumb) {
    final pos = _position;
    if (pos == null) return;
    final travel = trackHeight - thumb;
    if (travel <= 0) return;
    final frac = ((dy - thumb / 2) / travel).clamp(0.0, 1.0);
    pos.jumpTo(pos.minScrollExtent +
        frac * (pos.maxScrollExtent - pos.minScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetricsChanged,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onMetrics,
        child: Stack(
          children: [
            widget.child,
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              width: _railWidth,
              child: AnimatedBuilder(
                animation: Listenable.merge([widget.controller, _extent]),
                builder: (context, _) => _rail(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rail() {
    final pos = _position;
    if (pos == null) return const SizedBox.shrink();
    final extent = pos.maxScrollExtent - pos.minScrollExtent;
    final viewport = pos.viewportDimension;
    if (extent <= 1 || viewport < 220) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final track = box.maxHeight - 2 * _arrowHeight;
        if (track < _minThumb * 1.5) return const SizedBox.shrink();
        final thumb =
            (track * viewport / (extent + viewport)).clamp(_minThumb, track);
        final frac =
            ((pos.pixels - pos.minScrollExtent) / extent).clamp(0.0, 1.0);
        final thumbTop = (track - thumb) * frac;
        final color = AppColors.gold.withValues(alpha: _dragging ? 0.95 : 0.6);
        return Column(
          children: [
            _Arrow(
              icon: Icons.keyboard_arrow_up_rounded,
              color: color,
              onTap: () => _step(-1),
              onLongPress: () => _toEnd(-1),
            ),
            SizedBox(
              height: track,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    _step(d.localPosition.dy < thumbTop ? -1 : 1),
                onVerticalDragStart: (d) {
                  setState(() => _dragging = true);
                  _dragTo(d.localPosition.dy, track, thumb);
                },
                onVerticalDragUpdate: (d) =>
                    _dragTo(d.localPosition.dy, track, thumb),
                onVerticalDragEnd: (_) => setState(() => _dragging = false),
                onVerticalDragCancel: () => setState(() => _dragging = false),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: thumbTop,
                      height: thumb,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _dragging ? 9 : 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Arrow(
              icon: Icons.keyboard_arrow_down_rounded,
              color: color,
              onTap: () => _step(1),
              onLongPress: () => _toEnd(1),
            ),
          ],
        );
      },
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _Arrow({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: _ArrowScrollbarState._railWidth,
          height: _ArrowScrollbarState._arrowHeight,
          child: Icon(icon, size: 24, color: color),
        ),
      );
}
