import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/hadeethenc_repository.dart';
import '../../hadeethenc/data/hadeethenc_providers.dart';

/// One hadith for the Home card, from the Hadeeth Encyclopaedia and nowhere
/// else.
///
/// «خلّي كارت الحديث بشروحه مرتبط بالموسوعة بس». The card used to fall back to
/// the nine books when the Encyclopaedia pack was not downloaded — which meant
/// a card with no explanation and a «نزّل مكتبة الحديث» prompt. The packs ship
/// inside the app now (see `hadeethEncRepositoryProvider`), so there is no
/// state in which the Encyclopaedia is missing and nothing to fall back to.
class DailyHadith {
  final HadeethItem encyclopaedia;

  const DailyHadith(this.encyclopaedia);

  String get arabic => encyclopaedia.hadeethAr.isNotEmpty
      ? encyclopaedia.hadeethAr
      : encyclopaedia.hadeeth;

  String get explanation => encyclopaedia.explanation;
}

/// Picks [DailyHadith] once per app launch and holds it — a provider's state
/// is created fresh exactly once per app process and survives rebuilds/tab
/// switches within it, which is exactly "re-roll on a fresh launch" without
/// any extra persistence. `reroll()` is the "حديث آخر" button.
///
/// `null` state means the pack would not open — a real failure, which the
/// card shows as one.
class DailyHadithNotifier extends AsyncNotifier<DailyHadith?> {
  @override
  Future<DailyHadith?> build() async {
    final first = await _pick();
    if (first != null) _remember(first);
    return first;
  }

  /// P3‑36: no `AsyncLoading` between picks — the card would collapse to a
  /// spinner and shift everything below it. The card shows its own small
  /// in-button spinner instead.
  Future<void> reroll() async {
    final picked = await AsyncValue.guard(_pick);
    state = picked;
    final value = picked.valueOrNull;
    if (value != null) _remember(value);
  }

  // ── Swipe navigation ───────────────────────────────────────────
  // «خليه فيه إمكانية تنقل». The picks are kept in order and the swipe walks
  // that list, appending a fresh one only at its end, so swiping back never
  // loses a hadith that was still being read.

  final List<DailyHadith> _history = [];
  int _index = -1;

  void _remember(DailyHadith value) {
    if (_index >= 0 && _index < _history.length - 1) {
      _history.removeRange(_index + 1, _history.length);
    }
    _history.add(value);
    _index = _history.length - 1;
  }

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

  /// A random explained hadith. An entry with no Arabic text or no
  /// explanation is passed over rather than shown bare — the card promises an
  /// explanation. Measured over the bundled packs: Arabic, English, French,
  /// Portuguese and Russian explain every record; Spanish leaves 11 of 1,955
  /// and Urdu 5 of 2,220 without one.
  Future<DailyHadith?> _pick() async {
    final repo = await ref.read(hadeethEncRepositoryProvider.future);
    if (repo == null) return null;
    for (var attempt = 0; attempt < 8; attempt++) {
      final hit = await repo.random();
      if (hit == null) return null;
      if (hit.hadeethAr.trim().isEmpty && hit.hadeeth.trim().isEmpty) continue;
      if (hit.explanation.trim().isEmpty) continue;
      return DailyHadith(hit);
    }
    return null;
  }
}

final dailyHadithProvider =
    AsyncNotifierProvider<DailyHadithNotifier, DailyHadith?>(
        DailyHadithNotifier.new);
