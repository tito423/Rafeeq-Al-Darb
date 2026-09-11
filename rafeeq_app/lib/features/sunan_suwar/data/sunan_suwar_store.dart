import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/sunan_suwar_reminder_service.dart';

/// One surah's reminder: `weekday` is Dart's `DateTime.weekday`
/// (1=Monday..7=Sunday), null means no reminder set.
class SunanReminder {
  /// Dart `DateTime.weekday` values (1 = Monday … 7 = Sunday). «مش بيعطيني
  /// إمكانية اختيار أكتر من يوم» — a reminder used to hold exactly one.
  final Set<int> weekdays;
  final TimeOfDay time;
  const SunanReminder({required this.weekdays, required this.time});

  Map<String, dynamic> toJson() => {
        'weekdays': (weekdays.toList()..sort()),
        'hour': time.hour,
        'minute': time.minute,
      };

  /// Reads both shapes: a reminder saved before 3.17.3 has one `weekday`.
  static SunanReminder fromJson(Map<String, dynamic> j) => SunanReminder(
        weekdays: {
          if (j['weekdays'] is List)
            for (final d in j['weekdays'] as List) (d as num).toInt()
          else if (j['weekday'] != null)
            (j['weekday'] as num).toInt(),
        },
        time: TimeOfDay(hour: j['hour'] as int, minute: j['minute'] as int),
      );
}

/// The week in the order an Arabic calendar sets it, Saturday first.
const sunanWeekOrder = [6, 7, 1, 2, 3, 4, 5];

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
  /// The id a reminder had when it could fire on one day only.
  int _legacyId(int surahId) => 8000 + surahId;

  /// One alarm per day: 9000 + surah × 10 + weekday (at most 10147).
  int _dayId(int surahId, int weekday) => 9000 + surahId * 10 + weekday;

  Future<void> _cancelAll(int surahId) async {
    final service = SunanSuwarReminderService.instance;
    await service.cancel(_legacyId(surahId));
    for (var d = 1; d <= 7; d++) {
      await service.cancel(_dayId(surahId, d));
    }
  }

  Future<void> setReminder(
    int surahId,
    String surahLabel,
    SunanReminder reminder,
  ) async {
    state = {...state, surahId: reminder};
    await _persist();
    await _cancelAll(surahId);
    for (final weekday in reminder.weekdays) {
      await SunanSuwarReminderService.instance.schedule(
        id: _dayId(surahId, weekday),
        weekday: weekday,
        hour: reminder.time.hour,
        minute: reminder.time.minute,
        title: surahLabel,
        payload: '$surahId',
      );
    }
  }

  Future<void> clearReminder(int surahId) async {
    final next = {...state}..remove(surahId);
    state = next;
    await _persist();
    await _cancelAll(surahId);
  }
}

final sunanSuwarStoreProvider =
    StateNotifierProvider<SunanSuwarStore, Map<int, SunanReminder>>((ref) {
  return SunanSuwarStore(ref.watch(sharedPrefsProvider));
});
