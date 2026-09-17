/// المستوى الأول — «تحفة الأطفال والغلمان» للجمزوري، بشرح الضباع.
///
/// The arrangement lives in `tuhfa_course.dart` and every word of the lesson
/// is read at runtime from the book itself, downloaded once as
/// `tuhfat_al_atfal` like any other Library book. Nothing of the science is
/// written here.
///
/// WHY THIS SCREEN IS NOT THE LEVEL-TWO SCREEN WITH A DIFFERENT LIST.
/// A Tuhfa lesson is a **list of ranges**, not one: الضباع's note sits at the
/// foot of the page, below verses that already belong to the next lesson, and
/// one paragraph can carry the note for two lessons at once (page 4's last
/// paragraph holds (١) for المشددتين and (٢) for الميم الساكنة). So the body
/// walks ranges in reading order, and a range marked `commentary` is set in
/// smaller, quieter type under its own label — the matn is the Jamzuri's
/// verse, the note is the Dabba', and a reader must be able to see which is
/// which.
///
/// The heading paragraph is not repeated inside the card: the book's first
/// paragraph of a lesson IS its title, and `tuhfa_course_test.dart` is what
/// asserts that. It is compared diacritic-stripped, exactly as that test
/// compares it, and only dropped on an exact match — a near miss shows the
/// paragraph rather than swallowing it.
library;

import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/digits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../library/data/book_text.dart';
import '../../../library/data/library_api_service.dart';
import '../../data/tuhfa_course.dart';
import '../../data/tuhfa_lesson_text.dart';

/// Lessons the reader has marked done, kept by TITLE for the same reason
/// level two keeps its own that way: a boundary that is corrected later must
/// not slide somebody's ticks onto other lessons.
class TuhfaProgress extends StateNotifier<Set<String>> {
  TuhfaProgress() : super(const {}) {
    _restore();
  }

  static const _key = 'tuhfa.done_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  Future<void> toggle(String lesson) async {
    final next = {...state};
    next.contains(lesson) ? next.remove(lesson) : next.add(lesson);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final tuhfaProgressProvider =
    StateNotifierProvider<TuhfaProgress, Set<String>>((ref) => TuhfaProgress());

/// The Tuhfa text, downloaded on first use and then read from disk.
/// The error is logged rather than only turned into «يلزم تنزيل نص الدروس»,
/// for the reason written on `tajweedBookProvider`.
final tuhfaBookProvider = FutureProvider<BookText?>((ref) async {
  try {
    final api = LibraryApiService.instance;
    if (!await api.isBookDownloaded(tuhfaBook)) {
      await api.downloadBook(
        tuhfaBook,
        '${AppConfig.contentBaseUrl}/books/text/$tuhfaBook.json',
      );
    }
    return BookText.fromFile(await api.bookFilePath(tuhfaBook));
  } catch (e, st) {
    debugPrint('tuhfaBookProvider failed: $e\n$st');
    rethrow;
  }
});

class TuhfaLevelScreen extends ConsumerWidget {
  const TuhfaLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(tuhfaBookProvider);
    final done = ref.watch(tuhfaProgressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.level_one'.tr())),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('tajweed.needs_download'.tr(),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(tuhfaBookProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
        data: (text) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: tuhfaLessons.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Header(
                // Only ticks that still belong to a lesson, so a renamed
                // section can never make this read «11 من 10».
                done:
                    tuhfaLessons.where((l) => done.contains(l.title)).length,
                total: tuhfaLessons.length,
                theme: theme,
              );
            }
            final index = i - 1;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 350 + index.clamp(0, 10) * 55),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                    offset: Offset(0, (1 - v) * 22), child: child),
              ),
              child: _LessonTile(
                index: index,
                lesson: tuhfaLessons[index],
                done: done.contains(tuhfaLessons[index].title),
                book: text,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int done;
  final int total;
  final ThemeData theme;

  const _Header({required this.done, required this.total, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('tajweed.level_one_sub'.tr(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trn('tajweed.progress', namedArgs: {'done': '$done', 'total': '$total'}),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          // §1.2: the source is named where the content is read.
          Text(
            '${'tajweed.source_label'.tr()}: $tuhfaSourceLabel',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends ConsumerWidget {
  final int index;
  final TuhfaLesson lesson;
  final bool done;
  final BookText? book;

  const _LessonTile({
    required this.index,
    required this.lesson,
    required this.done,
    required this.book,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: done
              ? AppColors.gold.withValues(alpha: 0.9)
              : scheme.surfaceContainerHighest,
          child: done
              ? const Icon(Icons.check, size: 17, color: Colors.black)
              : Text(localizeDigits('${index + 1}', uiLanguageCode),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
        ),
        title: Text(lesson.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _LessonBody(lesson: lesson, book: book),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(tuhfaProgressProvider.notifier).toggle(lesson.title),
              icon: Icon(done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked),
              label: Text(
                  done ? 'tajweed.mark_undone'.tr() : 'tajweed.mark_done'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonBody extends StatelessWidget {
  final TuhfaLesson lesson;
  final BookText? book;

  const _LessonBody({required this.lesson, required this.book});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paras = tuhfaLessonParas(lesson, book);
    if (paras.isEmpty) {
      return Text('tajweed.needs_download'.tr(),
          style: TextStyle(color: scheme.onSurfaceVariant));
    }

    final children = <Widget>[];
    var labelled = false;
    for (final p in paras) {
      if (p.commentary && !labelled) {
        labelled = true;
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Divider(
                    color: AppColors.gold.withValues(alpha: 0.35), height: 1),
              ),
              const SizedBox(width: 8),
              Text(
                'tajweed.commentary'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ArabicText(
          p.text,
          style: p.commentary
              ? TextStyle(
                  fontSize: 13,
                  height: 1.8,
                  color: scheme.onSurfaceVariant,
                )
              : const TextStyle(height: 1.9),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
