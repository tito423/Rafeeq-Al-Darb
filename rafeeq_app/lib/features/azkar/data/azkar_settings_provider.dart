import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/services/azkar_reminder_service.dart';

/// Haptics-on-tap + optional morning/evening adhkar reminders — both real
/// persisted user choices. Neither reminder has a default time: WORK_QUEUE
/// Stage 3 explicitly calls out hardcoded 05:00/16:30 reminders as something
/// to not repeat, so a reminder is simply off (null) until the user sets one.
class AzkarSettings {
  final bool haptics;
  final TimeOfDay? morningReminder;
  final TimeOfDay? eveningReminder;

  const AzkarSettings({
    required this.haptics,
    required this.morningReminder,
    required this.eveningReminder,
  });

  AzkarSettings copyWith({
    bool? haptics,
    TimeOfDay? Function()? morningReminder,
    TimeOfDay? Function()? eveningReminder,
  }) =>
      AzkarSettings(
        haptics: haptics ?? this.haptics,
        morningReminder:
            morningReminder != null ? morningReminder() : this.morningReminder,
        eveningReminder:
            eveningReminder != null ? eveningReminder() : this.eveningReminder,
      );
}

class AzkarSettingsNotifier extends StateNotifier<AzkarSettings> {
  AzkarSettingsNotifier(this._prefs)
      : super(AzkarSettings(
          haptics: _prefs.getBool(_hapticsKey) ?? true,
          morningReminder: _parse(_prefs.getString(_morningKey)),
          eveningReminder: _parse(_prefs.getString(_eveningKey)),
        )) {
    // Re-arm any reminder that was already set, in case the app was
    // reinstalled or the exact alarm was lost — harmless no-op otherwise.
    if (state.morningReminder != null) {
      AzkarReminderService.instance.scheduleMorning(
          state.morningReminder!.hour, state.morningReminder!.minute);
    }
    if (state.eveningReminder != null) {
      AzkarReminderService.instance.scheduleEvening(
          state.eveningReminder!.hour, state.eveningReminder!.minute);
    }
  }

  final SharedPreferences _prefs;

  static const _hapticsKey = 'azkar_haptics_v1';
  static const _morningKey = 'azkar_morning_reminder_v1';
  static const _eveningKey = 'azkar_evening_reminder_v1';

  static TimeOfDay? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> setHaptics(bool enabled) async {
    state = state.copyWith(haptics: enabled);
    await _prefs.setBool(_hapticsKey, enabled);
  }

  Future<void> setMorningReminder(TimeOfDay? time) async {
    state = state.copyWith(morningReminder: () => time);
    if (time == null) {
      await _prefs.remove(_morningKey);
      await AzkarReminderService.instance.cancelMorning();
    } else {
      await _prefs.setString(_morningKey, _fmt(time));
      await AzkarReminderService.instance.scheduleMorning(time.hour, time.minute);
    }
  }

  Future<void> setEveningReminder(TimeOfDay? time) async {
    state = state.copyWith(eveningReminder: () => time);
    if (time == null) {
      await _prefs.remove(_eveningKey);
      await AzkarReminderService.instance.cancelEvening();
    } else {
      await _prefs.setString(_eveningKey, _fmt(time));
      await AzkarReminderService.instance.scheduleEvening(time.hour, time.minute);
    }
  }
}

final azkarSettingsProvider =
    StateNotifierProvider<AzkarSettingsNotifier, AzkarSettings>((ref) {
  return AzkarSettingsNotifier(ref.watch(sharedPrefsProvider));
});
