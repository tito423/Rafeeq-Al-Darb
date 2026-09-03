import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/sciences_repository.dart';

const _kTafseerSourceKey = 'reader_tafseer_source_v1';

/// The ayah-sciences sheet's single selected tafsir source (P3‑33: the
/// tafsir tab used to stack every bundled source at once, with an optional
/// side-by-side "compare" layout the owner asked to remove — mirrors
/// `translation_lang_provider.dart`'s exact same "one persisted choice
/// instead of everything stacked" shape).
class SelectedTafseerSource extends StateNotifier<String> {
  SelectedTafseerSource() : super(SciencesRepository.tafseerSources.keys.first) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTafseerSourceKey);
    if (saved != null && SciencesRepository.tafseerSources.containsKey(saved)) {
      state = saved;
    }
  }

  Future<void> select(String source) async {
    if (source == state) return;
    state = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTafseerSourceKey, source);
  }
}

final selectedTafseerSourceProvider =
    StateNotifierProvider<SelectedTafseerSource, String>(
        (ref) => SelectedTafseerSource());
