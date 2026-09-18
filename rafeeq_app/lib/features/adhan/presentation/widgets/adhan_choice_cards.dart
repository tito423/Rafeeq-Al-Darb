/// The two cards the Adhan settings screen lists recordings with. Moved out
/// of `adhan_settings_screen.dart`, which is over the file-length ceiling and
/// may not grow, when Fajr got its own list.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/theme/app_colors.dart';

/// Adhan selection card — tapping the entire card selects that adhan,
/// saves it immediately, and previews it. No separate "select" button.
class AdhanCard extends StatelessWidget {
  final AdhanOption option;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final VoidCallback? onRemove;

  const AdhanCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onStop,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? AppColors.gold.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.gold : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.gold
                          : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                // Name and label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.gold
                              : scheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      if (option.isCustom)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'prayer.imported'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Stop button (only visible when this adhan is playing)
                if (isPlaying)
                  IconButton(
                    icon: Icon(Icons.stop_circle,
                        color: AppColors.gold, size: 28),
                    tooltip: 'prayer.test'.tr(),
                    onPressed: onStop,
                  ),
                // Delete button for custom adhans
                if (onRemove != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: scheme.error, size: 22),
                    tooltip: 'prayer.remove_custom'.tr(),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrayerModeCard extends StatelessWidget {
  final String prayerKey;
  final String label;
  final AdhanMode mode;
  final String? adhanId;
  final List<AdhanOption> catalog;
  final ValueChanged<AdhanMode> onModeChanged;
  final ValueChanged<String?> onAdhanChanged;
  final VoidCallback onTest;
  final Color accent;

  const PrayerModeCard({
    super.key,
    required this.prayerKey,
    required this.label,
    required this.mode,
    required this.adhanId,
    required this.catalog,
    required this.onModeChanged,
    required this.onAdhanChanged,
    required this.onTest,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: accent)),
                ),
                TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text('prayer.test'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('prayer.notification_mode'.tr(),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AdhanMode.values.map((m) {
                return ChoiceChip(
                  label: Text(m.trKey.tr()),
                  selected: mode == m,
                  onSelected: (_) => onModeChanged(m),
                );
              }).toList(),
            ),
            if (mode == AdhanMode.full || mode == AdhanMode.audio) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                // A stored choice that no longer fits this prayer (an
                // ordinary adhan picked for Fajr before Fajr was separated)
                // reads as «default»; the dropdown asserts on a value that is
                // not among its items.
                initialValue: catalog.any(
                  (o) => o.id == adhanId && o.fitsPrayer(prayerKey),
                )
                    ? adhanId
                    : null,
                decoration: InputDecoration(
                  labelText: 'prayer.choose_adhan'.tr(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('prayer.use_default'.tr()),
                  ),
                  for (final o in catalog.where((o) => o.fitsPrayer(prayerKey)))
                    DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
                ],
                onChanged: onAdhanChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
