import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../adhan/presentation/screens/adhan_background_screen.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../adhan/presentation/screens/prayer_adjustments_screen.dart';
import '../../../adhan/presentation/screens/prayer_location_screen.dart';
import '../../../home/data/prayer_controller.dart';
import '../../../home/presentation/widgets/prayer_slides.dart'
    show prayerSlideLabelKeys, prayerSlideOrder;
import '../../../tutorial/data/tutorial_anchors.dart';

/// The Prayer page beyond the compass (owner, 2026-11-14: «وكذلك قسم
/// الصلاة» - one page for everything about the prayer, on a calm mosque
/// photograph): today's times with the next one marked, then where each
/// prayer setting lives. Split out of `qibla_screen.dart`, which sits at
/// its length ceiling.
class PrayerHubSections extends ConsumerWidget {
  const PrayerHubSections({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TodayTimesCard(),
        const SizedBox(height: 12),
        TutorialAnchor(
          id: TourAnchor.adhanSettings,
          child: IslamicActionCard(
            icon: Icons.campaign_outlined,
            title: 'prayer.adhan_settings'.tr(),
            subtitle: 'qibla.adhan_settings_hint'.tr(),
            onTap: () => _push(context, const AdhanSettingsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        TutorialAnchor(
          id: TourAnchor.prayerAdjustments,
          child: IslamicActionCard(
            icon: Icons.tune_rounded,
            accent: AppColors.info,
            title: 'prayer.adjustments'.tr(),
            subtitle: 'prayer.adjustments_hint'.tr(),
            onTap: () => _push(context, const PrayerAdjustmentsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        IslamicActionCard(
          icon: Icons.location_on_outlined,
          accent: AppColors.primarySoft,
          title: 'location.title'.tr(),
          subtitle: 'prayer_hub.location_sub'.tr(),
          onTap: () => _push(context, const PrayerLocationScreen()),
        ),
        const SizedBox(height: 10),
        IslamicActionCard(
          icon: Icons.wallpaper_outlined,
          accent: AppColors.primarySoft,
          title: 'adhan.backgrounds_title'.tr(),
          subtitle: 'prayer_hub.backgrounds_sub'.tr(),
          onTap: () => _push(context, const AdhanBackgroundScreen()),
        ),
      ],
    );
  }
}

/// Today's six times in one card, the next prayer filled in gold.
class _TodayTimesCard extends ConsumerWidget {
  const _TodayTimesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final times = ref.watch(prayerControllerProvider).valueOrNull?.times;
    if (times == null || times.isEmpty) return const SizedBox.shrink();
    final next = PrayerTimesService().nextPrayer(times, DateTime.now())?.$1;
    final theme = Theme.of(context);
    final gold = goldText(context);
    final lang = context.locale.languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'prayer_hub.today'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: gold,
              ),
            ),
            const SizedBox(height: 6),
            for (final key in prayerSlideOrder)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: key == next
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  border: key == next
                      ? Border.all(color: AppColors.gold.withValues(alpha: 0.6))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        prayerSlideLabelKeys[key]!.tr(),
                        style: TextStyle(
                          fontWeight: key == next
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (key == next)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Text(
                          'prayer_hub.next'.tr(),
                          style: TextStyle(color: gold, fontSize: 12),
                        ),
                      ),
                    Text(
                      formatTime12h(times.byName(key), lang),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: key == next ? gold : null,
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
