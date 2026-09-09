import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEveryMinutesKey = 'quote_reminder_every_minutes_v1';

/// How often the quote notification fires, in minutes. **0 means off**, the
/// same contract the three prayer reminders use, so there is no second flag
/// to keep in sync with the interval.
///
/// The owner asked for «كل مدة يحددها المالك (نص ساعة أو أكتر أو أقل)», so
/// the choices bracket half an hour on both sides rather than starting there.
/// A free-form minute counter was not used: the notification window is
/// re-armed in whole slots (`QuoteReminderService.slotCount`) and a handful
/// of named intervals is both easier to tap and easier to reason about.
const List<int> kQuoteIntervals = [15, 30, 60, 120, 180, 360, 720];

/// Off until the owner turns it on. A personal app does not start pushing
/// notifications at somebody because it was installed.
const int kQuoteIntervalDefault = 0;

class QuoteReminderSetting extends StateNotifier<int> {
  QuoteReminderSetting() : super(kQuoteIntervalDefault) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kEveryMinutesKey);
    if (saved != null && (saved == 0 || kQuoteIntervals.contains(saved))) {
      state = saved;
    }
  }

  Future<void> set(int everyMinutes) async {
    final v = everyMinutes <= 0
        ? 0
        : (kQuoteIntervals.contains(everyMinutes)
            ? everyMinutes
            : kQuoteIntervals.first);
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEveryMinutesKey, v);
  }
}

final quoteReminderProvider =
    StateNotifierProvider<QuoteReminderSetting, int>((ref) {
  return QuoteReminderSetting();
});
