import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/db/sciences_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_retry.dart';
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

/// P3‑11: real-keyword → icon mapping for the grid redesign
/// (`design_refs/ref_azkar_hub.jpg`) — deliberately **not** a fixed 6-card
/// taxonomy (أذكار الصباح / أذكار المساء / التسبيح والتحميد / أدعية
/// قرآنية / … as separate cards), because Hisn al-Muslim's real 134
/// sections don't actually split that way: there is exactly **one**
/// combined "أذكار الصباح والمساء" section (§29), no standalone "أدعية
/// قرآنية" section, and no "التسبيح والتحميد" dhikr-text section (§132/133
/// are *about* the virtue of tasbih, not the dhikr texts themselves — that
/// content lives in the المسبحة tab instead). Inventing separate cards for
/// categories the data doesn't actually have would be exactly the kind of
/// placeholder structure rule 1 forbids. Instead: every one of the real 133
/// sections (⁠المقدمة filtered) gets its own card in a 2-column grid — the
/// reference's *visual language* (icon + title card, not a bare list row),
/// applied honestly to the real content.
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
          final scheme = Theme.of(context).colorScheme;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('azkar.hub_subtitle'.tr(),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                sliver: SliverToBoxAdapter(
                  child: Text('azkar.choose_type'.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final s = sections[i];
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
                    childCount: sections.length,
                  ),
                ),
              ),
            ],
          );
        },
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

