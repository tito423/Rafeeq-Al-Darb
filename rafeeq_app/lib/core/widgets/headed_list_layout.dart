import 'package:flutter/material.dart';

/// A heading, a scrolling list, and buttons under it - upright or sideways.
///
/// Upright it is the plain stack: heading, the list taking what is left,
/// buttons. Sideways that stack is wrong: on the owner's Xiaomi held sideways
/// (2026-09-26) the heading and the buttons ate the height and left the list
/// a strip one row high - the permissions screen showed half a row of
/// language chips, the downloads screen half a mushaf card.
///
/// So sideways the heading and buttons share one pane (scrolling, if a
/// large font needs it) and the list gets the full height of the other.
class HeadedListLayout extends StatelessWidget {
  const HeadedListLayout({
    super.key,
    required this.header,
    required this.list,
    required this.footer,
  });

  final Widget header;
  final Widget list;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) != Orientation.landscape) {
      return Column(
        children: [
          header,
          Expanded(child: list),
          footer,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [header, footer],
                ),
              ),
            ),
          ),
        ),
        Expanded(flex: 3, child: list),
      ],
    );
  }
}
