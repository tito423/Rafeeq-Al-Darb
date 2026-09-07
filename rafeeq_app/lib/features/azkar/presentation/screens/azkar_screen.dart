import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
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
  AzkarCategory.morning:
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=640&q=70&fit=crop',
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
    final repoAsync = ref.watch(sciencesRepositoryProvider);
    return repoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          ErrorRetry(onRetry: () => ref.invalidate(sciencesRepositoryProvider)),
      data: (repo) => FutureBuilder<List<AzkarSection>>(
        future: repo.azkarSections(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // P3‑11: filter out the author preface (section 1 "المقدمة").
          final sections =
              snapshot.data!.where((s) => s.title != 'المقدمة').toList();
          final byId = {for (final s in sections) s.id: s};

          final byCategory = <AzkarCategory, List<AzkarSection>>{};
          for (final s in sections) {
            final cats = azkarSectionCategories[s.id] ??
                const [AzkarCategory.narrated];
            for (final c in cats) {
              (byCategory[c] ??= []).add(s);
            }
          }
          for (final list in byCategory.values) {
            list.removeWhere((s) => !byId.containsKey(s.id));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              Text(
                'azkar.hub_subtitle'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _categoryOrder.length; i++)
                if ((byCategory[_categoryOrder[i]] ?? const []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryExpansionCard(
                      key: PageStorageKey<int>(i),
                      category: _categoryOrder[i],
                      items: byCategory[_categoryOrder[i]]!,
                      initiallyExpanded: i == 0,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// A collapsible category card with an Islamic background image.
class _CategoryExpansionCard extends StatelessWidget {
  final AzkarCategory category;
  final List<AzkarSection> items;
  final bool initiallyExpanded;

  const _CategoryExpansionCard({
    super.key,
    required this.category,
    required this.items,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final info = azkarCategoryInfo[category]!;
    final bgUrl = _categoryBackgroundUrls[category];

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        title: _CategoryHeaderWithBg(
          info: info,
          bgUrl: bgUrl,
          count: items.length,
        ),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final s = items[i];
              return _AzkarSectionCard(
                section: s,
                icon: _azkarIcon(s.title),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AzkarSectionScreen(
                      section: s,
                      accent: info.gradient.last,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Category header with a beautiful Islamic background image overlaid with a
/// gradient in the category's own colors.
class _CategoryHeaderWithBg extends StatelessWidget {
  final AzkarCategoryInfo info;
  final String? bgUrl;
  final int count;

  const _CategoryHeaderWithBg({
    required this.info,
    required this.bgUrl,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with color filter
          if (bgUrl != null)
            CachedNetworkImage(
              imageUrl: bgUrl!,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.multiply,
              color: info.gradient.first.withValues(alpha: 0.6),
              placeholder: (_, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: info.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: info.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: info.gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          // Gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  info.gradient.first.withValues(alpha: 0.85),
                  info.gradient.last.withValues(alpha: 0.55),
                ],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.titleKey.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count ${_sectionCountLabel(count)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Arabic plural helper for "قسم".
  static String _sectionCountLabel(int n) {
    if (n <= 2) return 'قسم';
    if (n <= 10) return 'أقسام';
    return 'قسمًا';
  }
}

class _AzkarSectionCard extends StatelessWidget {
  final AzkarSection section;
  final IconData icon;
  final VoidCallback onTap;
  const _AzkarSectionCard(
      {required this.section, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.gold, size: 26),
              Text(
                section.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
