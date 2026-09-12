import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/tutorial_state.dart';
import '../screens/tutorial_screen.dart';

/// The tour's entry in «المزيد»: one card that plays it now, with the
/// every-launch switch tucked under the same border rather than loose in the
/// settings list — the two belong to the same thing and read as one control.
///
/// «وحطله خيارات في المزيد يتعرض عند كل فتح وتشغيل الآن».
class TutorialEntryCard extends ConsumerWidget {
  const TutorialEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final everyLaunch = ref.watch(tutorialOnEveryLaunchProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        color: AppColors.gold.withValues(alpha: 0.06),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: AppColors.gold.withValues(alpha: 0.14),
              ),
              child: const Icon(Icons.school_rounded,
                  color: AppColors.gold, size: 22),
            ),
            title: Text(
              'tutorial.card_title'.tr(),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'tutorial.card_subtitle'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () => TutorialScreen.open(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text('tutorial.play_now'.tr()),
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.gold.withValues(alpha: 0.18),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
            value: everyLaunch,
            activeThumbColor: AppColors.gold,
            onChanged: (v) =>
                ref.read(tutorialOnEveryLaunchProvider.notifier).set(v),
            title: Text(
              'tutorial.every_launch'.tr(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'tutorial.every_launch_desc'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
