import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/transliteration_settings_provider.dart';

/// Card in Settings providing reading assistance options for non-Arabic speakers,
/// including a live preview of the Latin transliteration toggle.
class NonArabicReadingCard extends ConsumerWidget {
  const NonArabicReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = AppColors.gold;
    final isEnabled = ref.watch(transliterationEnabledProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled
              ? gold.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.non_arabic_reading_title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'settings.non_arabic_reading_desc'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Toggle Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.record_voice_over_outlined,
                color: isEnabled ? gold : scheme.onSurfaceVariant,
              ),
              title: Text(
                'settings.show_transliteration'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'settings.show_transliteration_desc'.tr(),
                style: theme.textTheme.bodySmall,
              ),
              value: isEnabled,
              activeThumbColor: gold,
              onChanged: (v) =>
                  ref.read(transliterationEnabledProvider.notifier).set(v),
            ),

            const SizedBox(height: 10),

            // Live Preview Box
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isEnabled
                    ? gold.withValues(alpha: 0.08)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnabled
                      ? gold.withValues(alpha: 0.35)
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'settings.live_preview'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isEnabled ? gold : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Quran.com v4 API',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'AmiriQuran',
                      height: 1.8,
                    ),
                  ),
                  if (isEnabled) ...[
                    const SizedBox(height: 6),
                    Container(
                      height: 1,
                      width: 60,
                      color: gold.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bismi Allāhi r-Raḥmāni r-Raḥīm',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: gold,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'settings.transliteration_off_hint'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
