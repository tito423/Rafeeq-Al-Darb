import 'package:flutter/widgets.dart';

/// [base] widened at the sides so a form's content is at most [maxWidth]
/// across, centred - a tablet's settings page rather than a phone's
/// stretched to the edges.
///
/// Sideways (emulator-5554, 2026-09-26) a settings row put its label at one
/// edge of a line ~1,170 dp long (1200 dp screen, density 320) and its
/// switch or its − / + minutes at the other.
/// Upright the screen is narrower than [maxWidth] and [base] is returned as
/// it is. Padding rather than a centred box so the whole width still
/// scrolls.
EdgeInsets readableInsets(
  BuildContext context,
  EdgeInsets base, {
  double maxWidth = 680,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final content = width - base.left - base.right;
  if (content <= maxWidth) return base;
  final extra = (content - maxWidth) / 2;
  return base.copyWith(left: base.left + extra, right: base.right + extra);
}
