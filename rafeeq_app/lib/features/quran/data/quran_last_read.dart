import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// Shared key for the Quran reader's last-open page.
const kQuranLastPageKey = 'quran_last_page';

/// Reactive wrapper around [kQuranLastPageKey] — `quran_screen.dart` calls
/// [set] on every page change, and `ContinueReadingCard` on Home watches
/// this provider instead of reading `SharedPreferences` directly.
///
/// **A real bug found live (P3‑4), not by static review:** the first
/// version of this had `ContinueReadingCard` read the raw pref value via
/// `ref.watch(sharedPrefsProvider).getInt(...)` on every build. That looks
/// reactive but isn't: `AppShell` keeps every tab mounted in an
/// `IndexedStack`, so switching *back* to Home doesn't rebuild it — the
/// card kept showing whatever it saw on its *first* build (usually "never
/// read anything yet"), even after the user read several pages of Quran
/// in the same session and returned. Confirmed live on the emulator: read
/// page 77, switched back to Home, the card still didn't appear. A
/// `StateNotifierProvider` fixes this the normal Riverpod way — `set()`
/// updates real provider *state*, which `ref.watch` in the always-mounted
/// `ContinueReadingCard` does react to, regardless of which tab is
/// currently visible.
class QuranLastPageNotifier extends StateNotifier<int?> {
  QuranLastPageNotifier(this._prefs) : super(_prefs.getInt(kQuranLastPageKey));

  final SharedPreferences _prefs;

  Future<void> set(int page) async {
    state = page;
    await _prefs.setInt(kQuranLastPageKey, page);
  }
}

final quranLastPageProvider =
    StateNotifierProvider<QuranLastPageNotifier, int?>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return QuranLastPageNotifier(prefs);
});
