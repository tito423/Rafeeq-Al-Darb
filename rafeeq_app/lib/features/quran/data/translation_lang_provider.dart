import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/sciences_repository.dart';

const _kTranslationLangKey = 'reader_translation_lang_v1';

/// The app language the current [_kTranslationLangKey] value was aligned to.
/// See [SelectedTranslationLang.followAppLocale] for why this exists.
const _kFollowedLocaleKey = 'reader_translation_locale_v1';

/// The reader's single selected translation language (WORK_QUEUE Stage 4:
/// "Add a language selector so the reader picks which translation shows,
/// persisted" — the ayah card used to show en/fr/ur all stacked at once).
///
/// P3‑57: it now **follows the app's language**, at the owner's request
/// («بعد اختيار لغة التطبيق خلي الترجمة تلقائيا للغة التطبيق المختارة»). The
/// bundled `quran_sciences.db` carries a complete translation — all 6,236
/// ayahs — in exactly the app's six non-Arabic locales (en, fr, ur, es, ru,
/// pt), so every UI language a reader can pick has a real translation behind
/// it and nothing has to be guessed.
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

  /// Align the translation with the app's language.
  ///
  /// Called whenever the app rebuilds with a locale, so it fires on the very
  /// first run (giving a fresh Spanish install the Spanish translation rather
  /// than English) and again each time the reader changes the app language.
  ///
  /// It deliberately does **not** fire on every build: the app locale the
  /// current choice belongs to is remembered, and only a *change* of app
  /// language moves the translation. That is what keeps an explicit pick —
  /// an Arabic-reading user who wants the French translation, say — from being
  /// undone on the next frame.
  ///
  /// Arabic is not one of the choices, because a translation *into* Arabic is
  /// not a thing this app has or needs: on an Arabic UI the previous choice
  /// stands.
  Future<void> followAppLocale(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kFollowedLocaleKey) == localeCode) return;
    await prefs.setString(_kFollowedLocaleKey, localeCode);
    if (!SciencesRepository.supportedTranslationLangs.contains(localeCode)) {
      return; // 'ar' — keep whatever the reader already had
    }
    if (localeCode == state) return;
    state = localeCode;
    await prefs.setString(_kTranslationLangKey, localeCode);
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
