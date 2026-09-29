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
    // slides (126) and the gap above them (12), plus 26 dp of air (8 left
    // the card's bottom edge under the viewport at the Xiaomi's size). Seen before
    // this: sideways at the Xiaomi's size (1220x2712, 480 dpi - 407 dp high)
    // the fixed 176 dp clock sat entirely below the screen's edge.
    final twoPane = TwoPaneScroll.isTwoPane(context);
    final media = MediaQuery.of(context);
    // The photograph panel is 236 dp tall on a phone held upright. Sideways
    // (two columns) this card has a column to itself, and the panel takes the
    // height that column really has once the card's fixed parts are taken
    // off: its padding (36), the prayer slides (126), the gap above them (12)
    // and 26 dp of air. Everything inside it scales down to fit.
    final panelHeight = twoPane
        ? (media.size.height -
                  media.padding.vertical -
                  _homeListVertical -
                  126 -
                  12 -
                  36 -
                  26)
              .clamp(150.0, 340.0)
        : 236.0;
    final analogSize = twoPane ? (panelHeight - 44).clamp(90.0, 240.0) : 132.0;

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
          // The clock and the next prayer stand on a photograph of a mosque
          // at the hour of that prayer (owner, 2026-09-29): the prayer's name
          // and countdown at the start side, the clock at the other. The
          // photograph is always darkened, so the panel reads the same in
          // every theme and takes the DARK hero palette (`onPhoto`).
          final onPhoto = HeroSurface.dark;
          final Widget clockBlock = TutorialAnchor(
            id: TourAnchor.homeClock,
            child: Builder(
              builder: (clockContext) => InkWell(
                borderRadius: BorderRadius.circular(20),
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
                              ink: onPhoto.onSurface,
                            )
                          : AnalogClockFaceView(
                              face: clock.analogFace,
                              size: analogSize,
                              meridiem: _meridiem(clock),
                              arabicDigits: arabic,
                              ink: onPhoto.onSurface,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );

          // The name block: the prayer's icon, «الصلاة القادمة», its name and
          // the live counter. One tap turns it over to the PREVIOUS prayer
          // (kept from the earlier card, see [_showPrevious]).
          final Widget? nameBlock = shown == null
              ? null
              : TutorialAnchor(
                  id: TourAnchor.homeCountdown,
                  child: RemoteTap(
                    onTap: previous == null
                        ? null
                        : () => setState(() => _showPrevious = !_showPrevious),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PrayerBadge(
                            icon: prayerHeroIcons[shown.$1]!,
                            color: onPhoto.accent(prayerSlideColors[shown.$1]!),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            showingPrevious
                                ? 'home.previous_prayer'.tr()
                                : 'home.next_prayer'.tr(),
                            style: TextStyle(
                              color: onPhoto.onSurfaceMuted,
                              fontSize: 13,
                              shadows: _photoShadow,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              prayerSlideLabelKeys[shown.$1]!.tr(),
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                fontFamily: arabic ? 'AmiriQuran' : null,
                                shadows: _photoShadow,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: onPhoto.hairline),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PrayerCountdown(
                                target: shown.$2,
                                accent: prayerSlideColors[shown.$1]!,
                                arabicDigits: arabic,
                                elapsed: showingPrevious,
                              ),
                            ),
                          ),
                        ],
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
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: onPhoto.onSurfaceMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onPhoto.onSurfaceMuted,
                            fontSize: 12,
                            shadows: _photoShadow,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

          // The panel: photograph, scrim, then the two sides.
          final Widget panel = SizedBox(
            // Full width even when the content inside scales down.
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: panelHeight,
                  maxHeight: twoPane ? panelHeight : double.infinity,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 700),
                        child: SizedBox.expand(
                          key: ValueKey(shown?.$1 ?? 'none'),
                          child: shown == null
                              ? const ColoredBox(color: Color(0xFF0B0F1A))
                              : Image.asset(
                                  'assets/prayer_backgrounds/${shown.$1}.jpg',
                                  fit: BoxFit.cover,
                                  cacheWidth: 1000,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFF0B0F1A),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // 0.6 - 0.72 black: measured against each photograph's
                    // brightest 0.5 % (worst: Asr 5.7 : 1 for white text).
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Everything on the photograph is drawn with the dark theme,
                    // whatever the app's own is: the countdown and the clock
                    // faces read `Theme` for their tones.
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(brightness: Brightness.dark),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        // Sideways the panel's height is fixed to what the column
                        // has, so its content scales down as one piece instead of
                        // overflowing (seen on emulator-5554 rotated, 2026-09-29:
                        // «BOTTOM OVERFLOWED BY 61 PIXELS» over the countdown).
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final Widget content = Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    if (nameBlock != null)
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: nameBlock,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    // The clock takes what it needs but never more
                                    // than 46 % of the panel, so a wide digital face
                                    // scales down instead of crowding the name.
                                    Flexible(
                                      flex: 0,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: box.maxWidth * 0.46,
                                          maxHeight: panelHeight - 50,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: clockBlock,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (locationBlock != null) ...[
                                  const SizedBox(height: 10),
                                  locationBlock,
                                ],
                              ],
                            );
                            return twoPane
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: box.maxWidth,
                                      child: content,
                                    ),
                                  )
                                : content;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          return Column(
            children: [
              panel,
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

const _photoShadow = [Shadow(color: Color(0xCC000000), blurRadius: 6)];

/// The prayer's icon in a soft glowing disc.
class _PrayerBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _PrayerBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.black.withValues(alpha: 0.35),
      border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14),
      ],
    ),
    child: Icon(icon, color: color, size: 26),
  );
}
