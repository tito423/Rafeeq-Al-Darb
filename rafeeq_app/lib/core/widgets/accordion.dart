import 'dart:async';

import 'package:flutter/material.dart';

/// «أي كارت يتفتح في التطبيق كله لو جزء منه مابانش في الشاشة يترفع الشاشة
/// عشان كله يبان … ولما يكون فيه فاتح كارت ورحت على كارت تاني مش منبثق منه
/// … قوم عامل كولابس للمفتوح يقفل والتاني المختار يفتح» (2026-09-22).
///
/// Two rules for every card that opens in place:
///
/// * **One open at a time.** Opening a card closes every other card in the
///   same scrolling list, except the cards it sits inside — a nested card
///   opening must not fold up its own parent.
/// * **Opened means seen.** Once the opening animation has settled, the
///   list scrolls just enough to show the whole card; a card taller than
///   the screen is brought to its top, so it is read from the beginning.
///
/// An `ExpansionTile` gets both by being built through [AccordionTile]. A
/// hand-rolled expander mixes [AccordionMember] into its State, calls
/// [AccordionMember.accordionOpened] when it opens, and closes itself in
/// [AccordionMember.accordionCollapse].
mixin AccordionMember<T extends StatefulWidget> on State<T> {
  ScrollableState? _scrollable;

  /// Close this card because another one opened.
  void accordionCollapse();

  /// Whether this card is open right now.
  bool get accordionIsOpen;

  Set<AccordionMember>? get _group {
    final s = _scrollable;
    if (s == null) return null;
    return _groups[s] ??= <AccordionMember>{};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context);
    if (!identical(next, _scrollable)) {
      _group?.remove(this);
      _scrollable = next;
      _group?.add(this);
    }
  }

  @override
  void dispose() {
    _group?.remove(this);
    super.dispose();
  }

  bool _encloses(AccordionMember other) {
    var found = false;
    other.context.visitAncestorElements((e) {
      if (e is StatefulElement && identical(e.state, this)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  /// Call when this card has just opened: closes the others, then brings
  /// the whole of this one on screen once it has finished growing.
  void accordionOpened({
    Duration settle = const Duration(milliseconds: 260),
  }) {
    for (final other in [...?_group]) {
      if (identical(other, this) || other._encloses(this)) continue;
      if (other.mounted && other.accordionIsOpen) other.accordionCollapse();
    }
    revealWholeAfter(context, settle);
  }
}

/// The open-state registry, one per scrolling list, keyed by the list's own
/// `ScrollableState` so nothing has to be declared around the list.
final Expando<Set<AccordionMember>> _groups = Expando();

/// Builds an `ExpansionTile` that follows the accordion rules:
///
/// ```dart
/// AccordionTile(
///   builder: (controller, onExpansionChanged) => ExpansionTile(
///     controller: controller,
///     onExpansionChanged: onExpansionChanged,
///     ...
///   ),
/// )
/// ```
class AccordionTile extends StatefulWidget {
  final Widget Function(
    ExpansibleController controller,
    ValueChanged<bool> onExpansionChanged,
  )
  builder;

  /// Called after the tile's own bookkeeping, for callers that already
  /// listened to `onExpansionChanged`.
  final ValueChanged<bool>? onExpansionChanged;

  const AccordionTile({
    super.key,
    required this.builder,
    this.onExpansionChanged,
  });

  @override
  State<AccordionTile> createState() => _AccordionTileState();
}

class _AccordionTileState extends State<AccordionTile>
    with AccordionMember<AccordionTile> {
  final _controller = ExpansibleController();

  @override
  bool get accordionIsOpen => _controller.isExpanded;

  @override
  void accordionCollapse() => _controller.collapse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(bool expanded) {
    // ExpansionTile animates open over 200 ms; measure after it has.
    if (expanded) accordionOpened();
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_controller, _onChanged);
}

/// Scrolls the nearest list so the widget at [context] is fully on screen
/// — its bottom first, then its top, so a widget taller than the viewport
/// ends up showing its beginning.
Future<void> revealWhole(BuildContext context) async {
  const duration = Duration(milliseconds: 250);
  await Scrollable.ensureVisible(
    context,
    duration: duration,
    curve: Curves.easeOut,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
  );
  if (!context.mounted) return;
  await Scrollable.ensureVisible(
    context,
    duration: duration,
    curve: Curves.easeOut,
    alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
  );
}

/// [revealWhole], after an expansion animation of [settle] has finished.
void revealWholeAfter(
  BuildContext context, [
  Duration settle = const Duration(milliseconds: 260),
]) {
  unawaited(
    Future<void>.delayed(settle, () {
      if (context.mounted) return revealWhole(context);
    }),
  );
}
