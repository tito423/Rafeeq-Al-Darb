/// What the guided tour covers, in what order, and what each stop points at.
///
/// Moved out of the overlay that plays it: the chapter list is the tour's
/// content — which screen, which order, which icon — and the overlay is only
/// the thing that renders it. Keeping them apart is what lets a test read the
/// list without building a widget.
///
/// ONE STOP, ONE FEATURE, FRAMED WHERE IT IS.
/// «انا عايزه يحاوط الساعة مثلا بفريم شكله جميل ويشرح عليه مش يروح لزر الشاشة
/// ويشرح منه اكتر من فيتشر. كل فيتشر واسمه يروح يحاوطها ويشرح نبذة عنها». The
/// previous tour had a stop per tab that lit the tab's navigation button and
/// described five things at once from there. Every stop below except the
/// welcome now names the one widget it is about, on the screen it lives on;
/// there is no stop that points at the navigation bar, and a feature that is
/// not on screen (a card switched off in Settings) is skipped, not replaced
/// by a nav button.
library;

import 'package:flutter/material.dart';

import '../../../app/shell/tab_request_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'tutorial_anchors.dart';
import '../../hifz/presentation/hifz_screen.dart';
import '../../quran_audio/presentation/quran_audio_screen.dart';
import '../../tajweed/presentation/screens/tajweed_levels_screen.dart';

/// One stop on the tour.
///
/// [tab] is a real `AppTab` index — the tour does not mock up a screen, it
/// opens it. [anchor] is the widget registered with `TutorialAnchor` that the
/// stop frames; it is null only for the welcome, which is about the app.
class TutorialChapter {
  final String key;
  final int tab;
  final IconData icon;
  final Color accent;
  final String? anchor;

  /// A screen that is not a tab, drawn under the tour for this stop - the
  /// stop is about that screen, not about the card that opens it.
  /// «مش كارت الحفظ والتسميع، شاشته اللي فيها الحفظ» (owner, 2026-09-25).
  final WidgetBuilder? screen;

  /// The stop is about the whole screen, not one part of it: the picture is
  /// the screen as it opens, framed all round, nothing dimmed.
  final bool whole;

  const TutorialChapter(
    this.key,
    this.tab,
    this.icon,
    this.accent, {
    this.anchor,
    this.screen,
    this.whole = false,
  });
}

Widget _hifzScreen(BuildContext context) => const HifzScreen();
Widget _reciteScreen(BuildContext context) => const QuranAudioScreen();
Widget _tajweedScreen(BuildContext context) => const TajweedLevelsScreen();

const _quranGold = AppColors.gold;
const _prayerViolet = Color(0xFF6C5FBC);
const _azkarGreen = Color(0xFF2E9D6F);
const _tasbeehCopper = Color(0xFFD4785A);
const _libraryTeal = Color(0xFF3F7A8C);

const tutorialChapters = <TutorialChapter>[
  TutorialChapter('welcome', AppTab.home, Icons.mosque_rounded, AppColors.gold),

  // ── Home ────────────────────────────────────────────────────────────────
  TutorialChapter(
    'home_clock',
    AppTab.home,
    Icons.watch_later_rounded,
    AppColors.gold,
    anchor: TourAnchor.homeClock,
  ),
  TutorialChapter(
    'home_countdown',
    AppTab.home,
    Icons.hourglass_bottom_rounded,
    _prayerViolet,
    anchor: TourAnchor.homeCountdown,
  ),
  TutorialChapter(
    'home_location',
    AppTab.home,
    Icons.location_on_rounded,
    _prayerViolet,
    anchor: TourAnchor.homeLocation,
  ),
  TutorialChapter(
    'home_slides',
    AppTab.home,
    Icons.schedule_rounded,
    _prayerViolet,
    anchor: TourAnchor.homeSlides,
  ),
  TutorialChapter(
    'continue_reading',
    AppTab.home,
    Icons.bookmark_rounded,
    AppColors.gold,
    anchor: TourAnchor.continueReading,
  ),
  TutorialChapter(
    'khatma',
    AppTab.home,
    Icons.auto_stories_rounded,
    _libraryTeal,
    anchor: TourAnchor.khatmaCard,
  ),
  TutorialChapter(
    'sunan_card',
    AppTab.home,
    Icons.menu_book_rounded,
    _azkarGreen,
    anchor: TourAnchor.sunanCard,
  ),
  TutorialChapter(
    'quote_card',
    AppTab.home,
    Icons.auto_awesome_rounded,
    Color(0xFFB07BD6),
    anchor: TourAnchor.quoteCard,
  ),
  TutorialChapter(
    'hadith_card',
    AppTab.home,
    Icons.menu_book_rounded,
    _azkarGreen,
    anchor: TourAnchor.hadithCard,
  ),

  // ── Qur'an ──────────────────────────────────────────────────────────────
  TutorialChapter(
    'quran_layout',
    AppTab.quran,
    Icons.view_agenda_rounded,
    _quranGold,
    anchor: TourAnchor.quranLayout,
  ),
  TutorialChapter(
    'quran_font',
    AppTab.quran,
    Icons.text_increase_rounded,
    _quranGold,
    anchor: TourAnchor.quranFont,
  ),
  TutorialChapter(
    'recite',
    AppTab.quran,
    Icons.headphones_rounded,
    Color(0xFF2E9FE8),
    anchor: TourAnchor.quranRecite,
  ),
  TutorialChapter(
    'quran_theme',
    AppTab.quran,
    Icons.palette_outlined,
    _quranGold,
    anchor: TourAnchor.quranTheme,
  ),
  TutorialChapter(
    'quran_full_screen',
    AppTab.quran,
    Icons.fullscreen_rounded,
    _quranGold,
    anchor: TourAnchor.quranFullScreen,
  ),
  TutorialChapter(
    'quran_search',
    AppTab.quran,
    Icons.travel_explore_rounded,
    _quranGold,
    anchor: TourAnchor.quranSearch,
  ),
  TutorialChapter(
    'quran_jump',
    AppTab.quran,
    Icons.numbers_rounded,
    _quranGold,
    anchor: TourAnchor.quranJump,
  ),
  TutorialChapter(
    'quran_editions',
    AppTab.quran,
    Icons.auto_stories_rounded,
    _quranGold,
    anchor: TourAnchor.quranEditions,
  ),

  // ── Prayer ──────────────────────────────────────────────────────────────
  TutorialChapter(
    'qibla_compass',
    AppTab.prayer,
    Icons.explore_rounded,
    _prayerViolet,
    anchor: TourAnchor.qiblaCompass,
  ),
  TutorialChapter(
    'adhan_settings',
    AppTab.prayer,
    Icons.campaign_rounded,
    _prayerViolet,
    anchor: TourAnchor.adhanSettings,
  ),
  TutorialChapter(
    'prayer_adjustments',
    AppTab.prayer,
    Icons.tune_rounded,
    _prayerViolet,
    anchor: TourAnchor.prayerAdjustments,
  ),

  // ── Adhkar ──────────────────────────────────────────────────────────────
  TutorialChapter(
    'azkar_category',
    AppTab.azkar,
    Icons.grid_view_rounded,
    _azkarGreen,
    anchor: TourAnchor.azkarCategory,
  ),

  // ── Tasbeeh ─────────────────────────────────────────────────────────────
  TutorialChapter(
    'tasbeeh_targets',
    AppTab.tasbeeh,
    Icons.flag_rounded,
    _tasbeehCopper,
    anchor: TourAnchor.tasbeehTargets,
  ),
  TutorialChapter(
    'tasbeeh_mathur',
    AppTab.tasbeeh,
    Icons.format_quote_rounded,
    _tasbeehCopper,
    anchor: TourAnchor.tasbeehMathur,
  ),

  // No library stop (owner, 2026-09-25): a store build without the library
  // is planned, and the tour must not describe a screen it may not have.

  // ── More ────────────────────────────────────────────────────────────────
  TutorialChapter(
    'more_quran_audio',
    AppTab.more,
    Icons.library_music_rounded,
    AppColors.gold,
    anchor: TourAnchor.moreQuranAudio,
  ),
  TutorialChapter(
    'more_tajweed',
    AppTab.more,
    Icons.record_voice_over_rounded,
    AppColors.gold,
    anchor: TourAnchor.moreTajweed,
  ),
  TutorialChapter(
    'focus',
    AppTab.more,
    Icons.center_focus_strong_rounded,
    AppColors.primarySoft,
    anchor: TourAnchor.moreFocus,
  ),
  TutorialChapter(
    'more_downloads',
    AppTab.more,
    Icons.download_for_offline_rounded,
    AppColors.info,
    anchor: TourAnchor.moreDownloads,
  ),
  TutorialChapter(
    'themes',
    AppTab.more,
    Icons.palette_rounded,
    Color(0xFFB07BD6),
    anchor: TourAnchor.settingsTheme,
  ),
  TutorialChapter(
    'sources',
    AppTab.more,
    Icons.verified_rounded,
    AppColors.gold,
    anchor: TourAnchor.settingsSources,
  ),
];

/// The quick tour: the app's main screens, one picture of each WHOLE screen.
///
/// «انا عايز الحاجات الرئيسيه ... الشاشات الرئيسيه سبع ثمان شاشات كده
/// الميزات الرئيسية مش كل سمة صغيرة» (owner, 2026-09-25): the previous quick
/// tour framed one small part per screen (the clock, a toolbar button). Each
/// stop now shows the screen as it opens, framed all round, in the order he
/// listed them: Home, Qur'an, Prayer, Adhkar, Tasbeeh, then memorisation,
/// recitation and tajweed. Still no library (a store build without it is
/// planned). The feature-by-feature tour stays as the «detailed» one.
const quickTutorialChapters = <TutorialChapter>[
  TutorialChapter('welcome', AppTab.home, Icons.mosque_rounded, AppColors.gold),
  TutorialChapter(
    'quick_home',
    AppTab.home,
    Icons.home_rounded,
    AppColors.gold,
    whole: true,
  ),
  TutorialChapter(
    'quick_quran',
    AppTab.quran,
    Icons.menu_book_rounded,
    _quranGold,
    whole: true,
  ),
  TutorialChapter(
    'quick_prayer',
    AppTab.prayer,
    Icons.explore_rounded,
    _prayerViolet,
    whole: true,
  ),
  TutorialChapter(
    'quick_azkar',
    AppTab.azkar,
    Icons.auto_awesome_rounded,
    _azkarGreen,
    whole: true,
  ),
  TutorialChapter(
    'quick_tasbeeh',
    AppTab.tasbeeh,
    Icons.radio_button_checked,
    _tasbeehCopper,
    whole: true,
  ),
  TutorialChapter(
    'quick_hifz',
    AppTab.more,
    Icons.school_rounded,
    AppColors.gold,
    screen: _hifzScreen,
    whole: true,
  ),
  TutorialChapter(
    'quick_recite',
    AppTab.more,
    Icons.headphones_rounded,
    Color(0xFF2E9FE8),
    screen: _reciteScreen,
    whole: true,
  ),
  TutorialChapter(
    'quick_tajweed',
    AppTab.more,
    Icons.record_voice_over_rounded,
    AppColors.gold,
    screen: _tajweedScreen,
    whole: true,
  ),
];
