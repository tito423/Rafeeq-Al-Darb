/// What the guided tour covers, and in what order.
///
/// Moved out of the overlay that plays it: the chapter list is the tour's
/// content - which screen, which order, which icon - and the overlay is only
/// the thing that renders it. Keeping them apart is what lets a test read the
/// list without building a widget.
library;

import 'package:flutter/material.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';

/// One stop on the tour: a translation key, the tab it explains, and the
/// accent its card takes.
///
/// `tab` is a real `AppTab` index — the tour does not mock up a screen, it
/// opens it. Where a feature lives inside a tab rather than being one (the
/// recitation player, in «المزيد»), the chapter points at the tab that holds
/// it and the text says where to go from there.
class TutorialChapter {
  final String key;
  final int tab;
  final IconData icon;
  final Color accent;

  const TutorialChapter(this.key, this.tab, this.icon, this.accent);
}

const tutorialChapters = <TutorialChapter>[
  TutorialChapter('welcome', AppTab.home, Icons.mosque_rounded, AppColors.gold),
  TutorialChapter('home', AppTab.home, Icons.home_rounded, AppColors.primarySoft),
  TutorialChapter('quran', AppTab.quran, Icons.menu_book_rounded, AppColors.gold),
  TutorialChapter('recite', AppTab.more, Icons.headphones_rounded, Color(0xFF2E9FE8)),
  TutorialChapter('prayer', AppTab.prayer, Icons.mosque_outlined, Color(0xFF6C5FBC)),
  TutorialChapter('azkar', AppTab.azkar, Icons.spa_rounded, Color(0xFF2E9D6F)),
  TutorialChapter('tasbeeh', AppTab.tasbeeh, Icons.radio_button_checked, Color(0xFFD4785A)),
  TutorialChapter('library', AppTab.library, Icons.local_library_rounded, Color(0xFF3F7A8C)),
  TutorialChapter('more', AppTab.more, Icons.widgets_rounded, AppColors.goldSoft),
  // The last three are settings and facts about the app rather than tabs
  // of their own, so they are narrated over «المزيد», which is where each
  // of them is actually reached from.
  TutorialChapter('themes', AppTab.more, Icons.palette_rounded, Color(0xFFB07BD6)),
  TutorialChapter('offline', AppTab.more, Icons.cloud_off_rounded, Color(0xFF5C8A9E)),
  TutorialChapter('sources', AppTab.more, Icons.verified_rounded, AppColors.gold),
];
