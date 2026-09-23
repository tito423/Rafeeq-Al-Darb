/// «حفظي»: a stretch of the Qur'an the reader chose to memorize — from any
/// ayah of any surah to any later ayah, across surahs if he likes.
///
/// «حط امكانية اني اختار يبتدي منين … انا عاوز اقرا واحفظ من اي مكان … من اي
/// اية ومن اي سورة اختارها» (the owner, 2026-09-23). Before this a session
/// was a whole surah and always opened on its first ayah.
///
/// A plan is only a RANGE and a name. The review schedule stays per ayah in
/// `hifz_store.dart`, so an ayah memorized inside a plan is memorized in its
/// surah too — the same ayah is not two things to review.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A position in the mushaf.
class AyahRef implements Comparable<AyahRef> {
  final int surah;
  final int ayah;
  const AyahRef(this.surah, this.ayah);

  @override
  int compareTo(AyahRef other) => surah != other.surah
      ? surah.compareTo(other.surah)
      : ayah.compareTo(other.ayah);

  bool operator <=(AyahRef other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}

class HifzPlan {
  /// Creation time in milliseconds — unique enough on one device, and it
  /// keeps the list in the order the reader made it.
  final int id;

  /// What the reader called it; empty means «name it after its range».
  final String name;
  final AyahRef from;
  final AyahRef to;

  const HifzPlan({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
  });

  /// Whether [surah]:[ayah] falls inside this plan, ends included.
  bool contains(int surah, int ayah) {
    final r = AyahRef(surah, ayah);
    return from <= r && r <= to;
  }

  Map<String, Object?> toJson() => {
    'i': id,
    'n': name,
    'fs': from.surah,
    'fa': from.ayah,
    'ts': to.surah,
    'ta': to.ayah,
  };

  static HifzPlan fromJson(Map<String, Object?> j) => HifzPlan(
    id: (j['i'] as num).toInt(),
    name: j['n'] as String? ?? '',
    from: AyahRef((j['fs'] as num).toInt(), (j['fa'] as num).toInt()),
    to: AyahRef((j['ts'] as num).toInt(), (j['ta'] as num).toInt()),
  );
}

class HifzPlansStore extends StateNotifier<List<HifzPlan>> {
  HifzPlansStore() : super(const []) {
    _load();
  }

  static const _key = 'hifz.plans.v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      state = [
        for (final e in jsonDecode(raw) as List)
          HifzPlan.fromJson((e as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      // Unreadable plans are not worth a crash; the list starts empty.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final p in state) p.toJson()]),
    );
  }

  /// Adds a plan. [from] and [to] are put in mushaf order whichever way
  /// round they were picked.
  Future<HifzPlan> add({
    required String name,
    required AyahRef from,
    required AyahRef to,
  }) async {
    final ordered = from <= to ? (from, to) : (to, from);
    final plan = HifzPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name.trim(),
      from: ordered.$1,
      to: ordered.$2,
    );
    state = [...state, plan];
    await _save();
    return plan;
  }

  Future<void> remove(int id) async {
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
    await _save();
  }
}

final hifzPlansProvider = StateNotifierProvider<HifzPlansStore, List<HifzPlan>>(
  (ref) => HifzPlansStore(),
);
