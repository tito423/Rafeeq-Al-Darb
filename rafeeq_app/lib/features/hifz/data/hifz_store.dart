/// «قسم لتحفيظ القرآن الكريم وتسميعه» (2026-09-22) — what the app remembers
/// between sessions: which ayahs have been memorized, and when each is due
/// for review.
///
/// The schedule is a plain Leitner ladder, not a claim about anybody's
/// memory: an ayah answered «حفظت» moves up a box and comes back after that
/// box's number of days; one answered «أعِده» drops to the first box and
/// comes back today. The ladder is stated here so it can be read and argued
/// with, and `test/hifz_store_test.dart` holds it.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Days until the next review, by box. Five boxes: today, three days, a week,
/// a fortnight, a month.
const hifzBoxDays = <int>[0, 3, 7, 16, 35];

class HifzAyah {
  /// 0-based index into [hifzBoxDays].
  final int box;

  /// Midnight-anchored day number (UTC days since epoch) the ayah is due on.
  final int dueDay;

  /// How many times it has been answered «حفظت» in a row.
  final int streak;

  /// The best «تسميع» this ayah has had: percent of its words heard, or -1
  /// when it has never been recited to the device. Kept as the BEST rather
  /// than the last, because a bad attempt with a passing lorry should not
  /// erase a good one.
  final int bestPercent;

  const HifzAyah({
    required this.box,
    required this.dueDay,
    this.streak = 0,
    this.bestPercent = -1,
  });

  Map<String, Object?> toJson() =>
      {'b': box, 'd': dueDay, 's': streak, 'p': bestPercent};

  static HifzAyah fromJson(Map<String, Object?> j) => HifzAyah(
    box: (j['b'] as num?)?.toInt() ?? 0,
    dueDay: (j['d'] as num?)?.toInt() ?? 0,
    streak: (j['s'] as num?)?.toInt() ?? 0,
    bestPercent: (j['p'] as num?)?.toInt() ?? -1,
  );
}

/// `surah:ayah` — the key an ayah is stored under.
String hifzKey(int surah, int ayah) => '$surah:$ayah';

int todayDay([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 86400000;

class HifzState {
  final Map<String, HifzAyah> ayahs;
  const HifzState(this.ayahs);

  bool isDue(int surah, int ayah, {int? today}) {
    final a = ayahs[hifzKey(surah, ayah)];
    return a == null || a.dueDay <= (today ?? todayDay());
  }

  /// Ayahs of [surah] waiting for review today, in order.
  List<int> dueIn(int surah, int ayahCount, {int? today}) => [
    for (var i = 1; i <= ayahCount; i++)
      if (isDue(surah, i, today: today)) i,
  ];

  int get memorized =>
      ayahs.values.where((a) => a.box >= hifzBoxDays.length - 1).length;
  int get started => ayahs.length;
}

class HifzStore extends StateNotifier<HifzState> {
  HifzStore() : super(const HifzState({})) {
    _load();
  }

  static const _key = 'hifz.ayahs.v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      state = HifzState({
        for (final e in map.entries)
          e.key: HifzAyah.fromJson((e.value as Map).cast<String, Object?>()),
      });
    } catch (_) {
      // A stored value that cannot be read is not worth crashing over; the
      // reader simply starts again from an empty ladder.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({for (final e in state.ayahs.entries) e.key: e.value.toJson()}),
    );
  }

  /// «حفظت»: up one box, due after that box's days.
  Future<void> remembered(int surah, int ayah, {int? today}) async {
    final now = today ?? todayDay();
    final cur = state.ayahs[hifzKey(surah, ayah)];
    final box = ((cur?.box ?? -1) + 1).clamp(0, hifzBoxDays.length - 1);
    await _put(
      surah,
      ayah,
      HifzAyah(
        box: box,
        dueDay: now + hifzBoxDays[box],
        streak: (cur?.streak ?? 0) + 1,
        bestPercent: cur?.bestPercent ?? -1,
      ),
    );
  }

  /// «أعِده»: back to the first box, and due again today.
  Future<void> forgot(int surah, int ayah, {int? today}) async {
    final now = today ?? todayDay();
    final cur = state.ayahs[hifzKey(surah, ayah)];
    await _put(
      surah,
      ayah,
      HifzAyah(
        box: 0,
        dueDay: now,
        streak: 0,
        bestPercent: cur?.bestPercent ?? -1,
      ),
    );
  }

  /// Records a «تسميع» attempt: [percent] of the ayah's words were heard.
  /// Keeps the best, and never changes the review ladder by itself — the
  /// reader still says «حفظتها» or «أعِدها» himself.
  Future<void> recordTasmee(int surah, int ayah, int percent) async {
    final cur = state.ayahs[hifzKey(surah, ayah)];
    if (cur != null && cur.bestPercent >= percent) return;
    await _put(
      surah,
      ayah,
      HifzAyah(
        box: cur?.box ?? 0,
        dueDay: cur?.dueDay ?? todayDay(),
        streak: cur?.streak ?? 0,
        bestPercent: percent,
      ),
    );
  }

  int bestTasmee(int surah, int ayah) =>
      state.ayahs[hifzKey(surah, ayah)]?.bestPercent ?? -1;

  Future<void> reset(int surah, int ayah) async {
    final map = Map<String, HifzAyah>.from(state.ayahs)
      ..remove(hifzKey(surah, ayah));
    state = HifzState(map);
    await _save();
  }

  Future<void> _put(int surah, int ayah, HifzAyah value) async {
    state = HifzState({...state.ayahs, hifzKey(surah, ayah): value});
    await _save();
  }
}

final hifzStoreProvider = StateNotifierProvider<HifzStore, HifzState>(
  (ref) => HifzStore(),
);
