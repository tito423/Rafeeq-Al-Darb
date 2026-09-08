import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// Manual corrections a user applies on top of the calculated values.
///
/// Both exist because calculation and local practice legitimately disagree:
/// the Hijri date is announced by moon sighting and commonly runs a day either
/// side of any arithmetic calendar, and a local mosque's iqamah often differs
/// from the astronomical time by a few minutes. Rather than pretend the
/// computed value is authoritative, the reader can nudge it to match what they
/// actually follow.
///
/// Offsets are stored, never absolute values — so they keep applying as the
/// days roll over instead of freezing the app on one corrected date.
class PrayerAdjustments {
  /// Whole days added to the computed Hijri date, typically -2..+2.
  final int hijriOffsetDays;

  /// Minutes added per prayer, keyed by the same keys as [adhanPrayerKeys]
  /// plus `sunrise`. Typically -30..+30.
  final Map<String, int> minuteOffsets;

  const PrayerAdjustments({
    required this.hijriOffsetDays,
    required this.minuteOffsets,
  });

  int offsetFor(String prayerKey) => minuteOffsets[prayerKey] ?? 0;

  /// True when nothing has been changed from the calculated values — used to
  /// show an honest "calculated" vs "adjusted" state.
  bool get isPristine =>
      hijriOffsetDays == 0 && minuteOffsets.values.every((v) => v == 0);

  PrayerAdjustments copyWith({
    int? hijriOffsetDays,
    Map<String, int>? minuteOffsets,
  }) =>
      PrayerAdjustments(
        hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
        minuteOffsets: minuteOffsets ?? this.minuteOffsets,
      );
}

/// Every timing the manual editor can shift, in the order it displays them.
const adjustablePrayerKeys = [
  'fajr',
  'sunrise',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

class PrayerAdjustmentsNotifier extends StateNotifier<PrayerAdjustments> {
  PrayerAdjustmentsNotifier(this._prefs)
      : super(PrayerAdjustments(
          hijriOffsetDays: _prefs.getInt(_hijriKey) ?? 0,
          minuteOffsets: {
            for (final k in adjustablePrayerKeys)
              k: _prefs.getInt('$_minutePrefix$k') ?? 0,
          },
        ));

  final SharedPreferences _prefs;

  static const _hijriKey = 'prayer_hijri_offset_days_v1';
  static const _minutePrefix = 'prayer_minute_offset_v1_';

  Future<void> setHijriOffset(int days) async {
    final clamped = days.clamp(-3, 3);
    state = state.copyWith(hijriOffsetDays: clamped);
    await _prefs.setInt(_hijriKey, clamped);
  }

  Future<void> setMinuteOffset(String prayerKey, int minutes) async {
    final clamped = minutes.clamp(-60, 60);
    state = state.copyWith(
      minuteOffsets: {...state.minuteOffsets, prayerKey: clamped},
    );
    await _prefs.setInt('$_minutePrefix$prayerKey', clamped);
  }

  Future<void> resetAll() async {
    state = PrayerAdjustments(
      hijriOffsetDays: 0,
      minuteOffsets: {for (final k in adjustablePrayerKeys) k: 0},
    );
    await _prefs.remove(_hijriKey);
    for (final k in adjustablePrayerKeys) {
      await _prefs.remove('$_minutePrefix$k');
    }
  }
}

final prayerAdjustmentsProvider =
    StateNotifierProvider<PrayerAdjustmentsNotifier, PrayerAdjustments>((ref) {
  return PrayerAdjustmentsNotifier(ref.watch(sharedPrefsProvider));
});

/// Applies a minute offset to an "HH:mm" clock string, rolling correctly over
/// midnight in both directions. Returns the input unchanged if it isn't a
/// parseable time (an empty/failed fetch), so a bad value is never turned into
/// a confidently wrong one.
String applyMinuteOffset(String hhmm, int minutes) {
  if (minutes == 0) return hhmm;
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  var total = (h * 60 + m + minutes) % (24 * 60);
  if (total < 0) total += 24 * 60;
  final hh = (total ~/ 60).toString().padLeft(2, '0');
  final mm = (total % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}
