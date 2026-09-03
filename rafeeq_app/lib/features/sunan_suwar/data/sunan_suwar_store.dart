import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/sunan_suwar_reminder_service.dart';

/// One surah's reminder: `weekday` is Dart's `DateTime.weekday`
/// (1=Monday..7=Sunday), null means no reminder set.
class SunanReminder {
  final int weekday;
  final TimeOfDay time;
  const SunanReminder({required this.weekday, required this.time});

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'hour': time.hour, 'minute': time.minute};

  static SunanReminder fromJson(Map<String, dynamic> j) => SunanReminder(
        weekday: j['weekday'] as int,
        time: TimeOfDay(hour: j['hour'] as int, minute: j['minute'] as int),
      );
}

/// Persisted per-surah reminders for the 4 P2‑12 surahs — independent of
/// each other, each its own `zonedSchedule`.
class SunanSuwarStore extends StateNotifier<Map<int, SunanReminder>> {
  SunanSuwarStore(this._prefs) : super(_restore(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'sunan_suwar_reminders_v1';

  static Map<int, SunanReminder> _restore(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) =>
          MapEntry(int.parse(k), SunanReminder.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(state.map((k, v) => MapEntry('$k', v.toJson()))),
    );
  }

  /// Distinct, stable notification id per surah — offset well clear of
  /// every other notification id range this app already uses.
  int _reminderId(int surahId) => 8000 + surahId;

  Future<void> setReminder(
    int surahId,
    String surahLabel,
    SunanReminder reminder,
  ) async {
    state = {...state, surahId: reminder};
    await _persist();
    await SunanSuwarReminderService.instance.schedule(
      id: _reminderId(surahId),
      weekday: reminder.weekday,
      hour: reminder.time.hour,
      minute: reminder.time.minute,
      title: surahLabel,
      payload: '$surahId',
    );
  }

  Future<void> clearReminder(int surahId) async {
    final next = {...state}..remove(surahId);
    state = next;
    await _persist();
    await SunanSuwarReminderService.instance.cancel(_reminderId(surahId));
  }
}

final sunanSuwarStoreProvider =
    StateNotifierProvider<SunanSuwarStore, Map<int, SunanReminder>>((ref) {
  return SunanSuwarStore(ref.watch(sharedPrefsProvider));
});
