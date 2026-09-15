/// The way into «مخارج الحروف».
///
/// It used to be private to the course screen. It sits on the levels screen
/// now, above both levels, because that is where it belongs: the mouth is
/// learnt first and every rule in either level is about what that mouth then
/// does. Its own source is named on its own screen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../screens/makharij_screen.dart';

class MakharijEntry extends StatelessWidget {
  const MakharijEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MakharijScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
          color: AppColors.gold.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over_rounded,
                color: AppColors.gold, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'makharij.title'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'makharij.entry_sub'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // chevron_right, not chevron_left: the left one auto-mirrors in
            // RTL and would point the wrong way here (trap #7).
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
