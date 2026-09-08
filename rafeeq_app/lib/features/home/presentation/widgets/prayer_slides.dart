import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/adhan_native.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../adhan/data/adhan_catalog_provider.dart';
import '../../../adhan/data/adhan_presentation_provider.dart';
import '../../../adhan/data/adhan_settings_provider.dart';
import '../../../adhan/data/adhan_video_catalog.dart';
import '../../../adhan/data/prayer_adjustments_provider.dart';
import '../../data/prayer_controller.dart';

/// The six timings, in the order they occur.
const prayerSlideOrder = [
  'fajr',
  'sunrise',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

const prayerSlideLabelKeys = {
  'fajr': 'prayer.fajr',
  'sunrise': 'prayer.sunrise',
  'dhuhr': 'prayer.dhuhr',
  'asr': 'prayer.asr',
  'maghrib': 'prayer.maghrib',
  'isha': 'prayer.isha',
};

/// One colour per prayer, matching `design_refs/old_app_frames`' chip palette.
/// Cosmetic only — it doesn't encode anything.
const prayerSlideColors = {
  'fajr': Color(0xFF7C4DFF), // violet
  'sunrise': Color(0xFF8D6E63), // brown
  'dhuhr': Color(0xFF2F80A9), // blue
  'asr': Color(0xFF2E9D6F), // green
  'maghrib': Color(0xFFD4AF37), // gold
  'isha': Color(0xFF15C7B0), // teal
};

const _prayerSlideIcons = {
  'fajr': Icons.nights_stay_outlined,
  'sunrise': Icons.wb_twilight,
  'dhuhr': Icons.light_mode_outlined,
  'asr': Icons.wb_sunny_outlined,
  'maghrib': Icons.wb_twilight_outlined,
  'isha': Icons.dark_mode_outlined,
};

/// The Home card's prayer carousel.
///
/// The six timings are a real `PageView` rather than a plain scrolling row, so
/// each slide has a genuine focus state: the centred one grows to full size and
/// full colour while its neighbours shrink and dim, and moving between them is
/// one continuous interpolation of that transform rather than a snap.
///
/// Tapping the centred slide expands it into a full editor for that prayer —
/// alert mode, muezzin, background clip, a real adhan preview, and a manual
/// minute correction. Every control writes straight through the same providers
/// the Adhan settings screen uses, so a change here is the same change made
/// there: it re-schedules the alarms and moves the time on this very card
/// without leaving Home.
class PrayerSlides extends ConsumerStatefulWidget {
  final PrayerTimes times;

  /// The key of the next prayer, from `PrayerTimesService.nextPrayer`.
  final String? nextKey;

  const PrayerSlides({super.key, required this.times, required this.nextKey});

  @override
  ConsumerState<PrayerSlides> createState() => _PrayerSlidesState();
}

class _PrayerSlidesState extends ConsumerState<PrayerSlides> {
  static const _viewportFraction = 0.33;

  late final PageController _controller;
  double _page = 0;
  int _focused = 0;
  bool _expanded = false;

  /// True once the reader has moved the carousel themselves. Until then the
  /// card keeps following the next prayer; after it, it stays where they put
  /// it rather than yanking itself back under their finger.
  bool _userDriven = false;

  int get _nextIndex =>
      math.max(0, prayerSlideOrder.indexOf(widget.nextKey ?? ''));

  @override
  void initState() {
    super.initState();
    final initial = _nextIndex;
    _focused = initial;
    _page = initial.toDouble();
    _controller = PageController(
      viewportFraction: _viewportFraction,
      initialPage: initial,
    )..addListener(_onScroll);
  }

  /// The card is first built while the times are still loading, so the next
  /// prayer this widget was born with can be stale by the time the real
  /// fetch lands. Following [PrayerSlides.nextKey] here is what makes the
  /// carousel open on the prayer the card's own countdown is naming.
  @override
  void didUpdateWidget(PrayerSlides old) {
    super.didUpdateWidget(old);
    if (_userDriven || widget.nextKey == old.nextKey) return;
    final target = _nextIndex;
    if (target == _focused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onScroll() {
    final p = _controller.page;
    if (p == null) return;
    setState(() {
      _page = p;
      _focused = p.round().clamp(0, prayerSlideOrder.length - 1);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onSlideTapped(int index) {
    _userDriven = true;
    if (index != _focused) {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      setState(() => _expanded = true);
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 116,
          child: PageView.builder(
            controller: _controller,
            // No `reverse`: a horizontal PageView already resolves its scroll
            // direction from the ambient Directionality, so in Arabic Fajr is
            // at the right-hand (leading) end on its own. Setting `reverse`
            // here double-flipped it and laid the day out left-to-right.
            itemCount: prayerSlideOrder.length,
            padEnds: true,
            itemBuilder: (context, index) {
              final key = prayerSlideOrder[index];
              final distance = (_page - index).abs().clamp(0.0, 1.0);
              final scale = 1 - 0.22 * distance;
              final opacity = 1 - 0.45 * distance;
              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: _PrayerSlide(
                      label: prayerSlideLabelKeys[key]!.tr(),
                      time: formatTime12h(widget.times.byName(key)),
                      color: prayerSlideColors[key]!,
                      icon: _prayerSlideIcons[key]!,
                      isNext: widget.nextKey == key,
                      isFocused: index == _focused,
                      expanded: _expanded && index == _focused,
                      offsetMinutes:
                          ref.watch(prayerAdjustmentsProvider).offsetFor(key),
                      onTap: () => _onSlideTapped(index),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // The editor for whichever slide is focused. `AnimatedSize` gives the
        // whole card a real grow/shrink instead of a jump, and the switcher
        // cross-fades when the focus moves to another prayer while open.
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity, height: 0)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: PrayerSlideDetails(
                      key: ValueKey(prayerSlideOrder[_focused]),
                      prayerKey: prayerSlideOrder[_focused],
                      onClose: () => setState(() => _expanded = false),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PrayerSlide extends StatelessWidget {
  final String label;
  final String time;
  final Color color;
  final IconData icon;
  final bool isNext;
  final bool isFocused;
  final bool expanded;
  final int offsetMinutes;
  final VoidCallback onTap;

  const _PrayerSlide({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
    required this.isNext,
    required this.isFocused,
    required this.expanded,
    required this.offsetMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = isNext || isFocused;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                )
              : null,
          color: filled ? null : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : Colors.white70,
              ),
            ),
            // An honest marker that this timing is not the calculated one.
            if (offsetMinutes != 0) ...[
              const SizedBox(height: 2),
              Text(
                offsetMinutes > 0 ? '+$offsetMinutes' : '$offsetMinutes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white70 : Colors.white54,
                ),
              ),
            ],
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: (filled ? Colors.white : color).withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The expanded editor for one prayer, living inside the Home card.
class PrayerSlideDetails extends ConsumerStatefulWidget {
  final String prayerKey;
  final VoidCallback onClose;

  const PrayerSlideDetails({
    super.key,
    required this.prayerKey,
    required this.onClose,
  });

  @override
  ConsumerState<PrayerSlideDetails> createState() => _PrayerSlideDetailsState();
}

class _PrayerSlideDetailsState extends ConsumerState<PrayerSlideDetails> {
  bool _previewing = false;
  Timer? _previewWatch;

  @override
  void dispose() {
    _previewWatch?.cancel();
    // Leaving the card must never leave an adhan sounding behind it.
    if (_previewing) AdhanNative.stop();
    super.dispose();
  }

  bool get _hasAdhan => adhanPrayerKeys.contains(widget.prayerKey);

  /// Plays the adhan this prayer would actually use, through the same native
  /// player a real firing uses — not a second `just_audio` instance, which
  /// cannot work here (see `adhan_settings_screen.dart`'s note).
  Future<void> _togglePreview(AdhanOption option) async {
    if (_previewing) {
      _previewWatch?.cancel();
      await AdhanNative.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    final started = await AdhanNative.preview(
      AdhanNative.specFor(
        prayerKey: widget.prayerKey,
        prayerLabel: prayerSlideLabelKeys[widget.prayerKey]!.tr(),
        // `audio`: a card preview is the sound only, with no screen takeover.
        mode: AdhanMode.audio,
        option: option,
      ),
    );
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
      return;
    }
    setState(() => _previewing = true);
    _previewWatch?.cancel();
    _previewWatch =
        Timer.periodic(const Duration(milliseconds: 500), (t) async {
      final state = await AdhanNative.state();
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!state.playing) {
        t.cancel();
        setState(() => _previewing = false);
      }
    });
  }

  Future<void> _setMode(AdhanMode mode) async {
    await ref
        .read(adhanSettingsProvider.notifier)
        .setModeFor(widget.prayerKey, mode);
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }

  Future<void> _setAdhan(String? id) async {
    await ref
        .read(adhanSettingsProvider.notifier)
        .setAdhanFor(widget.prayerKey, id);
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }

  Future<void> _nudge(int delta) async {
    final current =
        ref.read(prayerAdjustmentsProvider).offsetFor(widget.prayerKey);
    await ref
        .read(prayerAdjustmentsProvider.notifier)
        .setMinuteOffset(widget.prayerKey, current + delta);
  }

  @override
  Widget build(BuildContext context) {
    final color = prayerSlideColors[widget.prayerKey]!;
    final settings = ref.watch(adhanSettingsProvider);
    final catalog = ref.watch(adhanCatalogProvider).valueOrNull ?? const [];
    final presentation = ref.watch(adhanPresentationProvider);
    final offset = ref.watch(prayerAdjustmentsProvider).offsetFor(
          widget.prayerKey,
        );

    final adhanId = settings.adhanIdFor(widget.prayerKey);
    final option = catalog.where((o) => o.id == adhanId).firstOrNull;
    final usesDefault =
        settings.adhanIdByPrayer[widget.prayerKey] == null;
    final video = adhanVideoById(presentation.videoId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_prayerSlideIcons[widget.prayerKey], size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prayerSlideLabelKeys[widget.prayerKey]!.tr(),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.white54),
              ),
            ],
          ),

          // ── Manual correction — always available, sunrise included ──
          _DetailRow(
            icon: Icons.tune_rounded,
            label: 'prayer.times_adjust'.tr(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _nudge(-1),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    offset == 0
                        ? '0'
                        : (offset > 0 ? '+$offset' : '$offset'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: offset == 0 ? Colors.white54 : color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: () => _nudge(1),
                ),
              ],
            ),
          ),

          if (!_hasAdhan)
            // Honest: the sunrise is a timing, not a prayer — it has no adhan
            // and never gets one, so the card says that rather than showing
            // dead controls.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'prayer.sunrise_no_adhan'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else ...[
            const _ThinDivider(),

            // ── Alert mode ──
            Text(
              'prayer.notification_mode'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mode in AdhanMode.values)
                  _Pill(
                    label: mode.trKey.tr(),
                    selected: settings.modeFor(widget.prayerKey) == mode,
                    color: color,
                    onTap: () => _setMode(mode),
                  ),
              ],
            ),

            const _ThinDivider(),

            // ── Muezzin ──
            _DetailRow(
              icon: Icons.record_voice_over_outlined,
              label: 'prayer.choose_adhan'.tr(),
              value: option?.name ?? '—',
              subValue: usesDefault ? 'prayer.use_default'.tr() : null,
              onTap: catalog.isEmpty
                  ? null
                  : () => _pickAdhan(catalog, adhanId, usesDefault),
              trailing: option == null
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'prayer.test'.tr(),
                      onPressed: () => _togglePreview(option),
                      icon: Icon(
                        _previewing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: color,
                      ),
                    ),
            ),

            // ── Background clip (only meaningful in video presentation) ──
            _DetailRow(
              icon: presentation.mode == AdhanPresentation.video
                  ? Icons.movie_outlined
                  : Icons.graphic_eq_rounded,
              label: 'prayer.adhan_video'.tr(),
              value: presentation.mode == AdhanPresentation.video
                  ? (context.locale.languageCode == 'ar'
                      ? (video?.nameAr ?? '—')
                      : (video?.nameEn ?? '—'))
                  : 'prayer.presentation_audio'.tr(),
              onTap: () => _pickVideo(presentation),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAdhan(
    List<AdhanOption> catalog,
    String currentId,
    bool usesDefault,
  ) async {
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: const Color(0xFF0E1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                'prayer.use_default'.tr(),
                style: const TextStyle(color: Colors.white),
              ),
              leading: Icon(
                usesDefault
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF15C7B0),
              ),
              onTap: () => Navigator.of(ctx).pop('__default__'),
            ),
            const Divider(height: 1, color: Colors.white12),
            for (final o in catalog)
              ListTile(
                title: Text(
                  o.name,
                  style: const TextStyle(color: Colors.white),
                ),
                leading: Icon(
                  !usesDefault && o.id == currentId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF15C7B0),
                ),
                onTap: () => Navigator.of(ctx).pop(o.id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await _setAdhan(chosen == '__default__' ? null : chosen as String);
  }

  Future<void> _pickVideo(AdhanPresentationState presentation) async {
    final arabic = context.locale.languageCode == 'ar';
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0E1626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(
                presentation.mode == AdhanPresentation.audioOnly
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFF15C7B0),
              ),
              title: Text(
                'prayer.presentation_audio'.tr(),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(ctx).pop('__audio__'),
            ),
            const Divider(height: 1, color: Colors.white12),
            for (final v in adhanVideoCatalog)
              ListTile(
                leading: Icon(
                  presentation.mode == AdhanPresentation.video &&
                          presentation.videoId == v.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF15C7B0),
                ),
                title: Text(
                  arabic ? v.nameAr : v.nameEn,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(ctx).pop(v.id),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                adhanVideoSourceLabel,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final notifier = ref.read(adhanPresentationProvider.notifier);
    if (chosen == '__audio__') {
      await notifier.setMode(AdhanPresentation.audioOnly);
    } else {
      await notifier.setVideo(chosen);
      await notifier.setMode(AdhanPresentation.video);
    }
    await ref.read(prayerControllerProvider.notifier).rescheduleFromCache();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? subValue;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.subValue,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (subValue != null)
                    Text(
                      subValue!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
      );
}
