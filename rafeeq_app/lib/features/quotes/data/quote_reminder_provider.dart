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

/// Whether the Home screen carries the «مقولة اليوم» card.
///
/// Separate from [quoteReminderProvider] on purpose: one is "interrupt me
/// every N minutes with a notification", the other is "keep a card on my Home
/// screen". A reader may well want the second without the first, and the
/// owner asked for the card to appear «لو متفعل من الإعدادات» — which means
/// there has to be a setting of its own to be enabled.
///
/// Defaults to on: it is a card, not an interruption.
class HomeQuoteCardSetting extends StateNotifier<bool> {
  HomeQuoteCardSetting() : super(true) {
    _restore();
  }

  static const _key = 'quotes.home_card_v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool on) async {
    state = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
  }
}

final homeQuoteCardProvider =
    StateNotifierProvider<HomeQuoteCardSetting, bool>((ref) {
  return HomeQuoteCardSetting();
});
