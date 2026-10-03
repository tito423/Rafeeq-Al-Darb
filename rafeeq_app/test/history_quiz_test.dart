import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';
import 'package:rafeeq_app/features/quiz/data/history_quiz.dart';

/// The quiz asset as `scripts/build_history_quiz.py` writes it. The script
/// checks each quote against its book page; this keeps the shipped file
/// whole: every level can fill a round, every question is well formed and
/// points at a book the library can open.
void main() {
  final j = jsonDecode(
          File('assets/data/quiz/history_quiz.json').readAsStringSync())
      as Map<String, dynamic>;
  final qs = [
    for (final q in j['questions'] as List)
      QuizQuestion.fromJson(q as Map<String, dynamic>),
  ];

  test('every level fills a round of ten', () {
    for (final l in QuizLevel.values) {
      expect(qs.where((q) => q.level == l).length, greaterThanOrEqualTo(10),
          reason: l.name);
    }
  });

  test('four distinct choices, a quote, a page, a library book', () {
    for (final q in qs) {
      expect(q.choices.toSet().length, 4, reason: q.question);
      expect(q.quote.trim(), isNotEmpty, reason: q.question);
      expect(q.page, greaterThan(0), reason: q.question);
      expect(bookById(q.book)?.textEdition, isNotNull, reason: q.book);
    }
  });

  test('ids and questions are unique', () {
    expect(qs.map((q) => q.id).toSet().length, qs.length);
    expect(qs.map((q) => q.question).toSet().length, qs.length);
  });
}
