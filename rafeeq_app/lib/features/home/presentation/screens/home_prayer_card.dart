part of 'home_screen.dart';

// The prayer card (clock, countdown, prayer slides), split out of
// home_screen.dart to keep it under the 800-line ceiling; `part` keeps it
// private to it.

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

    // «لو المستخدم اختار ساعة أنالوج قسّم الشاشة وصغّر العناصر الكبيرة بحيث
    // الشاشة تستوعبهم» (owner, 2026-09-26). In two columns this card has a
    // column to itself, and the clock is sized from the height that column
    // actually has: the card's fixed parts are its padding (36), the prayer
    // slides (126) and the gap above them (12), plus 8 dp of air. Seen before
    // this: sideways at the Xiaomi's size (1220x2712, 480 dpi - 407 dp high)
    // the fixed 176 dp clock sat entirely below the screen's edge.
    final twoPane = TwoPaneScroll.isTwoPane(context);
    final media = MediaQuery.of(context);
    final analogSize = twoPane
        ? (media.size.height -
                  media.padding.vertical -
                  _homeListVertical -
                  182)
              .clamp(96.0, 240.0)
        : 176.0;

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
      child: Builder(
        builder: (context) {
          final Widget clockBlock = // Tapping the clock opens the face gallery. `AnimatedSwitcher`
          // means swapping between the digital and analogue families is a
          // cross-fade in place rather than a hard cut.
          TutorialAnchor(
            id: TourAnchor.homeClock,
            child: Builder(
              builder: (clockContext) => InkWell(
                borderRadius: BorderRadius.circular(20),
                // `clockContext` is the tap target, so the gallery grows out of
                // the clock itself rather than out of nowhere.
                onTap: () =>
                    ClockGallerySheet.show(context, origin: clockContext),
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
                              size: analogSize,
                              meridiem: _meridiem(clock),
                              arabicDigits: arabic,
                              ink: hero.onSurface,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final Widget? countdownBlock = shown == null
              ? null
              : TutorialAnchor(
              id: TourAnchor.homeCountdown,
              child: GestureDetector(
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
                          ? hero
                                .accent(prayerSlideColors[shown.$1]!)
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
                          (child.key as ValueKey<bool>).value ==
                          showingPrevious;
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
                                  color: hero.accent(
                                    prayerSlideColors[shown.$1]!,
                                  ),
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
            );
          final Widget? locationBlock = location.isEmpty
              ? null
              : TutorialAnchor(
              id: TourAnchor.homeLocation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 14, color: hero.onSurfaceFaint),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: TextStyle(color: hero.onSurfaceFaint, fontSize: 12),
                  ),
                ],
              ),
            );
          if (twoPane) {
            // Split: the clock on one side, the countdown and the place on
            // the other, so the whole card - clock and prayer slides -
            // stands inside one screen's height (see `analogSize`).
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: clockBlock,
                        ),
                      ),
                    ),
                    if (countdownBlock != null || locationBlock != null) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ?countdownBlock,
                            if (locationBlock != null) ...[
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: locationBlock,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TutorialAnchor(
                  id: TourAnchor.homeSlides,
                  child: PrayerSlides(times: widget.times, nextKey: next?.$1),
                ),
              ],
            );
          }
          return Column(
            children: [
              clockBlock,
              if (countdownBlock != null) ...[
                const SizedBox(height: 12),
                countdownBlock,
              ],
              if (locationBlock != null) ...[
                const SizedBox(height: 8),
                locationBlock,
              ],
              const SizedBox(height: 12),
              TutorialAnchor(
                id: TourAnchor.homeSlides,
                child: PrayerSlides(times: widget.times, nextKey: next?.$1),
              ),
            ],
          );
        },
      ),
    );
  }
}
