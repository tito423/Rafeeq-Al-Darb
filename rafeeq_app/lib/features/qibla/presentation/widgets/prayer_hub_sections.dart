import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_action_card.dart';
import '../../../adhan/presentation/screens/adhan_settings_screen.dart';
import '../../../adhan/presentation/screens/prayer_adjustments_screen.dart';
import '../../../tutorial/data/tutorial_anchors.dart';

/// The Prayer page beyond the compass (owner, 2026-11-14: «وكذلك قسم
/// الصلاة» - one page for everything about the prayer, on a calm mosque
/// photograph): the two ways into every prayer setting. Split out of
/// `qibla_screen.dart`, which sits at its length ceiling.
///
/// Each thing lives once (owner, 2026-11-14: «مواقيت الصلاة وكمان موقع
/// الصلاة متكرر»): today's times are Home's prayer card, the place is the
/// first row of the adjustments screen, the adhan pictures are in the adhan
/// settings - so none of them has a card of its own here.
class PrayerHubSections extends StatelessWidget {
  const PrayerHubSections({super.key});

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }
}
