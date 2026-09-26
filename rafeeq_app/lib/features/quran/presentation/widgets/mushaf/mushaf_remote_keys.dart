import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The mushaf page on a TV remote.
///
/// A page swipes by finger; a remote has no swipe. The page area takes
/// focus (so the D-pad can land on it, and `FocusRingOverlay` rings it),
/// and then:
///  * LEFT turns to the NEXT page and RIGHT to the previous one - a mushaf
///    turns right to left, the way `QuranScreen`'s PageView already runs;
///  * OK / Enter does what a tap on the page does (shows the controls);
///  * UP / DOWN are not taken, so they move on to the toolbar as usual.
class MushafRemoteKeys extends StatelessWidget {
  const MushafRemoteKeys({
    super.key,
    required this.onTurn,
    required this.onSelect,
    required this.child,
  });

  /// +1 for the next page, -1 for the previous.
  final void Function(int delta) onTurn;
  final VoidCallback onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          onTurn(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          onTurn(-1);
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter)) {
          onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
