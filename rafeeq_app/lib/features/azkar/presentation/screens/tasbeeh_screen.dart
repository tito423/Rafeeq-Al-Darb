// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (ltr/rtl) the long-dhikr cards need.
import 'package:vibration/vibration.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../../core/utils/digits.dart';
import '../../../../core/utils/byte_formatter.dart' show ratio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/sync_service.dart';
import '../../data/tasbeeh_catalog.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../tutorial/data/tutorial_anchors.dart';

part 'tasbeeh_mathur_cards.dart';


class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen>
    with SingleTickerProviderStateMixin {
  int? _target = 33;
  int _dhikrIndex = 0;

  /// Index into [tasbeehLongAdhkar] when one of the five long adhkar is the one
  /// being counted; `null` when the seven short pills own the screen. The two
  /// selections are exclusive — picking either clears the other — so there is
  /// never a question of which phrase the number belongs to.
  int? _mathurIndex;

  int _count = 0;
  int _rounds = 0;
  int _total = 0;

  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {}); // clear the overlay when the burst finishes
      }
    });

  /// Whether haptic feedback is enabled — persisted in SharedPreferences.
  bool _hapticEnabled = true;
  static const _kHapticPref = 'tasbeeh_haptic_enabled';

  /// The reader's own round size, if they set one - no upper limit.
  int? _customTarget;
  static const _kCustomPref = 'tasbeeh_custom_target';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _hapticEnabled = prefs.getBool(_kHapticPref) ?? true;
          _total = prefs.getInt('tasbeeh_total') ?? 0;
          _customTarget = prefs.getInt(_kCustomPref);
        });
      }
    });
  }

  void _toggleHaptic() {
    setState(() => _hapticEnabled = !_hapticEnabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kHapticPref, _hapticEnabled),
    );
  }

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  void _tap() {
    setState(() {
      final t = _target;
      if (t != null && _count >= t) {
        _count = 1;
      } else {
        _count++;
      }
      _total++;
      if (t != null && _count == t) _rounds++;
    });
    
    SharedPreferences.getInstance().then((p) => p.setInt('tasbeeh_total', _total));
    ref.read(syncServiceProvider).incrementCounter('tasbeeh_total', 1);
    // Celebrate on a completed finite target of 1000, or every 1000 counts
    // in no-limit mode.
    final hitMilestone = _target == null
        ? _count > 0 && _count % tasbeehCelebrateEvery == 0
        : (_target! % tasbeehCelebrateEvery == 0 && _count == _target);
    if (_hapticEnabled && tasbeehStrongBuzz(_count)) {
      // One second at full strength, so it is felt through a pocket.
      Vibration.vibrate(duration: 1000, amplitude: 255);
    }
    if (_hapticEnabled) {
      if (hitMilestone) {
        _celebrate
          ..reset()
          ..forward();
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } else if (hitMilestone) {
      _celebrate
        ..reset()
        ..forward();
    }
  }

  void _selectDhikr(int i) {
    if (i == _dhikrIndex && _mathurIndex == null) return;
    setState(() {
      _dhikrIndex = i;
      _mathurIndex = null;
      _count = 0;
      _rounds = 0;
    });
  }

  void _selectMathur(int i) {
    setState(() {
      _mathurIndex = i;
      _count = 0;
      _rounds = 0;
    });
  }

  /// The phrase currently being counted, whichever of the two lists it is in.
  DhikrOption get _selected =>
      _mathurIndex == null ? tasbeehShortAdhkar[_dhikrIndex] : tasbeehLongAdhkar[_mathurIndex!];

  Future<void> _openMathurPicker() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _MathurPickerSheet(selected: _mathurIndex),
    );
    if (chosen != null && mounted) _selectMathur(chosen);
  }

  void _selectTarget(int? t) {
    setState(() {
      _target = t;
      _count = 0;
      _rounds = 0;
    });
  }

  Future<void> _askCustomTarget() async {
    final ctrl = TextEditingController(
        text: _customTarget == null ? '' : '$_customTarget');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('azkar.tasbeeh_custom_title'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: 'azkar.tasbeeh_custom_hint'.tr()),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(ctrl.text)),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
    if (n == null || n <= 0) return;
    setState(() => _customTarget = n);
    SharedPreferences.getInstance().then((p) => p.setInt(_kCustomPref, n));
    _selectTarget(n);
  }

  void _clearAll() {
    setState(() {
      _count = 0;
      _rounds = 0;
    });
  }

  String _targetLabel(int? t) => t == null
      ? 'azkar.tasbeeh_unlimited'.tr()
      : localizeDigits('$t', context.locale.languageCode);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: Text('azkar.tab_tasbeeh'.tr())),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(localizeDigits(
                            'azkar.tasbeeh_total'.tr(args: ['$_total']),
                            context.locale.languageCode)),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _hapticEnabled
                            ? 'azkar.haptic_on'.tr()
                            : 'azkar.haptic_off'.tr(),
                        onPressed: _toggleHaptic,
                        icon: Icon(
                          _hapticEnabled
                              ? Icons.vibration
                              : Icons.phonelink_erase,
                          color: _hapticEnabled
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        tooltip: 'common.reset_all'.tr(),
                        onPressed: _total == 0 && _rounds == 0 && _count == 0
                            ? null
                            : _clearAll,
                        icon: SvgPicture.asset(
                          'assets/icons/reset.svg',
                          colorFilter: ColorFilter.mode(scheme.error, BlendMode.srcIn),
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // Target selector (P3‑47).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TutorialAnchor(
                    id: TourAnchor.tasbeehTargets,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final t in tasbeehTargets)
                          ChoiceChip(
                            label: Text(_targetLabel(t)),
                            selected: _target == t,
                            onSelected: (_) => _selectTarget(t),
                          ),
                        // «مربع لعدد مخصص مالوش سقف».
                        ChoiceChip(
                          avatar: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(_customTarget == null ||
                                  tasbeehTargets.contains(_customTarget)
                              ? 'azkar.tasbeeh_custom'.tr()
                              : _targetLabel(_customTarget)),
                          selected: _target != null &&
                              !tasbeehTargets.contains(_target),
                          onSelected: (_) => _askCustomTarget(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < tasbeehShortAdhkar.length; i++)
                        _DhikrPill(
                          option: tasbeehShortAdhkar[i],
                          selected: i == _dhikrIndex && _mathurIndex == null,
                          onTap: () => _selectDhikr(i),
                        ),
                    ],
                  ),
                ),
                // The gateway to the five long adhkar.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                  child: TutorialAnchor(
                    id: TourAnchor.tasbeehMathur,
                    child: _MathurEntryCard(
                      active: _mathurIndex != null,
                      onTap: _openMathurPicker,
                    ),
                  ),
                ),
                if (_mathurIndex != null)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: _MathurCounterCard(
                          option: selected,
                          count: _count,
                          target: _target,
                          onTap: _tap,
                        ),
                      ),
                    ),
                  )
                else
                Expanded(
                  child: Center(
                    // A short or narrow screen gets a smaller circle rather
                    // than an overflow stripe.
                    child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GestureDetector(
                      onTap: _tap,
                      child: Container(
                        width: 250,
                        height: 250,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.alphaBlend(
                              selected.color.withValues(alpha: 0.10),
                              scheme.surfaceContainerHighest),
                          border: Border.all(
                              color: selected.color.withValues(alpha: 0.55),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: selected.color.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selected.textKey.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: selected.color,
                              ),
                            ),
                            // P3‑48: for non-Arabic UI languages, show a
                            // transliteration ("how to read it") beneath the
                            // Arabic so a non-Arabic speaker can pronounce it.
                            if (context.locale.languageCode != 'ar') ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '${selected.textKey}_ph'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // «٠ / ٣٣», not «٣٣ / ٠». Seen in Arabic on
                            // emulator-5554 reading «33 / 0» — «33 of 0».
                            // CORRECTION. This was "fixed" once already, by
                            // splitting the pair into three Text widgets in a
                            // Row. The reasoning about bidi was right - three
                            // Texts share no paragraph, so rule N1 has no
                            // neutral to resolve - and the fix STILL rendered
                            // «33 / 2» on emulator-5554, because it swapped
                            // one reordering for another: a Row lays its
                            // children out along the ambient Directionality,
                            // and under RTL that puts the FIRST child on the
                            // RIGHT. The pair was reordered by the Row itself.
                            //
                            // ratio() is the fix used by the other fifteen
                            // sites, and it is the one with a rendering test
                            // behind it (test/ratio_direction_test.dart lays
                            // text out under real RTL and reads caret offsets).
                            // Wrapped in localizeDigits because in Arabic this
                            // screen was the only one on it printing Latin
                            // numerals - the Home clock, the date and the
                            // prayer times are all Arabic-Indic.
                            Text(
                              localizeDigits(
                                _target == null
                                    ? '$_count'
                                    : localizeDigits(ratio(_count, _target!), uiLanguageCode),
                                context.locale.languageCode,
                              ),
                              style: const TextStyle(
                                  fontSize: 52, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text('azkar.tap_to_count'.tr(),
                                style:
                                    TextStyle(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
                Text(
                    localizeDigits('azkar.rounds_count'.tr(args: ['$_rounds']),
                        context.locale.languageCode),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: IconButton.filledTonal(
                    tooltip: 'azkar.reset'.tr(),
                    onPressed: () => setState(() {
                      _count = 0;
                      _rounds = 0;
                    }),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
            // Celebration overlay (P3‑47): a glowing burst + congratulatory
            // Arabic line when a 1000 milestone is reached. Auto-dismisses.
            if (_celebrate.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: _CelebrationOverlay(
                    animation: _celebrate,
                    color: selected.color,
                    milestone: _target ?? tasbeehCelebrateEvery,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CelebrationOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final int milestone;
  const _CelebrationOverlay({
    required this.animation,
    required this.color,
    required this.milestone,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // Fade in fast, hold, fade out.
        final opacity = t < 0.15
            ? t / 0.15
            : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.6 + 0.6 * Curves.easeOutBack.transform(t.clamp(0, 1)),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 64),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'azkar.tasbeeh_milestone'.tr(),
                  style: const TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$milestone',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: color,
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

class _DhikrPill extends StatelessWidget {
  final DhikrOption option;
  final bool selected;
  final VoidCallback onTap;
  const _DhikrPill(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: option.color,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          option.textKey.tr(),
          style: const TextStyle(
            fontFamily: 'AmiriQuran',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
