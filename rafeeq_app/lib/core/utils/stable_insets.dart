import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The room the system bars take, remembered for when they are hidden.
///
/// «ملء الشاشة … تبقى لحد النوتش ويبقى تحت المسافة لحد البوتوم نافيجيشن
/// بحيث إن لما أضغط على الشاشة يظهر … النوتش والحاجات اللي في الستيتس
/// بار» (owner, 2026-10-02). Full screen hides the status and navigation
/// bars, but the page must still stop where they would be, so that a tap
/// can bring them back without covering a line or moving the page.
///
/// Android reports only the notch (`displayCutout`) in
/// `MediaQuery.viewPadding` while the bars are hidden; the bars' own height
/// is known only while they show. So the largest padding seen is kept for
/// each orientation and notch side, and that is what full screen keeps clear.
/// The app always starts with the bars showing (full screen is applied only
/// once the Qur'an tab is on screen), so this has a real reading before it
/// is ever needed.
EdgeInsets stableSystemInsets(BuildContext context) {
  final now = MediaQuery.viewPaddingOf(context);
  final orientation = MediaQuery.orientationOf(context);
  // Turned the other way, the notch is on the other side.
  final side = now.left > now.right
      ? 'L'
      : now.right > now.left
          ? 'R'
          : '';
  final key = '${orientation.name}$side';
  final seen = _seen[key];
  final merged = seen == null
      ? now
      : EdgeInsets.fromLTRB(
          math.max(seen.left, now.left),
          math.max(seen.top, now.top),
          math.max(seen.right, now.right),
          math.max(seen.bottom, now.bottom),
        );
  _seen[key] = merged;
  return merged;
}

final Map<String, EdgeInsets> _seen = {};
