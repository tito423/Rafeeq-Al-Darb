/// «تعليم التجويد» — the three levels.
///
/// The ladder the owner asked for is «ابدأه بالسهل اللي يناسب الاطفال
/// وبالتدرج»: تحفة الأطفال للجمزوري first, then المقدمة الجزرية, then
/// التمهيد في علم التجويد — the last two by ابن الجزري himself, his
/// matn and then his own prose on the same science. All three are real books
/// read verbatim at runtime, and each level names its own source on its own
/// screen.
///
/// **Every rung is public domain.** The ladder used to end on two books by
/// modern authors from commercial houses; they were taken out of the app and
/// deleted off the bucket, because «انا مش عاوز في التطبيق اي مشكلة
/// لحقوق الملكية نهائيا». الجمزوري died after 1198 AH and ابن الجزري in
/// 833 AH; nothing on this ladder belongs to anyone living.
///
/// Only levels that HAVE lessons are listed — a card that opens onto nothing
/// is the kind of claim §1.1 forbids.
///
/// Each card's progress is read from that level's own store, so the three
/// counters cannot drift into each other.
library;

import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/digits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/jazariyyah_course.dart';
import '../../data/tamhid_course.dart';
import '../../data/tuhfa_course.dart';
import '../widgets/makharij_entry.dart';
import 'jazariyyah_level_screen.dart';
import 'tamhid_level_screen.dart';
import 'tuhfa_level_screen.dart';

class TajweedLevelsScreen extends ConsumerWidget {
  const TajweedLevelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tuhfaDone = ref.watch(tuhfaProgressProvider);
    final jazariyyahDone = ref.watch(jazariyyahProgressProvider);
    final tamhidDone = ref.watch(tamhidProgressProvider);

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
            total: jazariyyahLessons.length,
            done: jazariyyahLessons
                .where((l) => jazariyyahDone.contains(l.title))
                .length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const JazariyyahLevelScreen()),
            ),
          ),
          const SizedBox(height: 12),
          // «علم التجويد كامل في المستويين دول بس ولا في اكتر» — it was not,
          // and when it finally was, it stood on two books still in copyright.
          // The ladder is all Ibn al-Jazari and al-Jamzuri now: matn, matn,
          // then the author's own commentary. Nothing in it is anyone's
          // property.
          _LevelCard(
            number: 3,
            title: 'tajweed.level_three'.tr(),
            subtitle: 'tajweed.level_three_sub'.tr(),
            total: tamhidLessons.length,
            done: tamhidLessons
                .where((l) => tamhidDone.contains(l.title))
                .length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const TamhidLevelScreen()),
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
                            localizeDigits(
                                '$number', context.locale.languageCode),
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
                  const SizedBox(width: 6),
                  // chevron_right, not chevron_left: the left one auto-mirrors
                  // in RTL and would point the wrong way (trap #7).
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
                    localizeDigits('tajweed.lessons_count'.plural(total),
                        context.locale.languageCode),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    localizeDigits(
                        'tajweed.progress'.tr(
                            namedArgs: {'done': '$done', 'total': '$total'}),
                        context.locale.languageCode),
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
