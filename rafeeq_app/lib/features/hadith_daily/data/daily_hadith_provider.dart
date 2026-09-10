import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/hadith_repository.dart';

/// One randomly-picked hadith (+ its book) for the Home card (P2‑13).
class DailyHadith {
  final HadithItem item;
  final HadithBook book;
  const DailyHadith(this.item, this.book);
}

/// Picks [DailyHadith] once per app launch and holds it — a provider's state
/// is created fresh exactly once per app process and survives rebuilds/tab
/// switches within it, which is exactly "re-roll on a fresh launch" without
/// any extra persistence: killing and reopening the app makes a new
/// container, which calls `build()` again, which picks again. `reroll()` is
/// the "حديث آخر" button; it does not touch app-launch behavior.
///
/// `null` state means "no pick yet" — either `hadith.db` isn't downloaded
/// (or is stale, see `DbHelper.openDownloaded`'s doc) or it failed to load;
/// the card tells these apart via `hadithRepositoryProvider` directly rather
/// than guessing from this being null.
class DailyHadithNotifier extends AsyncNotifier<DailyHadith?> {
  @override
  Future<DailyHadith?> build() async {
    final first = await _pick();
    if (first != null) _remember(first);
    return first;
  }

  /// P3‑36: this used to set `state = const AsyncLoading()` before picking —
  /// harmless in isolation, but the Home card's `AsyncValue.when()` reacted
  /// to it by collapsing the whole card (several lines of hadith text) down
  /// to a 60px spinner box for the moment the pick took, then back up once
  /// it resolved. On a scrolled-down Home screen that height swing shifted
  /// everything below the card, which read as "the screen jumps to the
  /// top". `_pick()` is a fast local SQLite lookup, so there's nothing
  /// worth showing a loading state for — go straight from the old value to
  /// the new one; the card's UI shows its own small in-button spinner
  /// instead (`daily_hadith_card.dart`'s `_rerolling`), without touching
  /// this provider's state or the card's layout at all.
  Future<void> reroll() async {
    final picked = await AsyncValue.guard(_pick);
    state = picked;
    final value = picked.valueOrNull;
    if (value != null) _remember(value);
  }

  // ── Swipe navigation ───────────────────────────────────────────
  // The owner asked for the card to be flickable — «خليه فيه إمكانية تنقل».
  // A refresh button alone can only ever go forward, and a random pick with
  // no memory cannot go back at all: swiping away from a hadith you were
  // still reading would lose it for good. So the picks are kept in order and
  // the swipe walks that list, appending a fresh one only at its end.

  final List<DailyHadith> _history = [];
  int _index = -1;

  void _remember(DailyHadith value) {
    // Trim anything ahead of the cursor first, so going back and then
    // forward again does not interleave two different futures.
    if (_index >= 0 && _index < _history.length - 1) {
      _history.removeRange(_index + 1, _history.length);
    }
    _history.add(value);
    _index = _history.length - 1;
  }

  /// True when [previous] would actually move — the card uses it to know
  /// whether a swipe should do anything at all.
  bool get hasPrevious => _index > 0;

  Future<void> next() async {
    if (_index >= 0 && _index < _history.length - 1) {
      _index++;
      state = AsyncData(_history[_index]);
      return;
    }
    await reroll();
  }

  void previous() {
    if (!hasPrevious) return;
    _index--;
    state = AsyncData(_history[_index]);
  }

  Future<DailyHadith?> _pick() async {
    final repo = await ref.read(hadithRepositoryProvider.future);
    if (repo == null) return null;
    final item = await repo.randomDailyHadith();
    if (item == null) return null;
    final books = await repo.books();
    final book = books.firstWhere(
      (b) => b.id == item.bookId,
      orElse: () => books.first,
    );
    return DailyHadith(item, book);
  }
}

final dailyHadithProvider =
    AsyncNotifierProvider<DailyHadithNotifier, DailyHadith?>(
        DailyHadithNotifier.new);
