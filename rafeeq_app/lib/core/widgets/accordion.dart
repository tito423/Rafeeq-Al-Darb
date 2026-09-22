import 'dart:async';

import 'package:flutter/foundation.dart';
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
///
/// **Back closes the open card first.** «لما أكون فاتح كولابسد وأضغط
/// نافيجيشن باك عايزه يقفل الأول الكولابسد، ودي وحدها في التطبيق كله»
/// (2026-09-22). While a card is open and on screen, its route cannot pop;
/// the back gesture closes the most recently opened card instead. A card
/// on a tab that `IndexedStack` is keeping alive but not showing does not
/// count — `Visibility.of` says whether it is really on screen.
mixin AccordionMember<T extends StatefulWidget> on State<T> {
  ScrollableState? _scrollable;
  ModalRoute<Object?>? _route;

  /// Close this card because another one opened, or because back was
  /// pressed.
  void accordionCollapse();

  /// Whether this card is open right now.
  bool get accordionIsOpen;

  Set<AccordionMember>? get _group {
    final s = _scrollable;
    if (s == null) return null;
    return _groups[s] ??= <AccordionMember>{};
  }

  bool get _visibleOpen =>
      mounted && accordionIsOpen && Visibility.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context);
    if (!identical(next, _scrollable)) {
      _group?.remove(this);
      _scrollable = next;
      _group?.add(this);
    }
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _BackEntry.leave(this, _route);
      _route = route;
      _BackEntry.join(this, route);
    }
    // Visibility.of registers a dependency, so switching tabs lands here.
    _BackEntry.refreshSoon();
  }

  @override
  void dispose() {
    _group?.remove(this);
    _BackEntry.leave(this, _route);
    _opened.remove(this);
    _BackEntry.refreshSoon();
    super.dispose();
  }

  /// Call when this card has just closed by its own hand (a tap on its
  /// header), so the back gesture stops waiting on it.
  void accordionClosed() => _BackEntry.refreshSoon();

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
    _opened
      ..remove(this)
      ..add(this);
    _BackEntry.refreshSoon();
    revealWholeAfter(context, settle);
  }
}

/// The open-state registry, one per scrolling list, keyed by the list's own
/// `ScrollableState` so nothing has to be declared around the list.
final Expando<Set<AccordionMember>> _groups = Expando();

/// Cards in the order they were opened; the back gesture closes the last.
final List<AccordionMember> _opened = [];

/// Whether pressing back on [context]'s route will close an open card
/// rather than leave. `AppShell` asks this before treating back as «go to
/// Home», because every pop handler on a route hears the same press.
bool accordionHandlesBack(BuildContext context) {
  final route = ModalRoute.of(context);
  return route != null && _BackEntry._hasVisibleOpen(route);
}

/// One pop entry per route that holds accordion cards.
class _BackEntry extends PopEntry<Object?> {
  _BackEntry(this.route);

  final ModalRoute<Object?> route;
  final Set<AccordionMember> members = {};
  final ValueNotifier<bool> _canPop = ValueNotifier(true);

  static final Map<ModalRoute<Object?>, _BackEntry> _byRoute = {};
  static bool _refreshQueued = false;

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  static void join(AccordionMember m, ModalRoute<Object?>? route) {
    if (route == null) return;
    final entry = _byRoute.putIfAbsent(route, () {
      final e = _BackEntry(route);
      route.registerPopEntry(e);
      return e;
    });
    entry.members.add(m);
  }

  static void leave(AccordionMember m, ModalRoute<Object?>? route) {
    if (route == null) return;
    final entry = _byRoute[route];
    if (entry == null) return;
    entry.members.remove(m);
    if (entry.members.isEmpty) {
      _byRoute.remove(route);
      route.unregisterPopEntry(entry);
      entry._canPop.dispose();
    }
  }

  static bool _hasVisibleOpen(ModalRoute<Object?> route) =>
      _byRoute[route]?.members.any((m) => m._visibleOpen) ?? false;

  /// Recomputes every route's answer after the current frame — open states
  /// change inside builds, and a pop entry must not notify mid-build.
  static void refreshSoon() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      for (final e in _byRoute.values.toList()) {
        e._canPop.value = !_hasVisibleOpen(e.route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    // Deferred: every pop handler on this route hears this press, and
    // `AppShell`'s asks [accordionHandlesBack] — which must still see the
    // card open when it does.
    scheduleMicrotask(() {
      for (final m in _opened.reversed.toList()) {
        if (members.contains(m) && m._visibleOpen) {
          m.accordionCollapse();
          break;
        }
      }
      refreshSoon();
    });
  }
}

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
    if (expanded) {
      accordionOpened();
    } else {
      accordionClosed();
    }
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_controller, _onChanged);
}

/// A hand-built section (a header and what it opens onto) that follows
/// the accordion rules. [builder] gets whether it is open and the toggle
/// for its header.
class AccordionSection extends StatefulWidget {
  final Widget Function(BuildContext context, bool open, VoidCallback toggle)
  builder;

  const AccordionSection({super.key, required this.builder});

  @override
  State<AccordionSection> createState() => _AccordionSectionState();
}

class _AccordionSectionState extends State<AccordionSection>
    with AccordionMember<AccordionSection> {
  bool _open = false;

  @override
  bool get accordionIsOpen => _open;

  @override
  void accordionCollapse() => setState(() => _open = false);

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      accordionOpened();
    } else {
      accordionClosed();
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _open, _toggle);
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
