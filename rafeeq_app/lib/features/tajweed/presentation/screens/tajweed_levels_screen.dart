/// «تعليم التجويد» — the two levels.
///
/// The ladder the owner asked for is «ابدأه بالسهل اللي يناسب الاطفال
/// وبالتدرج»: تحفة الأطفال first, then تيسير أحكام التجويد. Both are real
/// books read verbatim at runtime, and each level names its own source on its
/// own screen.
///
/// Only levels that HAVE lessons are listed. غاية المريد is the third rung of
/// the ladder and is already hosted, but nothing has been arranged out of it
/// yet, and a card that opens onto nothing is the kind of claim §1.1 forbids.
///
/// Each card's progress is read from that level's own store, so the two
/// counters cannot drift into each other.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/tajweed_course.dart';
import '../../data/tuhfa_course.dart';
import '../widgets/makharij_entry.dart';
import 'tajweed_course_screen.dart';
import 'tuhfa_level_screen.dart';

class TajweedLevelsScreen extends ConsumerWidget {
  const TajweedLevelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tuhfaDone = ref.watch(tuhfaProgressProvider);
    final taysirDone = ref.watch(tajweedProgressProvider);

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text(
            'tajweed.subtitle'.tr(),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          const MakharijEntry(),
          const SizedBox(height: 18),
          _LevelCard(
            number: 1,
            title: 'tajweed.level_one'.tr(),
            subtitle: 'tajweed.level_one_sub'.tr(),
            total: tuhfaLessons.length,
            // Only ticks that still belong to a lesson in this level.
            done: tuhfaLessons.where((l) => tuhfaDone.contains(l.title)).length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TuhfaLevelScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _LevelCard(
            number: 2,
            title: 'tajweed.level_two'.tr(),
            subtitle: 'tajweed.level_two_sub'.tr(),
            total: tajweedLessons.length,
            done: tajweedLessons
                .where((l) => taysirDone.contains(l.sectionTitle))
                .length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const TajweedCourseScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final int done;
  final int total;
  final VoidCallback onTap;

  const _LevelCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final complete = total > 0 && done >= total;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: complete
                        ? AppColors.gold.withValues(alpha: 0.9)
                        : AppColors.gold.withValues(alpha: 0.18),
                    child: complete
                        ? const Icon(Icons.check, size: 19, color: Colors.black)
                        : Text(
                            '$number',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'tajweed.lessons_count'.plural(total),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    'tajweed.progress'
                        .tr(namedArgs: {'done': '$done', 'total': '$total'}),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
