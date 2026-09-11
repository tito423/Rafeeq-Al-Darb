import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_audio_player.dart';

/// «حُط في مشغّل التلاوة تاب للمفضّلة». A favourite is the track itself — its
/// title, reciter, and where it plays from — so it opens with no network
/// lookup and survives the catalogue changing.
class QuranAudioFavorites extends ChangeNotifier {
  QuranAudioFavorites._();
  static final QuranAudioFavorites instance = QuranAudioFavorites._();

  static const _key = 'quran_audio.favorites_v1';

  List<PlayerTrack> items = const [];
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      items = [
        for (final m in jsonDecode(raw) as List<dynamic>)
          PlayerTrack.fromJson(m as Map<String, dynamic>),
      ];
      notifyListeners();
    } catch (_) {}
  }

  bool contains(String id) => items.any((t) => t.id == id);

  Future<void> toggle(PlayerTrack track) async {
    await ensureLoaded();
    items = contains(track.id)
        ? [for (final t in items) if (t.id != track.id) t]
        : [...items, track];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    items = [for (final t in items) if (t.id != id) t];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final t in items) t.toJson()]));
  }
}
