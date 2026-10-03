import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// «مسابقة التاريخ الإسلامي» (owner, 2026-10-03: multiple-choice questions
/// on Islamic history only, «حصرا تبقى في التاريخ الاسلامي»).
///
/// Every question is built on one sentence of a named book in the app's own
/// library and carries it: `quote` is a verbatim substring of page
/// `pageIndex` of `books/text/<book>.json`, and `scripts/check_history_quiz.py`
/// fails if it is not. Nothing is answered from memory.
/// Five stages, easiest first: «الاطفال مش عندهم اصلا اي اطلاع … الاسئله
/// بتبقى بتدرج … السهل البسيط المتوسط اللي فوق متوسط الصعب» (owner,
/// 2026-10-03). Each opens once the one before is passed.
enum QuizLevel { l1, l2, l3, l4, l5 }

class QuizQuestion {
  final String id;
  final QuizLevel level;
  final String question;

  /// The correct answer first, as authored; [shuffled] deals them out.
  final List<String> choices;
  final String explain;
  final String book;
  final int pageIndex;

  /// The printed page, as the book's edition numbers it.
  final int page;
  final String quote;

  const QuizQuestion({
    required this.id,
    required this.level,
    required this.question,
    required this.choices,
    required this.explain,
    required this.book,
    required this.pageIndex,
    required this.page,
    required this.quote,
  });

  String get answer => choices.first;

  /// The choices in a fresh order for one showing.
  List<String> shuffled(math.Random rnd) => [...choices]..shuffle(rnd);

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: j['id'] as String,
    level: QuizLevel.values.byName(j['level'] as String),
    question: j['q'] as String,
    choices: [for (final c in j['choices'] as List) c as String],
    explain: j['explain'] as String,
    book: j['book'] as String,
    pageIndex: j['pageIndex'] as int,
    page: j['p'] as int,
    quote: j['quote'] as String,
  );
}

/// The question bank, read once from the bundled asset.
class HistoryQuiz {
  HistoryQuiz._();
  static const asset = 'assets/data/quiz/history_quiz.json';

  static Future<List<QuizQuestion>>? _all;

  static Future<List<QuizQuestion>> all() => _all ??= () async {
    final j = jsonDecode(await rootBundle.loadString(asset)) as Map;
    return [
      for (final q in j['questions'] as List)
        QuizQuestion.fromJson(q as Map<String, dynamic>),
    ];
  }();

  /// One round: [count] questions of [level], none repeated, drawn at random.
  static List<QuizQuestion> round(
    List<QuizQuestion> bank,
    QuizLevel level,
    math.Random rnd, {
    int count = 10,
  }) {
    final pool = bank.where((q) => q.level == level).toList()..shuffle(rnd);
    return pool.take(count).toList();
  }
}
