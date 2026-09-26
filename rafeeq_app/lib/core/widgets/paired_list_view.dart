import 'package:flutter/material.dart';

/// A list of cards: one card a row upright, two a row sideways.
///
/// «كانه تاب شغال بالعرض» (owner, 2026-09-26): a list of cards drawn for a
/// phone held upright, stretched across a phone on its side, is a row of
/// long thin bars with the text at one end - the reciters list and the
/// tajweed levels on his Xiaomi. Two a row keeps each card near the width it
/// was drawn for. Reading order is kept: 1 2 / 3 4 / 5.
///
/// Only for lists whose items are self-contained cards or tiles. A list that
/// is a document (a book's text, a hadith with its chain) must stay one
/// column - pairing would cut the reading line.
class PairedListView extends StatelessWidget {
  PairedListView({
    super.key,
    required List<Widget> children,
    this.padding,
    this.gap = 12,
    this.controller,
    this.physics,
    this.header,
    this.footer,
  }) : itemCount = children.length,
       itemBuilder = ((_, i) => children[i]);

  const PairedListView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.gap = 12,
    this.controller,
    this.physics,
    this.header,
    this.footer,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;

  /// Space between the two cards of a row.
  final double gap;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  /// Full width before the cards (an intro panel) - never paired.
  final Widget? header;

  /// Full width after the cards (a source credit, a note) - never paired.
  final Widget? footer;

  int get _extra => (header == null ? 0 : 1) + (footer == null ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) != Orientation.landscape) {
      return ListView.builder(
        controller: controller,
        physics: physics,
        padding: padding,
        itemCount: itemCount + _extra,
        itemBuilder: (context, i) {
          if (header != null) {
            if (i == 0) return header!;
            i -= 1;
          }
          return i == itemCount ? footer! : itemBuilder(context, i);
        },
      );
    }
    return ListView.builder(
      controller: controller,
      physics: physics,
      padding: padding,
      itemCount: (itemCount + 1) ~/ 2 + _extra,
      itemBuilder: (context, row) {
        if (header != null) {
          if (row == 0) return header!;
          row -= 1;
        }
        if (row == (itemCount + 1) ~/ 2) return footer!;
        final a = row * 2;
        final b = a + 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: itemBuilder(context, a)),
            SizedBox(width: gap),
            Expanded(
              child: b < itemCount ? itemBuilder(context, b) : const SizedBox(),
            ),
          ],
        );
      },
    );
  }
}

/// [PairedListView]'s rule for a run of cards inside a longer list: one a
/// row upright with [gap] between, [columns] a row sideways (two unless told).
class PairedColumn extends StatelessWidget {
  const PairedColumn({
    super.key,
    required this.children,
    this.gap = 12,
    this.columnGap,
    this.columns = 2,
    this.equalHeights = true,
  });

  final List<Widget> children;

  /// Space between rows, and between the cards of a row unless [columnGap].
  final double gap;
  final double? columnGap;

  /// Cards a row sideways.
  final int columns;

  /// Stretch the cards of a row to the tallest. Off for cards that open in
  /// place: a closed card stretched to its open neighbour's height is a tall
  /// empty slab.
  final bool equalHeights;

  @override
  Widget build(BuildContext context) {
    final sideways = MediaQuery.orientationOf(context) == Orientation.landscape;
    final per = sideways ? columns : 1;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += per) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(per == 1 ? children[i] : _row(i, per));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _row(int i, int per) {
    final row = Row(
      crossAxisAlignment:
          equalHeights ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var k = 0; k < per; k++) ...[
          if (k > 0) SizedBox(width: columnGap ?? gap),
          Expanded(
            child: i + k < children.length ? children[i + k] : const SizedBox(),
          ),
        ],
      ],
    );
    return equalHeights ? IntrinsicHeight(child: row) : row;
  }
}
