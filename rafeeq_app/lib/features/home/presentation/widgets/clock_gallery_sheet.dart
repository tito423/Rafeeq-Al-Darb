import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/hero_surface.dart';
import '../../../../core/widgets/card_route.dart';
import '../../data/clock_settings_provider.dart';
import 'analog_clock_faces.dart';
import 'digital_clock_faces.dart';

/// The clock gallery — twenty live faces, ten digital and ten analogue.
///
/// Every tile is the *real* face running on the real current time, not a
/// static thumbnail: what the reader taps is exactly what lands on the Home
/// card, and the card updates the moment they tap it (the gallery writes
/// straight through `clockSettingsProvider`, which Home watches).
///
/// It opens as a [CardScreen] rather than a bottom sheet, so it grows out of
/// the clock that was tapped and leaves Home visible (blurred) behind it.
const Color _accent = Color(0xFF15C7B0);

class ClockGallerySheet extends ConsumerStatefulWidget {
  const ClockGallerySheet({super.key});

  static Future<void> show(BuildContext context, {BuildContext? origin}) =>
      showCardScreen<void>(
        context: context,
        originContext: origin,
        child: const ClockGallerySheet(),
      );

  @override
  ConsumerState<ClockGallerySheet> createState() => _ClockGallerySheetState();
}

class _ClockGallerySheetState extends ConsumerState<ClockGallerySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex:
          ref.read(clockSettingsProvider).style == ClockStyle.digital ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(clockSettingsProvider);
    final notifier = ref.read(clockSettingsProvider.notifier);
    final arabic = context.locale.languageCode == 'ar';
    final meridiem = cs.use12Hour
        ? (DateTime.now().hour < 12 ? 'home.am'.tr() : 'home.pm'.tr())
        : null;

    return CardScreen(
      title: 'home.clock_gallery_title'.tr(),
      subtitle: 'home.clock_gallery_subtitle'.tr(),
      icon: Icons.schedule_rounded,
      accent: const Color(0xFF15C7B0),
      maxWidth: 520,
      maxHeightFraction: 0.9,
      // The grids scroll themselves inside a TabBarView, so the card must not
      // wrap them in a scroll view of its own.
      scrollable: false,
      footer: _bothFamiliesOptions(cs, notifier),
      child: Column(
          children: [
            // ── The live hero: whatever is selected right now ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: SizedBox(
                key: ValueKey(
                  '${cs.style}-${cs.digitalFace}-${cs.analogFace}-'
                  '${cs.use12Hour}-${cs.showSeconds}',
                ),
                height: 150,
                child: Center(
                  child: cs.style == ClockStyle.digital
                      ? DigitalClockFaceView(
                          face: cs.digitalFace,
                          use12Hour: cs.use12Hour,
                          showSeconds: cs.showSeconds,
                          arabicDigits: arabic,
                          meridiem: meridiem,
                          height: 92,
                        )
                      : AnalogClockFaceView(
                          face: cs.analogFace,
                          size: 142,
                          meridiem: meridiem,
                          arabicDigits: arabic,
                        ),
                ),
              ),
            ),

            // Every colour below comes from the card's own surface. These were
            // white — right on the dark card, and invisible on the light one:
            // the owner's photo shows «عقارب», «رقمية», every face name and
            // both switch labels as white on pale mint.
            TabBar(
              controller: _tabs,
              indicatorColor: HeroSurface.of(context).accent(_accent),
              labelColor: HeroSurface.of(context).onSurface,
              unselectedLabelColor: HeroSurface.of(context).onSurfaceMuted,
              tabs: [
                Tab(text: 'home.clock_digital'.tr()),
                Tab(text: 'home.clock_analog'.tr()),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _FaceGrid(
                    itemCount: DigitalClockFace.values.length,
                    aspectRatio: 1.45,
                    isSelected: (i) =>
                        cs.style == ClockStyle.digital &&
                        cs.digitalFace == DigitalClockFace.values[i],
                    label: (i) => DigitalClockFace.values[i].labelKey.tr(),
                    onTap: (i) =>
                        notifier.setDigitalFace(DigitalClockFace.values[i]),
                    preview: (i) => DigitalClockFaceView(
                      face: DigitalClockFace.values[i],
                      use12Hour: cs.use12Hour,
                      // Seconds are forced off in the tiles: at tile size a
                      // six-digit face would be illegible, and the choice is
                      // a separate switch below anyway.
                      showSeconds: false,
                      arabicDigits: arabic,
                      height: 46,
                    ),
                  ),
                  _FaceGrid(
                    itemCount: AnalogClockFace.values.length,
                    aspectRatio: 0.92,
                    isSelected: (i) =>
                        cs.style == ClockStyle.analogRgb &&
                        cs.analogFace == AnalogClockFace.values[i],
                    label: (i) => AnalogClockFace.values[i].labelKey.tr(),
                    onTap: (i) =>
                        notifier.setAnalogFace(AnalogClockFace.values[i]),
                    preview: (i) => AnalogClockFaceView(
                      face: AnalogClockFace.values[i],
                      size: 84,
                      arabicDigits: arabic,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
    );
  }

  /// The two switches that apply to both families, pinned under the grid so
  /// they stay reachable however far the reader has scrolled.
  Widget _bothFamiliesOptions(ClockSettings cs, ClockSettingsNotifier n) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: HeroSurface.of(context).hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniSwitch(
              label: 'home.clock_12h'.tr(),
              value: cs.use12Hour,
              onChanged: n.set12Hour,
            ),
          ),
          Expanded(
            child: _MiniSwitch(
              label: 'home.clock_seconds'.tr(),
              value: cs.showSeconds,
              onChanged: n.setShowSeconds,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceGrid extends StatelessWidget {
  final int itemCount;
  final double aspectRatio;
  final bool Function(int) isSelected;
  final String Function(int) label;
  final void Function(int) onTap;
  final Widget Function(int) preview;

  const _FaceGrid({
    required this.itemCount,
    required this.aspectRatio,
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        final selected = isSelected(i);
        final surface = HeroSurface.of(context);
        final accent = surface.accent(_accent);
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: surface.onSurface.withValues(alpha: selected ? 0.08 : 0.03),
              border: Border.all(
                color: selected ? accent : surface.hairline,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF15C7B0).withValues(alpha: 0.28),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: preview(i),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 6, right: 6),
                  child: Text(
                    label(i),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? accent : surface.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF15C7B0),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            style: TextStyle(
                color: HeroSurface.of(context).onSurfaceMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
