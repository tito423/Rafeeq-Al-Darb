/// The app-bar slot the mushaf toolbar lives in: its height, its entrance
/// animation, and its measurement.
///
/// Split out of `quran_screen.dart` because the screen is on the file-length
/// guard's list and this is chrome, not reading logic — but mostly because all
/// three of those concerns belong together and none of them belongs in a
/// `build` that is already five hundred lines.
library;

import 'package:flutter/material.dart';

import '../../../../../core/widgets/measure_size.dart';
import '../../../../../core/widgets/toolbar_action.dart';

/// Wraps [child] as an `AppBar.bottom`.
///
/// [height] is the last measured height of [child]; [onMeasured] delivers the
/// next one. That round trip is the whole point — see `MeasureSize` for the
/// bug a constant caused here.
PreferredSizeWidget mushafToolbarBar({
  required bool compact,
  required double height,
  required ValueChanged<Size> onMeasured,
  required Widget child,
}) {
  return PreferredSize(
    preferredSize: Size.fromHeight(
      compact ? ToolbarAction.compactHeight + 8 : height,
    ),
    // The bar is toggled by tapping the page, and it used to blink in and out
    // between two frames. It fades and lifts now — the owner asked for it to
    // be animated and to look like something.
    child: TweenAnimationBuilder<double>(
      key: ValueKey(compact),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -8),
          child: inner,
        ),
      ),
      child: MeasureSize(
        onChange: onMeasured,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: child,
        ),
      ),
    ),
  );
}
