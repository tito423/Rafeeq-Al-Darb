import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/prefs_provider.dart';
import 'history_quiz.dart';

/// What the reader has earned in the quiz, kept on the device.
class QuizProgress {
  /// Best round per level, as a count of right answers.
  final Map<QuizLevel, int> best;
  final int answered;
  final int correct;
  final int bestStreak;

  const QuizProgress({
    required this.best,
    required this.answered,
    required this.correct,
    required this.bestStreak,
  });

  /// Right answers out of ten in a stage that open the next one.
  static const passMark = 6;

  /// The first stage is always open; each later one once the stage before
  /// it has been passed.
  bool unlocked(QuizLevel l) =>
      l.index == 0 || (best[QuizLevel.values[l.index - 1]] ?? 0) >= passMark;

  /// Stars for a round of [total]: three for all but one, two for most,
  /// one for half.
  static int starsFor(int score, int total) {
    if (total == 0) return 0;
    final r = score / total;
    if (r >= 0.9) return 3;
    if (r >= 0.7) return 2;
    if (r >= 0.5) return 1;
    return 0;
  }
}

class QuizProgressNotifier extends StateNotifier<QuizProgress> {
  QuizProgressNotifier(this._prefs) : super(_read(_prefs));
  final SharedPreferences _prefs;

  static const _kBest = 'quiz_history_best_';
  static const _kAnswered = 'quiz_history_answered';
  static const _kCorrect = 'quiz_history_correct';
  static const _kStreak = 'quiz_history_best_streak';

  static QuizProgress _read(SharedPreferences p) => QuizProgress(
    best: {
      for (final l in QuizLevel.values) l: p.getInt('$_kBest${l.name}') ?? 0,
    },
    answered: p.getInt(_kAnswered) ?? 0,
    correct: p.getInt(_kCorrect) ?? 0,
    bestStreak: p.getInt(_kStreak) ?? 0,
  );

  /// Records a finished round; true when it beat the level's best.
  Future<bool> record(QuizLevel level, int score, int total, int streak) async {
    final record = score > (state.best[level] ?? 0);
    if (record) await _prefs.setInt('$_kBest${level.name}', score);
    await _prefs.setInt(_kAnswered, state.answered + total);
    await _prefs.setInt(_kCorrect, state.correct + score);
    if (streak > state.bestStreak) await _prefs.setInt(_kStreak, streak);
    state = _read(_prefs);
    return record;
  }
}

final quizProgressProvider =
    StateNotifierProvider<QuizProgressNotifier, QuizProgress>(
      (ref) => QuizProgressNotifier(ref.watch(sharedPrefsProvider)),
    );
