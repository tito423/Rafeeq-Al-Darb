/// The reader toolbar: a wrap in portrait so every action is visible at
/// once, and one scrolling row of icons in landscape, where the phone has
/// about 393 logical pixels of height to spend in total.
library;


import 'package:flutter/material.dart';

import '../../../../../core/widgets/toolbar_action.dart';
import '../../../../tutorial/data/tutorial_anchors.dart';

/// Quran tab — a real mushaf browser.
///  • Text mode: real Uthmani ayahs laid out by their real Madani page
///    boundaries from the bundled database (works fully offline).
///  • Image mode: the authentic KFQC mushaf pages as vector art, cached on
///    device, with the real ayah polygons layered on top for tap/highlight.

/// The Qur'an toolbar's two shapes.
///
/// Portrait keeps the captioned `Wrap` — every action visible at once, which
/// is what P3‑41's device feedback asked for. Landscape cannot afford it (see
/// the `bottom:` comment above), so the same actions become one compact,
/// horizontally-scrolling row.
///
/// The children arrive as ordinary [ToolbarAction]s and are rebuilt compact
/// here rather than each of the thirteen call sites having to pass a flag —
/// a flag that would then be possible to forget on the fourteenth.
class ToolbarStrip extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const ToolbarStrip({super.key, required this.compact, required this.children});

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 0,
        children: children,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in children) _compact(child),
        ],
      ),
    );
  }

  /// The compact form of [child]. A tour target (`TutorialAnchor`) keeps its
  /// anchor and has the action inside it made compact, so registering a
  /// button with the guided tour cannot quietly cost it its landscape form.
  static Widget _compact(Widget child) {
    if (child is TutorialAnchor) {
      return TutorialAnchor(id: child.id, child: _compact(child.child));
    }
    if (child is ToolbarAction) {
      return ToolbarAction(
        icon: child.icon,
        label: child.label,
        onPressed: child.onPressed,
        active: child.active,
        compact: true,
      );
    }
    return child;
  }
}
