import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/guide_content.dart';
import 'new_muslim_section_screen.dart';

const _icons = {
  'pillars': Icons.mosque_outlined,
  'faith': Icons.favorite_outline,
  'wudu': Icons.water_drop_outlined,
  'prayer': Icons.self_improvement_outlined,
  'quran': Icons.menu_book_outlined,
};

/// New Muslim Guide (WORK_QUEUE Stage 5) — pillars of Islam, articles of
/// faith, wudu, prayer steps, and a Quran introduction. Content is written
/// directly in `guide_content.dart` from well-established, uncontroversial
/// mainstream Sunni teaching, per the owner's explicit direction to use
/// known trusted sources rather than inventing content or scraping a site.
class NewMuslimGuideScreen extends StatelessWidget {
  const NewMuslimGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('new_muslim.title'.tr())),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: newMuslimGuideSections.length,
        itemBuilder: (context, i) {
          final section = newMuslimGuideSections[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NewMuslimSectionScreen(section: section),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icons[section.icon] ?? Icons.book_outlined,
                        size: 36,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? section.titleAr : section.titleEn,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${section.items.length} ${isAr ? "بنود" : "points"}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
