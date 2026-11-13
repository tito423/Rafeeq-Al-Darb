/// Floating page furniture that steps aside while the text moves.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Stacks [overlay] (the juz / page badges) over [viewer] and fades the
/// overlay out while the viewer scrolls vertically, back in once the text
/// has been still for [rest]. Owner, P3-51: nothing floating over the
/// ayah text — the badges were translucent and sat on moving lines in the
/// reading layout (every orientation). Horizontal page turns are ignored:
/// the page under the badges is not moving under them then.
///
/// Auto-scroll keeps the badges hidden (each tick is a short scroll); they
/// come back when it stops. The fade is local state, so a scroll never
/// rebuilds the reader around it.
class ScrollQuietOverlay extends StatefulWidget {
  final Widget viewer;
  final Widget? overlay;
  final Duration rest;

  const ScrollQuietOverlay({
    super.key,
    required this.viewer,
    this.overlay,
    this.rest = const Duration(milliseconds: 900),
  });

  @override
  State<ScrollQuietOverlay> createState() => _ScrollQuietOverlayState();
}

class _ScrollQuietOverlayState extends State<ScrollQuietOverlay> {
  bool _moving = false;
  Timer? _restTimer;

  void _setMoving(bool v) {
    if (v != _moving && mounted) setState(() => _moving = v);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollEndNotification) {
      _restTimer?.cancel();
      _restTimer = Timer(widget.rest, () => _setMoving(false));
    } else if (n is ScrollStartNotification ||
        (n is ScrollUpdateNotification && (n.scrollDelta ?? 0) != 0)) {
      _restTimer?.cancel();
      _setMoving(true);
    }
    return false;
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.viewer,
        ),
        if (widget.overlay != null)
          // Positioned.fill: the overlay lays its badges out against the
          // whole reader, as it did as a direct child of the outer Stack.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _moving ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: widget.overlay,
            ),
          ),
      ],
    );
  }
}
