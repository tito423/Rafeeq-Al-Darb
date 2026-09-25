import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

/// The first-run download page, again: «حطها خيار في التنزيلات ممكن ارجعلها
/// بعدين» (2026-09-25). Same rows and the same download jobs; the page's
/// button just closes it ([OnboardingScreen.revisit]).
class InitialDownloadsEntry extends StatelessWidget {
  const InitialDownloadsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // 12 above, 18 below: the gaps the list had around this slot.
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 18),
      child: Card(
        child: ListTile(
          leading: Icon(
            Icons.download_for_offline_rounded,
            color: goldText(context),
          ),
          title: Text('onboarding.title'.tr()),
          subtitle: Text('onboarding.revisit_hint'.tr()),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const OnboardingScreen(revisit: true),
            ),
          ),
        ),
      ),
    );
  }
}
