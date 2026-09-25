import 'package:flutter/material.dart';

/// `showModalBottomSheet` for a sheet whose content is a plain column: it is
/// as tall as its content, and scrolls when the screen is shorter than that.
///
/// A default modal sheet is capped at 9/16 of the screen's height and CLIPS
/// whatever is below - no scrolling, no overflow warning in a release build.
/// Upright that cap is rarely met. Sideways it always is: on the owner's
/// Xiaomi held sideways (2026-09-26) the sign-in offer closing the first run
/// showed its icon, title and one line, and its buttons were under the edge
/// of the screen with no way to reach them.
///
/// So the sheet is scroll-controlled (it may grow to the full height, kept
/// clear of the status bar by `useSafeArea`) and its content sits in a scroll
/// view. Short content still sizes the sheet exactly as before.
///
/// Only for content without a vertical `Expanded`/`Flexible` or its own
/// scrolling list - those already fit themselves to the height they are given.
Future<T?> showFittedSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: (ctx) => SingleChildScrollView(child: builder(ctx)),
  );
}
