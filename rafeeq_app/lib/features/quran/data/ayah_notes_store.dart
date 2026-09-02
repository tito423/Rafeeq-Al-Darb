import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// P2‑8 #7 — a private, free-text note attached to one ayah, distinct from a
/// bookmark (a bookmark just marks a position; a note is the user's own
/// annotation). Stored entirely on-device as `{"2:255": "…", …}` under one
/// `SharedPreferences` key — there's no server to sync to, and there won't
/// be one (§3 rule: no accounts).
class AyahNotesNotifier extends StateNotifier<Map<String, String>> {
  AyahNotesNotifier(this._prefs) : super(_restore(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'ayah_notes_v1';

  static Map<String, String> _restore(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return const {};
    }
  }

  static String keyFor(int surah, int ayah) => '$surah:$ayah';

  String? noteFor(int surah, int ayah) => state[keyFor(surah, ayah)];

  Future<void> setNote(int surah, int ayah, String text) async {
    final trimmed = text.trim();
    final next = Map<String, String>.from(state);
    if (trimmed.isEmpty) {
      next.remove(keyFor(surah, ayah));
    } else {
      next[keyFor(surah, ayah)] = trimmed;
    }
    state = next;
    await _prefs.setString(_key, jsonEncode(next));
  }

  Future<void> clearNote(int surah, int ayah) => setNote(surah, ayah, '');
}

final ayahNotesProvider =
    StateNotifierProvider<AyahNotesNotifier, Map<String, String>>((ref) {
  return AyahNotesNotifier(ref.watch(sharedPrefsProvider));
});
