import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../ruqyah/presentation/screens/ruqyah_screen.dart';
import '../../data/azkar_categories.dart';
import 'azkar_section_screen.dart';
import 'azkar_settings_sheet.dart';

/// Azkar tab — real sections from Hisn al-Muslim (134 real sections, no
/// duplicates within a section — verified against the bundled DB).
///
/// P3‑4 round 2: the owner sent real references
/// (`design_refs/round2_2026-09-04/`) of the old app's own bottom nav,
/// which has **المسبحة (Tasbeeh) as its own separate tab**, not a sub-tab
/// here — split out into `tasbeeh_screen.dart`; see `AppShell` for the new
/// tab wiring.
class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('nav.azkar'.tr()),
        actions: const [AzkarSettingsButton()],
      ),
      body: const _SectionsTab(),
    );
  }
}

/// P3‑11's original real-keyword → icon mapping, still used for each
/// section's own card icon within a category group.
// ignore: unused_element
IconData _azkarIcon(String title) {
  const map = <String, IconData>{
    'الصباح': Icons.wb_sunny_outlined,
    'المساء': Icons.nights_stay_outlined,
    'النوم': Icons.bedtime_outlined,
    'الاستيقاظ': Icons.alarm,
    'الاستغفار': Icons.refresh,
    'السفر': Icons.flight_outlined,
    'الطعام': Icons.restaurant_outlined,
    'المريض': Icons.healing_outlined,
    'الميت': Icons.spa_outlined,
    'المسجد': Icons.mosque_outlined,
    'الوضوء': Icons.water_drop_outlined,
    'الصلاة': Icons.self_improvement,
    'الأذان': Icons.campaign_outlined,
    'الهم': Icons.sentiment_dissatisfied_outlined,
    'الكرب': Icons.sentiment_very_dissatisfied_outlined,
    'الزواج': Icons.favorite_outline,
    'المولود': Icons.child_care_outlined,
    'المطر': Icons.water_outlined,
    'الرعد': Icons.bolt_outlined,
    'الحج': Icons.location_on_outlined,
    'العطاس': Icons.sick_outlined,
    'الغضب': Icons.mood_bad_outlined,
    'السلام': Icons.waving_hand_outlined,
  };
  for (final entry in map.entries) {
    if (title.contains(entry.key)) return entry.value;
  }
  return Icons.auto_awesome_outlined;
}

/// Display order for the category groups.
const _categoryOrder = [
  // First, because the owner asked for it to be in the Adhkar tab and it is
  // the one people come looking for.
  AzkarCategory.ruqyah,
  AzkarCategory.waking,
  AzkarCategory.morning,
  AzkarCategory.mosque,
  AzkarCategory.afterPrayer,
  AzkarCategory.evening,
  AzkarCategory.sleep,
  AzkarCategory.travel,
  AzkarCategory.narrated,
];

/// Beautiful Islamic background image URLs per category (royalty-free from
/// Unsplash, small 640px crops to minimize bandwidth). Cached locally by
/// CachedNetworkImage so they load once and work offline after that.
const _categoryBackgroundUrls = <AzkarCategory, String>{
  AzkarCategory.waking:
      'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?w=640&q=70&fit=crop',
  // A mosque under dawn light — the morning adhkar are read at first light,
  // so the card now actually looks like when they belong.
  AzkarCategory.morning:
      'https://images.unsplash.com/photo-1519817650390-64a93db51149?w=640&q=70&fit=crop',
  AzkarCategory.mosque:
      'https://images.unsplash.com/photo-1591604129939-f1efa4d99f7e?w=640&q=70&fit=crop',
  AzkarCategory.afterPrayer:
      'https://images.unsplash.com/photo-1564769625905-50e93615e769?w=640&q=70&fit=crop',
  AzkarCategory.evening:
      'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=640&q=70&fit=crop',
  AzkarCategory.sleep:
      'https://images.unsplash.com/photo-1532978379173-523e16f371f2?w=640&q=70&fit=crop',
  AzkarCategory.travel:
      'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=640&q=70&fit=crop',
  AzkarCategory.narrated:
      'https://images.unsplash.com/photo-1585036156171-384164a8c956?w=640&q=70&fit=crop',
};

class _SectionsTab extends ConsumerWidget {
  const _SectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: _categoryOrder.length,
      itemBuilder: (context, i) {
        final category = _categoryOrder[i];
        final info = azkarCategoryInfo[category]!;
        final bgUrl = _categoryBackgroundUrls[category];
        
        return _CategoryCard(
          category: category,
          info: info,
          bgUrl: bgUrl,
        );
      },
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final AzkarCategory category;
  final AzkarCategoryInfo info;
  final String? bgUrl;

  const _CategoryCard({
    required this.category,
    required this.info,
    required this.bgUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () async {
          // Ruqyah is not a Hisn al-Muslim section (see `azkar_categories.dart`),
          // so it opens its own composed screen rather than a section list.
          if (category == AzkarCategory.ruqyah) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RuqyahScreen()),
            );
            return;
          }
          final repo = await ref.read(sciencesRepositoryProvider.future);
          final allSections = await repo.azkarSections();
          final sections = allSections.where((s) {
            final cats = azkarSectionCategories[s.id] ?? const [AzkarCategory.narrated];
            return cats.contains(category) && s.title != 'المقدمة';
          }).toList();
          
          if (!context.mounted) return;
          
          if (sections.length == 1 || category == AzkarCategory.morning || category == AzkarCategory.evening) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AzkarSectionScreen(
                  section: sections.first,
                  accent: info.gradient.last,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CategorySectionsListScreen(
                  categoryInfo: info,
                  sections: sections,
                  bgUrl: bgUrl,
                ),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: info.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // A photo where there is one; otherwise the painted khātim
              // lattice, which costs no bytes and renders identically offline.
              // Before this, a card with no photo was a bare gradient.
              if (bgUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.2,
                    child: CachedNetworkImage(
                      imageUrl: bgUrl!,
                      fit: BoxFit.cover,
                      // Not `Positioned.fill`: this is laid out inside the
                      // image widget, not inside the Stack, and a Positioned
                      // there threw «type 'ParentData' is not a subtype of
                      // type 'StackParentData'» — seen in the release log on
                      // emulator-5554 whenever a card's photo failed to load.
                      errorWidget: (context, url, error) => SizedBox.expand(
                        child: CustomPaint(
                          painter: IslamicPatternPainter(
                            tile: 46,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: CustomPaint(
                    painter: IslamicPatternPainter(
                      tile: 46,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        info.icon,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        info.titleKey.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySectionsListScreen extends StatelessWidget {
  final AzkarCategoryInfo categoryInfo;
  final List<AzkarSection> sections;
  final String? bgUrl;

  const _CategorySectionsListScreen({
    required this.categoryInfo,
    required this.sections,
    this.bgUrl,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryInfo.titleKey.tr()),
        backgroundColor: categoryInfo.gradient.first,
        foregroundColor: Colors.white,
      ),
      // The owner found these lists bare next to the rest of the app — «فيه
      // في الأذكار شاشات مالهاش خلفيات زي مثلا أذكار السفر» — and asked
      // for the ground to be **drawn, not downloaded**: «ومش تنزلها لاء
      // اعملها برمجيا». So it is: the category's own two colours, the
      // geometric tile the app already paints elsewhere, and the app mark.
      // Nothing fetched, nothing bundled, and it costs no bytes.
      body: _CategoryGround(
        colors: categoryInfo.gradient,
        child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            // Slightly translucent so the ground reads through it without
            // costing the dark-on-light contrast the list depends on.
            color: scheme.surface.withValues(alpha: 0.92),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: categoryInfo.gradient.first.withValues(alpha: 0.18),
              ),
            ),
            child: ListTile(
              leading: Icon(categoryInfo.icon, color: categoryInfo.gradient.first),
              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AzkarSectionScreen(
                      section: s,
                      accent: categoryInfo.gradient.last,
                    ),
                  ),
                );
              },
            ),
          );
        },
        ),
      ),
    );
  }
}

/// The drawn ground behind a category's list of adhkar.
///
/// Three layers, all painted: a soft wash of the category's own gradient at
/// the top, the app's geometric tile at low opacity, and the app mark as a
/// faint watermark in the corner. It deliberately stays light — the list's
/// text is dark-on-light and a deep ground would have cost that contrast
/// (trap #15: judge a pairing by its composite, not by how the colour looks
/// alone).
class _CategoryGround extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const _CategoryGround({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = colors.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(tint.withValues(alpha: 0.16), scheme.surface),
            Color.alphaBlend(
                colors.last.withValues(alpha: 0.06), scheme.surface),
            scheme.surface,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(
                tile: 52,
                color: tint.withValues(alpha: 0.07),
              ),
            ),
          ),
          // No app-mark watermark here. It works on the dark card ground of
          // `azkar_section_screen.dart`, but seen on this light one it showed
          // its own PNG bounding box as a pale square — photographed on the
          // emulator before this line was removed. The tile alone carries the
          // identity.
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
