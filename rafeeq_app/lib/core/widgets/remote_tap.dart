import 'package:flutter/widgets.dart';

/// A tap target a TV remote can reach.
///
/// `GestureDetector` hears fingers only: it takes no focus, so the D-pad
/// skipped straight over it. 21 of the app's tap targets were built that
/// way (counted 2026-09-26) - the tasbeeh circle, the Hajj counters, the
/// prayer slides, the clock faces, the player's play button... On a TV none
/// of them could be pressed.
///
/// This is the same tap for a finger, plus focus (so the D-pad stops on it
/// and `FocusRingOverlay` rings it) and the remote's OK / Enter
/// (`ActivateIntent`, which Flutter maps from `select` and `enter`).
class RemoteTap extends StatelessWidget {
  const RemoteTap({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior,
  });

  final VoidCallback? onTap;
  final Widget child;
  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: onTap != null,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: behavior,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
