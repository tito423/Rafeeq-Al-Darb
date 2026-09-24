import '../../../../core/widgets/accordion.dart';
import '../../data/bundled_matn.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../library/data/book_text.dart';
import '../../data/jazariyyah_course.dart';
import '../../data/jazariyyah_examples.dart';
import '../../data/jazariyyah_lesson_text.dart';
import '../../data/jazariyyah_sharh.dart';
import '../widgets/listen_card.dart';

/// المستوى الثاني — «المقدمة الجزرية» لابن الجزري (ت ٨٣٣ هـ).
///
/// The level this replaced read «تيسير أحكام التجويد», a 2006 book by a living
/// author from a commercial house. «انا مش عاوز في التطبيق اي مشكلة لحقوق
/// الملكية نهائيا» — so the ladder climbs the classical way now: التحفة, then
/// الجزرية, then التمهيد. Six hundred years is a comfortable margin.
///
/// The lessons are `jazariyyah_course.dart`, generated from the book; the
/// editor's apparatus is excluded there and his footnotes are dropped again at
/// render time by `jazariyyahLessonParas`.
class JazariyyahProgress extends StateNotifier<Set<String>> {
  JazariyyahProgress() : super({}) {
    _load();
  }

  static const _key = 'jazariyyah_done_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> toggle(String lesson) async {
    final next = state.toSet();
    next.contains(lesson) ? next.remove(lesson) : next.add(lesson);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final jazariyyahProgressProvider =
    StateNotifierProvider<JazariyyahProgress, Set<String>>((ref) => JazariyyahProgress());

/// The book, downloaded on first use and then read from disk — the same
/// contract `tuhfaBookProvider` has, including why the error is logged rather
/// than only turned into «يلزم تنزيل نصّ الدروس».
final jazariyyahBookProvider = FutureProvider<BookText?>((ref) async {
  try {
    return await bundledMatn(jazariyyahBook);
  } catch (e, st) {
    debugPrint('jazariyyahBookProvider failed: $e\n$st');
    rethrow;
  }
});

/// The شرح, bundled beside the matn for the same reason the matn is.
final jazariyyahSharhProvider = FutureProvider<BookText?>((ref) async {
  try {
    return await bundledMatn(jazariyyahSharhBook);
  } catch (e, st) {
    debugPrint('jazariyyahSharhProvider failed: $e\n$st');
    return null;
  }
});

class JazariyyahLevelScreen extends ConsumerWidget {
  const JazariyyahLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(jazariyyahBookProvider);
    final done = ref.watch(jazariyyahProgressProvider);
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.level_two'.tr())),
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
                  onPressed: () => ref.invalidate(jazariyyahBookProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
        data: (text) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: jazariyyahLessons.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Header(
                // Only ticks that still belong to a lesson, so a renamed
                // section can never make this read «31 من 30».
                done: jazariyyahLessons.where((l) => done.contains(l.title)).length,
                total: jazariyyahLessons.length,
                theme: theme,
                locale: locale,
              );
            }
            final index = i - 1;
            final lesson = jazariyyahLessons[index];
            return _LessonTile(
              index: index,
              lesson: lesson,
              done: done.contains(lesson.title),
              book: text,
              locale: locale,
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
  final String locale;

  const _Header({
    required this.done,
    required this.total,
    required this.theme,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('tajweed.level_two_sub'.tr(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Text('tajweed.level_two_source'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'tajweed.progress'.tr(namedArgs: {
              'done': localizeDigits('$done', locale),
              'total': localizeDigits('$total', locale),
            }),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One lesson, collapsed until it is opened.
///
/// Collapsed by default on purpose: thirty lessons of a few hundred lines each
/// is a screen nobody can scroll, and the owner asked for the app's long lists
/// to open folded.
class _LessonTile extends ConsumerWidget {
  final int index;
  final JazariyyahLesson lesson;
  final bool done;
  final BookText? book;
  final String locale;

  const _LessonTile({
    required this.index,
    required this.lesson,
    required this.done,
    required this.book,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = book;
    final paras = text == null
        ? const <JazariyyahPara>[]
        : jazariyyahLessonParas(lesson, text);

    // The card already carries the heading; printing it again as the body's
    // first line reads as a stutter. Seen on the emulator: lesson 5 opened
    // «مدخل» / «الاستعاذة» under a card titled «الاستعاذة».
    //
    // Only the leading run is dropped, and only paragraphs that are the title
    // itself or one of Shamela's bare section anchors. A near miss keeps the
    // line rather than eating a sentence of the book.
    var skip = 0;
    while (skip < paras.length) {
      final b = jazariyyahBare(paras[skip].text);
      if (b == jazariyyahBare(lesson.title) || b == 'مدخل' || b == 'تمهيد') {
        skip++;
      } else {
        break;
      }
    }
    final body = paras.sublist(skip);

    final pages = lesson.printedFrom == lesson.printedTo
        ? 'makharij.page'.tr(
            namedArgs: {'page': localizeDigits('${lesson.printedFrom}', locale)})
        : 'makharij.page'.tr(namedArgs: {
            'page': '${localizeDigits('${lesson.printedFrom}', locale)}'
                '–${localizeDigits('${lesson.printedTo}', locale)}'
          });

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: AccordionTile(
        builder: (controller, onExpansionChanged) => ExpansionTile(
          controller: controller,
          onExpansionChanged: onExpansionChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: done
            ? CircleAvatar(
                backgroundColor: scheme.primary,
                child: Icon(Icons.check, color: scheme.onPrimary),
              )
            : CircleAvatar(
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(localizeDigits('${index + 1}', locale)),
              ),
        title: Text(lesson.title, style: theme.textTheme.titleMedium),
        subtitle: Text(pages, style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final p in body)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                p.text,
                textAlign: TextAlign.justify,
                style: switch (p.kind) {
                  'aya' => theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'AmiriQuran',
                      height: 1.9,
                      color: scheme.primary,
                    ),
                  'head' => theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.primary, height: 1.8),
                  _ => theme.textTheme.bodyMedium?.copyWith(height: 1.9),
                },
              ),
            ),
          // «الجزرية دي محتاجة شرح»: the verses above, then their شرح under
          // its own fold, so the poem stays the lesson and the explanation is
          // one tap away rather than in between its lines.
          if (index < jazariyyahSharhRanges.length)
            _SharhSection(range: jazariyyahSharhRanges[index]),
          // «اسمع الحكم في آية». One chapter can hold several rules here —
          // الجزرية puts izhar, idgham, iqlab, ikhfa and the sakin mim in a
          // single باب — so this is a list, not one card.
          for (final e in jazariyyahExamples[lesson.title] ?? const [])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListenCard(example: e),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(jazariyyahProgressProvider.notifier).toggle(lesson.title),
              icon: Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                color: scheme.primary,
              ),
              label: Text(
                done ? 'tajweed.mark_undone'.tr() : 'tajweed.mark_done'.tr(),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// «الشرح» inside a lesson: folded until tapped, and part of the accordion,
/// so opening it scrolls it into view and back folds it first.
class _SharhSection extends ConsumerWidget {
  final JazariyyahSharhRange range;
  const _SharhSection({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final book = ref.watch(jazariyyahSharhProvider).valueOrNull;
    if (book == null) return const SizedBox.shrink();
    final paras = jazariyyahSharhParas(range, book);
    if (paras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AccordionSection(
        builder: (context, open, toggle) => Container(
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'tajweed.sharh_title'.tr(),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: goldText(context)),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                ),
              ),
              if (open)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (range.shared)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'tajweed.sharh_shared'.tr(),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      for (final p in paras)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            p.text,
                            textAlign: isJazariyyahVerse(p.text)
                                ? TextAlign.center
                                : TextAlign.justify,
                            style: isJazariyyahVerse(p.text)
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.9,
                                    color: goldText(context),
                                    fontWeight: FontWeight.w600,
                                  )
                                : p.kind == 'aya'
                                    ? theme.textTheme.bodyLarge?.copyWith(
                                        fontFamily: 'AmiriQuran',
                                        height: 1.9,
                                        color: goldText(context),
                                      )
                                    : theme.textTheme.bodyMedium
                                        ?.copyWith(height: 1.9),
                          ),
                        ),
                      Text(
                        'tajweed.sharh_source'.tr(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
