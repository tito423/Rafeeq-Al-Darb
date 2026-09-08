import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clock_settings_provider.dart';
import 'analog_clock_faces.dart';
import 'digital_clock_faces.dart';

/// The clock gallery — twenty live faces, ten digital and ten analogue.
///
/// Every tile is the *real* face running on the real current time, not a
/// static thumbnail: what the reader taps is exactly what lands on the Home
/// card, and the card updates the moment they tap it (the sheet writes
/// straight through `clockSettingsProvider`, which Home watches).
class ClockGallerySheet extends ConsumerStatefulWidget {
  const ClockGallerySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ClockGallerySheet(),
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

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101A2B), Color(0xFF080C15)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'home.clock_gallery_title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

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

            TabBar(
              controller: _tabs,
              indicatorColor: const Color(0xFF15C7B0),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
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
                    scrollController: scrollController,
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
                    scrollController: scrollController,
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

            // ── The two options that apply to both families ──
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniSwitch(
                      label: 'home.clock_12h'.tr(),
                      value: cs.use12Hour,
                      onChanged: notifier.set12Hour,
                    ),
                  ),
                  Expanded(
                    child: _MiniSwitch(
                      label: 'home.clock_seconds'.tr(),
                      value: cs.showSeconds,
                      onChanged: notifier.setShowSeconds,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceGrid extends StatelessWidget {
  final ScrollController scrollController;
  final int itemCount;
  final double aspectRatio;
  final bool Function(int) isSelected;
  final String Function(int) label;
  final void Function(int) onTap;
  final Widget Function(int) preview;

  const _FaceGrid({
    required this.scrollController,
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
      controller: scrollController,
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
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: selected ? 0.08 : 0.03),
              border: Border.all(
                color: selected
                    ? const Color(0xFF15C7B0)
                    : Colors.white.withValues(alpha: 0.10),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF7DEBDA)
                          : Colors.white60,
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
