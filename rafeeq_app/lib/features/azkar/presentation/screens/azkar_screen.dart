import '../../../../core/widgets/paired_list_view.dart';
import '../../../../core/widgets/mirrored_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/azkar_repository.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../ruqyah/presentation/screens/ruqyah_screen.dart';
import '../../data/azkar_categories.dart';
import 'azkar_section_screen.dart';
import 'azkar_settings_sheet.dart';
import '../../data/azkar_backgrounds.dart';
import '../../../tutorial/data/tutorial_anchors.dart';
import '../../../../core/utils/screen_class.dart';

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


class _SectionsTab extends ConsumerWidget {
  const _SectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This tab is built `const`, so a language switch never rebuilt it and
    // the cards kept the old language until a restart (Arabic -> Urdu on
    // emulator-5554, 2026-09-24). Reading the locale makes it depend on it.
    context.locale;
    return LayoutBuilder(builder: (context, box) {
    // Where height is short (a phone sideways), each row is half of what
    // the grid has, so both rows of sections are whole on screen - the
    // second row was cut at the bottom (owner's Xiaomi, 2026-09-26).
    final rowHeight = ScreenClass.shortHeight(context)
        ? ((box.maxHeight - 32 - 14) / 2).clamp(120.0, 220.0)
        : null;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      // By card width, not a fixed 2: in landscape two columns made each
      // card taller than the screen and its title fell below the fold
      // (emulator-5554, 2026-09-24). A phone held upright still gets 2.
      //
      // Sideways that still left one row of tall cards on the owner's Xiaomi
      // (2026-09-26), three sections of nine in view. Sideways the
      // cards are smaller and wider than tall, like a tablet's tiles: four
      // across on that phone (788 dp / 214), two rows and more in view.
      gridDelegate: ScreenClass.twoColumns(context)
          ? SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.2,
              mainAxisExtent: rowHeight,
            )
          : const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
      itemCount: _categoryOrder.length,
      itemBuilder: (context, i) {
        final category = _categoryOrder[i];
        final info = azkarCategoryInfo[category]!;
        final bgUrl = azkarCategoryBackgrounds[category];
        
        final card = _CategoryCard(
          category: category,
          info: info,
          bgUrl: bgUrl,
        );
        // The tour explains the grid through its first card.
        return i == 0
            ? TutorialAnchor(id: TourAnchor.azkarCategory, child: card)
            : card;
      },
    );
    });
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
          final repo = await ref.read(azkarRepositoryProvider.future);
          final allSections = await repo.sections();
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
                    child: MirroredNetworkImage(
                      url: bgUrl!,
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
        // `foregroundColor` alone loses to the theme: AppBarTheme sets its own
        // iconTheme and titleTextStyle (onSurface), and those win. Found on
        // the splash preview (emulator-5554, 2026-09-26), where the same bar
        // drew dark icons on the dark clip. So white is given outright.
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: Theme.of(context)
            .appBarTheme
            .titleTextStyle
            ?.copyWith(color: Colors.white),
      ),
      // The owner found these lists bare next to the rest of the app — «فيه
      // في الأذكار شاشات مالهاش خلفيات زي مثلا أذكار السفر» — and asked
      // for the ground to be **drawn, not downloaded**: «ومش تنزلها لاء
      // اعملها برمجيا». So it is: the category's own two colours, the
      // geometric tile the app already paints elsewhere, and the app mark.
      // Nothing fetched, nothing bundled, and it costs no bytes.
      body: _CategoryGround(
        colors: categoryInfo.gradient,
        // Sideways two a row (`PairedListView`).
        child: PairedListView.builder(
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
              title: Text(s.localizedTitle(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
