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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: newMuslimGuideSections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final section = newMuslimGuideSections[i];
          return Card(
            child: ListTile(
              leading: Icon(_icons[section.icon] ?? Icons.book_outlined,
                  color: scheme.primary),
              title: Text(isAr ? section.titleAr : section.titleEn),
              subtitle: Text('${section.items.length} '
                  '${isAr ? "بنود" : "points"}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NewMuslimSectionScreen(section: section),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
