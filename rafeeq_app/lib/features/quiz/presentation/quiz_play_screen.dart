import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/proper_name.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/digits.dart' show localizeDigits;
import '../../library/data/book_catalog.dart';
import '../../library/data/library_api_service.dart';
import '../../library/presentation/screens/book_text_reader_screen.dart';
import '../data/history_quiz.dart';
import '../data/quiz_progress.dart';
import 'quiz_home_screen.dart' show quizLevelLook;
import 'quiz_result_screen.dart';
import 'widgets/quiz_effects.dart';

/// One round of ten questions. A choice locks the question: the right
/// answer lights green (with a burst of stars when it was the reader's), a
/// wrong pick shakes red, and the book's own sentence is shown under it
/// with its page, one tap from opening the book there.
class QuizPlayScreen extends ConsumerStatefulWidget {
  final QuizLevel level;
  final List<QuizQuestion> bank;
  const QuizPlayScreen({super.key, required this.level, required this.bank});

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen> {
  final _rnd = math.Random();
  List<QuizQuestion>? _round;
  List<String> _choices = const [];
  final List<bool> _results = [];
  int _i = 0;
  String? _picked;
  int _streak = 0;
  int _bestStreak = 0;
  int _burst = 0;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    HistoryQuiz.round(widget.bank, widget.level, _rnd).then((all) {
      if (!mounted) return;
      final lang = context.locale.languageCode;
      final r = [for (final q in all) q.localized(lang)];
      setState(() {
        _round = r;
        if (r.isNotEmpty) _choices = r.first.shuffled(_rnd);
      });
    });
  }

  List<QuizQuestion> get _questions => _round ?? const [];
  QuizQuestion get _q => _questions[_i];
  int get _score => _results.where((r) => r).length;

  void _pick(String c) {
    if (_picked != null) return;
    final right = c == _q.answer;
    setState(() {
      _picked = c;
      _results.add(right);
      if (right) {
        _streak++;
        _bestStreak = math.max(_bestStreak, _streak);
        _burst++;
      } else {
        _streak = 0;
        _shake++;
      }
    });
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
  }

  Future<void> _next() async {
    if (_i + 1 < _questions.length) {
      setState(() {
        _i++;
        _picked = null;
        _choices = _q.shuffled(_rnd);
      });
      return;
    }
    final next = widget.level.index + 1 < QuizLevel.values.length
        ? QuizLevel.values[widget.level.index + 1]
        : null;
    final wasOpen =
        next != null && ref.read(quizProgressProvider).unlocked(next);
    final record = await ref
        .read(quizProgressProvider.notifier)
        .record(widget.level, _score, _questions.length, _bestStreak);
    final opened =
        next != null &&
        !wasOpen &&
        ref.read(quizProgressProvider).unlocked(next);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuizResultScreen(
            level: widget.level,
            bank: widget.bank,
            score: _score,
            total: _questions.length,
            bestStreak: _bestStreak,
            newRecord: record,
            openedNext: opened,
          ),
        ),
      ),
    );
  }

  Future<void> _openBook(QuizQuestion q) async {
    final book = bookById(q.book);
    final url = book?.textEdition?.url;
    if (book == null || url == null) return;
    final api = LibraryApiService.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (!await api.isBookDownloaded(book.id)) {
      messenger.showSnackBar(
        SnackBar(content: Text('quiz.downloading_book'.tr())),
      );
      try {
        await api.downloadBook(book.id, url);
      } catch (_) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('quiz.book_failed'.tr())));
        return;
      }
      messenger.hideCurrentSnackBar();
    }
    final path = await api.bookFilePath(book.id);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookTextReaderScreen(
            book: book,
            path: path,
            initialPageIndex: q.pageIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final (colors, _) = quizLevelLook(widget.level);
    if (_round == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return Scaffold(
      body: QuizStarfield(
        child: StarBurst(
          trigger: _burst,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: _Segments(
                          total: _questions.length,
                          results: _results,
                          at: _i,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StreakChip(streak: _streak, lang: lang),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position:
                                Tween(
                                  begin: const Offset(0.25, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: a,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                            child: child,
                          ),
                        ),
                        child: _QuestionCard(
                          key: ValueKey(_i),
                          colors: colors,
                          label: 'quiz.question_n'.tr(
                            args: [
                              localizeDigits('${_i + 1}', lang),
                              localizeDigits('${_questions.length}', lang),
                            ],
                          ),
                          text: _q.question,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final (k, c) in _choices.indexed)
                        _ChoiceTile(
                          key: ValueKey('$_i-$c'),
                          letter: const ['أ', 'ب', 'ج', 'د'][k % 4],
                          text: c,
                          state: _picked == null
                              ? _ChoiceState.open
                              : c == _q.answer
                              ? _ChoiceState.right
                              : c == _picked
                              ? _ChoiceState.wrong
                              : _ChoiceState.dim,
                          shake: c == _picked ? _shake : 0,
                          onTap: () => _pick(c),
                        ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: _picked == null
                            ? const SizedBox(width: double.infinity)
                            : _Explain(
                                question: _q,
                                right: _picked == _q.answer,
                                last: _i + 1 == _questions.length,
                                onNext: _next,
                                onOpenBook: () => _openBook(_q),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  final int total;
  final List<bool> results;
  final int at;
  const _Segments({
    required this.total,
    required this.results,
    required this.at,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: i == at ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i < results.length
                    ? (results[i] ? AppColors.success : AppColors.error)
                    : i == at
                    ? AppColors.goldSoft
                    : Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int streak;
  final String lang;
  const _StreakChip({required this.streak, required this.lang});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: streak >= 2 ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF7A2F).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 2),
            Text(
              localizeDigits('$streak', lang),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final List<Color> colors;
  final String label;
  final String text;
  const _QuestionCard({
    super.key,
    required this.colors,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                height: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChoiceState { open, right, wrong, dim }

class _ChoiceTile extends StatelessWidget {
  final String letter;
  final String text;
  final _ChoiceState state;
  final int shake;
  final VoidCallback onTap;
  const _ChoiceTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.shake,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      _ChoiceState.right => (
        AppColors.success,
        Colors.white,
        Icons.check_circle_rounded,
      ),
      _ChoiceState.wrong => (
        AppColors.error,
        Colors.white,
        Icons.cancel_rounded,
      ),
      _ => (Colors.white.withValues(alpha: 0.10), Colors.white, null),
    };
    return Shake(
      trigger: shake,
      child: AnimatedScale(
        scale: state == _ChoiceState.right ? 1.03 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: state == _ChoiceState.dim ? 0.45 : 1,
          duration: const Duration(milliseconds: 260),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: state == _ChoiceState.open ? onTap : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: state == _ChoiceState.open
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: icon != null
                            ? Icon(icon, color: Colors.white, size: 22)
                            : Text(
                                letter,
                                style: const TextStyle(
                                  color: AppColors.goldSoft,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: fg,
                            fontSize: 16.5,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Explain extends StatelessWidget {
  final QuizQuestion question;
  final bool right;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onOpenBook;
  const _Explain({
    required this.question,
    required this.right,
    required this.last,
    required this.onNext,
    required this.onOpenBook,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final book = bookById(question.book);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: (right ? AppColors.success : AppColors.error).withValues(
              alpha: 0.6,
            ),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  right ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
                  color: right ? AppColors.gold : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    right
                        ? 'quiz.right'.tr()
                        : 'quiz.wrong'.tr(args: [question.answer]),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.explain,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paperDark,
                borderRadius: BorderRadius.circular(14),
                border: const BorderDirectional(
                  start: BorderSide(color: AppColors.gold, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '«${question.quote}»',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      height: 1.7,
                      fontFamily: 'AmiriQuran',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'quiz.source'.tr(
                      args: [
                        book == null
                            ? question.book
                            : '${properName(book.titleAr, book.titleEn)} — '
                              '${properName(book.authorAr, book.authorEn)}',
                        localizeDigits('${question.page}', lang),
                      ],
                    ),
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onOpenBook,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text('quiz.read_in_book'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: Icon(
                    last ? Icons.flag_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(last ? 'quiz.see_result'.tr() : 'quiz.next'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
