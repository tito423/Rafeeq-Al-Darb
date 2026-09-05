import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One of the standard tasbeeh phrases + the pill/accent colour the owner's
/// reference image (`design_refs/ref_tasbeeh.jpg`) used for it.
class _DhikrOption {
  final String textKey;
  final Color color;
  const _DhikrOption(this.textKey, this.color);
}

const _dhikrOptions = [
  _DhikrOption('azkar.tasbeeh_subhanallah', Color(0xFF2E9FE8)), // blue
  _DhikrOption('azkar.tasbeeh_alhamdulillah', Color(0xFF2E9D6F)), // green
  _DhikrOption('azkar.tasbeeh_allahuakbar', Color(0xFF6C5FBC)), // purple
  _DhikrOption('azkar.tasbeeh_lailahaillallah', Color(0xFFC9A227)), // gold
  _DhikrOption('azkar.tasbeeh_allahumma_salli', Color(0xFFD4785A)), // amber
  _DhikrOption('azkar.tasbeeh_lahawla', Color(0xFF5C8A6E)), // sage
  _DhikrOption('azkar.tasbeeh_astaghfirullah', Color(0xFF3F7A8C)), // teal
];

/// The selectable per-round targets. `null` = no limit (count climbs freely,
/// celebrating every 1000). P3‑47: real-device feedback — the fixed 33 was
/// the only option and the counter visibly stopped at 32 (it reset the
/// instant it hit the target, so the target number itself was never shown).
const List<int?> _targets = [33, 100, 1000, null];

/// Milestone every N counts triggers the full-screen celebration — the
/// owner asked specifically for 1000 / 1000n.
const _celebrateEvery = 1000;

class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen>
    with SingleTickerProviderStateMixin {
  int? _target = 33;
  int _dhikrIndex = 0;
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

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  void _tap() {
    setState(() {
      // Show the target number itself: when the previous tap had just
      // landed exactly on the target (a completed round for a finite
      // target), the next tap starts a fresh round at 1 rather than the
      // count being reset the instant it reaches the target.
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
        ? _count > 0 && _count % _celebrateEvery == 0
        : (_target! % _celebrateEvery == 0 && _count == _target);
    if (hitMilestone) {
      _celebrate
        ..reset()
        ..forward();
    }
  }

  void _selectDhikr(int i) {
    if (i == _dhikrIndex) return;
    setState(() {
      _dhikrIndex = i;
      _count = 0;
      _rounds = 0;
    });
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
    final selected = _dhikrOptions[_dhikrIndex];
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
                        tooltip: 'common.reset_all'.tr(),
                        onPressed: _total == 0 && _rounds == 0 && _count == 0
                            ? null
                            : _clearAll,
                        icon: Icon(Icons.delete_outline, color: scheme.error),
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
                      for (final t in _targets)
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
                      for (var i = 0; i < _dhikrOptions.length; i++)
                        _DhikrPill(
                          option: _dhikrOptions[i],
                          selected: i == _dhikrIndex,
                          onTap: () => _selectDhikr(i),
                        ),
                    ],
                  ),
                ),
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
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: selected.color,
                              ),
                            ),
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
                    milestone: _target ?? _celebrateEvery,
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
  final _DhikrOption option;
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
