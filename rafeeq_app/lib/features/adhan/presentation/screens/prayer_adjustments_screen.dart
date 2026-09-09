import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/i18n/hijri_months.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/data/prayer_controller.dart';
import '../../data/adhan_settings_provider.dart';
import '../../data/prayer_adjustments_provider.dart';

/// Manual corrections for the Hijri date and each prayer time, plus the
/// calculation method that decides those times in the first place.
///
/// The method used to sit in Adhan settings, which is about *how the adhan is
/// announced*; it belongs here with the other things that determine *when*.
class PrayerAdjustmentsScreen extends ConsumerWidget {
  const PrayerAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adj = ref.watch(prayerAdjustmentsProvider);
    final settings = ref.watch(adhanSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('prayer.adjustments'.tr()),
        actions: [
          if (!adj.isPristine)
            TextButton(
              onPressed: () {
                ref.read(prayerAdjustmentsProvider.notifier).resetAll();
                ref.read(prayerControllerProvider.notifier).refresh();
              },
              child: Text('prayer.reset_adjustments'.tr()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Calculation method (moved here from Adhan settings) ──
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'prayer.calc_method'.tr(),
                  icon: const Icon(Icons.calculate_outlined),
                  border: InputBorder.none,
                ),
                initialValue: settings.calculationMethod,
                items: [
                  DropdownMenuItem(
                      value: 4, child: Text('prayer.calc_umm_alqura'.tr())),
                  DropdownMenuItem(
                      value: 5, child: Text('prayer.calc_egyptian'.tr())),
                  DropdownMenuItem(
                      value: 3, child: Text('prayer.calc_mwl'.tr())),
                  DropdownMenuItem(
                      value: 2, child: Text('prayer.calc_isna'.tr())),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref
                      .read(adhanSettingsProvider.notifier)
                      .setCalculationMethod(v);
                  ref.read(prayerControllerProvider.notifier).refresh();
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hijri date ──
          _SectionLabel('prayer.hijri_adjust'.tr()),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'prayer.hijri_adjust_desc'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  _Stepper(
                    value: adj.hijriOffsetDays,
                    min: -3,
                    max: 3,
                    unit: 'prayer.days_unit'.tr(),
                    onChanged: (v) {
                      ref
                          .read(prayerAdjustmentsProvider.notifier)
                          .setHijriOffset(v);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _hijriPreview(adj.hijriOffsetDays),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.gold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Per-prayer minute offsets ──
          _SectionLabel('prayer.times_adjust'.tr()),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'prayer.times_adjust_desc'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  for (final key in adjustablePrayerKeys) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'prayer.$key'.tr(),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _Stepper(
                          value: adj.offsetFor(key),
                          min: -60,
                          max: 60,
                          unit: 'prayer.minutes_unit'.tr(),
                          onChanged: (v) => ref
                              .read(prayerAdjustmentsProvider.notifier)
                              .setMinuteOffset(key, v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// What the corrected Hijri date reads as today, so the user can dial the
  /// offset until it matches what their locality announced.
  String _hijriPreview(int offsetDays) {
    final date = HijriCalendar.fromDate(
      DateTime.now().add(Duration(days: offsetDays)),
    );
    return '${date.hDay} ${hijriMonthName(date.hMonth)} ${date.hYear}'
        '${'hijri.suffix'.tr()}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}

/// A compact -/value/+ control. Steppers rather than a text field because
/// every one of these is a small nudge around zero, and a keyboard for a
/// two-digit signed number is more friction than it's worth.
class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == 0 ? '0 $unit' : '${value > 0 ? '+' : ''}$value $unit';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 88,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: value == 0 ? null : AppColors.gold,
                  fontWeight: value == 0 ? null : FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
