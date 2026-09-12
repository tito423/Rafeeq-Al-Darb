/// What the guided tour covers, in what order, and what each stop points at.
///
/// Moved out of the overlay that plays it: the chapter list is the tour's
/// content — which screen, which order, which icon — and the overlay is only
/// the thing that renders it. Keeping them apart is what lets a test read the
/// list without building a widget.
library;

import 'package:flutter/material.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'tutorial_anchors.dart';

/// One stop on the tour.
///
/// [tab] is a real `AppTab` index — the tour does not mock up a screen, it
/// opens it. [anchor] names a widget registered with [TutorialAnchor] when the
/// stop is about one particular card rather than a whole tab; when it is null
/// the tour points at that tab's own button in the navigation bar, which is
/// where the reader has to go to find it.
class TutorialChapter {
  final String key;
  final int tab;
  final IconData icon;
  final Color accent;
  final String? anchor;

  const TutorialChapter(this.key, this.tab, this.icon, this.accent,
      {this.anchor});
}

const tutorialChapters = <TutorialChapter>[
  // No target: this one is the welcome and the language chips, and there is
  // nothing on screen it is about yet.
  TutorialChapter('welcome', AppTab.home, Icons.mosque_rounded, AppColors.gold),
  TutorialChapter('home', AppTab.home, Icons.home_rounded, AppColors.primarySoft),
  // The four Home cards worth a stop of their own, each pointed at where it
  // actually sits. «التوتوريال مش بيذكر كارت الحديث» — it does now.
  TutorialChapter('prayer_card', AppTab.home, Icons.schedule_rounded,
      Color(0xFF6C5FBC),
      anchor: TourAnchor.prayerCard),
  TutorialChapter('continue_reading', AppTab.home, Icons.bookmark_rounded,
      AppColors.gold,
      anchor: TourAnchor.continueReading),
  TutorialChapter('khatma', AppTab.home, Icons.auto_stories_rounded,
      Color(0xFF3F7A8C),
      anchor: TourAnchor.khatmaCard),
  TutorialChapter('quote_card', AppTab.home, Icons.auto_awesome_rounded,
      Color(0xFFB07BD6),
      anchor: TourAnchor.quoteCard),
  TutorialChapter('hadith_card', AppTab.home, Icons.menu_book_rounded,
      Color(0xFF2E9D6F),
      anchor: TourAnchor.hadithCard),
  TutorialChapter('quran', AppTab.quran, Icons.menu_book_rounded, AppColors.gold),
  TutorialChapter('recite', AppTab.more, Icons.headphones_rounded, Color(0xFF2E9FE8)),
  TutorialChapter('prayer', AppTab.prayer, Icons.mosque_outlined, Color(0xFF6C5FBC)),
  TutorialChapter('azkar', AppTab.azkar, Icons.spa_rounded, Color(0xFF2E9D6F)),
  TutorialChapter('tasbeeh', AppTab.tasbeeh, Icons.radio_button_checked, Color(0xFFD4785A)),
  TutorialChapter('library', AppTab.library, Icons.local_library_rounded, Color(0xFF3F7A8C)),
  TutorialChapter('more', AppTab.more, Icons.widgets_rounded, AppColors.goldSoft),
  TutorialChapter('focus', AppTab.more, Icons.center_focus_strong_rounded,
      AppColors.primarySoft),
  // The last three are settings and facts about the app rather than tabs of
  // their own, so they are narrated over «المزيد», which is where each of them
  // is actually reached from.
  TutorialChapter('themes', AppTab.more, Icons.palette_rounded, Color(0xFFB07BD6)),
  TutorialChapter('offline', AppTab.more, Icons.cloud_off_rounded, Color(0xFF5C8A9E)),
  TutorialChapter('sources', AppTab.more, Icons.verified_rounded, AppColors.gold),
];
