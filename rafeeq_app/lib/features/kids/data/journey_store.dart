import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «رحلتي» - the reader's own record of what he actually did, kept on the
/// phone (owner, 2026-09-29: gamification that makes people love the app).
///
/// Nothing here is invented: every point is one real act counted where it
/// happens - a dhikr tapped in an adhkar chapter, a tasbeeh counted, a right
/// answer in «أكمل الآية». A day with any of them is an active day; the streak
/// is the run of active days ending today (or yesterday, so the streak is not
/// lost before the reader has had a chance to open the app today).
///
/// Real prizes would need a server that can check a claim; that is not built.
class JourneyStore {
  JourneyStore._();
  static final JourneyStore instance = JourneyStore._();

  static const _kDays = 'journey_days_v1';
  static String _kCount(String kind) => 'journey_count_${kind}_v1';

  /// The kinds of act that are counted, and what each is worth. `surah` is a
  /// surah the reader marked as memorised - one count per surah, ever
  /// ([setMemorized] keeps the set; unmarking takes the count back).
  static const weights = {'dhikr': 1, 'tasbeeh': 1, 'game': 5, 'surah': 20};

  static const _kMemorized = 'journey_memorized_v1';

  Future<Set<int>> memorized() async {
    final p = await SharedPreferences.getInstance();
    return {
      for (final s in p.getStringList(_kMemorized) ?? const <String>[])
        ?int.tryParse(s),
    };
  }

  /// Marks or unmarks [surah] as memorised; the `surah` count always equals
  /// the size of the set, so marking twice never earns twice.
  Future<void> setMemorized(int surah, bool on, {DateTime? now}) async {
    final p = await SharedPreferences.getInstance();
    final set = await memorized();
    final changed = on ? set.add(surah) : set.remove(surah);
    if (!changed) return;
    await p.setStringList(_kMemorized, [for (final s in set) '$s']);
    await p.setInt(_kCount('surah'), set.length);
    if (on) {
      await record('surah', count: 0, now: now);
    }
    changes.value++;
  }

  /// Ticks on every record, for screens that show the numbers.
  final changes = ValueNotifier<int>(0);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> record(String kind, {int count = 1, DateTime? now}) async {
    if (!weights.containsKey(kind) || count < 0) return;
    final p = await SharedPreferences.getInstance();
    if (count > 0) {
      await p.setInt(_kCount(kind), (p.getInt(_kCount(kind)) ?? 0) + count);
    }
    final days = (p.getStringList(_kDays) ?? const <String>[]).toSet()
      ..add(dayKey(now ?? DateTime.now()));
    // Only the last 400 days are needed for any streak or badge shown.
    final kept = days.toList()..sort();
    await p.setStringList(
        _kDays, kept.length > 400 ? kept.sublist(kept.length - 400) : kept);
    changes.value++;
  }

  Future<JourneySnapshot> read({DateTime? now}) async {
    final p = await SharedPreferences.getInstance();
    return JourneySnapshot(
      counts: {for (final k in weights.keys) k: p.getInt(_kCount(k)) ?? 0},
      activeDays: (p.getStringList(_kDays) ?? const <String>[]).toSet(),
      today: now ?? DateTime.now(),
    );
  }
}

/// What «رحلتي» shows, computed from the counts and the active days.
class JourneySnapshot {
  final Map<String, int> counts;
  final Set<String> activeDays;
  final DateTime today;
  const JourneySnapshot({
    required this.counts,
    required this.activeDays,
    required this.today,
  });

  int get points => counts.entries
      .fold(0, (s, e) => s + e.value * (JourneyStore.weights[e.key] ?? 0));

  /// Level n needs 50·n·(n-1) points: 0, 100, 300, 600, 1000, ...
  int get level {
    var n = 1;
    while (50 * (n + 1) * n <= points) {
      n++;
    }
    return n;
  }

  int get pointsForThisLevel => 50 * level * (level - 1);
  int get pointsForNextLevel => 50 * (level + 1) * level;

  /// Consecutive active days ending today, or yesterday when today has
  /// nothing yet.
  int get streak {
    var d = DateTime(today.year, today.month, today.day);
    if (!activeDays.contains(JourneyStore.dayKey(d))) {
      d = d.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (activeDays.contains(JourneyStore.dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// The longest run of active days ever kept.
  int get bestStreak {
    final sorted = activeDays.map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  bool earned(JourneyBadge b) => switch (b.kind) {
        'streak' => bestStreak >= b.target,
        'level' => level >= b.target,
        final k => (counts[k] ?? 0) >= b.target,
      };
}

/// A badge: earned when [kind] reaches [target]. `streak` is the best run of
/// active days, `level` the level, anything else a count in [JourneyStore].
class JourneyBadge {
  final String id;
  final String kind;
  final int target;
  const JourneyBadge(this.id, this.kind, this.target);
}

const journeyBadges = <JourneyBadge>[
  JourneyBadge('first_dhikr', 'dhikr', 1),
  JourneyBadge('dhikr_100', 'dhikr', 100),
  JourneyBadge('dhikr_1000', 'dhikr', 1000),
  JourneyBadge('tasbeeh_1000', 'tasbeeh', 1000),
  JourneyBadge('tasbeeh_10000', 'tasbeeh', 10000),
  JourneyBadge('streak_3', 'streak', 3),
  JourneyBadge('streak_7', 'streak', 7),
  JourneyBadge('streak_30', 'streak', 30),
  JourneyBadge('game_1', 'game', 1),
  JourneyBadge('game_50', 'game', 50),
  JourneyBadge('level_5', 'level', 5),
  JourneyBadge('surah_1', 'surah', 1),
  JourneyBadge('surah_10', 'surah', 10),
  // 37 = the number of surahs in Juz ʿAmma; 97 = the whole path of the
  // kids' corner, al-Fātiḥah and Maryam to an-Nās (kids_stages_test pins it).
  JourneyBadge('surah_37', 'surah', 37),
  JourneyBadge('surah_97', 'surah', 97),
];
