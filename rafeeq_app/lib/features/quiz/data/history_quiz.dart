import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/content_mirrors.dart';

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

/// The question bank: the bundled asset, or the hosted copy
/// (`quiz/history_quiz.json` on the bucket) once one larger than it has been
/// fetched - new questions arrive without an app update (owner, 2026-10-03:
/// «عايز الاسئلة اللي في المسابقات متجددة»). Both are built by
/// scripts/build_history_quiz.py, with the same checks.
class HistoryQuiz {
  HistoryQuiz._();

  static const asset = 'assets/data/quiz/history_quiz.json';
  static const hosted = '${AppConfig.contentBaseUrl}/quiz/history_quiz.json';
  static const _cacheName = 'quiz_history_bank.json';

  static Future<List<QuizQuestion>>? _all;
  static Future<List<QuizQuestion>> all() => _all ??= _load();

  static Future<List<QuizQuestion>> _load() async {
    var best = jsonDecode(await rootBundle.loadString(asset)) as Map;
    try {
      final f = await _cacheFile();
      if (await f.exists()) {
        final cached = jsonDecode(await f.readAsString()) as Map;
        if (_version(cached) > _version(best)) best = cached;
      }
    } catch (_) {
      // a damaged cache is ignored; the next refresh rewrites it
    }
    unawaited(_refresh(_version(best)));
    return _parse(best);
  }

  static int _version(Map j) =>
      (j['version'] as int?) ?? (j['questions'] as List).length;

  static List<QuizQuestion> _parse(Map j) => [
    for (final q in j['questions'] as List)
      QuizQuestion.fromJson(q as Map<String, dynamic>),
  ];

  static Future<File> _cacheFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_cacheName');

  /// Fetches the hosted bank in the background; a larger one is kept for the
  /// next opening. Offline or a failed host changes nothing.
  static Future<void> _refresh(int have) async {
    for (final url in ContentMirrors.of(hosted)) {
      try {
        final res = await Dio().get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        final j = jsonDecode(res.data!) as Map;
        _parse(j); // must parse before it may replace anything
        if (_version(j) > have) {
          await (await _cacheFile()).writeAsString(res.data!);
        }
        return;
      } catch (_) {
        continue;
      }
    }
  }

  /// One round: [count] questions of [level] the player has not met yet;
  /// once a level's questions are all seen, its record starts again (owner:
  /// no repeats «مش على اد اللي موجود وخلاص»).
  static Future<List<QuizQuestion>> round(
    List<QuizQuestion> bank,
    QuizLevel level,
    math.Random rnd, {
    int count = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'quiz_history_seen_${level.name}';
    final pool = bank.where((q) => q.level == level).toList()..shuffle(rnd);
    var seen = (prefs.getStringList(key) ?? const <String>[]).toSet();
    var fresh = pool.where((q) => !seen.contains(q.id)).toList();
    if (fresh.length < count) {
      // finish what is left unseen, then start the cycle again
      final rest = pool.where((q) => seen.contains(q.id)).take(count - fresh.length);
      fresh = [...fresh, ...rest];
      seen = {};
    }
    final picked = fresh.take(count).toList();
    await prefs.setStringList(key, [...seen, ...picked.map((q) => q.id)]);
    return picked;
  }
}
