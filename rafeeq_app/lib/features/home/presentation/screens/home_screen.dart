import '../../../../core/widgets/remote_tap.dart';
import '../../../../core/widgets/two_pane_scroll.dart';
import '../../data/on_this_day_repository.dart';
import '../widgets/header_quick_actions.dart';
import '../../../../core/services/official_hijri.dart';
import '../../../../core/services/official_hijri_provider.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../../core/i18n/hijri_months.dart';
import '../../../../core/utils/digits.dart' as digits;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_service.dart';

import 'package:hijri/hijri_calendar.dart';

import '../../../adhan/data/prayer_adjustments_provider.dart';
import '../../data/clock_settings_provider.dart';
import '../widgets/analog_clock_faces.dart';
import '../widgets/clock_gallery_sheet.dart';
import '../widgets/digital_clock_faces.dart';
import '../widgets/prayer_countdown.dart';
import '../widgets/prayer_slides.dart';

import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/models/prayer_times.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/hero_surface.dart';
import '../../../hadith_daily/presentation/daily_hadith_card.dart';
import '../../../quotes/presentation/widgets/home_quote_card.dart';
import '../../../settings/data/reader_name_provider.dart';
import '../widgets/on_this_day_sheet.dart';
import '../../../settings/presentation/widgets/reader_name_sheet.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../khatma/presentation/khatma_card.dart';
import '../../../quran/presentation/widgets/continue_reading_card.dart';
import '../../../sunan_suwar/presentation/selected_surahs_card.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_card.dart';
import '../../data/prayer_controller.dart';

part 'home_prayer_card.dart';

/// Home tab — real prayer times (once location is granted) + quick access.
class HomeScreen extends ConsumerStatefulWidget {
  /// [onNavigate] is the shell tab index — see `AppTab`
  /// (`app/shell/tab_request_provider.dart`) for the named constants.
  final void Function(int tab) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// The home list's top + bottom padding (24 + 32), which the clock's size
/// budget subtracts.
const double _homeListVertical = 56;

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // No `refresh()` here any more: it replaced the controller's instant
    // first answer (drawn from the last saved position) with a wait for a
    // fresh GPS fix, which is what kept the card a spinner for up to 15 s.
    // The controller refreshes itself in the background on first load.
    //
    // The two date sheets read a year of events each; parse them now, in
    // the background, so a tap on a date finds them ready.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      ref.read(onThisDayHijriProvider.future).ignore();
      ref.read(onThisDayProvider(context.locale.languageCode).future).ignore();
    });
    // This used to tick every second, with a comment saying the live HH:MM:SS
    // clock needed it. It does not: `DigitalClockFaceView` drives itself from
    // its own `Ticker`, and `PrayerCountdown` has its own one-second timer.
    // What this `setState` actually did was rebuild the **whole** Home tree
    // sixty times a minute — the ornate frames and their `CustomPaint`s, the
    // hadith card, the sunan card, the prayer card, all of it — to move a
    // number that two widgets were already moving themselves.
    //
    // What is genuinely left to it is minute-scale: the AM/PM label, the day
    // name, the Hijri line, and which prayer is next. Thirty seconds is finer
    // than any of those need.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayerState = ref.watch(prayerControllerProvider);
    final twoPane = TwoPaneScroll.isTwoPane(context);

    return HomeNavigate(
      onNavigate: widget.onNavigate,
      child: Scaffold(
        // P3‑4: the old AppBar just repeated "app.name" as a plain title —
        // dropped in favour of the header card below carrying the app's
        // identity through its own presence, freeing a full row of vertical
        // space for content.
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(prayerControllerProvider.notifier).refresh(),
            // Sideways, two columns (see `TwoPaneScroll`): what is happening
            // now - the date and the prayer - on the start side, what to read
            // on the other.
            child: TwoPaneScroll(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              start: [
                // In two columns the prayer card has the start column to
                // itself so it fits the height whole; the header card opens
                // the other column instead.
                if (!twoPane) const _HeaderCard(),
                // The four cards the guided tour stops on, each wrapped so it
                // can say where it is rather than describing it from a
                // distance. TutorialAnchor costs one GlobalKey and nothing
                // else - it does not rebuild and does not know the tour is
                // running.
                TutorialAnchor(
                  id: TourAnchor.prayerCard,
                  child: _PrayerCard(state: prayerState),
                ),
              ],
              end: [
                if (twoPane) const _HeaderCard(),
                // P3‑4: split out of KhatmaCard's own "اقرأ اليوم" nudge —
                // the reference shows a "متابعة القراءة" bookmark-style card
                // ("where you left off") as its own thing, separate from the
                // khatma daily-goal card below it. Renders nothing when
                // there's no real last-read page yet (see its own doc).
                TutorialAnchor(
                  id: TourAnchor.continueReading,
                  child: const ContinueReadingCard(),
                ),
                TutorialAnchor(
                  id: TourAnchor.khatmaCard,
                  child: const KhatmaCard(),
                ),
                TutorialAnchor(
                  id: TourAnchor.sunanCard,
                  child: const SunanSuwarCard(),
                ),
                const SelectedSurahsCard(),
                // «حط كارت مقولة اليوم … في الشاشة الرئيسية فوق حديث
                // اليوم». It draws nothing at all when the setting is off.
                TutorialAnchor(
                  id: TourAnchor.quoteCard,
                  child: const HomeQuoteCard(),
                ),
                TutorialAnchor(
                  id: TourAnchor.hadithCard,
                  child: const DailyHadithCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// P3‑4: replaces the old "رفيق الدرب" title + time-of-day greeting with a
/// single fixed card — the Hijri date at the row's start, a centred
/// welcome, the Gregorian date at the end. "Start"/"end" (not literal
/// left/right) so this reads correctly mirrored in both RTL and LTR
/// locales without special-casing either.
///
/// P3‑44: this used to hard-code the dark navy/teal/gold palette
/// regardless of theme ("same look in every app theme" — a deliberate
/// choice at the time). Real-device feedback in Light theme called that
/// out directly: a fixed dark card reads as a rendering bug sitting above
/// an otherwise-light screen, not a brand accent. Now themed: the same
/// teal/gold accent identity, just on a light parchment-toned gradient
/// with dark text when `Theme.of(context).brightness` is light.
///
/// The welcome text is honestly generic ("مرحبا بك") rather than a fake
/// name — P3‑5 (login, answered: optional) hasn't been built yet, so there
/// is no real username to show for a guest session. Once accounts exist,
/// swap this for the signed-in user's real name; do **not** invent one in
/// the meantime — that would be exactly the kind of placeholder data rule
/// 1 forbids.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard();

  /// Height of the band the dates sit in: room for weekday + date.
  static const double _dateBand = 36;

  /// [offsetDays] is the reader's own correction (see `PrayerAdjustments`) —
  /// the Hijri date is set by moon sighting, so an arithmetic calendar can sit
  /// a day either side of what a locality actually announced.
  String _hijriLine(String localeCode, int offsetDays) {
    final lang = localeCode == 'ar' ? 'ar' : 'en';
    HijriCalendar.setLocal(lang);
    // The declared calendar (see `OfficialHijri`), so the card and the
    // fasting reminders never name two different days.
    final (hYear, hMonth, hDay) =
        OfficialHijri.dateOf(DateTime.now(), offsetDays: offsetDays);
    // The month names and the era suffix come from the locale files, via
    // `hijriMonthName`. The two tables that used to sit here (and a second
    // copy in the prayer notification) covered Arabic and English only, so a
    // French or Urdu reader was shown the English transliteration.
    // The digits follow the language too. The header used to print «6 ربيع
    // الآخر 1448 هـ» in Latin figures while the sheet it opens printed
    // «٦ ربيع الآخر ١٤٤٨ هـ» — the same date, twice, in two scripts, one
    // above the other on screen.
    return '${digits.localizeDigits('$hDay', localeCode)} '
        '${hijriMonthName(hMonth)} '
        '${digits.localizeDigits('$hYear', localeCode)}'
        '${'hijri.suffix'.tr()}';
  }

  String _gregorianLine(BuildContext context) {
    final now = DateTime.now();
    return DateFormat.yMMMd(context.locale.toString()).format(now);
  }

  /// The weekday's own name ("السبت", "Saturday") — asked for explicitly, and
  /// taken from the locale's own calendar data rather than a hand-written
  /// list, so it is right in all seven locales.
  String _weekdayLine(BuildContext context) =>
      DateFormat.EEEE(context.locale.toString()).format(DateTime.now());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redraws the Hijri line once the declared calendar has loaded.
    ref.watch(officialHijriProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Same teal/gold brand identity in both themes, just re-pitched: a
    // parchment-toned gradient + dark ink text for Light, the original
    // near-black/navy/violet + light text for Dark and RGB.
    final gradient = isLight
        ? const [Color(0xFFFBF6E9), Color(0xFFF3ECD8), Color(0xFFEFE6D2)]
        : const [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)];
    // Light values measured against the gradient's darkest stop #EFE6D2
    // (2026-09-25): Hijri 4.11 : 1, Gregorian 3.27 : 1 - both under 4.5.
    // readableOn deepens them just enough; the dark values already pass.
    final hijriColor = isLight
        ? readableOn(const Color(0xFF0E7C6B), gradient.last)
        : const Color(0xFF7DEBDA);
    final welcomeColor = isLight ? const Color(0xFF1D2C26) : Colors.white;
    final readerName = ref.watch(readerNameProvider);
    final gregorianColor = isLight
        ? readableOn(const Color(0xFF9A7A15), gradient.last)
        : const Color(0xFFD4AF37);
    return Container(
      // «وسّع كارت التاريخ ومرحبًا شوية».
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        // «ممكن تكوّر شكل الكارت ده».
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(
          color: const Color(0xFF15C7B0).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      // P3‑54: the settings gear was removed from this card entirely — every
      // option it reached now lives on the dedicated "المزيد" (More) bottom-
      // nav tab, so this card is purely a date/greeting header again.
      //
      // Three balanced cells: the full Hijri date (start), the welcome in the
      // exact centre, the full Gregorian date (end). Each cell is an
      // `Expanded` wrapping a `BoxFit.scaleDown` `FittedBox`, so a long
      // translated greeting (fr "Bienvenue", ru "Добро пожаловать") or a wide
      // month name only ever shrinks to fit — it can never wrap mid-word or
      // trip a `RenderFlex overflowed` and break the card's shape. The side
      // cells share the same flex so the welcome stays optically centred.
      // «لما اضغط ع التاريخ الهجري يعرض تاريخ اليوم واهم الاحداث اللي
      // حصلت فيه … وبالنسبة للتاريخ الميلادي عايز لما اضغط عليه يعرض
      // تاريخ اليوم الميلادي» — so the two dates are two controls now. They
      // used to share one InkWell over the whole card and open one sheet,
      // which meant tapping «١٧ رمضان» showed events keyed to 8 March.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => showHijriDaySheet(
                context,
                hijriOffset: ref
                    .read(prayerAdjustmentsProvider)
                    .hijriOffsetDays,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Both dates sit in a band of the same height, so the
                  // buttons under them line up whether the Gregorian side
                  // takes one line or two (English: «Saturday / Sep 19»).
                  SizedBox(
                    height: _dateBand,
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _hijriLine(
                            context.locale.languageCode,
                            ref.watch(prayerAdjustmentsProvider).hijriOffsetDays,
                          ),
                          maxLines: 1,
                          style: TextStyle(
                            color: hijriColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ThemeQuickButton(color: hijriColor),
                  const SizedBox(height: 6),
                  SupportQuickButton(color: hijriColor),
                ],
              ),
            ),
          ),
          // A gap on each side of the greeting. Without it the three cells
          // are only separated by whatever slack the text leaves, and in
          // Russian there is none: «27 Раби аль-авваль 1448 г.х.» filled its
          // cell edge to edge and «Добро пожаловать» started against it with
          // no space at all, seen on emulator-5554 during the Russian sweep.
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'home.welcome_guest'.tr(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: welcomeColor,
                      // The AmiriQuran calligraphy face is only right for the
                      // Arabic "مرحبًا بك"; Latin locales use the app's normal
                      // (narrower, Latin-tuned) font. FittedBox now guarantees no
                      // overflow either way, but keeping the right face per script
                      // still reads better than scaling a mismatched one down.
                      fontFamily: context.locale.languageCode == 'ar'
                          ? 'AmiriQuran'
                          : null,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // «ويتكتب الاسم ده بزخرفة جميلة جدًا جنب أو تحت مرحبًا بك».
                  // Nothing is drawn for a reader who has not given one - the
                  // greeting stays exactly as it always was rather than
                  // inventing a name, which is what the comment above this
                  // card warned against for as long as it has existed.
                  if (readerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ReaderNameFlourish(name: readerName, fontSize: 19),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => showGregorianDaySheet(
                context,
                hijriOffset: ref
                    .read(prayerAdjustmentsProvider)
                    .hijriOffsetDays,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: _dateBand,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      _weekdayLine(context),
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: gregorianColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      _gregorianLine(context),
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: gregorianColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LanguageQuickButton(color: gregorianColor),
                  const SizedBox(height: 6),
                  SettingsQuickButton(color: gregorianColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends ConsumerWidget {
  final AsyncValue<PrayerTimesResult> state;
  const _PrayerCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return state.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _MessageCard(
        icon: Icons.error_outline,
        message: 'errors.generic'.tr(),
      ),
      data: (result) {
        if (result.locationDenied) {
          // P3‑43 #10: this used to be static text with no way to act on
          // it — a real button that actually triggers the OS permission
          // prompt, reusing `LocationService.getCurrentPosition()`'s own
          // existing `Geolocator.requestPermission()` call inside
          // `PrayerController.refresh()` rather than a second, separate
          // permission-request path.
          return _MessageCard(
            icon: Icons.location_off_outlined,
            message: 'home.location_needed'.tr(),
            actionLabel: 'home.enable_location'.tr(),
            onAction: () async {
              // Permission, a refusal for good, and a phone with location
              // switched off are all handled there. Coming back from the
              // settings it opens re-fetches through AppShell's resume check.
              if (await LocationService.instance.askToEnable()) {
                await ref.read(prayerControllerProvider.notifier).refresh();
              }
            },
          );
        }
        if (result.times.isEmpty) {
          return _MessageCard(
            icon: Icons.wifi_off,
            message: 'errors.offline'.tr(),
          );
        }
        return _PrayerTimesTable(times: result.times);
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _MessageCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
