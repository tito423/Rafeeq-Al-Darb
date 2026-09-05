import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/azkar_settings_provider.dart';
import 'azkar_settings_sheet.dart';

/// One of the four standard tasbeeh phrases + the pill/accent colour the
/// owner's reference image (`design_refs/ref_tasbeeh.jpg`) used for it.
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
  // P3‑43 #14: the owner clarified these two belong on the Tasbeeh
  // screen's own hand-picked preset list specifically — they already
  // exist inside the (much larger) Azkar Hisn al-Muslim dataset, but
  // that's a different list from this screen's own counter presets.
  _DhikrOption('azkar.tasbeeh_allahumma_salli', Color(0xFFD4785A)), // amber
  _DhikrOption('azkar.tasbeeh_lahawla', Color(0xFF5C8A6E)), // sage
  // P3‑44: real-device feedback asked for this one directly.
  _DhikrOption('azkar.tasbeeh_astaghfirullah', Color(0xFF3F7A8C)), // teal
];

/// المسبحة (Tasbeeh) tab — P3‑12 redesign, matching `design_refs/ref_tasbeeh.jpg`:
/// pick one of the four standard tadhkir phrases (a colour-coded pill each),
/// tap the glowing circle to count it, target is the classical 33 per round —
/// reaching it advances "عدد الجولات" (rounds) and rolls the count back to 0
/// rather than climbing to some arbitrary target the old 33/100/1000 chips
/// picked. A "المجموع" chip tracks the running total across every dhikr and
/// round this session; the trash icon clears everything back to zero.
///
/// P3‑4 round 2: was a sub-tab of `AzkarScreen`, now its own bottom-nav tab
/// (`AppShell`) — the owner's real references
/// (`design_refs/round2_2026-09-04/ref_tasbeeh_v2.jpg`) show the old app's
/// bottom nav with المسبحة separate from الأذكار, not nested under it.
class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen> {
  static const _target = 33;
  int _dhikrIndex = 0;
  int _count = 0;
  int _rounds = 0;
  int _total = 0;

  void _tap() {
    final haptics = ref.read(azkarSettingsProvider).haptics;
    setState(() {
      _count++;
      _total++;
      if (_count >= _target) {
        _count = 0;
        _rounds++;
      }
    });
    if (haptics) {
      HapticFeedback.lightImpact();
      if (_count == 0) HapticFeedback.mediumImpact(); // a round just closed
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

  void _clearAll() {
    setState(() {
      _count = 0;
      _rounds = 0;
      _total = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _dhikrOptions[_dhikrIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('azkar.tab_tasbeeh'.tr()),
        actions: const [AzkarSettingsButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              child: Row(
                children: [
                  Chip(
                    label: Text('azkar.tasbeeh_total'.tr(args: ['$_total'])),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        Text('$_count',
                            style: const TextStyle(
                                fontSize: 56, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('azkar.tap_to_count'.tr(),
                            style: TextStyle(color: scheme.onSurfaceVariant)),
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
      ),
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
