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
}
