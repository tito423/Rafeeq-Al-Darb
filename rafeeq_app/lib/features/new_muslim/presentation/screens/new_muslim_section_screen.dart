import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../data/guide_content.dart';

/// One guide topic's steps/points, e.g. Wudu's 8 steps.
class NewMuslimSectionScreen extends StatelessWidget {
  final GuideSection section;
  const NewMuslimSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(section.titleKey.tr())),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: section.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = section.items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.headingKey.tr(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.bodyKey.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  if (item.phraseAr != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                      ),
                      // ArabicText: the phrase is Arabic (the shahada, the
                      // tasbeeh) shown in a UI that is LTR in six locales.
                      child: ArabicText(
                        item.phraseAr!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 18,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
