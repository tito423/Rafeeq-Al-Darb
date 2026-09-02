import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/sciences_repository.dart';

const _kTranslationLangKey = 'reader_translation_lang_v1';

/// The reader's single selected translation language (WORK_QUEUE Stage 4:
/// "Add a language selector so the reader picks which translation shows,
/// persisted" — the ayah card used to show en/fr/ur all stacked at once).
class SelectedTranslationLang extends StateNotifier<String> {
  SelectedTranslationLang() : super(SciencesRepository.supportedTranslationLangs.first) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTranslationLangKey);
    if (saved != null && SciencesRepository.supportedTranslationLangs.contains(saved)) {
      state = saved;
    }
  }

  Future<void> select(String lang) async {
    if (lang == state) return;
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTranslationLangKey, lang);
  }
}

final selectedTranslationLangProvider =
    StateNotifierProvider<SelectedTranslationLang, String>(
        (ref) => SelectedTranslationLang());
