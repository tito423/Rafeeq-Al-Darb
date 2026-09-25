import 'package:flutter/material.dart';

/// A screen's cards in one scrolling column upright, and in two side by side
/// when the phone is on its side.
///
/// «اظبط الشكل والتصميم في الاورينتيشن … كانه تاب شغال بالعرض» (owner,
/// 2026-09-26). The cards were designed for a phone held upright, about
/// 400 dp wide. Sideways, one column stretched each of them across ~900 dp:
/// the home header card alone filled the screen. Two columns give every card
/// roughly the width it was drawn for, and each column scrolls on its own,
/// the way a tablet dashboard does.
///
/// [start] and [end] are the two columns' children, in reading order;
/// upright they are simply one list, [start] first.
class TwoPaneScroll extends StatelessWidget {
  const TwoPaneScroll({
    super.key,
    required this.start,
    required this.end,
    this.padding = const EdgeInsets.all(20),
    this.gap = 16,
    this.columnGap,
    this.startFlex = 1,
    this.endFlex = 1,
  });

  final List<Widget> start;
  final List<Widget> end;
  final EdgeInsets padding;

  /// Space between cards, and between the two columns.
  final double gap;

  /// Space between the two columns; [gap] when not given.
  final double? columnGap;
  final int startFlex;
  final int endFlex;

  static bool isSideways(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  List<Widget> _spaced(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    if (!isSideways(context)) {
      return ListView(padding: padding, children: _spaced([...start, ...end]));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Directional: in Arabic the START column is the right-hand one, and
        // its inner edge is its left.
        Expanded(
          flex: startFlex,
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              padding.left,
              padding.top,
              (columnGap ?? gap) / 2,
              padding.bottom,
            ),
            children: _spaced(start),
          ),
        ),
        Expanded(
          flex: endFlex,
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              (columnGap ?? gap) / 2,
              padding.top,
              padding.right,
              padding.bottom,
            ),
            children: _spaced(end),
          ),
        ),
      ],
    );
  }
}
