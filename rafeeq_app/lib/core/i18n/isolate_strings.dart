import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Translations for code that runs where `.tr()` cannot work.
///
/// `.tr()` resolves through `Localization.instance`, which only exists once
/// the `EasyLocalization` widget has built. Anything that runs outside that
/// widget tree — a `background_downloader` callback in a headless isolate, a
/// service configured before the first frame — gets the **key itself** back,
/// silently. That is not a hypothetical: the owner's own screenshot of the
/// notification shade reads
///
///     notif.dl_recit_running_title
///     notif.dl_recit_running_body
///
/// in place of «تنزيل التلاوة». Trap #8 says a missing key renders as the raw
/// key on screen; this is the same failure from the other direction — the key
/// is present in all seven files and still rendered raw.
///
/// So this reads the same JSON asset `easy_localization` reads, straight off
/// the root bundle, which works in any Flutter isolate. **One source of
/// truth** — no second copy of the strings to drift out of sync, which is the
/// whole reason it is not simply a hardcoded fallback map.
class IsolateStrings {
  IsolateStrings._();

  static final Map<String, Map<String, dynamic>> _cache = {};

  /// The key `easy_localization` persists the chosen locale under when
  /// `saveLocale: true` — see `main.dart`.
  static const String _prefsLocaleKey = 'locale';

  /// Matches `fallbackLocale` in `main.dart`. If that changes, change this.
  static const String fallbackLocale = 'ar';

  static Future<Map<String, dynamic>> _load(String locale) async {
    final cached = _cache[locale];
    if (cached != null) return cached;
    try {
      final raw =
          await rootBundle.loadString('assets/translations/$locale.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache[locale] = map;
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// The locale the user picked, read from storage rather than from the
  /// widget tree so it is available in a headless isolate too.
  static Future<String> currentLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsLocaleKey);
      if (saved != null && saved.isNotEmpty) {
        // Stored as a full locale ("ar", "pt_BR"); the files are language-only.
        return saved.split(RegExp('[_-]')).first;
      }
    } catch (_) {}
    return fallbackLocale;
  }

  /// [key] is dotted exactly as in the JSON, e.g. `notif.dl_recit_running_title`.
  ///
  /// Falls back to [fallbackLocale] and, only if that fails too, returns the
  /// key — the same last resort `.tr()` has, so nothing new can go missing
  /// here that would not have gone missing there.
  static Future<String> tr(String key, {String? locale}) async {
    final lang = locale ?? await currentLocale();
    for (final candidate in {lang, fallbackLocale}) {
      final value = _lookup(await _load(candidate), key);
      if (value != null) return value;
    }
    return key;
  }

  static String? _lookup(Map<String, dynamic> map, String key) {
    dynamic node = map;
    for (final part in key.split('.')) {
      if (node is! Map<String, dynamic>) return null;
      node = node[part];
    }
    return node is String ? node : null;
  }

  /// Clears the parsed-asset cache. Call it when the locale changes so the
  /// next read picks up the new file rather than the one already parsed.
  static void forgetCache() => _cache.clear();
}
