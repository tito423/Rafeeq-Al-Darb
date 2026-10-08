/// A prose course of the tajweed ladder (`course_book.dart`): its lessons,
/// and each lesson on a page of its own.
///
/// A lesson of «غاية المريد» runs to dozens of paragraphs, its questions and
/// its footnotes; folded into a list tile it was a wall. So the list only
/// names the lessons, and a lesson opens full-screen with «الدرس التالي» at
/// its foot, the way a child turns the page of a school book.
///
/// The Taysir is written as question and answer («س - … ج - …»); the two are
/// set as a question card and an answer card, which is what the author's
/// letters meant on paper. Every Qur'an word is in the mushaf's own face and
/// can be tapped to hear its ayah recited.
library;

import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../data/course_book.dart';
import '../../data/tajweed_example.dart';
import '../widgets/lesson_text.dart';
import '../widgets/listen_card.dart';

class CourseBookScreen extends ConsumerWidget {
  final String courseId;

  /// The level's name and one-line description (translation keys).
  final String titleKey;
  final String subtitleKey;

  const CourseBookScreen({
    super.key,
    required this.courseId,
    required this.titleKey,
    required this.subtitleKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(courseBookProvider(courseId));
    final done = ref.watch(courseProgressProvider(courseId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(titleKey.tr())),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(courseBookProvider(courseId)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('common.retry'.tr()),
          ),
        ),
        data: (b) {
          final count = b.lessons.where((l) => done.contains(l.title)).length;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: b.lessons.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitleKey.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: b.lessons.isEmpty
                              ? 0
                              : count / b.lessons.length,
                          minHeight: 8,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trn(
                          'tajweed.progress',
                          namedArgs: {
                            'done': '$count',
                            'total': '${b.lessons.length}',
                          },
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // §1.2: the source is named where the content is read.
                      ArabicText(
                        '${b.title} — ${b.author} — ${b.edition}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${'tajweed.via_shamela'.tr()} · ${b.shamelaUrl}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final index = i - 1;
              final lesson = b.lessons[index];
              final isDone = done.contains(lesson.title);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isDone
                        ? AppColors.gold.withValues(alpha: 0.9)
                        : scheme.surfaceContainerHighest,
                    child: isDone
                        ? const Icon(Icons.check, size: 17, color: Colors.black)
                        : Text(
                            localizeDigits('${index + 1}', uiLanguageCode),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  title: ArabicText(
                    lesson.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  // chevron_right: the left one mirrors in RTL (trap #7).
                  trailing: Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CourseLessonScreen(courseId: courseId, index: index),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CourseLessonScreen extends ConsumerWidget {
  final String courseId;
  final int index;

  const CourseLessonScreen({
    super.key,
    required this.courseId,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(courseBookProvider(courseId)).valueOrNull;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lesson = book.lessons[index];
    final done = ref.watch(courseProgressProvider(courseId));
    final isDone = done.contains(lesson.title);
    final hasNext = index + 1 < book.lessons.length;
    final blocks = lesson.blocks;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: blocks.length + 1,
        itemBuilder: (context, i) {
          if (i < blocks.length) {
            return CourseBlockView(
              block: blocks[i],
              // A table's first row is its header.
              firstRow:
                  blocks[i].kind == 'row' &&
                  (i == 0 || blocks[i - 1].kind != 'row'),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(courseProgressProvider(courseId).notifier)
                      .toggle(lesson.title),
                  icon: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                  ),
                  label: Text(
                    isDone
                        ? 'tajweed.mark_undone'.tr()
                        : 'tajweed.mark_done'.tr(),
                  ),
                ),
                if (hasNext)
                  FilledButton.icon(
                    onPressed: () {
                      final notifier = ref.read(
                        courseProgressProvider(courseId).notifier,
                      );
                      if (!isDone) notifier.toggle(lesson.title);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => CourseLessonScreen(
                            courseId: courseId,
                            index: index + 1,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text('tajweed.next_lesson'.tr()),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// «2:255» spans in the ornate brackets of the mushaf, run by run: a quote
/// over two ayahs is «﴿…﴾ ﴿٣﴾ ﴿…﴾» in the book's data — the number between
/// two runs is the ayah's end, and the brackets open and close around the
/// whole quotation.
final _ayahEnd = RegExp(r'^\s*\uFD3E[\u0660-\u0669]+\uFD3F\s*$');

/// One paragraph of a course.
class CourseBlockView extends ConsumerStatefulWidget {
  final CourseBlock block;
  final bool firstRow;

  const CourseBlockView({
    super.key,
    required this.block,
    this.firstRow = false,
  });

  @override
  ConsumerState<CourseBlockView> createState() => _CourseBlockViewState();
}

class _CourseBlockViewState extends ConsumerState<CourseBlockView> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  void _listen(CourseSpan s) {
    final place = s.place;
    if (place == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListenCard(
            example: TajweedExample(
              surah: place.$1,
              ayah: place.$2,
              phrase: s.kind == 'q' ? s.text : '',
              listenKey: 'tajweed.listen_example',
            ),
          ),
        ),
      ),
    );
  }

  /// The spans of [spans] as one rich paragraph.
  TextSpan _rich(List<CourseSpan> spans, TextStyle base) {
    final quran = base.copyWith(
      fontFamily: 'KFGQPCHafs',
      // Above zero, Skia turns the font's ligatures off (see
      // test/quran_font_ligatures_test.dart).
      letterSpacing: 0,
      fontSize: (base.fontSize ?? 17) + 3,
      color: goldText(context),
      height: 2.0,
    );
    final bracket = quran.copyWith(fontWeight: FontWeight.w400);
    final out = <InlineSpan>[];
    for (var i = 0; i < spans.length; i++) {
      final s = spans[i];
      switch (s.kind) {
        case 'q':
          // Opens a run unless the span before was this quote's ayah end.
          final opens =
              i < 2 ||
              spans[i - 1].kind != 't' ||
              !_ayahEnd.hasMatch(spans[i - 1].text) ||
              spans[i - 2].kind != 'q';
          final closes =
              i + 2 >= spans.length ||
              spans[i + 1].kind != 't' ||
              !_ayahEnd.hasMatch(spans[i + 1].text) ||
              spans[i + 2].kind != 'q';
          final tap = TapGestureRecognizer()..onTap = () => _listen(s);
          _taps.add(tap);
          if (opens) out.add(TextSpan(text: '﴿', style: bracket));
          out.add(TextSpan(text: s.text, style: quran, recognizer: tap));
          if (closes) out.add(TextSpan(text: '﴾', style: bracket));
        case 't':
          final isEnd =
              _ayahEnd.hasMatch(s.text) && i > 0 && spans[i - 1].kind == 'q';
          out.add(
            TextSpan(
              text: isEnd ? ' ${s.text.trim()} ' : s.text,
              style: isEnd ? bracket : null,
            ),
          );
        case 'b' || 'h':
          out.add(
            TextSpan(
              text: s.text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        case 'n':
          out.add(
            TextSpan(
              text: '(${s.text})',
              style: TextStyle(
                fontSize: (base.fontSize ?? 17) * 0.7,
                color: goldText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        default:
          out.add(TextSpan(text: s.text));
      }
    }
    // The first run of a paragraph starts at its first letter.
    if (out.isNotEmpty && out.first is TextSpan) {
      final f = out.first as TextSpan;
      if (f.recognizer == null && f.text != null) {
        out[0] = TextSpan(text: f.text!.trimLeft(), style: f.style);
      }
    }
    return TextSpan(style: base, children: out);
  }

  Widget _para(
    List<CourseSpan> spans,
    TextStyle base, {
    TextAlign align = TextAlign.justify,
  }) => Directionality(
    textDirection: ui.TextDirection.rtl,
    child: Text.rich(_rich(spans, base), textAlign: align),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _label(IconData icon, String text) {
    final c = goldText(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: AppColors.gold.withValues(alpha: 0.35),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This build's recognisers replace the last one's.
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final scheme = Theme.of(context).colorScheme;
    final b = widget.block;
    final body = lessonTextStyle(fontSize: 17, color: scheme.onSurface);
    final quiet = lessonTextStyle(
      fontSize: 14,
      color: scheme.onSurfaceVariant,
    ).copyWith(height: 1.8);

    switch (b.kind) {
      case 'head':
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: _para(
            b.spans,
            lessonTextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
            align: TextAlign.start,
          ),
        );
      case 'q':
      case 'a':
        final isQ = b.kind == 'q';
        final color = isQ ? scheme.primary : AppColors.gold;
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: isQ ? 12 : 0, bottom: isQ ? 4 : 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isQ ? 0.08 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _badge(
                isQ ? 'tajweed.question'.tr() : 'tajweed.answer'.tr(),
                isQ ? scheme.primary : goldText(context),
              ),
              _para(
                b.spans,
                isQ
                    ? lessonTextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      )
                    : body,
              ),
            ],
          ),
        );
      case 'row':
        // Cells are split on «\» in the book's text.
        final cells = <List<CourseSpan>>[[]];
        for (final s in b.spans) {
          if (s.kind != 't' || !s.text.contains(r'\')) {
            cells.last.add(s);
            continue;
          }
          final parts = s.text.split(r'\');
          for (var k = 0; k < parts.length; k++) {
            if (k > 0) cells.add([]);
            if (parts[k].trim().isNotEmpty) {
              cells.last.add(CourseSpan('t', parts[k].trim()));
            }
          }
        }
        final style = widget.firstRow
            ? lessonTextStyle(fontSize: 15, fontWeight: FontWeight.w700)
            : lessonTextStyle(fontSize: 15, color: scheme.onSurface);
        return Container(
          decoration: BoxDecoration(
            color: widget.firstRow
                ? AppColors.gold.withValues(alpha: 0.12)
                : null,
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.7),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: Row(
              children: [
                for (var k = 0; k < cells.length; k++)
                  Expanded(
                    // The examples' cell is the wide one.
                    flex: cells.length == 3 && k == 1 ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _para(cells[k], style, align: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
        );
      case 'verse':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: LessonVerse(
            b.spans.where((s) => s.kind != 'n').map((s) => s.text).join(),
          ),
        );
      case 'exh':
        return _label(Icons.quiz_outlined, 'tajweed.exercises'.tr());
      case 'ex':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _para(
            b.spans,
            lessonTextStyle(fontSize: 16),
            align: TextAlign.start,
          ),
        );
      case 'notes':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(Icons.notes_rounded, 'tajweed.footnotes'.tr()),
            for (final s in b.spans)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: ArabicText(s.text, style: quiet),
              ),
          ],
        );
      case 'refs':
        final mushaf = ref.watch(mushafDataProvider).valueOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(
              Icons.menu_book_rounded,
              'tajweed.examples_from_mushaf'.tr(),
            ),
            Text('tajweed.examples_from_mushaf_note'.tr(), style: quiet),
            const SizedBox(height: 6),
            for (final s in b.spans)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _listen(s),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ArabicText(
                          '﴿${s.text}﴾',
                          style: const TextStyle(
                            fontFamily: 'KFGQPCHafs',
                            letterSpacing: 0,
                            fontSize: 19,
                            height: 2.0,
                          ),
                        ),
                        if (s.place != null)
                          Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: goldText(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                localizeDigits(
                                  '${mushaf?.surahNameAr(s.place!.$1) ?? s.place!.$1} : ${s.place!.$2}',
                                  'ar',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _para(b.spans, body),
        );
    }
  }
}
