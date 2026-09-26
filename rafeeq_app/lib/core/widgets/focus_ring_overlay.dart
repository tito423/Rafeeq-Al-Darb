import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A ring around whatever has focus, drawn once over the whole app.
///
/// Seen on the Google TV emulator (2026-09-26): the D-pad moved focus to
/// «Français» and the only sign was a light-grey tint on a light chip -
/// invisible from a sofa. Android's TV guidance asks for a clearly visible
/// focus indicator on EVERY focusable item
/// (developer.android.com/training/tv/get-started/navigation).
///
/// Styling each button, chip, card and field would leave the next new
/// widget without one. This is one layer instead: it asks the focus manager
/// where the focused node is and paints a ring there, whatever the widget.
///
/// Only in «traditional» highlight mode - a remote, a keyboard, a D-pad.
/// A touch puts Flutter back in touch mode and the ring is gone, so phones
/// used by hand never see it. While shown it repaints every frame (a scroll
/// or an animation moves the focused item without telling anyone); in
/// touch mode the ticker is stopped and it costs nothing.
class FocusRingOverlay extends StatefulWidget {
  const FocusRingOverlay({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<FocusRingOverlay> createState() => _FocusRingOverlayState();
}

class _FocusRingOverlayState extends State<FocusRingOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _sync());
  Rect? _rect;
  bool _traditional = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
    FocusManager.instance.addListener(_sync);
    _onMode(FocusManager.instance.highlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    FocusManager.instance.removeListener(_sync);
    _ticker.dispose();
    super.dispose();
  }

  void _onMode(FocusHighlightMode mode) {
    _traditional = mode == FocusHighlightMode.traditional;
    if (_traditional) {
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    Rect? next;
    final node = FocusManager.instance.primaryFocus;
    // A scope (a route, a dialog) holding focus with nothing chosen inside
    // it is not a control, and has no ring.
    if (_traditional && node != null && node is! FocusScopeNode) {
      final box = context.findRenderObject();
      final ctx = node.context;
      final target = ctx?.findRenderObject();
      if (box is RenderBox && target is RenderBox && target.attached &&
          target.hasSize) {
        final topLeft = target.localToGlobal(Offset.zero, ancestor: box);
        next = topLeft & target.size;
      }
    }
    if (next != _rect) setState(() => _rect = next);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_rect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(_rect!, widget.color),
              ),
            ),
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Outside the item by 3 px so it never covers the item's own edge, with
    // a dark halo under the gold so it reads on light AND dark grounds.
    final r = RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(14));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0x66000000),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rect != rect || old.color != color;
}
