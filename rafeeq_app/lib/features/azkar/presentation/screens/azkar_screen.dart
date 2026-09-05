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
/// section's own card icon within a category group. P3‑43 #13 later added
/// the category *grouping* itself (`azkar_categories.dart`) on top of this
/// same per-section icon lookup — see that file's doc comment for why 8 of
/// the reference's 10 categories are real and 2 are deliberately left out
/// rather than force-fit.
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

/// Display order for the category groups — a rough daily/situational flow
/// (wake → morning → after-prayer/mosque → evening → sleep, then travel and
/// the general catch-all last) rather than the enum's declaration order.
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

class _SectionsTab extends ConsumerWidget {
  const _SectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(sciencesRepositoryProvider);
    return repoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorRetry(onRetry: () => ref.invalidate(sciencesRepositoryProvider)),
      data: (repo) => FutureBuilder<List<AzkarSection>>(
        future: repo.azkarSections(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // P3‑11: "المقدمة" (section 1) is al-Qahtani's own author's preface
          // to Hisn al-Muslim — real front-matter, but not a dhikr a user
          // would ever tap into from a list of dhikr categories. Filtered
          // out here, not at the DB/repository layer, so the underlying
          // "134 real sections" count and azkar_items(1) both stay exactly
          // as bundled — this is a display-only decision.
          final sections =
              snapshot.data!.where((s) => s.title != 'المقدمة').toList();
          final byId = {for (final s in sections) s.id: s};
          final scheme = Theme.of(context).colorScheme;

          // P3‑43 #13: group the real sections under the reference's
          // category taxonomy (`azkarSectionCategories`). Any real section
          // with no assignment there falls back into "narrated" rather than
          // silently vanishing from the tab — every one of the 133 sections
          // must still be reachable.
          final byCategory = <AzkarCategory, List<AzkarSection>>{};
          for (final s in sections) {
            final cats = azkarSectionCategories[s.id] ?? const [AzkarCategory.narrated];
            for (final c in cats) {
              (byCategory[c] ??= []).add(s);
            }
          }
          // Sanity net: azkarSectionCategories may reference an id the
          // current bundled DB doesn't have (shouldn't happen, but a
          // stale mapping should never crash the tab).
          for (final list in byCategory.values) {
            list.removeWhere((s) => !byId.containsKey(s.id));
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('azkar.hub_subtitle'.tr(),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
              ),
              for (final cat in _categoryOrder)
                if ((byCategory[cat] ?? const []).isNotEmpty)
                  ..._categorySlivers(context, cat, byCategory[cat]!),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySlivers(
    BuildContext context,
    AzkarCategory cat,
    List<AzkarSection> items,
  ) {
    final info = azkarCategoryInfo[cat]!;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
        sliver: SliverToBoxAdapter(child: _CategoryHeader(info: info)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final s = items[i];
              return _AzkarSectionCard(
                section: s,
                icon: _azkarIcon(s.title),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AzkarSectionScreen(section: s),
                  ),
                ),
              );
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }
}

class _CategoryHeader extends StatelessWidget {
  final AzkarCategoryInfo info;
  const _CategoryHeader({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: info.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            info.titleKey.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
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

