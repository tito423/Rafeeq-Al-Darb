import 'package:flutter/material.dart';

import '../../../../core/widgets/more_group_accent.dart';
import '../../../../core/widgets/paired_list_view.dart';

/// A «المزيد» group opened as a page of its own - sideways and on tablets.
///
/// Owner, 2026-11-13 (phone sideways): opening a group in place squeezed
/// its cards into a third of the screen, a word to a line - «سيئة جدا، غيّر
/// طريقة العرض لشيء منطقي وجميل». In the three-a-row grid a group now opens
/// onto the whole width, its cards two or three a row with their
/// descriptions, under the group's own title. Upright on a phone the group
/// still opens in place, where a card has the full width anyway.
class MoreGroupPage extends StatelessWidget {
  final String title;
  final Color accent;
  final List<Widget> children;

  const MoreGroupPage({
    super.key,
    required this.title,
    required this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          MoreGroupAccent(
            accent: accent,
            child: PairedColumn(
              columns: width >= 1100 ? 3 : 2,
              columnGap: 16,
              // Some groups hand over one child holding several cards; a
              // single card beside it was stretched into a tall empty slab
              // («عن التطبيق», API 24 sideways).
              equalHeights: false,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
