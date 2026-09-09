import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

import '../../data/guide_content.dart';
import 'new_muslim_section_screen.dart';

const _icons = {
  'pillars': Icons.mosque_outlined,
  'faith': Icons.favorite_outline,
  'wudu': Icons.water_drop_outlined,
  // 'prayer' is drawn from assets/icons/praying_person.svg instead — see
  // _sectionBackgrounds' neighbour below. Material has no praying glyph and
  // the meditation one that was here read as yoga, not salah.
  'quran': Icons.menu_book_outlined,
};

/// A real Islamic photograph behind each card, each one checked by eye before
/// being used — several plausible-looking Unsplash ids turned out to be
/// autumn leaves, a fashion illustration and a climbing gym.
const _sectionBackgrounds = <String, String>{
  'pillars':
      'https://images.unsplash.com/photo-1584551246679-0daf3d275d0f?w=640&q=70&fit=crop',
  'faith':
      'https://images.unsplash.com/photo-1512632578888-169bbbc64f33?w=640&q=70&fit=crop',
  'wudu':
      'https://images.unsplash.com/photo-1548013146-72479768bada?w=640&q=70&fit=crop',
  'prayer':
      'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=640&q=70&fit=crop',
  'quran':
      'https://images.unsplash.com/photo-1609599006353-e629aaabfeae?w=640&q=70&fit=crop',
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
          final bg = _sectionBackgrounds[section.icon];
          return Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bg != null)
                  CachedNetworkImage(
                    imageUrl: bg,
                    fit: BoxFit.cover,
                    memCacheWidth: 640,
                    // No placeholder art: an empty card simply shows the
                    // scrim and stays perfectly readable, which is better
                    // than a grey block flashing on every scroll.
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                // A scrim dark enough that the title and count keep their
                // contrast over any photo underneath.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                InkWell(
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
                          padding: EdgeInsets.all(
                              section.icon == 'prayer' ? 5 : 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.6),
                            ),
                          ),
                          // The owner's own artwork for the prayer steps —
                          // used exactly as supplied, so it keeps its colours
                          // rather than being tinted to match the other
                          // glyphs. It is already a round medallion, so it
                          // fills the circle instead of sitting inside it.
                          child: section.icon == 'prayer'
                              ? ClipOval(
                                  child: Image.asset(
                                    'assets/icons/prayer_steps.jpeg',
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  _icons[section.icon] ?? Icons.book_outlined,
                                  size: 34,
                                  color: AppColors.gold,
                                ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          section.titleKey.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${section.items.length} ${isAr ? "بنود" : "points"}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
