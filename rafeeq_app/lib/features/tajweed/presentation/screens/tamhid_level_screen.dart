import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/digits.dart';
import '../../../library/data/book_text.dart';
import '../../../library/data/library_api_service.dart';
import '../../data/tamhid_course.dart';
import '../../data/tamhid_lesson_text.dart';

/// المستوى الثالث — «التمهيد في علم التجويد» لابن الجزري (ت ٨٣٣ هـ).
///
/// This level used to read «غاية المريد» لعطية قابل نصر (ت ١٤٢٤ هـ), a book
/// still in copyright. «انا مش عاوز في التطبيق اي مشكلة لحقوق الملكية نهائيا»,
/// so it reads ابن الجزري's own prose instead — the same author as the matn
/// the level below teaches, six hundred years out of copyright.
///
/// Thirteen lessons along his own أبواب, from «مقدمة ابن الجزري» to
/// «معرفة الظاء وتمييزها من الضاد».
class TamhidProgress extends StateNotifier<Set<String>> {
  TamhidProgress() : super({}) {
    _load();
  }

  static const _key = 'tamhid_done_v1';

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

final tamhidProgressProvider =
    StateNotifierProvider<TamhidProgress, Set<String>>((ref) => TamhidProgress());

/// The book, downloaded on first use and then read from disk — the same
/// contract `tuhfaBookProvider` has, including why the error is logged rather
/// than only turned into «يلزم تنزيل نصّ الدروس».
final tamhidBookProvider = FutureProvider<BookText?>((ref) async {
  try {
    final api = LibraryApiService.instance;
    if (!await api.isBookDownloaded(tamhidBook)) {
      await api.downloadBook(
        tamhidBook,
        '${AppConfig.contentBaseUrl}/books/text/$tamhidBook.json',
      );
    }
    return BookText.fromFile(await api.bookFilePath(tamhidBook));
  } catch (e, st) {
    debugPrint('tamhidBookProvider failed: $e\n$st');
    rethrow;
  }
});

class TamhidLevelScreen extends ConsumerWidget {
  const TamhidLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(tamhidBookProvider);
    final done = ref.watch(tamhidProgressProvider);
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.level_three'.tr())),
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
                  onPressed: () => ref.invalidate(tamhidBookProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('common.retry'.tr()),
                ),
              ],
            ),
          ),
        ),
        data: (text) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: tamhidLessons.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Header(
                // Only ticks that still belong to a lesson, so a renamed
                // section can never make this read «31 من 30».
                done: tamhidLessons.where((l) => done.contains(l.title)).length,
                total: tamhidLessons.length,
                theme: theme,
                locale: locale,
              );
            }
            final index = i - 1;
            final lesson = tamhidLessons[index];
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
          Text('tajweed.level_three_sub'.tr(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Text('tajweed.level_three_source'.tr(),
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
  final TamhidLesson lesson;
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
        ? const <TamhidPara>[]
        : tamhidLessonParas(lesson, text);

    // The card already carries the heading; printing it again as the body's
    // first line reads as a stutter. Seen on the emulator: lesson 5 opened
    // «مدخل» / «الاستعاذة» under a card titled «الاستعاذة».
    //
    // Only the leading run is dropped, and only paragraphs that are the title
    // itself or one of Shamela's bare section anchors. A near miss keeps the
    // line rather than eating a sentence of the book.
    var skip = 0;
    while (skip < paras.length) {
      final b = tamhidBare(paras[skip].text);
      if (b == tamhidBare(lesson.title) || b == 'مدخل' || b == 'تمهيد') {
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
      child: ExpansionTile(
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(tamhidProgressProvider.notifier).toggle(lesson.title),
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
    );
  }
}
