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
import '../../caravan/presentation/caravan_screen.dart';
import '../../dedications/presentation/dedications_screen.dart';
import '../../downloads/presentation/screens/downloads_screen.dart';
import '../../hifz/presentation/hifz_screen.dart';
import '../../kids/presentation/journey_screen.dart';
import '../../kids/presentation/kids_corner_screen.dart';
import '../../quiz/presentation/quiz_home_screen.dart';
import '../../quran_audio/presentation/quran_audio_screen.dart';
import '../../tajweed/presentation/screens/tajweed_levels_screen.dart';
import 'tutorial_anchors.dart';

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

  /// The control to press first (an anchor id), so the stop is photographed
  /// with its real sheet or screen open rather than the button outside it.
  /// «قلنا يدخل جواها ايقونة ايقونة طالما بيشرحها» (owner, 2026-11-05).
  final String? openWith;

  const TutorialChapter(
    this.key,
    this.tab,
    this.icon,
    this.accent, {
    this.anchor,
    this.screen,
    this.whole = false,
    this.openWith,
  });
}

Widget _hifzScreen(BuildContext context) => const HifzScreen();
Widget _reciteScreen(BuildContext context) => const QuranAudioScreen();
Widget _tajweedScreen(BuildContext context) => const TajweedLevelsScreen();
Widget _kidsScreen(BuildContext context) => const KidsCornerScreen();
Widget _journeyScreen(BuildContext context) => const JourneyScreen();
Widget _quizScreen(BuildContext context) => const QuizHomeScreen();
Widget _caravanScreen(BuildContext context) => const CaravanScreen();
Widget _dedicationsScreen(BuildContext context) => const DedicationsScreen();
Widget _downloadsScreen(BuildContext context) => const DownloadsScreen();

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
  // The five display options live in the «العرض» sheet: each stop opens the
  // sheet and frames its own option inside it.
  // The Quran page's own cards come first, on the page itself (they
  // left Home on 2026-11-14); `QuranTab` shows the page for these stops.
  TutorialChapter(
    'continue_reading',
    AppTab.quran,
    Icons.bookmark_rounded,
    AppColors.gold,
    anchor: TourAnchor.continueReading,
  ),
  TutorialChapter(
    'khatma',
    AppTab.quran,
    Icons.auto_stories_rounded,
    _libraryTeal,
    anchor: TourAnchor.khatmaCard,
  ),
  TutorialChapter(
    'sunan_card',
    AppTab.quran,
    Icons.menu_book_rounded,
    _azkarGreen,
    anchor: TourAnchor.sunanCard,
  ),
  TutorialChapter(
    'quran_layout',
    AppTab.quran,
    Icons.view_agenda_rounded,
    _quranGold,
    anchor: TourAnchor.quranLayout,
    openWith: TourAnchor.quranDisplay,
  ),
  TutorialChapter(
    'quran_font',
    AppTab.quran,
    Icons.text_increase_rounded,
    _quranGold,
    anchor: TourAnchor.quranFont,
    openWith: TourAnchor.quranDisplay,
  ),
  TutorialChapter(
    'quran_theme',
    AppTab.quran,
    Icons.palette_outlined,
    _quranGold,
    anchor: TourAnchor.quranTheme,
    openWith: TourAnchor.quranDisplay,
  ),
  TutorialChapter(
    'quran_full_screen',
    AppTab.quran,
    Icons.fullscreen_rounded,
    _quranGold,
    anchor: TourAnchor.quranFullScreen,
    openWith: TourAnchor.quranDisplay,
  ),
  TutorialChapter(
    'quran_editions',
    AppTab.quran,
    Icons.auto_stories_rounded,
    _quranGold,
    anchor: TourAnchor.quranEditions,
    openWith: TourAnchor.quranDisplay,
  ),
  TutorialChapter(
    'recite',
    AppTab.quran,
    Icons.headphones_rounded,
    Color(0xFF2E9FE8),
    anchor: TourAnchor.quranRecite,
  ),
  TutorialChapter(
    'quran_search',
    AppTab.quran,
    Icons.travel_explore_rounded,
    _quranGold,
    whole: true,
    openWith: TourAnchor.quranSearch,
  ),
  TutorialChapter(
    'quran_jump',
    AppTab.quran,
    Icons.numbers_rounded,
    _quranGold,
    whole: true,
    openWith: TourAnchor.quranJump,
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

  // ── More: each stop opens the screen itself, not the card outside it ────
  // «الكامل مش بتدخل جوه الخيارات الحقيقية ده من برة بس» (owner,
  // 2026-11-05): these stops used to frame the More card that opens the
  // feature. Each now draws the feature's own screen.
  TutorialChapter(
    'more_quran_audio',
    AppTab.more,
    Icons.library_music_rounded,
    AppColors.gold,
    screen: _reciteScreen,
    whole: true,
  ),
  TutorialChapter(
    'more_tajweed',
    AppTab.more,
    Icons.record_voice_over_rounded,
    AppColors.gold,
    screen: _tajweedScreen,
    whole: true,
  ),
  TutorialChapter(
    'hifz',
    AppTab.more,
    Icons.school_rounded,
    AppColors.gold,
    screen: _hifzScreen,
    whole: true,
  ),
  TutorialChapter(
    'kids',
    AppTab.more,
    Icons.child_care_rounded,
    Color(0xFFE8A33D),
    screen: _kidsScreen,
    whole: true,
  ),
  TutorialChapter(
    'journey',
    AppTab.more,
    Icons.emoji_events_rounded,
    AppColors.gold,
    screen: _journeyScreen,
    whole: true,
  ),
  TutorialChapter(
    'quiz',
    AppTab.more,
    Icons.quiz_rounded,
    _libraryTeal,
    screen: _quizScreen,
    whole: true,
  ),
  TutorialChapter(
    'caravan',
    AppTab.more,
    Icons.landscape_rounded,
    _tasbeehCopper,
    screen: _caravanScreen,
    whole: true,
  ),
  TutorialChapter(
    'dedications',
    AppTab.more,
    Icons.volunteer_activism_rounded,
    _azkarGreen,
    screen: _dedicationsScreen,
    whole: true,
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
    screen: _downloadsScreen,
    whole: true,
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
