import 'dart:async';
import 'dart:math' as math;

import '../../../../core/i18n/hijri_months.dart';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../../core/theme/hero_surface.dart';
import '../../../hadith_daily/presentation/daily_hadith_card.dart';
import '../../../quotes/presentation/widgets/home_quote_card.dart';
import '../../../settings/data/reader_name_provider.dart';
import '../../../settings/presentation/widgets/reader_name_sheet.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../khatma/presentation/khatma_card.dart';
import '../../../quran/presentation/widgets/continue_reading_card.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_card.dart';
import '../../data/prayer_controller.dart';

/// Home tab — real prayer times (once location is granted) + quick access.
class HomeScreen extends ConsumerStatefulWidget {
  /// [onNavigate] is the shell tab index — see `AppTab`
  /// (`app/shell/tab_request_provider.dart`) for the named constants.
  final void Function(int tab) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(prayerControllerProvider.notifier).refresh(),
    );
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
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 4),
                const _HeaderCard(),
                const SizedBox(height: 16),
                // The four cards the guided tour stops on, each wrapped so it
                // can say where it is rather than describing it from a
                // distance. TutorialAnchor costs one GlobalKey and nothing
                // else - it does not rebuild and does not know the tour is
                // running.
                TutorialAnchor(
                  id: TourAnchor.prayerCard,
                  child: _PrayerCard(state: prayerState),
                ),
                const SizedBox(height: 16),
                // P3‑4: split out of KhatmaCard's own "اقرأ اليوم" nudge —
                // the reference shows a "متابعة القراءة" bookmark-style card
                // ("where you left off") as its own thing, separate from the
                // khatma daily-goal card below it. Renders nothing when
                // there's no real last-read page yet (see its own doc).
                const TutorialAnchor(
                  id: TourAnchor.continueReading,
                  child: ContinueReadingCard(),
                ),
                const SizedBox(height: 16),
                const TutorialAnchor(
                  id: TourAnchor.khatmaCard,
                  child: KhatmaCard(),
                ),
                const SizedBox(height: 16),
                const SunanSuwarCard(),
                const SizedBox(height: 16),
                // «حط كارت مقولة اليوم … في الشاشة الرئيسية فوق حديث
                // اليوم». It draws nothing at all when the setting is off.
                const TutorialAnchor(
                  id: TourAnchor.quoteCard,
                  child: HomeQuoteCard(),
                ),
                const SizedBox(height: 16),
                const TutorialAnchor(
                  id: TourAnchor.hadithCard,
                  child: DailyHadithCard(),
                ),
                const SizedBox(height: 12),
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

  /// [offsetDays] is the reader's own correction (see `PrayerAdjustments`) —
  /// the Hijri date is set by moon sighting, so an arithmetic calendar can sit
  /// a day either side of what a locality actually announced.
  String _hijriLine(String localeCode, int offsetDays) {
    final lang = localeCode == 'ar' ? 'ar' : 'en';
    HijriCalendar.setLocal(lang);
    final h = HijriCalendar.fromDate(
      DateTime.now().add(Duration(days: offsetDays)),
    );
    // The month names and the era suffix come from the locale files, via
    // `hijriMonthName`. The two tables that used to sit here (and a second
    // copy in the prayer notification) covered Arabic and English only, so a
    // French or Urdu reader was shown the English transliteration.
    return '${h.hDay} ${hijriMonthName(h.hMonth)} ${h.hYear}'
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Same teal/gold brand identity in both themes, just re-pitched: a
    // parchment-toned gradient + dark ink text for Light, the original
    // near-black/navy/violet + light text for Dark and RGB.
    final gradient = isLight
        ? const [Color(0xFFFBF6E9), Color(0xFFF3ECD8), Color(0xFFEFE6D2)]
        : const [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)];
    final hijriColor = isLight ? const Color(0xFF0E7C6B) : const Color(0xFF7DEBDA);
    final welcomeColor = isLight ? const Color(0xFF1D2C26) : Colors.white;
    final readerName = ref.watch(readerNameProvider);
    final gregorianColor = isLight ? const Color(0xFF9A7A15) : const Color(0xFFD4AF37);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _hijriLine(context.locale.languageCode,
                    ref.watch(prayerAdjustmentsProvider).hijriOffsetDays),
                maxLines: 1,
                style: TextStyle(
                  color: hijriColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
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
            onAction: () =>
                ref.read(prayerControllerProvider.notifier).refresh(),
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

/// P3‑4/P3‑22: the animated, interactive prayer card — rebuilt to match a
/// video the owner sent of an earlier working build of this same app
/// (`design_refs/old_app_video.mp4`, frames in `old_app_frames/`), which
/// turned out to be a much more precise target than the static
/// `ref_home.jpg` mock: a live ticking clock, a "next prayer + countdown"
/// pill, a real location line, and coloured per-prayer slides with a badge
/// on the next one.
///
/// The clock itself is a tap target: it opens the twenty-face gallery
/// (`ClockGallerySheet`) and re-renders with the chosen face the moment one
/// is picked. The six timings below it are `PrayerSlides` — a focus-scaled
/// carousel whose centred slide expands into a full editor for that prayer.
class _PrayerTimesTable extends ConsumerStatefulWidget {
  final PrayerTimes times;
  const _PrayerTimesTable({required this.times});

  @override
  ConsumerState<_PrayerTimesTable> createState() => _PrayerTimesTableState();
}

class _PrayerTimesTableState extends ConsumerState<_PrayerTimesTable> {
  /// «عايز لما أضغط على عدّاد الصلاة القادمة التنازلي يغيّر ويعرض إيه على
  /// الصلاة السابقة، أنيميتد برضه وبشكل روعة». One tap on the counter box
  /// turns it over: the same box, the previous prayer's name and colour, and
  /// the same three units counting **up** from when it came in. Tapping again
  /// turns it back. Nothing else on the card moves.
  bool _showPrevious = false;

  /// AM/PM in the app's own language — never shown in 24-hour mode.
  String? _meridiem(ClockSettings cs) {
    if (!cs.use12Hour) return null;
    return DateTime.now().hour < 12 ? 'home.am'.tr() : 'home.pm'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final service = PrayerTimesService();
    final now = DateTime.now();
    final next = service.nextPrayer(widget.times, now);
    final previous = service.previousPrayer(widget.times, now);
    // The flipped side needs a previous prayer to show. On a phone whose
    // times have not arrived yet there is none, and the box stays on the
    // countdown rather than offering a face with nothing on it.
    final shown = _showPrevious && previous != null ? previous : next;
    final showingPrevious = _showPrevious && previous != null;
    final clock = ref.watch(clockSettingsProvider);
    final arabic = context.locale.languageCode == 'ar';
    final location = [
      widget.times.cityName,
      widget.times.countryName,
    ].where((s) => s.isNotEmpty).join('، ');

    // P3‑4 pinned this card to one fixed dark gradient in every theme. The
    // owner has since asked for it to follow the theme instead, so the
    // gradient, the border, the glow and every text tone now come from
    // [HeroSurface] — which keeps the dark and RGB themes exactly as they
    // were and adds a light member of the same family.
    final hero = HeroSurface.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hero.gradient,
        ),
        border: Border.all(color: hero.border),
        // A cast under the card so it lifts off the page instead of sitting
        // flat on it — the clock is the first thing on the screen and should
        // read as the hero it is.
        boxShadow: [
          BoxShadow(
            color: hero.glow,
            blurRadius: 26,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tapping the clock opens the face gallery. `AnimatedSwitcher`
          // means swapping between the digital and analogue families is a
          // cross-fade in place rather than a hard cut.
          Builder(
            builder: (clockContext) => InkWell(
            borderRadius: BorderRadius.circular(20),
            // `clockContext` is the tap target, so the gallery grows out of
            // the clock itself rather than out of nowhere.
            onTap: () => ClockGallerySheet.show(context, origin: clockContext),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(
                    '${clock.style}-${clock.digitalFace}-${clock.analogFace}-'
                    '${clock.use12Hour}-${clock.showSeconds}',
                  ),
                  child: clock.style == ClockStyle.digital
                      ? DigitalClockFaceView(
                          face: clock.digitalFace,
                          use12Hour: clock.use12Hour,
                          showSeconds: clock.showSeconds,
                          arabicDigits: arabic,
                          meridiem: _meridiem(clock),
                          height: 78,
                          // The face is drawn ON this card, so it takes the
                          // card own ink — white numerals were invisible on
                          // the light theme.
                          ink: hero.onSurface,
                        )
                      : AnalogClockFaceView(
                          face: clock.analogFace,
                          size: 176,
                          meridiem: _meridiem(clock),
                          arabicDigits: arabic,
                          ink: hero.onSurface,
                        ),
                ),
              ),
            ),
            ),
          ),
          if (shown != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: previous == null
                  ? null
                  : () => setState(() => _showPrevious = !_showPrevious),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
                decoration: BoxDecoration(
                  color: hero.scrim,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: showingPrevious
                        ? hero.accent(prayerSlideColors[shown.$1]!)
                            .withValues(alpha: 0.55)
                        : hero.hairline,
                  ),
                ),
                // The two faces swap on a half-turn about the vertical axis,
                // so the box reads as one thing turning over rather than two
                // things cross-fading. `AnimatedSwitcher` drives both halves
                // of the turn; the outgoing face is held at the far side
                // (`0.5 → 1`) while the incoming one comes back to flat.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final incoming =
                        (child.key as ValueKey<bool>).value == showingPrevious;
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final t = incoming
                            ? (1 - animation.value) * -0.5
                            : (1 - animation.value) * 0.5;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateY(t * math.pi),
                          child: Opacity(
                            opacity: animation.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  child: Column(
                    key: ValueKey<bool>(showingPrevious),
                    children: [
                      Text.rich(
                        TextSpan(
                          text: showingPrevious
                              ? '${'home.previous_prayer'.tr()}: '
                              : '${'home.next_prayer'.tr()}: ',
                          style: TextStyle(color: hero.onSurfaceMuted),
                          children: [
                            TextSpan(
                              text: prayerSlideLabelKeys[shown.$1]!.tr(),
                              style: TextStyle(
                                // Toned for this ground: the raw violet
                                // measured 2.43 : 1 on the dark card
                                // (CLAUDE.md #15).
                                color:
                                    hero.accent(prayerSlideColors[shown.$1]!),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      PrayerCountdown(
                        target: shown.$2,
                        accent: prayerSlideColors[shown.$1]!,
                        arabicDigits: arabic,
                        elapsed: showingPrevious,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on,
                    size: 14, color: hero.onSurfaceFaint),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: TextStyle(color: hero.onSurfaceFaint, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrayerSlides(times: widget.times, nextKey: next?.$1),
        ],
      ),
    );
  }

}
