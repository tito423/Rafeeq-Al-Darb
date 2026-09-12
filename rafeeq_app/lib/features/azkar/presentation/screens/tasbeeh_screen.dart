// easy_localization re-exports package:intl, whose `TextDirection` (LTR/RTL)
// collides with the `dart:ui` enum (ltr/rtl) the long-dhikr cards need.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/tasbeeh_catalog.dart';
import '../../../../core/widgets/islamic_pattern.dart';


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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _hapticEnabled = prefs.getBool(_kHapticPref) ?? true;
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
    // Celebrate on a completed finite target of 1000, or every 1000 counts
    // in no-limit mode.
    final hitMilestone = _target == null
        ? _count > 0 && _count % tasbeehCelebrateEvery == 0
        : (_target! % tasbeehCelebrateEvery == 0 && _count == _target);
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

  void _clearAll() {
    setState(() {
      _count = 0;
      _rounds = 0;
      _total = 0;
    });
  }

  String _targetLabel(int? t) =>
      t == null ? 'azkar.tasbeeh_unlimited'.tr() : '$t';

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
                        label:
                            Text('azkar.tasbeeh_total'.tr(args: ['$_total'])),
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
                    ],
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
                  child: _MathurEntryCard(
                    active: _mathurIndex != null,
                    onTap: _openMathurPicker,
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
                            Text(
                              _target == null ? '$_count' : '$_count / $_target',
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
                Text('azkar.rounds_count'.tr(args: ['$_rounds']),
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

/// The card that opens the picker. Deliberately quiet when nothing is
/// selected and gold-edged once one of the five is being counted, so the
/// screen always says which list the number on it belongs to.
class _MathurEntryCard extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _MathurEntryCard({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.10)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? AppColors.gold.withValues(alpha: 0.6)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined,
                color: active ? AppColors.gold : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'azkar.tasbeeh_mathur_title'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'azkar.tasbeeh_mathur_desc'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            // Trap #7: `chevron_left` auto-mirrors in RTL and `chevron_right`
            // does not — a disclosure chevron has to point the same way in
            // both directions.
            Icon(Icons.chevron_right,
                color: active ? AppColors.gold : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// The picker: the five, each in full, each tappable.
class _MathurPickerSheet extends StatelessWidget {
  final int? selected;
  const _MathurPickerSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'azkar.tasbeeh_mathur_pick'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tasbeehLongAdhkar.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final option = tasbeehLongAdhkar[i];
                  final isSelected = selected == i;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(i),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          option.color.withValues(alpha: 0.12),
                          scheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: option.color
                              .withValues(alpha: isSelected ? 0.9 : 0.35),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        option.textKey.tr(),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 17,
                          height: 1.9,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected long dhikr, counting. Same gesture as the circle — a tap
/// anywhere on it is one count — with the Azkar screen's own counter shape
/// underneath it: the number, its target, and a gold bar filling toward it.
class _MathurCounterCard extends StatelessWidget {
  final DhikrOption option;
  final int count;
  final int? target;
  final VoidCallback onTap;

  const _MathurCounterCard({
    required this.option,
    required this.count,
    required this.target,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = target;
    // SIZED TO THE SCREEN, not to a number somebody typed. «لما بختار ذكر
    // طويل في المسبحة صغّر شكل الكارت لأنه لازم أحرّك الشاشة لتحت عشان أوصل
    // لآخره» - the longest of the five is 88 characters, and at a fixed 19pt
    // over a 2.0 line height plus a 44pt counter the card ran past the bottom
    // of a phone, so the count you are tapping for was off screen. Both type
    // sizes now come from the viewport, with floors so a small phone still
    // gets something readable rather than something tiny.
    final h = MediaQuery.sizeOf(context).height;
    final dhikrSize = (h * 0.0195).clamp(14.0, 19.0);
    final countSize = (h * 0.032).clamp(26.0, 44.0);
    return GestureDetector(
      onTap: onTap,
      child: IslamicPatternPanel(
        padding: EdgeInsets.fromLTRB(18, h * 0.012, 18, h * 0.010),
        colors: [
          Color.alphaBlend(
            option.color.withValues(alpha: 0.28),
            AppColors.primaryContainer,
          ),
          AppColors.nightSurface,
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.textKey.tr(),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: dhikrSize,
                height: 1.75,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            // Same rule as the circle above: the "how to say it" line is for
            // a reader who cannot read the script, so it is absent in Arabic.
            if (context.locale.languageCode != 'ar') ...[
              const SizedBox(height: 8),
              Text(
                '${option.textKey}_ph'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
            SizedBox(height: h * 0.010),
            Container(
              height: 1,
              width: 90,
              color: AppColors.gold.withValues(alpha: 0.45),
            ),
            SizedBox(height: h * 0.010),
            // The count springs on every tap, so the card visibly answers the
            // finger rather than silently swapping a digit.
            TweenAnimationBuilder<double>(
              key: ValueKey<int>(count),
              tween: Tween(begin: 0.82, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text(
                t == null ? '$count' : '$count / $t',
                style: TextStyle(
                  fontSize: countSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (t != null) ...[
              SizedBox(height: h * 0.009),
              GoldProgressBar(value: (count / t).clamp(0.0, 1.0)),
            ],
            const SizedBox(height: 12),
            Text(
              'azkar.tap_to_count'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
