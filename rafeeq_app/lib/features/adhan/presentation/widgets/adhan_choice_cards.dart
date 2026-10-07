/// The two cards the Adhan settings screen lists recordings with. Moved out
/// of `adhan_settings_screen.dart`, which is over the file-length ceiling and
/// may not grow, when Fajr got its own list.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/adhan_mode.dart';
import '../../../../core/models/adhan_option.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/prayer_look.dart';

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
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? AppColors.gold : scheme.onSurface,
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
                    icon: Icon(
                      Icons.stop_circle,
                      color: goldText(context),
                      size: 28,
                    ),
                    tooltip: 'prayer.test'.tr(),
                    onPressed: onStop,
                  ),
                // Delete button for custom adhans
                if (onRemove != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: scheme.error,
                      size: 22,
                    ),
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

/// The icon each alert mode wears in the per-prayer page.
IconData adhanModeIcon(AdhanMode m) => switch (m) {
  AdhanMode.full => Icons.fullscreen_rounded,
  AdhanMode.audio => Icons.volume_up_rounded,
  AdhanMode.vibrate => Icons.vibration_rounded,
  AdhanMode.silent => Icons.notifications_off_outlined,
};

/// «تخصيص كل صلاة» on one page (owner, 2026-10-06: «ممكن تهندسه بشكل مش
/// يبقى طويل اوي … في صفحة وحدة وبشكل متكور وروعه بصريا»). It was five tall
/// cards, each with a title, a caption, four long chips and a full-width
/// dropdown - two screens of scrolling for five choices. Now: a «للكل» row
/// that sets every prayer at once, then one short card per prayer - its
/// name and time of day, the four modes as one segmented row of icons with
/// the chosen one named, and the adhan as a single pill that opens a list.
class PerPrayerPage extends StatelessWidget {
  final List<String> prayerKeys;
  final String Function(String key) label;
  final AdhanMode Function(String key) modeOf;
  final String? Function(String key) adhanOf;
  final List<AdhanOption> catalog;
  final void Function(String key, AdhanMode mode) onMode;
  final void Function(AdhanMode mode) onModeAll;
  final void Function(String key, String? adhanId) onAdhan;
  final void Function(String key) onTest;

  const PerPrayerPage({
    super.key,
    required this.prayerKeys,
    required this.label,
    required this.modeOf,
    required this.adhanOf,
    required this.catalog,
    required this.onMode,
    required this.onModeAll,
    required this.onAdhan,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modes = {for (final k in prayerKeys) modeOf(k)};
    final common = modes.length == 1 ? modes.first : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                AppColors.gold.withValues(alpha: 0.18),
                AppColors.gold.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'prayer.per_prayer_all'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: goldText(context),
                ),
              ),
              const SizedBox(height: 8),
              _ModeSegments(selected: common, onSelect: onModeAll),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final k in prayerKeys)
          _PrayerTile(
            prayerKey: k,
            label: label(k),
            mode: modeOf(k),
            adhanId: adhanOf(k),
            catalog: catalog,
            onMode: (m) => onMode(k, m),
            onAdhan: (id) => onAdhan(k, id),
            onTest: () => onTest(k),
          ),
        const SizedBox(height: 4),
        Text(
          'prayer.per_prayer_desc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PrayerTile extends StatelessWidget {
  final String prayerKey;
  final String label;
  final AdhanMode mode;
  final String? adhanId;
  final List<AdhanOption> catalog;
  final ValueChanged<AdhanMode> onMode;
  final ValueChanged<String?> onAdhan;
  final VoidCallback onTest;

  const _PrayerTile({
    required this.prayerKey,
    required this.label,
    required this.mode,
    required this.adhanId,
    required this.catalog,
    required this.onMode,
    required this.onAdhan,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tint) =
        prayerLook[prayerKey] ?? (Icons.access_time_rounded, AppColors.gold);
    final sounds = mode == AdhanMode.full || mode == AdhanMode.audio;
    final fits = [
      for (final o in catalog)
        if (o.fitsPrayer(prayerKey)) o,
    ];
    // A stored choice that no longer fits this prayer (an ordinary adhan
    // picked for Fajr before Fajr was separated) reads as «default».
    final chosen = fits.where((o) => o.id == adhanId).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [tint, tint.withValues(alpha: 0.6)],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
              // Expanded, so the play button sits at the same place on
              // every card whatever the adhan's name is (it wandered with the
              // pill's width on emulator-5554).
              if (sounds)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ActionChip(
                      avatar: const Icon(Icons.music_note_rounded, size: 16),
                      label: Text(
                        chosen?.name ?? 'prayer.use_default_short'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _pickAdhan(context, fits, chosen?.id),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'prayer.test'.tr(),
                visualDensity: VisualDensity.compact,
                onPressed: onTest,
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  color: goldText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ModeSegments(selected: mode, onSelect: onMode),
        ],
      ),
    );
  }

  Future<void> _pickAdhan(
    BuildContext context,
    List<AdhanOption> fits,
    String? current,
  ) async {
    final picked = await showModalBottomSheet<(String?,)>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '${'prayer.choose_adhan'.tr()} — $label',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final (id, name) in [
              (null, 'prayer.use_default'.tr()),
              for (final o in fits) (o.id, o.name),
            ])
              ListTile(
                leading: Icon(
                  id == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: id == current ? AppColors.gold : null,
                ),
                title: Text(name),
                onTap: () => Navigator.pop(ctx, (id,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onAdhan(picked.$1);
  }
}

/// The four alert modes as one row: every mode an icon, the chosen one
/// filled and named under it, so the row stays one line on any phone.
class _ModeSegments extends StatelessWidget {
  final AdhanMode? selected;
  final ValueChanged<AdhanMode> onSelect;

  const _ModeSegments({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surface.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          for (final m in AdhanMode.values)
            Expanded(
              child: Tooltip(
                message: m.trKey.tr(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onSelect(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: m == selected
                          ? AppColors.gold.withValues(alpha: 0.9)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          adhanModeIcon(m),
                          size: 20,
                          color: m == selected
                              ? Colors.black87
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.trKey}_short'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: m == selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: m == selected
                                ? Colors.black87
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
