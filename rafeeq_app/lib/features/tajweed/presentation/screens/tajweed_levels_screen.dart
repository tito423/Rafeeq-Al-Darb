/// «تعليم التجويد» — the ladder.
///
/// The owner, 2026-10-02: the three-matn ladder was «كبير جدا وصعب جدا على
/// الاطفال لدرجة اني انا في المستوى الاول مفهمتش حاجة», and «مش شرط تلت
/// مستويات … اهم حاجة بتدرج وسهولة … منهج كامل ميسيبش اي حاجة». So it now
/// opens on two prose books written to TEACH (`course_book.dart`):
///
///   1. «تيسير أحكام التجويد (المستوى الأول)» — question and answer, for
///      young pupils, with the examples in tables.
///   2. «غاية المريد في علم التجويد» — the whole science, chapter by
///      chapter, each chapter with its questions.
///   3. تحفة الأطفال, then 4. الجزرية — the two mutoon, read once the rules
///      they versify are understood, rather than before.
///   5. التمهيد — Ibn al-Jazari's own prose, for whoever wants more.
///
/// The owner lifted the copyright constraint for this section himself
/// («مش شرط حقوق ملكية»); each level still names its source where it is read.
///
/// Each card's progress is read from that level's own store, so the
/// counters cannot drift into each other.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/paired_list_view.dart';
import '../../data/course_book.dart';
import '../../data/jazariyyah_course.dart';
import '../../data/tamhid_course.dart';
import '../../data/tuhfa_course.dart';
import '../widgets/makharij_entry.dart';
import 'course_book_screen.dart';
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

    _LevelCard course(int number, String id, String key) {
      final lessons =
          ref.watch(courseBookProvider(id)).valueOrNull?.lessons ?? const [];
      final done = ref.watch(courseProgressProvider(id));
      return _LevelCard(
        number: number,
        title: 'tajweed.$key'.tr(),
        subtitle: 'tajweed.${key}_sub'.tr(),
        total: lessons.length,
        done: lessons.where((l) => done.contains(l.title)).length,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CourseBookScreen(
              courseId: id,
              titleKey: 'tajweed.$key',
              subtitleKey: 'tajweed.${key}_sub',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text(
            'tajweed.subtitle'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          // Sideways the entries stand two by two (`PairedColumn`).
          PairedColumn(
            children: [
              const MakharijEntry(),
              course(1, taysirCourse, 'taysir'),
              course(2, ghayaCourse, 'ghaya'),
              _LevelCard(
                number: 3,
                title: 'tajweed.level_one'.tr(),
                subtitle: 'tajweed.level_one_sub'.tr(),
                total: tuhfaLessons.length,
                // Only ticks that still belong to a lesson in this level.
                done: tuhfaLessons
                    .where((l) => tuhfaDone.contains(l.title))
                    .length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TuhfaLevelScreen(),
                  ),
                ),
              ),
              _LevelCard(
                number: 4,
                title: 'tajweed.level_two'.tr(),
                subtitle: 'tajweed.level_two_sub'.tr(),
                total: jazariyyahLessons.length,
                done: jazariyyahLessons
                    .where((l) => jazariyyahDone.contains(l.title))
                    .length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const JazariyyahLevelScreen(),
                  ),
                ),
              ),
              _LevelCard(
                number: 5,
                title: 'tajweed.level_three'.tr(),
                subtitle: 'tajweed.level_three_sub'.tr(),
                total: tamhidLessons.length,
                done: tamhidLessons
                    .where((l) => tamhidDone.contains(l.title))
                    .length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TamhidLevelScreen(),
                  ),
                ),
              ),
            ],
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
                              '$number',
                              context.locale.languageCode,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: goldText(context),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: scheme.onSurfaceVariant,
                          ),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    localizeDigits(
                      'tajweed.lessons_count'.plural(total),
                      context.locale.languageCode,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    localizeDigits(
                      'tajweed.progress'.tr(
                        namedArgs: {'done': '$done', 'total': '$total'},
                      ),
                      context.locale.languageCode,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
