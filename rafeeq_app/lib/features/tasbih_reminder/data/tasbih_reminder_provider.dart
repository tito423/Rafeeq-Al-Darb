import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/tasbih_reminder_service.dart';

/// Minutes between tasbih reminders; 0 = off (the same contract as the quote
/// reminder). Off until asked for.
const tasbihIntervals = <int>[60, 120, 180, 240, 360];

class TasbihReminderSetting extends StateNotifier<int> {
  TasbihReminderSetting() : super(0) {
    loaded = _restore();
  }

  late final Future<int> loaded;
  static const _key = 'tasbih_reminder_every_minutes_v1';

  Future<int> _restore() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_key) ?? 0;
    final ok = v == 0 || tasbihIntervals.contains(v) ? v : 0;
    if (mounted) state = ok;
    return ok;
  }

  Future<void> set(int minutes) async {
    state = minutes;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key, minutes);
  }
}

final tasbihReminderProvider =
    StateNotifierProvider<TasbihReminderSetting, int>(
        (ref) => TasbihReminderSetting());

/// Re-arms with a rotation shifted by the day of the year, so each day starts
/// on a different dhikr.
Future<void> rearmTasbihReminders(int everyMinutes) {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return TasbihReminderService.instance
      .reschedule(everyMinutes: everyMinutes, shift: dayOfYear);
}
