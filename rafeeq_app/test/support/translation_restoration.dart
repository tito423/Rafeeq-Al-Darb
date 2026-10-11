import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/translation_lang_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const translationRestoreCases = <String, Future<void> Function()>{
  'Turkish pick survives reopening with the same UI language': _turkish,
  'every catalog language survives restoration': _catalog,
  'changed UI language follows while Arabic keeps the choice': _locale,
  'explicit pick during restoration wins after locale following': _concurrent,
  'rapid UI changes preserve the last requested language': _rapid,
  'disposing during restoration does not write dead notifier state': _disposed,
  'unknown saved language keeps a valid default without deleting preferences':
      _unknown,
  'first run still follows a non-Arabic UI language': _firstRun,
};

const _langKey = 'reader_translation_lang_v1';
const _localeKey = 'reader_translation_locale_v1';

Future<SharedPreferences> _seed(String? language, String locale) async {
  final prefs = await SharedPreferences.getInstance();
  if (language == null) {
    await prefs.remove(_langKey);
  } else {
    await prefs.setString(_langKey, language);
  }
  await prefs.setString(_localeKey, locale);
  return prefs;
}

Future<void> cleanTranslationTestPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_langKey);
  await prefs.remove(_localeKey);
}

Future<void> _saved(SharedPreferences prefs, String lang, String locale) async {
  await prefs.reload();
  expect(prefs.getString(_langKey), lang);
  expect(prefs.getString(_localeKey), locale);
}

Future<void> _turkish() async {
  final prefs = await _seed(null, 'en');
  final first = SelectedTranslationLang();
  try {
    await first.select('tr');
    expect(first.state, 'tr');
    await _saved(prefs, 'tr', 'en');
  } finally {
    first.dispose();
  }
  final reopened = SelectedTranslationLang();
  try {
    await reopened.followAppLocale('en');
    expect(reopened.state, 'tr');
    await _saved(prefs, 'tr', 'en');
  } finally {
    reopened.dispose();
  }
}

Future<void> _catalog() async {
  final raw = await rootBundle.loadString(
    'assets/data/catalogs/quran_translations.json',
  );
  final catalog =
      ((jsonDecode(raw) as Map<String, dynamic>)['translations']
              as List<dynamic>)
          .cast<Map<String, dynamic>>();
  expect(
    catalog.any((entry) => entry['lang'] == 'tr' && entry['bundled'] == false),
    isTrue,
  );
  for (final entry in catalog) {
    final lang = entry['lang'] as String;
    final prefs = await _seed(lang, 'en');
    final restored = SelectedTranslationLang();
    try {
      await restored.followAppLocale('en');
      expect(restored.state, lang, reason: 'Catalog language $lang');
      await _saved(prefs, lang, 'en');
    } finally {
      restored.dispose();
    }
  }
}

Future<void> _locale() async {
  final prefs = await _seed('tr', 'en');
  final selected = SelectedTranslationLang();
  try {
    await selected.followAppLocale('en');
    expect(selected.state, 'tr');
    await selected.followAppLocale('fr');
    expect(selected.state, 'fr');
    await selected.followAppLocale('ar');
    expect(selected.state, 'fr');
    await _saved(prefs, 'fr', 'ar');
  } finally {
    selected.dispose();
  }
}

Future<void> _concurrent() async {
  final prefs = await _seed('tr', 'en');
  final selected = SelectedTranslationLang();
  try {
    final follow = selected.followAppLocale('fr');
    final pick = selected.select('ja');
    await Future.wait([follow, pick]);
    expect(selected.state, 'ja');
    await _saved(prefs, 'ja', 'fr');
  } finally {
    selected.dispose();
  }
  final reopened = SelectedTranslationLang();
  try {
    await reopened.followAppLocale('fr');
    expect(reopened.state, 'ja');
  } finally {
    reopened.dispose();
  }
}

Future<void> _rapid() async {
  final prefs = await _seed('en', 'en');
  final selected = SelectedTranslationLang();
  try {
    await Future.wait([
      selected.followAppLocale('fr'),
      selected.followAppLocale('es'),
      selected.followAppLocale('ru'),
    ]);
    expect(selected.state, 'ru');
    await _saved(prefs, 'ru', 'ru');
  } finally {
    selected.dispose();
  }
}

Future<void> _disposed() async {
  await _seed('fr', 'en');
  final selected = SelectedTranslationLang();
  final restoration = selected.followAppLocale('en');
  selected.dispose();
  await restoration;
}

Future<void> _unknown() async {
  final prefs = await _seed('not-a-catalog-language', 'en');
  final selected = SelectedTranslationLang();
  try {
    await selected.followAppLocale('en');
    expect(selected.state, 'en');
    await _saved(prefs, 'not-a-catalog-language', 'en');
  } finally {
    selected.dispose();
  }
}

Future<void> _firstRun() async {
  final prefs = await _seed(null, 'en');
  await prefs.remove(_localeKey);
  final selected = SelectedTranslationLang();
  try {
    await selected.followAppLocale('es');
    expect(selected.state, 'es');
    await _saved(prefs, 'es', 'es');
  } finally {
    selected.dispose();
  }
}
