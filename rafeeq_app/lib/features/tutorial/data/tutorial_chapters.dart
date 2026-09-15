/// What the guided tour covers, in what order, and what each stop points at.
///
/// Moved out of the overlay that plays it: the chapter list is the tour's
/// content — which screen, which order, which icon — and the overlay is only
/// the thing that renders it. Keeping them apart is what lets a test read the
/// list without building a widget.
///
/// «عايزه يشرح امكانيات التطبيق حتة حتة في كل شاشة ولما يشرح حاجة حوط
/// عليها». So every tab now has its own stop to introduce it, followed by a
/// stop for each part of that screen worth knowing, each lit on its own.
library;

import 'package:flutter/material.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'tutorial_anchors.dart';

/// One stop on the tour.
///
/// [tab] is a real `AppTab` index — the tour does not mock up a screen, it
/// opens it. [anchor] names a widget registered with [TutorialAnchor] when the
/// stop is about one particular part rather than a whole tab; when it is null,
/// or that part is not on screen, the tour points at the tab's own button in
/// the navigation bar, which is where the reader has to go to find it.
class TutorialChapter {
  final String key;
  final int tab;
  final IconData icon;
  final Color accent;
  final String? anchor;

  const TutorialChapter(this.key, this.tab, this.icon, this.accent,
      {this.anchor});
}

const _quranGold = AppColors.gold;
const _prayerViolet = Color(0xFF6C5FBC);
const _azkarGreen = Color(0xFF2E9D6F);
const _tasbeehCopper = Color(0xFFD4785A);
const _libraryTeal = Color(0xFF3F7A8C);

const tutorialChapters = <TutorialChapter>[
  // No target: this one is the welcome and the language chips, and there is
  // nothing on screen it is about yet.
  TutorialChapter('welcome', AppTab.home, Icons.mosque_rounded, AppColors.gold),

  // ── Home ────────────────────────────────────────────────────────────────
  TutorialChapter('home', AppTab.home, Icons.home_rounded, AppColors.primarySoft),
  TutorialChapter('prayer_card', AppTab.home, Icons.schedule_rounded,
      _prayerViolet,
      anchor: TourAnchor.prayerCard),
  TutorialChapter('continue_reading', AppTab.home, Icons.bookmark_rounded,
      AppColors.gold,
      anchor: TourAnchor.continueReading),
  TutorialChapter('khatma', AppTab.home, Icons.auto_stories_rounded,
      _libraryTeal,
      anchor: TourAnchor.khatmaCard),
  TutorialChapter('quote_card', AppTab.home, Icons.auto_awesome_rounded,
      Color(0xFFB07BD6),
      anchor: TourAnchor.quoteCard),
  TutorialChapter('hadith_card', AppTab.home, Icons.menu_book_rounded,
      _azkarGreen,
      anchor: TourAnchor.hadithCard),

  // ── Qur'an ──────────────────────────────────────────────────────────────
  TutorialChapter('quran', AppTab.quran, Icons.menu_book_rounded, _quranGold),
  TutorialChapter('quran_layout', AppTab.quran, Icons.view_agenda_rounded,
      _quranGold,
      anchor: TourAnchor.quranLayout),
  TutorialChapter('quran_font', AppTab.quran, Icons.text_increase_rounded,
      _quranGold,
      anchor: TourAnchor.quranFont),
  TutorialChapter('recite', AppTab.quran, Icons.headphones_rounded,
      Color(0xFF2E9FE8),
      anchor: TourAnchor.quranRecite),
  TutorialChapter('quran_theme', AppTab.quran, Icons.palette_outlined,
      _quranGold,
      anchor: TourAnchor.quranTheme),
  TutorialChapter('quran_full_screen', AppTab.quran, Icons.fullscreen_rounded,
      _quranGold,
      anchor: TourAnchor.quranFullScreen),
  TutorialChapter('quran_search', AppTab.quran, Icons.travel_explore_rounded,
      _quranGold,
      anchor: TourAnchor.quranSearch),
  TutorialChapter('quran_jump', AppTab.quran, Icons.numbers_rounded, _quranGold,
      anchor: TourAnchor.quranJump),
  TutorialChapter('quran_editions', AppTab.quran, Icons.auto_stories_rounded,
      _quranGold,
      anchor: TourAnchor.quranEditions),

  // ── Prayer ──────────────────────────────────────────────────────────────
  TutorialChapter('prayer', AppTab.prayer, Icons.mosque_outlined, _prayerViolet),
  TutorialChapter('qibla_compass', AppTab.prayer, Icons.explore_rounded,
      _prayerViolet,
      anchor: TourAnchor.qiblaCompass),
  TutorialChapter('adhan_settings', AppTab.prayer, Icons.campaign_rounded,
      _prayerViolet,
      anchor: TourAnchor.adhanSettings),
  TutorialChapter('prayer_adjustments', AppTab.prayer, Icons.tune_rounded,
      _prayerViolet,
      anchor: TourAnchor.prayerAdjustments),

  // ── Adhkar ──────────────────────────────────────────────────────────────
  TutorialChapter('azkar', AppTab.azkar, Icons.spa_rounded, _azkarGreen),
  TutorialChapter('azkar_category', AppTab.azkar, Icons.grid_view_rounded,
      _azkarGreen,
      anchor: TourAnchor.azkarCategory),

  // ── Tasbeeh ─────────────────────────────────────────────────────────────
  TutorialChapter('tasbeeh', AppTab.tasbeeh, Icons.radio_button_checked,
      _tasbeehCopper),
  TutorialChapter('tasbeeh_targets', AppTab.tasbeeh, Icons.flag_rounded,
      _tasbeehCopper,
      anchor: TourAnchor.tasbeehTargets),
  TutorialChapter('tasbeeh_mathur', AppTab.tasbeeh, Icons.format_quote_rounded,
      _tasbeehCopper,
      anchor: TourAnchor.tasbeehMathur),

  // ── Library ─────────────────────────────────────────────────────────────
  TutorialChapter('library', AppTab.library, Icons.local_library_rounded,
      _libraryTeal),
  TutorialChapter('library_tabs', AppTab.library, Icons.tab_rounded,
      _libraryTeal,
      anchor: TourAnchor.libraryTabs),

  // ── More ────────────────────────────────────────────────────────────────
  TutorialChapter('more', AppTab.more, Icons.widgets_rounded, AppColors.goldSoft),
  TutorialChapter('more_quran_audio', AppTab.more, Icons.library_music_rounded,
      AppColors.gold,
      anchor: TourAnchor.moreQuranAudio),
  TutorialChapter('more_tajweed', AppTab.more, Icons.record_voice_over_rounded,
      AppColors.gold,
      anchor: TourAnchor.moreTajweed),
  TutorialChapter('focus', AppTab.more, Icons.center_focus_strong_rounded,
      AppColors.primarySoft,
      anchor: TourAnchor.moreFocus),
  TutorialChapter('more_downloads', AppTab.more,
      Icons.download_for_offline_rounded, AppColors.info,
      anchor: TourAnchor.moreDownloads),
  // The last three are settings and facts about the app rather than parts of
  // one screen, so they are narrated over «المزيد», where each is reached.
  TutorialChapter('themes', AppTab.more, Icons.palette_rounded, Color(0xFFB07BD6)),
  TutorialChapter('offline', AppTab.more, Icons.cloud_off_rounded, Color(0xFF5C8A9E)),
  TutorialChapter('sources', AppTab.more, Icons.verified_rounded, AppColors.gold),
];
