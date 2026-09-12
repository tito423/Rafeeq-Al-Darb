/// «تعليم التجويد» — the course.
///
/// The lessons are read from «تيسير أحكام التجويد — المستوى الأول», downloaded
/// once like any other Library book, so not a word of the science is written
/// by this app. What the app adds is the path through it: the order, the
/// progress, and — the part the owner insisted on — the sound.
///
/// «يتقصه النطق الفعلي للحروف والغنن والمدود والإقلاب والإظهار». Every rule
/// that can be pointed at has a real ayah where it happens; the card shows the
/// ayah, marks the words the rule lives in, and plays it in a **mujawwad**
/// recitation, because that is the reading where a ghunnah is actually held
/// and a madd is actually stretched. The examples were checked against the
/// bundled mushaf text before they were written down — see `tajweed_course.dart`.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/db/models.dart';
import '../../../../core/db/quran_repository.dart';
import '../../../../core/services/ayah_audio_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/arabic_text.dart';
import '../../../library/data/book_text.dart';
import '../../../library/data/library_api_service.dart';
import '../../data/tajweed_course.dart';

/// Lessons the reader has marked done. Persisted, because a course you lose
/// your place in is a course you stop.
///
/// Kept by lesson TITLE rather than by position. The arrangement moved once
/// already — the first cut had seventeen lessons and the corrected one has
/// twenty-three — and a reader's ticks must not slide onto other lessons the
/// next time a boundary is fixed.
class TajweedProgress extends StateNotifier<Set<String>> {
  TajweedProgress() : super(const {}) {
    _restore();
  }

  static const _key = 'tajweed.done_v2';

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

final tajweedProgressProvider =
    StateNotifierProvider<TajweedProgress, Set<String>>(
        (ref) => TajweedProgress());

/// The course text, downloaded on first use and then read from disk.
final tajweedBookProvider = FutureProvider<BookText?>((ref) async {
  final api = LibraryApiService.instance;
  if (!await api.isBookDownloaded(tajweedCourseBook)) {
    await api.downloadBook(
      tajweedCourseBook,
      '${AppConfig.contentBaseUrl}/books/text/$tajweedCourseBook.json',
    );
  }
  return BookText.fromFile(await api.bookFilePath(tajweedCourseBook));
});

class TajweedCourseScreen extends ConsumerWidget {
  const TajweedCourseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(tajweedBookProvider);
    final done = ref.watch(tajweedProgressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('tajweed.title'.tr())),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('tajweed.needs_download'.tr(),
                textAlign: TextAlign.center),
          ),
        ),
        data: (text) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: tajweedLessons.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Header(
                // Only ticks that still belong to a lesson in the course, so
                // a renamed section can never make this read «24 من 23».
                done: tajweedLessons
                    .where((l) => done.contains(l.sectionTitle))
                    .length,
                total: tajweedLessons.length,
                theme: theme,
              );
            }
            final index = i - 1;
            return _LessonTile(
              index: index,
              lesson: tajweedLessons[index],
              done: done.contains(tajweedLessons[index].sectionTitle),
              book: text,
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
          Text('tajweed.subtitle'.tr(),
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
            'tajweed.progress'.tr(namedArgs: {'done': '$done', 'total': '$total'}),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          // Where every word of the lesson comes from. §1.2: the source is
          // named where the content is read, not buried on another screen.
          Text(
            'tajweed.source'.tr(),
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
  final TajweedLesson lesson;
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
              : Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant)),
        ),
        title: Text(lesson.sectionTitle,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          _LessonBody(lesson: lesson, book: book),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(tajweedProgressProvider.notifier).toggle(lesson.sectionTitle),
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
  final TajweedLesson lesson;
  final BookText? book;

  const _LessonBody({required this.lesson, required this.book});

  @override
  Widget build(BuildContext context) {
    // The lesson's span, inclusive at both ends. The book does not start a
    // topic at the top of a page, so a lesson can begin part-way down one and
    // end part-way down another.
    final paras = <String>[];
    for (final p in book?.pages ?? const <BookPage>[]) {
      if (p.printedPage < lesson.fromPage || p.printedPage > lesson.toPage) {
        continue;
      }
      final first = p.printedPage == lesson.fromPage ? lesson.fromPara : 0;
      final last =
          p.printedPage == lesson.toPage ? lesson.toPara : p.paras.length - 1;
      for (var i = first; i <= last && i < p.paras.length; i++) {
        final t = p.paras[i].text;
        if (t.trim().isEmpty) continue;
        paras.add(t);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (paras.isEmpty)
          Text('tajweed.needs_download'.tr(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          for (final t in paras)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ArabicText(t, style: const TextStyle(height: 1.9)),
            ),
        if (lesson.example != null) ...[
          const SizedBox(height: 6),
          _ListenCard(example: lesson.example!),
        ],
      ],
    );
  }
}

/// The ayah the rule is heard in.
class _ListenCard extends ConsumerStatefulWidget {
  final TajweedExample example;

  const _ListenCard({required this.example});

  @override
  ConsumerState<_ListenCard> createState() => _ListenCardState();
}

class _ListenCardState extends ConsumerState<_ListenCard> {
  Ayah? _ayah;

  /// Whether the player is running *for this card*. The service is a
  /// singleton shared by the whole app, so its «is something playing» stream
  /// alone would turn every lesson's button into a stop button at once;
  /// `_mine` is what narrows it to the card that started the recitation.
  bool _mine = false;
  bool _audioOn = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = AyahAudioService.instance.isPlayingStream.listen((on) {
      if (!mounted) return;
      setState(() {
        _audioOn = on;
        if (!on) _mine = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(quranRepositoryProvider.future);
    final a = await repo.ayah(widget.example.surah, widget.example.ayah);
    if (mounted) setState(() => _ayah = a);
  }

  bool get _playing => _mine && _audioOn;

  Future<void> _toggle() async {
    final ayah = _ayah;
    if (ayah == null) return;
    if (_playing) {
      await AyahAudioService.instance.stop();
      return;
    }
    setState(() => _mine = true);
    final repo = await ref.read(quranRepositoryProvider.future);
    // The mujawwad reading on purpose: a murattal one is correct but does
    // not let you hear a ghunnah being held.
    await AyahAudioService.instance.play(
      ayah,
      repo,
      edition: AyahAudioService.defaultEdition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ayah = _ayah;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.gold.withValues(alpha: 0.10),
          scheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded,
                  size: 17, color: AppColors.gold),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.example.listenKey.tr(),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ayah != null)
            ArabicText(
              ayah.textUthmani,
              style: const TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 18,
                height: 2.0,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '﴿${widget.example.phrase}﴾',
                style: const TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 15,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: ayah == null ? null : _toggle,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                    _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 18),
                label: Text(_playing
                    ? 'tajweed.stop'.tr()
                    : 'tajweed.listen'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
