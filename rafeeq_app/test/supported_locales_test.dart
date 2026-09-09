import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/i18n/supported_locales.dart';

/// `kSupportedLocales` must list exactly the translation files that ship.
///
/// This exists because two hand-maintained lists drifted: `main.dart` declared
/// seven locales and `adhan_entry.dart` — the full-screen Adhan alert, which
/// boots as its own miniature Flutter app — declared **six**, missing Urdu. An
/// Urdu user's adhan alert fell back to Arabic while every other screen in the
/// app was in Urdu, and nothing failed: `flutter analyze` sees two perfectly
/// valid lists. There is one list now, and this pins it to what is on disk.
void main() {
  test('kSupportedLocales matches assets/translations exactly', () {
    final onDisk = Directory('assets/translations')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.json'))
        .map((n) => n.substring(0, n.length - '.json'.length))
        .toSet();

    final declared = kSupportedLocales.map((l) => l.languageCode).toSet();

    expect(declared, onDisk);
    expect(kSupportedLocales.length, onDisk.length,
        reason: 'a duplicate Locale would make the two sets match anyway');
  });

  /// The other setting these two roots have to agree on, and the other one
  /// that fails silently.
  ///
  /// `easy_localization` defaults `ignorePluralRules` to **true**, and then
  /// `.plural()` resolves only zero / one / two / other — every `few` and
  /// `many` a locale file carries is dead text. Russian showed «7277 хадиса»
  /// and «97 главы» on `emulator-5554`; both take the genitive plural, which
  /// is the `many` form. Arabic's «{} آيات» (few, 3–10) had never been
  /// reached either. Nothing warns: the key resolves, a string appears, and
  /// it is the wrong one.
  test('both app entry points turn the real plural rules on', () {
    for (final path in ['lib/main.dart', 'lib/adhan_entry.dart']) {
      final source = File(path).readAsStringSync();
      expect(source, contains('EasyLocalization('),
          reason: '$path no longer starts EasyLocalization — update this test');
      expect(source, contains('ignorePluralRules: false'),
          reason: '$path must pass ignorePluralRules: false, or `few` and '
              '`many` are silently ignored in every locale');
    }
  });
}
