import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The About card's version badge and `pubspec.yaml` must agree.
///
/// THE DEFECT THIS EXISTS FOR, MEASURED IN THE REPOSITORY.
/// `AboutScreen.appVersion` was a hand-typed constant reading `3.1.0` while
/// `pubspec.yaml` said `3.19.0+18` — eighteen releases of drift, invisible to
/// `flutter analyze` because a stale string is a perfectly valid string. It is
/// the same defect §2.3 of CLAUDE.md already records once: «a release tagged
/// v3.2.0 while the About card said 3.0.0 shipped once».
///
/// Every other figure on that screen is now counted from the catalogue it
/// describes, so it cannot go stale. The version is the one number the app
/// cannot count from anything it carries at runtime, so it is pinned here
/// instead: bump `pubspec.yaml` without bumping the constant and this fails.
void main() {
  test('AboutScreen.appVersion equals pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
            multiLine: true)
        .firstMatch(pubspec);
    expect(declared, isNotNull, reason: 'pubspec.yaml has no version:');

    final about =
        File('lib/features/settings/presentation/screens/about_screen.dart')
            .readAsStringSync();
    final shown = RegExp(r"appVersion\s*=\s*'([^']+)'").firstMatch(about);
    expect(shown, isNotNull,
        reason: 'AboutScreen no longer declares appVersion');

    expect(
      shown!.group(1),
      declared!.group(1),
      reason: 'the About card would show a version the app is not. '
          'Bump AboutScreen.appVersion with pubspec.yaml.',
    );
  });

  test('every number on the About screen is read from a catalogue', () {
    final about =
        File('lib/features/settings/presentation/screens/about_screen.dart')
            .readAsStringSync();
    // The sources the counts come from. If one of these disappears, a figure
    // has probably gone back to being typed by hand.
    for (final source in const [
      'mushafEditionsProvider',
      'quranTranslationCatalogProvider',
      'recitersProvider',
      'adhanCatalogProvider',
      'kPrayerCalculationMethods.length',
      'libraryBookCatalog.length',
      'islamicChannels.length',
      'kSupportedLocales.length',
      'repo?.counts()',
    ]) {
      expect(about.contains(source), isTrue,
          reason: '$source is no longer what the About screen counts');
    }

    // A literal count written into a locale file is the thing this screen
    // stopped doing; these sentences take their number as an argument now.
    for (final locale in const ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final about = json['about'] as Map<String, dynamic>;
      for (final key in const [
        'f_quran',
        'f_quran_desc',
        'f_translations',
        'f_audio_desc',
        'f_prayer_desc',
        'f_hadith',
        'f_hadith_desc',
        'f_library',
        'f_library_desc',
        'f_locales',
      ]) {
        expect(about[key], isNotNull, reason: '$locale is missing about.$key');
        expect((about[key] as String).contains('{}'), isTrue,
            reason: '$locale/about.$key states its count instead of taking '
                'it as an argument');
      }
    }
  });
}
