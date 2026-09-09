import 'package:flutter/widgets.dart';

/// The seven locales the app ships, in one place.
///
/// There were two hand-maintained lists: `main.dart`'s and the one in
/// `adhan_entry.dart`, which boots the full-screen Adhan alert as its own
/// miniature Flutter app. They had drifted - the alert's list held **six**
/// locales, missing Urdu, so an Urdu user's adhan alert fell back to Arabic
/// while every other screen was in Urdu. Both read from here now, and
/// `test/supported_locales_test.dart` asserts this list matches the
/// translation files actually shipped in `assets/translations`.
const kSupportedLocales = <Locale>[
  Locale('ar'),
  Locale('en'),
  Locale('es'),
  Locale('ru'),
  Locale('pt'),
  Locale('fr'),
  // Urdu: RTL like Arabic, so the whole shell mirrors the same way the
  // Arabic locale already does - nothing special-cased for it.
  Locale('ur'),
];
