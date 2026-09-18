import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/fasting_reminder_service.dart';
import '../../adhan/data/prayer_adjustments_provider.dart';
import 'sunnah_fasting.dart';

/// The reader's sunnah-fasting reminder settings. Both off until asked for:
/// an app does not start sending reminders because it was installed.
class FastingReminderSettings {
  final bool mondayThursday;
  final bool whiteDays;

  /// When, on the evening before, the reminder comes. 21:00 by default —
  /// after Isha in most places, early enough to intend the fast and set an
  /// alarm for suhur.
  final int hour;
  final int minute;

  const FastingReminderSettings({
    this.mondayThursday = false,
    this.whiteDays = false,
    this.hour = 21,
    this.minute = 0,
  });

  bool get anyOn => mondayThursday || whiteDays;

  FastingReminderSettings copyWith({
    bool? mondayThursday,
    bool? whiteDays,
    int? hour,
    int? minute,
  }) =>
      FastingReminderSettings(
        mondayThursday: mondayThursday ?? this.mondayThursday,
        whiteDays: whiteDays ?? this.whiteDays,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class FastingReminderNotifier extends StateNotifier<FastingReminderSettings> {
  FastingReminderNotifier() : super(const FastingReminderSettings()) {
    loaded = _restore();
  }

  late final Future<FastingReminderSettings> loaded;

  static const _kMonThu = 'fasting_reminder_mon_thu_v1';
  static const _kWhite = 'fasting_reminder_white_v1';
  static const _kHour = 'fasting_reminder_hour_v1';
  static const _kMinute = 'fasting_reminder_minute_v1';

  Future<FastingReminderSettings> _restore() async {
    final p = await SharedPreferences.getInstance();
    final s = FastingReminderSettings(
      mondayThursday: p.getBool(_kMonThu) ?? false,
      whiteDays: p.getBool(_kWhite) ?? false,
      hour: p.getInt(_kHour) ?? 21,
      minute: p.getInt(_kMinute) ?? 0,
    );
    if (mounted) state = s;
    return s;
  }

  Future<void> update(FastingReminderSettings s) async {
    state = s;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMonThu, s.mondayThursday);
    await p.setBool(_kWhite, s.whiteDays);
    await p.setInt(_kHour, s.hour);
    await p.setInt(_kMinute, s.minute);
  }
}

final fastingReminderProvider =
    StateNotifierProvider<FastingReminderNotifier, FastingReminderSettings>(
        (ref) => FastingReminderNotifier());

/// Plans and arms the next two months from the current settings and the
/// reader's Hijri correction. Called on launch, on a language change, and
/// whenever a setting changes.
Future<void> rearmFastingReminders(
  FastingReminderSettings s,
  int hijriOffsetDays,
) async {
  final plan = s.anyOn
      ? planFastingReminders(
          now: DateTime.now(),
          hijriOffsetDays: hijriOffsetDays,
          mondayThursday: s.mondayThursday,
          whiteDays: s.whiteDays,
          hour: s.hour,
          minute: s.minute,
        )
      : const <FastingReminder>[];
  await FastingReminderService.instance.reschedule(plan);
}

/// [rearmFastingReminders] with the values read from [ref].
Future<void> rearmFastingFrom(WidgetRef ref) => rearmFastingReminders(
      ref.read(fastingReminderProvider),
      ref.read(prayerAdjustmentsProvider).hijriOffsetDays,
    );
